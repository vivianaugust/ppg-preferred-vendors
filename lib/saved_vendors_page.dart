import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedVendorsPage extends StatelessWidget {
  const SavedVendorsPage({super.key});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_vendors')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final saved = snapshot.data?.docs ?? [];

          if (saved.isEmpty) {
            return const Center(child: Text('No vendors saved yet.'));
          }

          return ListView.builder(
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final vendor = saved[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(vendor['services'] ?? 'Unnamed Vendor'),
                  subtitle: Text(vendor['company'] ?? ''),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vendor['contactName'] != null)
                            Text('Contact: ${vendor['contactName']}'),
                          if (vendor['phone'] != null)
                            Text('Phone: ${vendor['phone']}'),
                          if (vendor['email'] != null && vendor['email'] != '')
                            Text('Email: ${vendor['email']}'),
                          if (vendor['website'] != null && vendor['website'] != '')
                            Text('Website: ${vendor['website']}'),
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
    );
  }
}
