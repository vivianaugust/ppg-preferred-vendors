import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

// Import the new files
import 'package:ppg_preferred_vendors/models/vendor.dart'; // Corrected path based on structure
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/utils/firestore_helpers.dart'; // For normalizeString
import 'package:ppg_preferred_vendors/services/sheet_data.dart'; // Assuming this still exists and is correct
import 'package:ppg_preferred_vendors/widgets/rating_comment_section.dart';
import 'package:ppg_preferred_vendors/widgets/comments_display.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_details_content.dart';

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<Vendor>> _categorizedVendors = {};
  Map<String, List<Vendor>> _filteredCategories = {};
  bool _loading = true;

  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  final Map<String, ExpansibleController> _categoryControllers = {};
  final Map<String, ExpansibleController> _vendorControllers = {};

  final Map<String, bool> _showRatingCommentBox = {};
  final Map<String, bool> _isFavorite = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadVendorsAndFavorites();
  }

  void _ensureController(String key, Map<String, ExpansibleController> controllerMap) {
    controllerMap.putIfAbsent(key, () => ExpansibleController());
  }

  Future<void> _loadVendorsAndFavorites() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadVendorsFromSheet();
    await _loadFavoriteStatuses();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadVendorsFromSheet() async {
    try {
      final jsonString = await rootBundle.loadString(AppConstants.googleSheetJsonAssetPath);

      final sheetService = SheetDataService(
        spreadsheetUrl: AppConstants.googleSheetUrl,
      );

      await sheetService.initializeFromJson(jsonString);
      final data = await sheetService.getSheetData(AppConstants.mainSheetName);

      if (data == null || data.length <= 2) {
        debugPrint('No data or only headers found in the sheet.');
        return;
      }

      final Map<String, int> tempVendorSheetRowIndices = {};
      final cleanedRows = data.sublist(2).where((row) =>
          row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)
      ).toList();

      if (cleanedRows.isEmpty) {
        debugPrint('No meaningful data rows after cleaning.');
        return;
      }

      final Map<String, List<Vendor>> tempCategorized = {};

      for (int i = 0; i < cleanedRows.length; i++) {
        List<Object?> row = cleanedRows[i];

        const int minExpectedColumns = 2;
        if (row.length < minExpectedColumns) {
          continue;
        }

        const int requiredColumnsForData = 12;
        if (row.length < requiredColumnsForData) {
          final List<Object?> paddedRow = List.from(row);
          while (paddedRow.length < requiredColumnsForData) {
            paddedRow.add(null);
          }
          row = paddedRow;
          cleanedRows[i] = row;
        }

        final service = row[0]?.toString().trim();
        final company = row[1]?.toString().trim();

        if ((service?.isEmpty ?? true) || (company?.isEmpty ?? true)) {
          debugPrint('Skipping row ${i + 3} due to empty service ("$service") or company name ("$company").');
          continue;
        }

        final int originalSheetRowIndex = i + 3;
        final Vendor vendor = Vendor.fromSheetRow(row, originalSheetRowIndex);
        tempCategorized.putIfAbsent(vendor.service, () => []).add(vendor);

        tempVendorSheetRowIndices[vendor.uniqueId] = originalSheetRowIndex;

        _showRatingCommentBox[vendor.uniqueId] = false;
      }

      _categorizedVendors = tempCategorized;
      _filteredCategories = Map.from(_categorizedVendors);

      for (final category in _categorizedVendors.keys) {
        _ensureController(category, _categoryControllers);
        for (var vendor in _categorizedVendors[category]!) {
          _ensureController(vendor.uniqueId, _vendorControllers);
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading vendors from sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vendors: $e')),
        );
      }
    }
  }

  Future<void> _loadFavoriteStatuses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite.clear();
        for (final category in _categorizedVendors.keys) {
          for (final vendor in _categorizedVendors[category]!) {
            _isFavorite[vendor.uniqueId] = false;
          }
        }
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .get();

      final Set<String> favoritedVendorIds = snapshot.docs.map((doc) => doc.id).toSet();

      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite.clear();
        for (final category in _categorizedVendors.keys) {
          for (final vendor in _categorizedVendors[category]!) {
            _isFavorite[vendor.uniqueId] = favoritedVendorIds.contains(vendor.uniqueId);
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading favorite statuses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load favorite statuses: $e')),
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

      final docSnapshot = await vendorDocRef.get();

      if (docSnapshot.exists) {
        await vendorDocRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$vendorCompanyName removed from Favorites.')),
          );
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _isFavorite[vendor.uniqueId] = false;
        });
      } else {
        await vendorDocRef.set(vendor.toFirestore()..['savedAt'] = FieldValue.serverTimestamp(), SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$vendorCompanyName added to Favorites!')),
          );
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _isFavorite[vendor.uniqueId] = true;
        });
      }
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
    Map<String, List<Vendor>> newFilteredCategories = {};

    for (var controller in _vendorControllers.values) {
      controller.collapse();
    }

    if (query.isEmpty) {
      newFilteredCategories = Map.from(_categorizedVendors);
      for (var controller in _categoryControllers.values) {
        controller.collapse();
      }
      _allCategoriesExpanded = false;
      _allVendorsExpanded = false;
    } else {
      final sortedCategories = _categorizedVendors.keys.toList()..sort();
      for (final category in sortedCategories) {
        final vendors = _categorizedVendors[category]!;
        final matching = vendors.where((vendor) {
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

        if (matching.isNotEmpty) {
          newFilteredCategories[category] = matching;
        } else {
          _categoryControllers[category]?.collapse();
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_searchController.text.isNotEmpty) {
          _expandAllVendors();
        }
      });
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _filteredCategories = newFilteredCategories;
    });
  }

  void _clearSearchBar() {
    _searchController.clear();
  }

  void _expandAllCategories() {
    if (!mounted) {
      return;
    }
    setState(() {
      for (var categoryName in _filteredCategories.keys) {
        _categoryControllers[categoryName]?.expand();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _collapseAllCategories() {
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    setState(() {
      bool anyCategoryOpenInFilteredView = _filteredCategories.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (!anyCategoryOpenInFilteredView && _filteredCategories.isNotEmpty) {
        for (var categoryName in _filteredCategories.keys) {
          _categoryControllers[categoryName]?.expand();
        }
      }

      for (var entry in _filteredCategories.entries) {
        String categoryName = entry.key;
        List<Vendor> vendorsList = entry.value;
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
    if (!mounted) {
      return;
    }
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
    final Map<String, List<Vendor>> groupedByServiceForExpansionCheck = {};
    for (var entry in _filteredCategories.entries) {
      if (entry.value.isNotEmpty) {
        groupedByServiceForExpansionCheck[entry.key] = entry.value;
      }
    }
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

          if (vendorsInCategory.isEmpty) {
            continue;
          }

          for (var vendor in vendorsInCategory) {
            if (_vendorControllers[vendor.uniqueId]?.isExpanded != true) {
              areAllVendorsExp = false;
              break;
            }
          }
          if (!areAllVendorsExp) {
            break;
          }
        }
      }
    }

    if (_allCategoriesExpanded != areAllCatsExpanded || _allVendorsExpanded != areAllVendorsExp) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allCategoriesExpanded = areAllCatsExpanded;
        _allVendorsExpanded = areAllVendorsExp;
      });
    }
  }

  Future<void> _sendRatingAndComment(Vendor vendor, int newRating, String newComment) async {
    try {
      final sheetService = SheetDataService(
        spreadsheetUrl: AppConstants.googleSheetUrl,
      );

      final jsonString = await rootBundle.loadString(AppConstants.googleSheetJsonAssetPath);
      await sheetService.initializeFromJson(jsonString);

      int? sheetRowIndexToUpdate = vendor.sheetRowIndex;

      if (sheetRowIndexToUpdate == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not find vendor row to update in sheet.')),
          );
        }
        debugPrint('Invalid sheetRowIndexToUpdate: $sheetRowIndexToUpdate for vendor ${vendor.uniqueId}');
        return;
      }

      String existingRatingList = vendor.ratingListString;
      String existingCommentsString = vendor.commentsString;

      String updatedRatingList;
      if (existingRatingList.isEmpty) {
        updatedRatingList = newRating.toString();
      } else {
        updatedRatingList = '$existingRatingList,$newRating';
      }

      String updatedCommentsString;
      if (existingCommentsString.isEmpty) {
        updatedCommentsString = newComment.trim();
      } else {
        updatedCommentsString = newComment.trim().isNotEmpty ? '$existingCommentsString;${newComment.trim()}' : existingCommentsString;
      }

      final Map<String, Object> cellsToUpdate = {
        'K': updatedRatingList,
        'L': updatedCommentsString,
      };

      await sheetService.updateCells(AppConstants.mainSheetName, sheetRowIndexToUpdate, cellsToUpdate);

      await _loadVendorsAndFavorites();

      if (!mounted) {
        return;
      }
      setState(() {
        _showRatingCommentBox[vendor.uniqueId] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating and comment submitted! Average rating updated.')),
        );
      }
    } catch (e) {
      debugPrint('Error sending rating/comment to sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send rating/comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedFilteredCategoryKeys = _filteredCategories.keys.toList()..sort();

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
                      hintText: 'Search vendors...',
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
                          onPressed: _loading || _filteredCategories.isEmpty
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
                          onPressed: _loading || _filteredCategories.isEmpty
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
                      : _filteredCategories.isEmpty
                          ? const Center(child: Text('No vendors found'))
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: sortedFilteredCategoryKeys.map((category) {
                                final vendors = _filteredCategories[category]!;
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
                                    final bool isFavorite = _isFavorite[vendor.uniqueId] ?? false;
                                    final bool showRatingCommentBoxForThisVendor = _showRatingCommentBox[vendor.uniqueId] ?? false;

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
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                                      color: isFavorite ? Colors.redAccent : Colors.grey,
                                                    ),
                                                    Text(
                                                      'Favorite',
                                                      style: TextStyle(fontSize: 12, color: isFavorite ? Colors.redAccent : Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  if (!mounted) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _showRatingCommentBox[vendor.uniqueId] = !(showRatingCommentBoxForThisVendor);
                                                  });
                                                },
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min, // Corrected from MainAxisSize.AxisSize
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
                                                  String shareText = 'Check out ${vendor.company} for ${vendor.service}!\n';
                                                  if (vendor.website.isNotEmpty) {
                                                    shareText += 'Website: ${vendor.website}\n';
                                                  }
                                                  if (vendor.phone.isNotEmpty) {
                                                    shareText += 'Phone: ${vendor.phone}\n';
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
                                                  if (vendor.paymentInfo.isNotEmpty) {
                                                    shareText += 'Payment: ${vendor.paymentInfo}\n';
                                                  }
                                                  if (vendor.averageRating > 0) {
                                                    shareText += 'Average Rating: ${vendor.averageRating.toStringAsFixed(1)}/5 (${vendor.comments.length} reviews)\n';
                                                  }
                                                  if (vendor.comments.isNotEmpty) {
                                                    shareText += 'Comments:\n${vendor.comments.map((vc) => '(${vc.rating}/5) ${vc.comment}').join('\n')}\n';
                                                  }
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