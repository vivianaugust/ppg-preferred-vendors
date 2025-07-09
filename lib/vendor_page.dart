import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sheet_data.dart';

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  final TextEditingController _searchController = TextEditingController();
  List<List<Object?>> _vendors = [];
  List<List<Object?>> _filteredVendors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadVendorsFromSheet();
  }

  Future<void> _loadVendorsFromSheet() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/ppg-vendors-d80304679d8f.json',
      );

      final sheetService = SheetDataService(
        spreadsheetUrl:
            'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      await sheetService.initializeFromJson(jsonString);
      final data = await sheetService.getSheetData('Main List');

      final cleaned = (data ?? [])
          .sublist(2)
          .where(
            (row) =>
                row.isNotEmpty &&
                row.any((cell) => cell.toString().trim().isNotEmpty),
          )
          .toList();

      if (mounted) {
        setState(() {
          _vendors = cleaned;
          _filteredVendors = [...cleaned];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sheet: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() => _applyFilters();

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredVendors = _vendors.where((row) {
        return row.any((cell) => cell.toString().toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _saveVendor(List<Object?> row) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final vendorId = row.length > 1 && row[1].toString().isNotEmpty
        ? row[1].toString()
        : row[0]?.toString() ?? DateTime.now().toIso8601String();

    final saveRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_vendors')
        .doc(vendorId);

    await saveRef.set({
      'services': row.length > 0 ? row[0]?.toString() ?? '' : '',
      'company': row.length > 1 ? row[1]?.toString() ?? '' : '',
      'contactName': row.length > 2 ? row[2]?.toString() ?? '' : '',
      'phone': row.length > 3 ? row[3]?.toString() ?? '' : '',
      'email': row.length > 4 ? row[4]?.toString() ?? '' : '',
      'website': row.length > 5 ? row[5]?.toString() ?? '' : '',
      'address': row.length > 6 ? row[6]?.toString() ?? '' : '',
      'notes': row.length > 7 ? row[7]?.toString() ?? '' : '',
      'paymentInfo': row.length > 8 ? row[8]?.toString() ?? '' : '',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor saved!')),
      );
    }
  }

  void _shareVendor(List<Object?> row) {
    final buffer = StringBuffer();
    for (var cell in row) {
      if (cell != null && cell.toString().trim().isNotEmpty) {
        buffer.writeln(cell.toString());
      }
    }
    Share.share(buffer.toString().trim());
  }

  Widget linkRow({
    required IconData icon,
    required String label,
    required String value,
    required String scheme,
  }) {
    final uri = Uri.tryParse(scheme.isEmpty ? value : '$scheme$value');
    return InkWell(
      onTap: () async {
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: $value',
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search vendors...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Expanded(
                    child: _filteredVendors.isEmpty
                        ? const Center(
                            child: Text(
                              'No vendors found.',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _filteredVendors.length,
                            itemBuilder: (context, index) {
                              final row = _filteredVendors[index];
                              final hasSubtitle = row.length > 0 &&
                                  row[0] != null &&
                                  row[0].toString().trim().isNotEmpty;

                              return Card(
                                margin: EdgeInsets.only(
                                  top: index == 0 ? 0 : 8,
                                  bottom: 8,
                                ),
                                child: ExpansionTile(
                                  tilePadding: hasSubtitle
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12)
                                      : const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                  title: Text(
                                    row.length > 1 ? row[1].toString() : '',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  subtitle: hasSubtitle
                                      ? Text(
                                          row[0].toString(),
                                          style: const TextStyle(fontSize: 14),
                                        )
                                      : null,
                                  childrenPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (row.length > 2 && row[2] != null)
                                          SelectableText(
                                            'Contact: ${row[2]}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        if (row.length > 3 && row[3] != null)
                                          linkRow(
                                            icon: Icons.phone,
                                            label: 'Phone',
                                            value: row[3].toString(),
                                            scheme: 'tel:',
                                          ),
                                        if (row.length > 4 && row[4] != null)
                                          linkRow(
                                            icon: Icons.email,
                                            label: 'Email',
                                            value: row[4].toString(),
                                            scheme: 'mailto:',
                                          ),
                                        if (row.length > 5 && row[5] != null)
                                          linkRow(
                                            icon: Icons.public,
                                            label: 'Website',
                                            value: row[5].toString(),
                                            scheme: '',
                                          ),
                                        if (row.length > 6 && row[6] != null)
                                          SelectableText(
                                            'Address: ${row[6].toString()}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        if (row.length > 7 && row[7] != null)
                                          SelectableText(
                                            'Notes: ${row[7].toString()}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        if (row.length > 8 && row[8] != null)
                                          SelectableText(
                                            'Payment info: ${row[8].toString()}',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            TextButton.icon(
                                              icon: const Icon(Icons.share),
                                              label: const Text('Share',
                                                  style:
                                                      TextStyle(fontSize: 14)),
                                              onPressed: () => _shareVendor(row),
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.bookmark_add_outlined),
                                              label: const Text('Save',
                                                  style:
                                                      TextStyle(fontSize: 14)),
                                              onPressed: () => _saveVendor(row),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
