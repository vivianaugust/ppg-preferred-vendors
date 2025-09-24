// lib/widgets/vendor_list_display.dart
import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_card.dart';
import 'package:ppg_preferred_vendors/utils/firestore_helpers.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

enum _VendorMatchScope {
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
  final Function(List<int>)? onDeleteDuplicateRows;

  const VendorListDisplay({
    super.key,
    required this.initialVendors,
    required this.loading,
    required this.onToggleFavorite,
    required this.onSendRatingAndComment,
    required this.favoriteStatusMap,
    this.onDeleteDuplicateRows,
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

  final Map<String, _VendorMatchScope> _vendorMatchScopeMap = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('VendorListDisplay initialized.');
    _searchController.addListener(_onSearchChanged);
    _currentVendors = List.from(widget.initialVendors);
    _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
    _initializeControllers(_currentVendors);

    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant VendorListDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVendors != oldWidget.initialVendors) {
      AppLogger.info('VendorListDisplay received new data. Updating state.');
      _currentVendors = List.from(widget.initialVendors);
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
      _initializeControllers(_currentVendors);
      _onSearchChanged();
    }
  }

  String _getVendorKey(Vendor vendor, int index) {
    return vendor.uniqueId;
  }

  void _initializeControllers(List<Vendor> vendors) {
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

    for (var key in requiredCategoryKeys) {
      _categoryControllers.putIfAbsent(key, () => ExpansibleController());
    }
    for (var key in requiredVendorKeys) {
      _vendorControllers.putIfAbsent(key, () => ExpansibleController());
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final normalizedQuery = normalizeString(query);
    List<Vendor> tempFilteredVendors = [];
    _vendorMatchScopeMap.clear();

    if (query.isEmpty) {
      tempFilteredVendors = List.from(widget.initialVendors);
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    } else {
      for (var vendor in widget.initialVendors) {
        final normalizedCompanyName = normalizeString(vendor.company);
        final companyMatches = normalizedCompanyName.contains(normalizedQuery);
        final otherFieldsToSearch = [
          vendor.service,
          vendor.contactName,
          vendor.phone,
          vendor.email,
          vendor.website,
          vendor.address,
          vendor.paymentInfo,
        ].map((field) => normalizeString(field)).toList();

        final otherFieldMatches = otherFieldsToSearch.any((field) => field.contains(normalizedQuery));
        if (companyMatches || otherFieldMatches) {
          tempFilteredVendors.add(vendor);
          if (companyMatches && otherFieldMatches) {
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.companyAndOtherField;
          } else if (companyMatches) {
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.companyOnly;
          } else {
            _vendorMatchScopeMap[vendor.uniqueId] = _VendorMatchScope.otherFieldOnly;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _currentVendors = tempFilteredVendors;
      _categorizedFilteredVendors = _groupVendorsByService(_currentVendors);
      _initializeControllers(_currentVendors);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
      if (_searchController.text.isNotEmpty) {
        _handleSearchExpansion();
      } else {
        _collapseAllCategories();
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
      _collapseAllVendors();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _handleSearchExpansion() {
    if (!mounted) return;
    setState(() {
      for (var categoryName in _categorizedFilteredVendors.keys) {
        _categoryControllers[categoryName]?.expand();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (var entry in _categorizedFilteredVendors.entries) {
          final categoryName = entry.key;
          final vendorsList = entry.value;

          if (_categoryControllers[categoryName]?.isExpanded == true) {
            for (var vendorEntry in vendorsList.asMap().entries) {
              final vendor = vendorEntry.value;
              final index = vendorEntry.key;
              final String vendorKey = _getVendorKey(vendor, index);
              final matchScope = _vendorMatchScopeMap[vendor.uniqueId];

              if (matchScope == _VendorMatchScope.otherFieldOnly ||
                  matchScope == _VendorMatchScope.companyAndOtherField) {
                _vendorControllers[vendorKey]?.expand();
              } else {
                _vendorControllers[vendorKey]?.collapse();
              }
            }
          } else {
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
      bool anyCategoryOpenInFilteredView = _categorizedFilteredVendors.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (!anyCategoryOpenInFilteredView && _categorizedFilteredVendors.isNotEmpty) {
        for (var categoryName in _categorizedFilteredVendors.keys) {
          _categoryControllers[categoryName]?.expand();
        }
      }

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
    AppLogger.info('VendorListDisplay is being disposed.');
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
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
                            : ExpansibleController();
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
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
                          childrenPadding: EdgeInsets.zero,
                          initiallyExpanded: categoryController.isExpanded,
                          onExpansionChanged: (isExpanded) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _updateExpansionStates();
                            });
                          },
                          children: vendors.asMap().entries.map((entry) {
                            final int index = entry.key;
                            final Vendor vendor = entry.value;
                            final String vendorKey = _getVendorKey(vendor, index);
                            final vendorController = _vendorControllers.containsKey(vendorKey)
                                ? _vendorControllers[vendorKey]!
                                : ExpansibleController();
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