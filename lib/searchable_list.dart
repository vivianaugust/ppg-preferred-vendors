import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'sheet_data.dart';

class SearchableVendorList extends StatefulWidget {
  const SearchableVendorList({super.key});

  @override
  State<SearchableVendorList> createState() => _SearchableVendorListState();
}

class _SearchableVendorListState extends State<SearchableVendorList> {
  final TextEditingController _searchController = TextEditingController();
  late final SheetDataService _service;

  List<List<Object?>> _allRows = [];
  List<List<Object?>> _filteredRows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/ppg-vendors-d80304679d8f.json');

      _service = SheetDataService(
        spreadsheetUrl:
            'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      await _service.initializeFromJson(jsonString);

      final data = await _service.getSheetData('Main List');

      final cleaned = (data ?? [])
          .sublist(2)
          .where((row) => row.isNotEmpty &&
              row.any((cell) => cell.toString().trim().isNotEmpty))
          .toList();

      setState(() {
        _allRows = cleaned;
        _filteredRows = [...cleaned];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sheet: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRows = _allRows
          .where((row) => row.any(
              (cell) => cell.toString().toLowerCase().contains(query)))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Search')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search vendors...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredRows.isEmpty
                      ? const Center(child: Text('No results found.'))
                      : ListView.builder(
                          itemCount: _filteredRows.length,
                          itemBuilder: (context, index) {
                            final row = _filteredRows[index];
                            if (row.isEmpty ||
                                row[0].toString().trim().isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                title: Text(row[0].toString()),
                                subtitle: Text(
                                  row.skip(1)
                                      .map((e) => e.toString())
                                      .join(' • '),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
