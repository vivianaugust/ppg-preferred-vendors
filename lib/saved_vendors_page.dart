import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedVendorsPage extends StatefulWidget {
  const SavedVendorsPage({super.key});

  @override
  State<SavedVendorsPage> createState() => _SavedVendorsPageState();
}

class _SavedVendorsPageState extends State<SavedVendorsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allVendors = [];
  List<DocumentSnapshot> _filteredVendors = [];
  bool _loading = true;

  // State variables for category and vendor expansion button indicators
  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  // Controllers for categories and individual vendors
  final Map<String, ExpansionTileController> _categoryControllers = {};
  final Map<String, ExpansionTileController> _vendorControllers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSavedVendors();
  }

  // Helper to ensure controller exists for a given key
  void _ensureController<T extends ExpansionTileController>(String key, Map<String, T> controllerMap) {
    controllerMap.putIfAbsent(key, () => ExpansionTileController() as T);
  }

  Future<void> _loadSavedVendors() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_vendors')
          .get();

      final sortedDocs = snapshot.docs;
      sortedDocs.removeWhere((doc) => doc.data() == null || doc.data() is! Map<String, dynamic>);

      sortedDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aService = aData['services']?.toString().toLowerCase() ?? '';
        final bService = bData['services']?.toString().toLowerCase() ?? '';
        return aService.compareTo(bService);
      });

      // Clear existing controllers before re-initializing
      _categoryControllers.clear();
      _vendorControllers.clear();

      // Initialize controllers for all fetched categories and vendors
      final Map<String, List<DocumentSnapshot>> tempGrouped = {};
      for (var doc in sortedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final service = data['services']?.toString() ?? 'Uncategorized';
        tempGrouped.putIfAbsent(service, () => []).add(doc);
      }

      tempGrouped.forEach((category, vendors) {
        _ensureController(category, _categoryControllers);
        for (var doc in vendors) {
          _ensureController(doc.id, _vendorControllers); // Using doc.id as unique ID for saved vendors
        }
      });

      setState(() {
        _allVendors = sortedDocs;
        _filteredVendors = List.from(sortedDocs);
        _loading = false;
        // Ensure initial state for buttons is collapsed
        _allCategoriesExpanded = false;
        _allVendorsExpanded = false;
      });
    } catch (e) {
      debugPrint('Error loading saved vendors: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();

    // Collapse all individual vendor tiles when search changes for a clean view.
    // This is generally desired even with multiple expansion enabled,
    // as new search results might not align with previously opened tiles.
    _vendorControllers.values.forEach((controller) => controller.collapse());

    setState(() {
      _filteredVendors = _allVendors.where((doc) {
        final data = doc.data();
        if (data == null || data is! Map<String, dynamic>) return false;

        final match = [
          'company',
          'services',
          'contactName',
          'notes',
          'phone',
          'email',
          'address'
        ].any((field) =>
            (data[field]?.toString().toLowerCase() ?? '').contains(query));

        return match;
      }).toList();

      // Expand categories and vendors when search query is active
      if (query.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Explicitly expand categories that have matching vendors
          _filteredVendors.forEach((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final service = data['services']?.toString() ?? 'Uncategorized';
            _categoryControllers[service]?.expand();
          });
          _expandAllVendors(); // Trigger expanding all vendors within currently visible categories
        });
      } else {
        // When search is cleared, collapse all and reset states
        _categoryControllers.values.forEach((controller) => controller.collapse());
        _allCategoriesExpanded = false;
        _allVendorsExpanded = false;
      }
    });
  }

  Future<void> _removeVendor(DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_vendors')
          .doc(doc.id)
          .delete();

      // Remove the controller for the deleted vendor
      _vendorControllers.remove(doc.id);

      // Reload data to update the UI
      _loadSavedVendors();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor removed!')),
        );
      }
    } catch (e) {
      debugPrint('Error removing vendor: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove vendor.')),
        );
      }
    }
  }

  Widget _buildLinkRow({
    required IconData icon,
    required String text,
    required Uri uri,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not launch $text')),
                    );
                  }
                }
              },
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- New Functionality for Expansion Buttons ---

  void _expandAllCategories() {
    setState(() {
      // Get unique categories from the currently filtered vendors
      _filteredVendors.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['services']?.toString() ?? 'Uncategorized';
      }).toSet().forEach((categoryName) {
        _categoryControllers[categoryName]?.expand();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _collapseAllCategories() {
    setState(() {
      _categoryControllers.values.forEach((controller) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      });
      _collapseAllVendors(); // Also collapse all vendors when categories collapse
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _expandAllVendors() {
    setState(() {
      // Group filtered vendors by service to correctly handle expansion logic
      final Map<String, List<DocumentSnapshot>> groupedFilteredVendors = {};
      for (var doc in _filteredVendors) {
        final data = doc.data() as Map<String, dynamic>;
        final service = data['services']?.toString() ?? 'Uncategorized';
        groupedFilteredVendors.putIfAbsent(service, () => []).add(doc);
      }

      bool anyCategoryOpenInFilteredView = groupedFilteredVendors.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (anyCategoryOpenInFilteredView) {
        // Scenario 1: Some categories are open. Expand only vendors in *those* categories.
        groupedFilteredVendors.forEach((categoryName, vendorsList) {
          if (_categoryControllers[categoryName]?.isExpanded == true) {
            for (var doc in vendorsList) {
              _vendorControllers[doc.id]?.expand();
            }
          }
        });
      } else {
        // Scenario 2: No categories are open. Expand all categories and all vendors.
        // First expand all categories
        groupedFilteredVendors.keys.forEach((categoryName) {
          _categoryControllers[categoryName]?.expand();
        });
        // Then expand all vendors within those categories
        _filteredVendors.forEach((doc) { // Iterate through all filtered vendors
          _vendorControllers[doc.id]?.expand();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }


  void _collapseAllVendors() {
    setState(() {
      _vendorControllers.values.forEach((controller) {
        if (controller.isExpanded) {
          controller.collapse();
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateExpansionStates();
    });
  }

  void _updateExpansionStates() {
    // Group vendors by service category from the _filteredVendors list
    final Map<String, List<DocumentSnapshot>> groupedByServiceForExpansionCheck = {};
    for (var doc in _filteredVendors) {
      final data = doc.data() as Map<String, dynamic>;
      final service = data['services']?.toString() ?? 'Uncategorized';
      groupedByServiceForExpansionCheck.putIfAbsent(service, () => []).add(doc);
    }
    final visibleCategories = groupedByServiceForExpansionCheck.keys.toSet();


    bool areAllCatsExpanded = visibleCategories.every(
      (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
    );

    bool areAllVendorsExp = true; // Assume true, prove false

    if (_filteredVendors.isEmpty) { // If no vendors are found, nothing is expanded.
      areAllVendorsExp = false;
    } else {
      var expandedCategoriesInView = visibleCategories.where(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true
      ).toList();

      if (expandedCategoriesInView.isEmpty) {
        areAllVendorsExp = false; // No categories expanded, so no vendors are considered "expanded" by the button
      } else {
        // Are ALL vendors WITHIN currently EXPANDED categories expanded?
        areAllVendorsExp = true;
        for (var categoryKey in expandedCategoriesInView) {
          final vendorsInCategory = groupedByServiceForExpansionCheck[categoryKey] ?? [];

          if (vendorsInCategory.isEmpty) continue; // Should not happen if category is in visibleCategories

          for (var doc in vendorsInCategory) {
            if (_vendorControllers[doc.id]?.isExpanded != true) {
              areAllVendorsExp = false;
              break; // Found a non-expanded vendor in an expanded category
            }
          }
          if (!areAllVendorsExp) break; // No need to check further categories
        }
      }
    }

    if (_allCategoriesExpanded != areAllCatsExpanded || _allVendorsExpanded != areAllVendorsExp) {
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
    _categoryControllers.values.forEach((controller) => controller.dispose());
    _vendorControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Group vendors by service category, only for filtered vendors
    final Map<String, List<DocumentSnapshot>> groupedByService = {};
    for (var doc in _filteredVendors) {
      final data = doc.data();
      if (data == null || data is! Map<String, dynamic>) continue;
      final service = data['services']?.toString() ?? 'Uncategorized';
      groupedByService.putIfAbsent(service, () => []).add(doc);
    }

    final sortedKeys = groupedByService.keys.toList()..sort();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search saved vendors...',
                    prefixIcon: const Icon(Icons.search),
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
                        onPressed: _loading || _filteredVendors.isEmpty
                            ? null // Disable if loading or no results
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
                        onPressed: _loading || _filteredVendors.isEmpty
                            ? null // Disable if loading or no results
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
                        ? const Center(child: Text('No saved vendors found'))
                        : ListView(
                            children: sortedKeys.map((category) {
                              final vendors = groupedByService[category]!;
                              final categoryController = _categoryControllers[category]!;

                              return ExpansionTile(
                                key: GlobalObjectKey(category), // Use GlobalObjectKey for categories
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
                                children: vendors.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final company = data['company'] ?? '';
                                  final contact = data['contactName'] ?? '';
                                  final phone = data['phone'] ?? '';
                                  final email = data['email'] ?? '';
                                  final website = data['website'] ?? '';
                                  final address = data['address'] ?? '';
                                  final notes = data['notes'] ?? '';

                                  final vendorController = _vendorControllers[doc.id]!;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    child: ExpansionTile(
                                      key: ValueKey(doc.id), // Use ValueKey for individual vendors
                                      controller: vendorController,
                                      title: Text(company),
                                      subtitle: notes.isNotEmpty
                                          ? Text(notes)
                                          : null,
                                      initiallyExpanded: vendorController.isExpanded,
                                      onExpansionChanged: (isExpanded) {
                                        setState(() {
                                          // Allow multiple vendor tiles to be expanded
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            _updateExpansionStates();
                                          });
                                        });
                                      },
                                      childrenPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (contact.isNotEmpty)
                                              Text('Contact: $contact'),
                                            if (phone.isNotEmpty)
                                              _buildLinkRow(
                                                icon: Icons.phone,
                                                text: phone,
                                                uri: Uri(
                                                    scheme: 'tel',
                                                    path: phone),
                                              ),
                                            if (email.isNotEmpty)
                                              _buildLinkRow(
                                                icon: Icons.email,
                                                text: email,
                                                uri: Uri(
                                                    scheme: 'mailto',
                                                    path: email),
                                              ),
                                            if (website.isNotEmpty)
                                              _buildLinkRow(
                                                icon: Icons.language,
                                                text: website,
                                                uri: Uri.parse(
                                                  website.startsWith('http')
                                                      ? website
                                                      : 'https://$website',
                                                ),
                                              ),
                                            if (address.isNotEmpty)
                                              _buildLinkRow(
                                                icon: Icons.location_on,
                                                text: address,
                                                // Correct Google Maps URL format
                                                uri: Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': Uri.encodeComponent(address)}),
                                              ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.share),
                                                  onPressed: () {
                                                    Share.share(
                                                        '$company\n$contact\n$phone\n$email\n$website\n$address\n$notes');
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                                'Remove Vendor'),
                                                            content: const Text(
                                                                'Are you sure you want to remove this vendor?'),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        false),
                                                                child: const Text(
                                                                    'Cancel'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        true),
                                                                child: const Text(
                                                                    'Remove'),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                    if (confirm == true) {
                                                      _removeVendor(doc);
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
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
    );
  }
}