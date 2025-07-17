// lib/widgets/vendor_card.dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/vendor.dart';
import 'link_row.dart';
import 'rating_comment_section.dart';
import 'comments_display.dart';

// Assuming ExpansibleController is defined elsewhere in your project.
// No definition for ExpansibleController is included here as per your instruction.

class VendorCard extends StatefulWidget {
  final Vendor vendor;
  final bool isFavorite; // This is the authoritative favorite status received from parent
  final ExpansibleController vendorController; // This line is untouched as per your instruction
  final Function(Vendor) onToggleFavorite;
  final Function(Vendor, int, String) onSendRatingAndComment;
  final Function() onExpansionStateChanged;

  const VendorCard({
    super.key,
    required this.vendor,
    required this.isFavorite, // Receive the correct, updated status from parent
    required this.vendorController,
    required this.onToggleFavorite,
    required this.onSendRatingAndComment,
    required this.onExpansionStateChanged,
  });

  @override
  State<VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<VendorCard> {
  bool _showRatingCommentBoxForThisVendor = false; // State for controlling the review box
  late bool _currentIsFavorite; // Internal state for immediate visual feedback of favorite status

  @override
  void initState() {
    super.initState();
    // Initialize the internal favorite state with the authoritative state from the parent
    _currentIsFavorite = widget.isFavorite;
  }

  @override
  void didUpdateWidget(covariant VendorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent rebuilds and provides a new 'isFavorite' value,
    // update our internal state to reflect the authoritative status.
    if (oldWidget.isFavorite != widget.isFavorite) {
      _currentIsFavorite = widget.isFavorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        key: ValueKey(widget.vendor.uniqueId),
        controller: widget.vendorController,
        title: Text(
          widget.vendor.company,
          style: const TextStyle(fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.vendor.notes.isNotEmpty) Text(widget.vendor.notes),
            if (widget.vendor.averageRating > 0 || widget.vendor.comments.isNotEmpty)
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < widget.vendor.averageRating.floor() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.vendor.averageRating.toStringAsFixed(1)} (${widget.vendor.comments.length} reviews)',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
        initiallyExpanded: widget.vendorController.isExpanded, // This line is untouched
        onExpansionChanged: (isExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onExpansionStateChanged(); // Calls the parent's function
            if (!isExpanded) {
              setState(() {
                _showRatingCommentBoxForThisVendor = false; // Collapse review box if tile collapses
              });
            }
          });
        },
        children: [
          // Keeping the Padding/Column structure as per your latest provided code
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.vendor.contactName.isNotEmpty) Text('Contact: ${widget.vendor.contactName}'),
                if (widget.vendor.phone.isNotEmpty) LinkRow(icon: Icons.phone, text: widget.vendor.phone, uri: Uri(scheme: 'tel', path: widget.vendor.phone)),
                if (widget.vendor.email.isNotEmpty) LinkRow(icon: Icons.email, text: widget.vendor.email, uri: Uri(scheme: 'mailto', path: widget.vendor.email)),
                if (widget.vendor.website.isNotEmpty) LinkRow(icon: Icons.language, text: widget.vendor.website, uri: Uri.parse(widget.vendor.website.startsWith('http') ? widget.vendor.website : 'https://${widget.vendor.website}')),
                if (widget.vendor.address.isNotEmpty) LinkRow(icon: Icons.location_on, text: widget.vendor.address, uri: Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': widget.vendor.address})),
                if (widget.vendor.paymentInfo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.payment, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('Payment: ${widget.vendor.paymentInfo}'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  // Immediately update the internal state for visual feedback
                  setState(() {
                    _currentIsFavorite = !_currentIsFavorite;
                  });
                  // Call the parent's function to handle the actual favorite toggling and persistence
                  widget.onToggleFavorite(widget.vendor);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      // Icon shape: Filled if favorite, outlined if not. Uses internal state.
                      _currentIsFavorite ? Icons.favorite : Icons.favorite_border,
                      // Icon color: RedAccent if favorite, grey if not. Uses internal state.
                      color: _currentIsFavorite ? Colors.redAccent : Colors.grey, // Uses RedAccent
                    ),
                    Text(
                      'Favorite',
                      style: TextStyle(
                        fontSize: 12,
                        // Text color: RedAccent if favorite, grey if not. Uses internal state.
                        color: _currentIsFavorite ? Colors.redAccent : Colors.grey, // Uses RedAccent
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Correctly uses the local state variable for the review box
                  setState(() {
                    _showRatingCommentBoxForThisVendor = !_showRatingCommentBoxForThisVendor;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showRatingCommentBoxForThisVendor
                          ? Icons.rate_review
                          : Icons.rate_review_outlined,
                      color: Colors.grey,
                    ),
                    Text(
                      _showRatingCommentBoxForThisVendor
                          ? 'Close Review'
                          : 'Review',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  String shareText = 'PPG Preferred Vendors invites you to check out ${widget.vendor.company} for ${widget.vendor.service}!\n\n';
                  if (widget.vendor.website.isNotEmpty) {
                    shareText += 'Website: ${widget.vendor.website}\n';
                  }
                  if (widget.vendor.phone.isNotEmpty) {
                    shareText += 'Phone: ${widget.vendor.phone}\n';
                  }
                  if (widget.vendor.email.isNotEmpty) {
                    shareText += 'Email: ${widget.vendor.email}\n';
                  }
                  if (widget.vendor.address.isNotEmpty) {
                    shareText += 'Address: ${widget.vendor.address}\n';
                  }
                  if (widget.vendor.notes.isNotEmpty) {
                    shareText += 'Notes: ${widget.vendor.notes}\n';
                  }
                  if (widget.vendor.paymentInfo.isNotEmpty) {
                    shareText += 'Payment: ${widget.vendor.paymentInfo}\n';
                  }
                  if (widget.vendor.averageRating > 0) {
                    shareText += 'Average Rating: ${widget.vendor.averageRating.toStringAsFixed(1)}/5 (${widget.vendor.comments.length} reviews)\n';
                  }
                  shareText += '\nSee our website for information on buying or selling a home in Bergen, Morris, Essex, or Union Counties in NJ: pollockpropertiesgroup.com';
                  Share.share(shareText);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.share, color: Colors.grey),
                    Text('Share', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          if (_showRatingCommentBoxForThisVendor)
            RatingCommentSection(
              vendor: widget.vendor,
              onSubmit: (rating, comment) {
                widget.onSendRatingAndComment(widget.vendor, rating, comment);
                setState(() {
                  _showRatingCommentBoxForThisVendor = false;
                });
              },
            ),
          CommentsDisplay(vendor: widget.vendor),
        ],
      ),
    );
  }
}