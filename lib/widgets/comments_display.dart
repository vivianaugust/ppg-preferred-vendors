// lib/widgets/comments_display.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vendor.dart';

class CommentsDisplay extends StatefulWidget {
  final Vendor vendor;

  const CommentsDisplay({
    super.key,
    required this.vendor,
  });

  @override
  State<CommentsDisplay> createState() => _CommentsDisplayState();
}

class _CommentsDisplayState extends State<CommentsDisplay> {
  bool _showAllComments = false;
  int? _selectedCommentRatingFilter;
  late ExpansibleController _commentFilterController;

  @override
  void initState() {
    super.initState();
    _commentFilterController = ExpansibleController();
  }

  @override
  void dispose() {
    _commentFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<VendorComment> allComments = widget.vendor.comments;
    final int reviewCount = allComments.length;

    if (allComments.isEmpty) {
      return const SizedBox.shrink();
    }

    final filteredComments = allComments.where((comment) =>
        _selectedCommentRatingFilter == null ||
        comment.rating == _selectedCommentRatingFilter
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showAllComments = !_showAllComments;
              if (!_showAllComments) {
                _selectedCommentRatingFilter = null;
                _commentFilterController.collapse();
              }
            });
          },
          icon: Icon(
            _showAllComments ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.blue,
          ),
          label: Text(
            '${_showAllComments ? 'Hide' : 'See All'} $reviewCount Reviews',
            style: const TextStyle(color: Colors.blue),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),
        Visibility(
          visible: _showAllComments,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter by Rating for comments using ExpansionTile
              ExpansionTile(
                controller: _commentFilterController,
                title: const Text('Filter Reviews'),
                leading: const Icon(Icons.filter_list, color: Colors.blue),
                tilePadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                childrenPadding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildRatingFilterButton(null, 'All'),
                        _buildRatingFilterButton(1, '1★'),
                        _buildRatingFilterButton(2, '2★'),
                        _buildRatingFilterButton(3, '3★'),
                        _buildRatingFilterButton(4, '4★'),
                        _buildRatingFilterButton(5, '5★'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 0.0), // Ensure no gap from here

              if (filteredComments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No reviews found for this filter.'),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  // --- FIX START: Add padding: EdgeInsets.zero here ---
                  padding: EdgeInsets.zero, // This is the crucial line!
                  // --- FIX END ---
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filteredComments.length,
                  itemBuilder: (context, index) {
                    final commentData = filteredComments[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index > 0) const SizedBox(height: 8.0), // Spacing between comments, not before first one
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < commentData.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 14,
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          '${commentData.reviewerName} - ${DateFormat('MM/dd/yyyy').format(commentData.timestamp)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          commentData.commentText.isEmpty ? "(No comment provided)" : commentData.commentText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                            return const SizedBox.shrink();
                          },
                        ),
                        if (index < filteredComments.length - 1)
                          const Divider(height: 16, thickness: 0.5),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingFilterButton(int? rating, String label) {
    final bool isSelected = _selectedCommentRatingFilter == rating;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCommentRatingFilter = selected ? rating : null;
        });
      },
      selectedColor: Colors.blue,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}