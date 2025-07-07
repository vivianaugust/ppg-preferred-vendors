import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sheet_data.dart'; // Your custom class

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  List<List<Object?>> _vendors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVendorsFromSheet();
  }

  Future<void> _loadVendorsFromSheet() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/ppg-vendors-d80304679d8f.json');

      final sheetService = SheetDataService(
        spreadsheetUrl:
            'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      await sheetService.initializeFromJson(jsonString);
      final data = await sheetService.getSheetData('Main List');

      final cleaned = (data ?? [])
          .sublist(2)
          .where((row) => row.isNotEmpty &&
              row.any((cell) => cell.toString().trim().isNotEmpty))
          .toList();

      if (mounted) {
        setState(() {
          _vendors = cleaned;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sheet: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveVendor(List<Object?> row) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final vendorId = row[1]?.toString() ?? row[0]?.toString() ?? DateTime.now().toIso8601String();

    final saveRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_vendors')
        .doc(vendorId);

    await saveRef.set({
      'services': row[0]?.toString() ?? '',
      'company': row[1]?.toString() ?? '',
      'contactName': row[2]?.toString() ?? '',
      'phone': row[3]?.toString() ?? '',
      'email': row[4]?.toString() ?? '',
      'website': row[5]?.toString() ?? '',
      'address': row[6]?.toString() ?? '',
      'notes': row[7]?.toString() ?? '',
      'paymentInfo': row.length > 8 ? row[8]?.toString() ?? '' : '',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      body: ListView.builder(
        itemCount: _vendors.length,
        itemBuilder: (context, index) {
          final row = _vendors[index];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              title: Text(row[0]?.toString() ?? 'Unnamed Vendor'),
              subtitle: Text(row[1]?.toString() ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: () => _saveVendor(row),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (row.length > 2 && row[2] != null) Text('Contact: ${row[2]}'),
                      if (row.length > 3 && row[3] != null) Text('Phone: ${row[3]}'),
                      if (row.length > 4 && row[4] != null && row[4].toString().isNotEmpty)
                        Text('Email: ${row[4]}'),
                      if (row.length > 5 && row[5] != null && row[5].toString().isNotEmpty)
                        Text('Website: ${row[5]}'),
                      if (row.length > 6 && row[6] != null) Text('Address: ${row[6]}'),
                      if (row.length > 7 && row[7] != null) Text('Notes: ${row[7]}'),
                      if (row.length > 8 && row[8] != null) Text('Payment: ${row[8]}'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
