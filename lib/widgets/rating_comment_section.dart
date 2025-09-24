// lib/widgets/rating_comment_section.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vendor.dart';
import '../utils/logger.dart';

class RatingCommentSection extends StatefulWidget {
  final Vendor vendor;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave a Review:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _tempSelectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _tempSelectedRating = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Your Comment (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            minLines: 1,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _tempSelectedRating == 0
                ? null
                : () {
                    final User? currentUser = FirebaseAuth.instance.currentUser;
                    final String reviewerName = currentUser?.displayName ?? 'Anonymous';
                    final DateTime reviewTimestamp = DateTime.now();
                    final String commentText = _commentController.text.trim();
                    AppLogger.info('Submitting review for vendor "${widget.vendor.company}".');
                    widget.onSubmit(
                      _tempSelectedRating,
                      commentText,
                      reviewerName,
                      reviewTimestamp,
                    );
                    setState(() {
                      _tempSelectedRating = 0;
                      _commentController.clear();
                    });
                  },
            child: const Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}