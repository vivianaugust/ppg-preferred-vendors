// lib/widgets/rating_comment_section.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth to get user name

import '../models/vendor.dart'; // Import Vendor model

class RatingCommentSection extends StatefulWidget {
  final Vendor vendor;
  // UPDATED: The onSubmit callback now expects reviewerName (String) and timestamp (DateTime)
  final Function(int rating, String comment, String reviewerName, DateTime timestamp) onSubmit;

  const RatingCommentSection({
    super.key,
    required this.vendor,
    required this.onSubmit,
  });

  @override
  State<RatingCommentSection> createState() => _RatingCommentSectionState();
}

class _RatingCommentSectionState extends State<RatingCommentSection> {
  int _tempSelectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding( // Added padding for better spacing
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start
        children: [
          const Text(
            'Leave a Review:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8), // Spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _tempSelectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30, // Increased star size for better tap target
                ),
                onPressed: () {
                  setState(() {
                    _tempSelectedRating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16), // Spacing
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Your Comment (optional)', // Changed hintText to labelText
              border: OutlineInputBorder(),
              alignLabelWithHint: true, // Helps with multiline text field
            ),
            maxLines: 3,
            minLines: 1, // Allow text field to start at one line
            keyboardType: TextInputType.multiline, // Enable multiline input
          ),
          const SizedBox(height: 16), // Spacing
          ElevatedButton(
            onPressed: _tempSelectedRating == 0
                ? null // Disable button if no rating is selected
                : () {
                    // Get the current authenticated user
                    final User? currentUser = FirebaseAuth.instance.currentUser;

                    // Determine the reviewer's name. Use displayName if available, otherwise 'Anonymous'.
                    final String reviewerName = currentUser?.displayName ?? 'Anonymous';

                    // Get the current timestamp
                    final DateTime reviewTimestamp = DateTime.now();

                    // Call the onSubmit callback with all the required data
                    widget.onSubmit(
                      _tempSelectedRating,
                      _commentController.text.trim(), // Trim whitespace from comment
                      reviewerName,
                      reviewTimestamp,
                    );

                    // Clear fields and reset rating after submission
                    setState(() {
                      _tempSelectedRating = 0;
                      _commentController.clear();
                    });
                  },
            child: const Text('Submit Review'), // Changed button text for clarity
          ),
        ],
      ),
    );
  }
}