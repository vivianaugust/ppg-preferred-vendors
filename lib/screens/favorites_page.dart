import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

// Import the new files
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/utils/firestore_helpers.dart'; // For normalizeString
import 'package:ppg_preferred_vendors/widgets/comments_display.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_details_content.dart';
import 'package:ppg_preferred_vendors/widgets/rating_comment_section.dart'; // Import the new rating section widget


class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Vendor> _allVendors = [];
  List<Vendor> _filteredVendors = [];
  bool _loading = true;

  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  final Map<String, ExpansibleController> _categoryControllers = {};
  final Map<String, ExpansibleController> _vendorControllers = {};
  final Map<String, bool> _showRatingCommentBoxForVendor = {}; // New state to manage visibility of rating section

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFavorites();
  }

  void _ensureController(String key, Map<String, ExpansibleController> controllerMap) {
    controllerMap.putIfAbsent(key, () => ExpansibleController());
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .get();

      if (!mounted) return;
      setState(() {
        _allVendors = snapshot.docs.map((doc) => Vendor.fromFirestore(doc)).toList();
        _filteredVendors = List.from(_allVendors); // Initialize filtered list
        for (var vendor in _allVendors) {
          _ensureController(vendor.service, _categoryControllers); // Grouping favorites by service
          _ensureController(vendor.uniqueId, _vendorControllers);
          _showRatingCommentBoxForVendor.putIfAbsent(vendor.uniqueId, () => false); // Initialize rating section visibility
        }
        _loading = false;
      });
      _onSearchChanged(); // Apply initial filter
    } catch (e) {
      debugPrint('Error loading favorite statuses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load favorite statuses: $e')),
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleRatingCommentBox(Vendor vendor) {
    if (!mounted) return;
    setState(() {
      _showRatingCommentBoxForVendor[vendor.uniqueId] =
          !(_showRatingCommentBoxForVendor[vendor.uniqueId] ?? false);
    });
  }

  Future<void> _sendRatingAndComment(Vendor vendor, int rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to submit reviews.')),
        );
      }
      return;
    }

    try {
      final vendorDocRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(vendor.uniqueId);

      final docSnapshot = await vendorDocRef.get();
      List<int> currentRatings = [];
      List<String> currentComments = [];

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final String ratingListString = data?['ratingListString'] ?? '';
        final String commentsString = data?['commentsString'] ?? '';

        currentRatings = ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
        currentComments = commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      currentRatings.add(rating);
      currentComments.add(comment);

      double newAverageRating = currentRatings.isNotEmpty
          ? currentRatings.reduce((a, b) => a + b) / currentRatings.length
          : 0.0;

      final String newRatingListString = currentRatings.join(',');
      final String newCommentsString = currentComments.join(';');

      await vendorDocRef.update({
        'ratingListString': newRatingListString,
        'commentsString': newCommentsString,
        'averageRating': newAverageRating,
        'reviewCount': currentComments.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }

      if (!mounted) return;
      setState(() {
        _showRatingCommentBoxForVendor[vendor.uniqueId] = false;
      });
      _loadFavorites();

    } catch (e) {
      debugPrint('Error sending rating and comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Vendor vendor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to favorite vendors.')),
        );
      }
      return;
    }

    final vendorCompanyName = vendor.company;

    try {
      final vendorDocRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(vendor.uniqueId);

      await vendorDocRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$vendorCompanyName removed from Favorites.')),
        );
      }
      _loadFavorites();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite status: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = normalizeString(_searchController.text);
    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        _filteredVendors = List.from(_allVendors);
      } else {
        _filteredVendors = _allVendors.where((vendor) {
          final fieldsToSearch = [
            vendor.service,
            vendor.company,
            vendor.contactName,
            vendor.phone,
            vendor.email,
            vendor.website,
            vendor.address,
            vendor.notes,
            vendor.paymentInfo,
            vendor.averageRating.toString(),
            vendor.ratingListString,
            vendor.commentsString,
          ].map((field) => normalizeString(field)).toList();

          return fieldsToSearch.any((field) => field.contains(query));
        }).toList();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
      if (_searchController.text.isNotEmpty) {
        _expandAllVendors();
      }
    });
  }

  void _clearSearchBar() {
    _searchController.clear();
    // NEW: Collapse all categories when the search bar is cleared
    _collapseAllCategories();
  }

  Map<String, List<Vendor>> _groupVendorsByService(List<Vendor> vendors) {
    Map<String, List<Vendor>> grouped = {};
    for (var vendor in vendors) {
      grouped.putIfAbsent(vendor.service, () => []).add(vendor);
    }
    return grouped;
  }

  void _expandAllCategories() {
    if (!mounted) return;
    setState(() {
      for (var categoryName in _groupVendorsByService(_filteredVendors).keys) {
        _categoryControllers[categoryName]?.expand();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _collapseAllCategories() {
    if (!mounted) return;
    setState(() {
      for (var controller in _categoryControllers.values) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      }
      _collapseAllVendors();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _expandAllVendors() {
    if (!mounted) return;
    setState(() {
      final groupedVendors = _groupVendorsByService(_filteredVendors);
      bool anyCategoryOpenInFilteredView = groupedVendors.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (!anyCategoryOpenInFilteredView && groupedVendors.isNotEmpty) {
        for (var categoryName in groupedVendors.keys) {
          _categoryControllers[categoryName]?.expand();
        }
      }

      for (var entry in groupedVendors.entries) {
        final categoryName = entry.key;
        final vendorsList = entry.value;
        if (_categoryControllers[categoryName]?.isExpanded == true) {
          for (var vendor in vendorsList) {
            _vendorControllers[vendor.uniqueId]?.expand();
          }
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _collapseAllVendors() {
    if (!mounted) return;
    setState(() {
      for (var controller in _vendorControllers.values) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _updateExpansionStates() {
    final Map<String, List<Vendor>> groupedByServiceForExpansionCheck = _groupVendorsByService(_filteredVendors);
    final visibleCategories = groupedByServiceForExpansionCheck.keys.toSet();

    bool areAllCatsExpanded = visibleCategories.isNotEmpty && visibleCategories.every(
      (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
    );

    bool areAllVendorsExp = true;

    if (visibleCategories.isEmpty || groupedByServiceForExpansionCheck.values.every((list) => list.isEmpty)) {
      areAllVendorsExp = false;
    } else {
      var expandedCategoriesInView = visibleCategories.where(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true
      ).toList();

      if (expandedCategoriesInView.isEmpty) {
        areAllVendorsExp = false;
      } else {
        for (var categoryKey in expandedCategoriesInView) {
          final vendorsInCategory = groupedByServiceForExpansionCheck[categoryKey] ?? [];

          if (vendorsInCategory.isEmpty) continue;

          for (var vendor in vendorsInCategory) {
            if (_vendorControllers[vendor.uniqueId]?.isExpanded != true) {
              areAllVendorsExp = false;
              break;
            }
          }
          if (!areAllVendorsExp) break;
        }
      }
    }

    if (_allCategoriesExpanded != areAllCatsExpanded || _allVendorsExpanded != areAllVendorsExp) {
      if (!mounted) return;
      setState(() {
        _allCategoriesExpanded = areAllCatsExpanded;
        _allVendorsExpanded = areAllVendorsExp;
      });
    }
  }


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    for (var controller in _categoryControllers.values) {
      controller.dispose();
    }
    for (var controller in _vendorControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Vendor>> categorizedFilteredVendors = _groupVendorsByService(_filteredVendors);
    final sortedFilteredCategoryKeys = categorizedFilteredVendors.keys.toList()..sort();

    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search favorited vendors...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearchBar,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _loading || categorizedFilteredVendors.isEmpty
                              ? null
                              : () {
                                  if (_allCategoriesExpanded) {
                                    _collapseAllCategories();
                                  } else {
                                    _expandAllCategories();
                                  }
                                },
                          icon: Icon(
                            _allCategoriesExpanded ? Icons.unfold_less : Icons.unfold_more,
                            color: Colors.blue,
                          ),
                          label: Text(
                            _allCategoriesExpanded ? 'Collapse Categories' : 'Expand Categories',
                            style: const TextStyle(color: Colors.blue),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.blue),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _loading || categorizedFilteredVendors.isEmpty
                              ? null
                              : () {
                                  if (_allVendorsExpanded) {
                                    _collapseAllVendors();
                                  } else {
                                    _expandAllVendors();
                                  }
                                },
                          icon: Icon(
                            _allVendorsExpanded ? Icons.unfold_less : Icons.unfold_more,
                            color: Colors.blue,
                          ),
                          label: Text(
                            _allVendorsExpanded ? 'Collapse Vendors' : 'Expand Vendors',
                            style: const TextStyle(color: Colors.blue),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.blue),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredVendors.isEmpty
                          ? const Center(child: Text('No favorited vendors found'))
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: sortedFilteredCategoryKeys.map((category) {
                                final vendors = categorizedFilteredVendors[category]!;
                                final categoryController = _categoryControllers[category]!;

                                return ExpansionTile(
                                  key: GlobalObjectKey(category),
                                  controller: categoryController,
                                  title: Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  initiallyExpanded: categoryController.isExpanded,
                                  onExpansionChanged: (isExpanded) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _updateExpansionStates();
                                    });
                                  },
                                  children: vendors.map((vendor) {
                                    final vendorController = _vendorControllers[vendor.uniqueId]!;
                                    final showRatingCommentBoxForThisVendor = _showRatingCommentBoxForVendor[vendor.uniqueId] ?? false;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      child: ExpansionTile(
                                        key: ValueKey(vendor.uniqueId),
                                        controller: vendorController,
                                        title: Text(
                                          vendor.company,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (vendor.notes.isNotEmpty) Text(vendor.notes),
                                            if (vendor.averageRating > 0 || vendor.comments.isNotEmpty)
                                              Row(
                                                children: [
                                                  ...List.generate(5, (index) {
                                                    return Icon(
                                                      index < vendor.averageRating.floor() ? Icons.star : Icons.star_border,
                                                      color: Colors.amber,
                                                      size: 18,
                                                    );
                                                  }),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${vendor.averageRating.toStringAsFixed(1)} (${vendor.comments.length} reviews)',
                                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        initiallyExpanded: vendorController.isExpanded,
                                        onExpansionChanged: (isExpanded) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            _updateExpansionStates();
                                          });
                                        },
                                        children: [
                                          VendorDetailsContent(vendor: vendor),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleFavorite(vendor),
                                                child: const Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.favorite, color: Colors.redAccent),
                                                    Text(
                                                      'Unfavorite',
                                                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _toggleRatingCommentBox(vendor),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      showRatingCommentBoxForThisVendor
                                                          ? Icons.rate_review
                                                          : Icons.rate_review_outlined,
                                                      color: Colors.blue,
                                                    ),
                                                    Text(
                                                      showRatingCommentBoxForThisVendor
                                                          ? 'Close Review'
                                                          : 'Review',
                                                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  String shareText = 'Check out ${vendor.company} from PPG Preferred Vendors:\n';
                                                  shareText += 'Service: ${vendor.service}\n';
                                                  shareText += 'Contact: ${vendor.contactName} - ${vendor.phone}\n';
                                                  if (vendor.website.isNotEmpty) {
                                                    shareText += 'Website: ${vendor.website}\n';
                                                  }
                                                  if (vendor.email.isNotEmpty) {
                                                    shareText += 'Email: ${vendor.email}\n';
                                                  }
                                                  if (vendor.address.isNotEmpty) {
                                                    shareText += 'Address: ${vendor.address}\n';
                                                  }
                                                  if (vendor.notes.isNotEmpty) {
                                                    shareText += 'Notes: ${vendor.notes}\n';
                                                  }
                                                  if (vendor.comments.isNotEmpty) {
                                                    shareText += '\nComments:\n${vendor.comments.map((vc) => '(${vc.rating}/5) ${vc.comment}').join('\n')}';
                                                  }
                                                  Share.share(shareText);
                                                },
                                                child: const Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.share, color: Colors.grey),
                                                    Text('Share', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (showRatingCommentBoxForThisVendor)
                                            RatingCommentSection(
                                              vendor: vendor,
                                              onSubmit: (rating, comment) {
                                                _sendRatingAndComment(vendor, rating, comment);
                                              },
                                            ),
                                          CommentsDisplay(vendor: vendor),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}