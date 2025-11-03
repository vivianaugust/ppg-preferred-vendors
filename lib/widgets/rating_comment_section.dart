// lib/widgets/rating_comment_section.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vendor.dart';
import '../utils/logger.dart';

class RatingCommentSection extends StatefulWidget {
  final Vendor vendor;
  // This function handles both initial submission and editing/updating.
  final Function(int rating, String comment, String reviewerName, DateTime timestamp) onSubmit;
  
  // NEW: Callback for review deletion.
  final VoidCallback? onDelete; 
  
  // NEW: The user's existing rating. If not null and > 0, the widget is in edit mode.
  final int? initialRating; 
  
  // NEW: The user's existing comment.
  final String? initialComment; 

  const RatingCommentSection({
    super.key,
    required this.vendor,
    required this.onSubmit,
    this.onDelete,
    this.initialRating,
    this.initialComment,
  });

  @override
  State<RatingCommentSection> createState() => _RatingCommentSectionState();
}

class _RatingCommentSectionState extends State<RatingCommentSection> {
  late int _tempSelectedRating;
  late final TextEditingController _commentController;
  late final bool _isEditing;

  @override
  void initState() {
    super.initState();
    // Determine if we are editing an existing review.
    _isEditing = widget.initialRating != null && widget.initialRating! > 0;
    
    // Initialize the rating and comment fields with existing data if present.
    _tempSelectedRating = widget.initialRating ?? 0;
    _commentController = TextEditingController(text: widget.initialComment ?? '');
    
    AppLogger.info('RatingCommentSection initialized. Is editing existing review: $_isEditing');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String submitButtonText = _isEditing ? 'Update Review' : 'Submit Review';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Edit Your Review:' : 'Leave a Review:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // DELETE BUTTON (Visible only in edit mode and if a delete function is provided)
              if (_isEditing && widget.onDelete != null)
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                  label: Text('Delete Review', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              
              if (_isEditing && widget.onDelete != null)
                const SizedBox(width: 8),

              // SUBMIT/UPDATE BUTTON
              ElevatedButton.icon(
                onPressed: _tempSelectedRating == 0
                    ? null
                    : () {
                        final User? currentUser = FirebaseAuth.instance.currentUser;
                        // Safety check in case the user was logged out unexpectedly
                        if (currentUser == null) {
                           AppLogger.warning('Review action attempted by non-logged-in user.');
                           return;
                        }
                        
                        final String reviewerName = currentUser.displayName ?? 'Anonymous';
                        final DateTime reviewTimestamp = DateTime.now();
                        final String commentText = _commentController.text.trim();
                        
                        AppLogger.info('${_isEditing ? "Updating" : "Submitting"} review for vendor "${widget.vendor.company}".');

                        // Call the onSubmit function (parent handles if it's an update or new submission)
                        widget.onSubmit(
                          _tempSelectedRating,
                          commentText,
                          reviewerName,
                          reviewTimestamp,
                        );

                        // Only clear the form if it was a new submission, otherwise leave for user confirmation
                        if (!_isEditing) {
                          setState(() {
                            _tempSelectedRating = 0;
                            _commentController.clear();
                          });
                        }
                      },
                icon: Icon(_isEditing ? Icons.save : Icons.send),
                label: Text(submitButtonText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}