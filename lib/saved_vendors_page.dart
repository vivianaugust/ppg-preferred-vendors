import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedVendorsPage extends StatefulWidget {
  const SavedVendorsPage({super.key});

  @override
  State<SavedVendorsPage> createState() => _SavedVendorsPageState();
}

class _SavedVendorsPageState extends State<SavedVendorsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _allVendors = [];
  List<QueryDocumentSnapshot> _filteredVendors = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVendors = _allVendors.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data.values.any((value) =>
            value.toString().toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _removeVendor(BuildContext context, String vendorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_vendors')
          .doc(vendorId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor removed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove vendor.')),
        );
      }
    }
  }

  void _shareVendor(Map<String, dynamic> vendor) {
    final buffer = StringBuffer();

    if (vendor['services'] != null) buffer.writeln(vendor['services']);
    if (vendor['company'] != null) buffer.writeln('Company: ${vendor['company']}');
    if (vendor['contactName'] != null) buffer.writeln('Contact: ${vendor['contactName']}');
    if (vendor['phone'] != null) buffer.writeln('Phone: ${vendor['phone']}');
    if (vendor['email'] != null) buffer.writeln('Email: ${vendor['email']}');
    if (vendor['website'] != null) buffer.writeln('Website: ${vendor['website']}');
    if (vendor['address'] != null) buffer.writeln('Address: ${vendor['address']}');
    if (vendor['notes'] != null) buffer.writeln('Notes: ${vendor['notes']}');
    if (vendor['paymentInfo'] != null) buffer.writeln('Payment: ${vendor['paymentInfo']}');

    Share.share(buffer.toString().trim());
  }

  Widget linkRow({required IconData icon, required String label, required String value, required String scheme}) {
    final uri = Uri.parse('$scheme$value');
    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(uri)) {
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
                ),
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be signed in to view saved vendors.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Vendors')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search saved vendors...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_vendors')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                _allVendors = docs;
                _filteredVendors = _searchController.text.isEmpty
                    ? docs
                    : _filteredVendors;

                if (_filteredVendors.isEmpty) {
                  return const Center(child: Text('No saved vendors found.'));
                }

                return ListView.builder(
                  itemCount: _filteredVendors.length,
                  itemBuilder: (context, index) {
                    final doc = _filteredVendors[index];
                    final vendor = doc.data() as Map<String, dynamic>;
                    final vendorId = doc.id;

                    final hasPrimary = vendor['services']?.toString().trim().isNotEmpty ?? false;
                    final hasSecondary = vendor['company']?.toString().trim().isNotEmpty ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(
                          hasPrimary
                              ? vendor['services']
                              : hasSecondary
                                  ? vendor['company']
                                  : 'Unnamed Vendor',
                        ),
                        subtitle: hasPrimary && hasSecondary
                            ? Text(vendor['company'])
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () => _shareVendor(vendor),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeVendor(context, vendorId),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vendor['contactName'] != null)
                                  Text('Contact: ${vendor['contactName']}'),
                                if (vendor['phone'] != null)
                                  linkRow(icon: Icons.phone, label: 'Phone', value: vendor['phone'], scheme: 'tel:'),
                                if (vendor['email'] != null)
                                  linkRow(icon: Icons.email, label: 'Email', value: vendor['email'], scheme: 'mailto:'),
                                if (vendor['website'] != null)
                                  linkRow(
                                    icon: Icons.language,
                                    label: 'Website',
                                    value: vendor['website'],
                                    scheme: vendor['website'].toString().startsWith('http') ? '' : 'https://',
                                  ),
                                if (vendor['address'] != null)
                                  Text('Address: ${vendor['address']}'),
                                if (vendor['notes'] != null)
                                  Text('Notes: ${vendor['notes']}'),
                                if (vendor['paymentInfo'] != null)
                                  Text('Payment: ${vendor['paymentInfo']}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
