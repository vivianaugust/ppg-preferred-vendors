// lib/widgets/rating_comment_section.dart
import 'package:flutter/material.dart';
import '../models/vendor.dart'; // Import Vendor model

class RatingCommentSection extends StatefulWidget {
  final Vendor vendor;
  final Function(int rating, String comment) onSubmit;

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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < _tempSelectedRating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () {
                setState(() {
                  _tempSelectedRating = index + 1;
                });
              },
            );
          }),
        ),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _tempSelectedRating == 0
              ? null
              : () {
                  widget.onSubmit(_tempSelectedRating, _commentController.text);
                  // Clear fields after submission
                  setState(() {
                    _tempSelectedRating = 0;
                    _commentController.clear();
                  });
                },
          child: const Text('Submit Rating'),
        ),
      ],
    );
  }
}