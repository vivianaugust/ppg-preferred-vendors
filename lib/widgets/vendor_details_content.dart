// lib/widgets/vendor_details_content.dart
import 'package:flutter/material.dart';
import '../models/vendor.dart';
import 'link_row.dart'; // Import the new LinkRow widget

class VendorDetailsContent extends StatelessWidget {
  final Vendor vendor;

  const VendorDetailsContent({
    super.key,
    required this.vendor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vendor.contactName.isNotEmpty) Text('Contact: ${vendor.contactName}'),
          if (vendor.phone.isNotEmpty) LinkRow(icon: Icons.phone, text: vendor.phone, uri: Uri(scheme: 'tel', path: vendor.phone)),
          if (vendor.email.isNotEmpty) LinkRow(icon: Icons.email, text: vendor.email, uri: Uri(scheme: 'mailto', path: vendor.email)),
          if (vendor.website.isNotEmpty) LinkRow(icon: Icons.language, text: vendor.website, uri: Uri.parse(vendor.website.startsWith('http') ? vendor.website : 'https://${vendor.website}')),
          if (vendor.address.isNotEmpty) LinkRow(icon: Icons.location_on, text: vendor.address, uri: Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': Uri.encodeComponent(vendor.address)})),
          if (vendor.paymentInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.payment, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('Payment: ${vendor.paymentInfo}'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Actions: Favorite, Rate, Share will still be handled in the parent page due to state management
        ],
      ),
    );
  }
}