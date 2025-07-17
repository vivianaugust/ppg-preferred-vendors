// lib/widgets/vendor_list_display.dart
import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_card.dart';
import 'package:ppg_preferred_vendors/utils/firestore_helpers.dart'; // For normalizeString

// Placeholder for ExpansibleController if it's not defined globally in your project.
// If you have a specific definition elsewhere, ensure it's imported correctly.
class ExpansibleController extends ExpansionTileController {}

class VendorListDisplay extends StatefulWidget {
  final List<Vendor> initialVendors;
  final bool loading;
  final Function(Vendor) onToggleFavorite;
  final Function(Vendor, int, String) onSendRatingAndComment;
  // NEW: Add the favorite status map to the constructor
  final Map<String, bool> favoriteStatusMap;

  const VendorListDisplay({
    super.key,
    required this.initialVendors,
    required this.loading,
    required this.onToggleFavorite,
    required this.onSendRatingAndComment,
    required this.favoriteStatusMap, // Initialize the new parameter
  });

  @override
  State<VendorListDisplay> createState() => _VendorListDisplayState();
}

class _VendorListDisplayState extends State<VendorListDisplay> {
  final TextEditingController _searchController = TextEditingController();
  List<Vendor> _currentVendors = []; // The active list of vendors (initial or filtered)
  Map<String, List<Vendor>> _categorizedFilteredVendors = {}; // Vendors grouped by category after filtering

  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  final Map<String, ExpansibleController> _categoryControllers = {};
  final Map<String, ExpansibleController> _vendorControllers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _currentVendors = List.from(widget.initialVendors);
    _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
    _initializeControllers(_currentVendors);
  }

  @override
  void didUpdateWidget(covariant VendorListDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if initialVendors actually changed to prevent unnecessary re-initialization
    if (widget.initialVendors != oldWidget.initialVendors) {
      _currentVendors = List.from(widget.initialVendors);
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
      _initializeControllers(_currentVendors); // Re-initialize controllers if underlying data changes
      _onSearchChanged(); // Re-apply search filter if data changes
    }
  }

  void _initializeControllers(List<Vendor> vendors) {
    _categoryControllers.clear();
    _vendorControllers.clear();
    for (var vendor in vendors) {
      _ensureController(vendor.service, _categoryControllers);
      _ensureController(vendor.uniqueId, _vendorControllers);
    }
  }

  void _ensureController(
    String key,
    Map<String, ExpansibleController> controllerMap,
  ) {
    controllerMap.putIfAbsent(key, () => ExpansibleController());
  }

  void _onSearchChanged() {
    final query = normalizeString(_searchController.text);
    List<Vendor> tempFilteredVendors;

    if (query.isEmpty) {
      tempFilteredVendors = List.from(widget.initialVendors);
    } else {
      tempFilteredVendors = widget.initialVendors.where((vendor) {
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

    // Collapse all vendor tiles when search query changes
    for (var controller in _vendorControllers.values) {
      controller.collapse();
    }

    if (!mounted) return;
    setState(() {
      _currentVendors = tempFilteredVendors;
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
      if (_searchController.text.isNotEmpty) {
        _expandAllVendors(); // Automatically expand vendors when searching
      } else {
        _collapseAllCategories(); // Collapse all when search is cleared
      }
    });
  }

  void _clearSearchBar() {
    _searchController.clear();
    // _onSearchChanged will handle the filtering and collapsing
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
      for (var categoryName in _categorizedFilteredVendors.keys) {
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
      _collapseAllVendors(); // Also collapse vendors when categories collapse
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _expandAllVendors() {
    if (!mounted) return;
    setState(() {
      bool anyCategoryOpenInFilteredView = _categorizedFilteredVendors.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      // If no categories are open, expand them all first
      if (!anyCategoryOpenInFilteredView && _categorizedFilteredVendors.isNotEmpty) {
        for (var categoryName in _categorizedFilteredVendors.keys) {
          _categoryControllers[categoryName]?.expand();
        }
      }

      // Then expand all vendors within currently expanded categories
      for (var entry in _categorizedFilteredVendors.entries) {
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
    final Map<String, List<Vendor>> groupedByServiceForExpansionCheck =
        _groupVendorsByService(_currentVendors); // Use _currentVendors for accurate check

    final visibleCategories = groupedByServiceForExpansionCheck.keys.toSet();

    bool areAllCatsExpanded = visibleCategories.isNotEmpty &&
        visibleCategories.every(
          (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
        );

    bool areAllVendorsExp = true;

    if (visibleCategories.isEmpty || groupedByServiceForExpansionCheck.values.every(
          (list) => list.isEmpty,
        )) {
      areAllVendorsExp = false;
    } else {
      var expandedCategoriesInView = visibleCategories
          .where(
            (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
          )
          .toList();

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

    // Only update state if something actually changed to prevent unnecessary rebuilds
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
    final sortedFilteredCategoryKeys = _categorizedFilteredVendors.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vendors...', // Placeholder for specific page
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
                  onPressed: widget.loading || _categorizedFilteredVendors.isEmpty
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
                  onPressed: widget.loading || _categorizedFilteredVendors.isEmpty
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
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : _currentVendors.isEmpty
                  ? const Center(child: Text('No vendors found'))
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: sortedFilteredCategoryKeys.map((category) {
                        final vendors = _categorizedFilteredVendors[category]!;
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
                            // Pass the favorite status from the map
                            final bool isFavorite = widget.favoriteStatusMap[vendor.uniqueId] ?? false;

                            return VendorCard(
                              key: ValueKey(vendor.uniqueId), // Ensure unique keys for list items
                              vendor: vendor,
                              isFavorite: isFavorite, // Pass the correct status!
                              vendorController: vendorController,
                              onToggleFavorite: widget.onToggleFavorite,
                              onSendRatingAndComment: widget.onSendRatingAndComment,
                              onExpansionStateChanged: _updateExpansionStates,
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }
}