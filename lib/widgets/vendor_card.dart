import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

import '../models/vendor.dart';
import 'link_row.dart';
import 'rating_comment_section.dart';
import 'comments_display.dart';

// Assuming ExpansibleController is defined elsewhere in your project.
class VendorCard extends StatefulWidget {
  final Vendor vendor;
  final bool isFavorite;
  final ExpansibleController vendorController;
  final Function(Vendor) onToggleFavorite;
  final Function(Vendor, int, String, String, DateTime) onSendRatingAndComment;
  final Function() onExpansionStateChanged;

  const VendorCard({
    super.key,
    required this.vendor,
    required this.isFavorite,
    required this.vendorController,
    required this.onToggleFavorite,
    required this.onSendRatingAndComment,
    required this.onExpansionStateChanged,
  });

  @override
  State<VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<VendorCard> {
  bool _showRatingCommentBoxForThisVendor = false;
  late bool _currentIsFavorite;

  @override
  void initState() {
    super.initState();
    _currentIsFavorite = widget.isFavorite;
    AppLogger.info('VendorCard initState for ${widget.vendor.company}');
  }

  @override
  void didUpdateWidget(covariant VendorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      if (mounted) {
        setState(() {
          _currentIsFavorite = widget.isFavorite;
        });
        AppLogger.info('VendorCard didUpdateWidget: Favorite status changed for ${widget.vendor.company}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRatingOrComments = widget.vendor.averageRating > 0 || widget.vendor.comments.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        key: ValueKey(widget.vendor.uniqueId),
        controller: widget.vendorController,
        title: Text(
          widget.vendor.company,
          style: const TextStyle(fontSize: 18),
        ),
        subtitle: hasRatingOrComments
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              )
            : null,
        initiallyExpanded: widget.vendorController.isExpanded,
        onExpansionChanged: (isExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              AppLogger.info('ExpansionTile for ${widget.vendor.company} changed state to isExpanded: $isExpanded');
              widget.onExpansionStateChanged();
              if (!isExpanded) {
                setState(() {
                  _showRatingCommentBoxForThisVendor = false;
                });
              }
            }
          });
        },
        children: [
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
                  if (mounted) {
                    setState(() {
                      _currentIsFavorite = !_currentIsFavorite;
                    });
                  }
                  AppLogger.info('Favorite toggle tapped for ${widget.vendor.company}. New status: $_currentIsFavorite');
                  widget.onToggleFavorite(widget.vendor);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentIsFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _currentIsFavorite ? Colors.redAccent : Colors.grey,
                    ),
                    Text(
                      'Favorite',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentIsFavorite ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _showRatingCommentBoxForThisVendor = !_showRatingCommentBoxForThisVendor;
                    });
                  }
                  AppLogger.info('Review button tapped for ${widget.vendor.company}. Show review box: $_showRatingCommentBoxForThisVendor');
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
                  AppLogger.info('Share button tapped for ${widget.vendor.company}');
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
                  if (widget.vendor.paymentInfo.isNotEmpty) {
                    shareText += 'Payment: ${widget.vendor.paymentInfo}\n';
                  }
                  if (widget.vendor.averageRating > 0) {
                    shareText += 'Average Rating: ${widget.vendor.averageRating.toStringAsFixed(1)}/5 (${widget.vendor.comments.length} reviews)\n';
                  }
                  shareText += '\n#careservegive\npollockpropertiesgroup.com';
                  SharePlus.instance.share(ShareParams(text: shareText));
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
              onSubmit: (rating, comment, reviewerName, timestamp) {
                AppLogger.info('Submitted rating for ${widget.vendor.company}');
                widget.onSendRatingAndComment(widget.vendor, rating, comment, reviewerName, timestamp);
                if (mounted) {
                  setState(() {
                    _showRatingCommentBoxForThisVendor = false;
                  });
                }
              },
            ),
          CommentsDisplay(vendor: widget.vendor),
        ],
      ),
    );
  }
}