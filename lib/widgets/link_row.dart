// lib/widgets/link_row.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Uri uri;

  const LinkRow({
    super.key,
    required this.icon,
    required this.text,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Flexible(
            child: GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) { // Using context.mounted for async operations
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch $text')),
                    );
                  }
                }
              },
              child: Text(
                text,
                style: const TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}