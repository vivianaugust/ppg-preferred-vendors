// lib/widgets/vendor_list_display.dart

import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_card.dart';
import 'package:ppg_preferred_vendors/utils/firestore_helpers.dart'; // For normalizeString

// Define an enum to track the type of match for each vendor
enum _VendorMatchScope {
  noMatch, // Should not be in _vendorMatchScopeMap for filtered vendors (warning ignored for clarity of enum)
  companyOnly,
  otherFieldOnly,
  companyAndOtherField,
}

class VendorListDisplay extends StatefulWidget {
  final List<Vendor> initialVendors;
  final bool loading;
  final Function(Vendor) onToggleFavorite;
  final Function(Vendor, int, String, String, DateTime) onSendRatingAndComment;
  final Map<String, bool> favoriteStatusMap;
  final Function(List<int>)? onDeleteDuplicateRows; // NEW: Callback for deleting rows

  const VendorListDisplay({
    super.key,
    required this.initialVendors,
    required this.loading,
    required this.onToggleFavorite,
    required this.onSendRatingAndComment,
    required this.favoriteStatusMap,
    this.onDeleteDuplicateRows, // NEW: Add to constructor
  });

  @override
  State<VendorListDisplay> createState() => _VendorListDisplayState();
}

class _VendorListDisplayState extends State<VendorListDisplay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Vendor> _currentVendors = [];
  Map<String, List<Vendor>> _categorizedFilteredVendors = {};

  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  final Map<String, ExpansibleController> _categoryControllers = {};
  final Map<String, ExpansibleController> _vendorControllers = {};

  // New map to store how each vendor matched the search query (by uniqueId)
  final Map<String, _VendorMatchScope> _vendorMatchScopeMap = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _currentVendors = List.from(widget.initialVendors);
    _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
    _initializeControllers(_currentVendors); // Initial setup of controllers

    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuilds to update border color based on focus
      }
    });
  }

  @override
  void didUpdateWidget(covariant VendorListDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVendors != oldWidget.initialVendors) {
      _currentVendors = List.from(widget.initialVendors);
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
      // Important: Re-initialize/update controllers when initialVendors change
      _initializeControllers(_currentVendors);
      _onSearchChanged(); // Re-filter and update based on new initialVendors
    }
  }

  // Helper to generate a unique key for VendorCard and its controller
  String _getVendorKey(Vendor vendor, int index) {
    return vendor.uniqueId;
  }

  // Modified to intelligently manage controllers
  void _initializeControllers(List<Vendor> vendors) {
    // Determine the set of category and vendor keys that *should* exist
    Set<String> requiredCategoryKeys = {};
    Set<String> requiredVendorKeys = {};

    _groupVendorsByService(vendors).forEach((category, categoryVendors) {
      requiredCategoryKeys.add(category);
      for (int i = 0; i < categoryVendors.length; i++) {
        final vendor = categoryVendors[i];
        final String compoundVendorKey = _getVendorKey(vendor, i);
        requiredVendorKeys.add(compoundVendorKey);
      }
    });

    // Dispose controllers that are no longer needed (not in required sets)
    _categoryControllers.keys.toList().forEach((key) {
      if (!requiredCategoryKeys.contains(key)) {
        _categoryControllers[key]?.dispose();
        _categoryControllers.remove(key);
      }
    });
    _vendorControllers.keys.toList().forEach((key) {
      if (!requiredVendorKeys.contains(key)) {
        _vendorControllers[key]?.dispose();
        _vendorControllers.remove(key);
      }
    });

    // Create new controllers for required keys that don't yet exist
    for (var key in requiredCategoryKeys) {
      _categoryControllers.putIfAbsent(key, () => ExpansibleController());
    }
    for (var key in requiredVendorKeys) {
      _vendorControllers.putIfAbsent(key, () => ExpansibleController());
    }
  }

  void _onSearchChanged() {
    final query = normalizeString(_searchController.text);
    List<Vendor> tempFilteredVendors = [];
    _vendorMatchScopeMap.clear(); // Clear previous match info on new search

    if (query.isEmpty) {
      tempFilteredVendors = List.from(widget.initialVendors);
      // When search is cleared, unfocus if it has focus
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    } else {
      for (var vendor in widget.initialVendors) {
        final normalizedCompanyName = normalizeString(vendor.company);
        final companyMatches = normalizedCompanyName.contains(query);

        // --- EXCLUDE REVIEWS FROM SEARCH FIELDS ---
        final otherFieldsToSearch = [
          vendor.service,
          vendor.contactName,
          vendor.phone,
          vendor.email,
          vendor.website,
          vendor.address,
          vendor.paymentInfo,
        ].map((field) => normalizeString(field)).toList();

        final otherFieldMatches = otherFieldsToSearch.any((field) => field.contains(query));

        if (companyMatches || otherFieldMatches) {
          tempFilteredVendors.add(vendor);
          if (companyMatches && otherFieldMatches) {
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.companyAndOtherField;
          } else if (companyMatches) {
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.companyOnly;
          } else { // otherFieldMatches must be true here
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.otherFieldOnly;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _currentVendors = tempFilteredVendors;
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
      // Re-initialize/update controllers after the data source changes
      _initializeControllers(_currentVendors);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
      if (_searchController.text.isNotEmpty) {
        _handleSearchExpansion(); // Call new expansion logic for search results
      } else {
        _collapseAllCategories(); // Correctly collapse all when search is cleared
      }
    });
  }

  void _clearSearchBar() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Map<String, List<Vendor>> _groupVendorsByService(List<Vendor> vendors) {
    Map<String, List<Vendor>> grouped = {};
    for (var vendor in vendors) {
      grouped.putIfAbsent(vendor.service, () => []).add(vendor);
    }
    // Sort vendors within each category by company name
    grouped.forEach((key, value) {
      value.sort((a, b) => a.company.compareTo(b.company));
    });
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
      _collapseAllVendors(); // Also collapse all vendors when categories collapse
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  // New method to handle specific expansion logic based on search match type
  void _handleSearchExpansion() {
    if (!mounted) return;

    // First setState to ensure categories are expanded for relevant vendors
    setState(() {
      for (var categoryName in _categorizedFilteredVendors.keys) {
        _categoryControllers[categoryName]?.expand();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Second setState to apply vendor-level expansion after categories have expanded
      setState(() {
        // Iterate through the currently categorized and filtered vendors
        for (var entry in _categorizedFilteredVendors.entries) {
          final categoryName = entry.key;
          final vendorsList = entry.value;

          // Only operate on vendors within categories that are (now) expanded
          if (_categoryControllers[categoryName]?.isExpanded == true) {
            for (var vendorEntry in vendorsList.asMap().entries) {
              final vendor = vendorEntry.value;
              final index = vendorEntry.key;
              final String vendorKey = _getVendorKey(vendor, index);
              final matchScope = _vendorMatchScopeMap[vendor.uniqueId];

              // --- NEW EXPANSION LOGIC ---
              // Expand if matched by any field other than company name
              // Collapse if only company name matched or no specific match type (shouldn't be filtered if no match)
              if (matchScope == _VendorMatchScope.otherFieldOnly ||
                  matchScope == _VendorMatchScope.companyAndOtherField) {
                _vendorControllers[vendorKey]?.expand();
              } else {
                _vendorControllers[vendorKey]?.collapse();
              }
            }
          } else {
            // If category itself is not expanded, ensure its vendors are collapsed
            for (var vendorEntry in vendorsList.asMap().entries) {
              final vendor = vendorEntry.value;
              final index = vendorEntry.key;
              final String vendorKey = _getVendorKey(vendor, index);
              _vendorControllers[vendorKey]?.collapse();
            }
          }
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateExpansionStates();
      });
    });
  }

  void _expandAllVendors() {
    if (!mounted) return;
    setState(() {
      // Ensure categories are expanded if vendors are to be expanded within them
      bool anyCategoryOpenInFilteredView = _categorizedFilteredVendors.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (!anyCategoryOpenInFilteredView && _categorizedFilteredVendors.isNotEmpty) {
        for (var categoryName in _categorizedFilteredVendors.keys) {
          _categoryControllers[categoryName]?.expand();
        }
      }

      // Expand vendors only within currently expanded categories
      for (var entry in _categorizedFilteredVendors.entries) {
        final categoryName = entry.key;
        final vendorsList = entry.value;
        if (_categoryControllers[categoryName]?.isExpanded == true) {
          for (var vendorEntry in vendorsList.asMap().entries) {
            final vendor = vendorEntry.value;
            final index = vendorEntry.key;
            final String vendorKey = _getVendorKey(vendor, index);
            _vendorControllers[vendorKey]?.expand();
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
        _groupVendorsByService(_currentVendors);

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

          for (var vendorEntry in vendorsInCategory.asMap().entries) {
            final Vendor vendor = vendorEntry.value;
            final int index = vendorEntry.key;
            final String vendorKey = _getVendorKey(vendor, index);
            if (_vendorControllers[vendorKey]?.isExpanded != true) {
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
    _searchFocusNode.dispose();
    // Dispose all remaining controllers when the widget itself is disposed
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
          // --- REMOVED TapRegion to allow interaction outside search bar ---
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search vendors...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearchBar,
                          tooltip: 'Clear search',
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey, width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 2.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey, width: 1.0),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            ),
            style: const TextStyle(fontSize: 18),
            showCursor: true,
            cursorColor: Colors.blue,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _searchFocusNode.unfocus();
            },
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
                    _allCategoriesExpanded ? 'Collapse All Categories' : 'Expand All Categories',
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
                    _allVendorsExpanded ? 'Collapse All Vendors' : 'Expand All Vendors',
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
                  ? Center(
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'No vendors found for "${_searchController.text}".'
                            : 'No vendors available.',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: sortedFilteredCategoryKeys.map((category) {
                        final vendors = _categorizedFilteredVendors[category]!;
                        final categoryController = _categoryControllers.containsKey(category)
                            ? _categoryControllers[category]!
                            : ExpansibleController(); // Fallback

                        return ExpansionTile(
                          key: ValueKey(category),
                          controller: categoryController,
                          title: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // --- FIX START: Adjusting padding for Category ExpansionTile ---
                          // Remove default vertical padding from the tile itself
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                          // Remove default vertical padding from the children area
                          childrenPadding: EdgeInsets.zero, // Children (VendorCard) will handle their own padding
                          // --- FIX END ---
                          initiallyExpanded: categoryController.isExpanded,
                          onExpansionChanged: (isExpanded) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _updateExpansionStates();
                            });
                          },
                          children: vendors.asMap().entries.map((entry) {
                            final int index = entry.key; // Index within this category's vendor list
                            final Vendor vendor = entry.value;
                            final String vendorKey = _getVendorKey(vendor, index);

                            final vendorController = _vendorControllers.containsKey(vendorKey)
                                ? _vendorControllers[vendorKey]!
                                : ExpansibleController(); // Fallback

                            final bool isFavorite = widget.favoriteStatusMap[vendor.uniqueId] ?? false;

                            return VendorCard(
                              key: ValueKey(vendorKey),
                              vendor: vendor,
                              isFavorite: isFavorite,
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