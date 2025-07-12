import 'package:flutter/material.dart';
import '../models/vendor.dart'; // Import Vendor and VendorComment

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
  int? _selectedCommentRatingFilter; // null means 'All'
  late ExpansibleController _commentFilterController; // Controller for the filter tile

  @override
  void initState() {
    super.initState();
    _commentFilterController = ExpansibleController(); // Initialize controller
  }

  @override
  void dispose() {
    // ExpansibleController does not have a dispose method,
    // as it's typically managed by the ExpansionTile itself.
    // So, no explicit dispose needed here for _commentFilterController.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<VendorComment> allComments = widget.vendor.comments;
    final int reviewCount = allComments.length;

    if (allComments.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no comments
    }

    // Filter comments based on selected rating
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
              // Reset filter to 'All' when hiding/showing comments
              if (!_showAllComments) {
                _selectedCommentRatingFilter = null;
                _commentFilterController.collapse(); // Collapse filter when comments are hidden
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
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    // MODIFICATION START: Removed SingleChildScrollView and Spacing, adjusted ChoiceChip padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute evenly
                      children: [
                        _buildRatingFilterButton(null, 'All'),
                        _buildRatingFilterButton(1, '1★'),
                        _buildRatingFilterButton(2, '2★'),
                        _buildRatingFilterButton(3, '3★'),
                        _buildRatingFilterButton(4, '4★'),
                        _buildRatingFilterButton(5, '5★'),
                      ],
                    ),
                    // MODIFICATION END
                  ),
                ],
              ),
              if (filteredComments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No reviews found for this filter.'),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filteredComments.length,
                  itemBuilder: (context, index) {
                    final commentData = filteredComments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < commentData.rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 14,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(commentData.comment)),
                        ],
                      ),
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
          fontSize: 12, // Further reduced font size
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCommentRatingFilter = selected ? rating : null;
        });
      },
      selectedColor: Colors.blue,
      // MODIFICATION START: Adjusted padding to make the chip smaller
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced horizontal label padding
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0), // Reduced overall chip padding
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces minimum tap target size
      // MODIFICATION END
    );
  }
}