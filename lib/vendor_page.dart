import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Still needed for other potential async operations, but no longer for search debounce
import 'sheet_data.dart'; // Assuming this file exists and is correct

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<List<Object?>>> _categorizedVendors = {};
  Map<String, List<List<Object?>>> _filteredCategories = {};
  bool _loading = true;

  // Separate state variables for category and vendor expansion
  bool _allCategoriesExpanded = false;
  bool _allVendorsExpanded = false;

  // Controllers for categories and individual vendors
  final Map<String, ExpansionTileController> _categoryControllers = {};
  final Map<String, ExpansionTileController> _vendorControllers = {};

  // Debounce timer removed as per request
  // Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadVendorsFromSheet();
  }

  void _ensureController<T extends ExpansionTileController>(String key, Map<String, T> controllerMap) {
    controllerMap.putIfAbsent(key, () => ExpansionTileController() as T);
  }

  Future<void> _loadVendorsFromSheet() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/ppg-vendors-d80304679d8f.json',
      );

      final sheetService = SheetDataService(
        spreadsheetUrl:
            'https://docs.google.com/sheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      await sheetService.initializeFromJson(jsonString);
      final data = await sheetService.getSheetData('Main List');

      if (data == null || data.length <= 2) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final cleaned = data
          .sublist(2)
          .where((row) =>
              row.isNotEmpty &&
              row.any((cell) => cell.toString().trim().isNotEmpty))
          .toList();

      final Map<String, List<List<Object?>>> tempCategorized = {};

      for (final row in cleaned) {
        if (row.length < 2) continue;

        final service = row[0]?.toString().trim();
        final company = row[1]?.toString().trim();

        if ((service?.isEmpty ?? true) || (company?.isEmpty ?? true)) continue;

        tempCategorized.putIfAbsent(service!, () => []).add(row);
      }

      if (mounted) {
        setState(() {
          _categorizedVendors = tempCategorized;
          _filteredCategories = Map.from(tempCategorized);
          _loading = false;
          // Ensure initial state is collapsed for both
          _allCategoriesExpanded = false;
          _allVendorsExpanded = false;

          // Initialize controllers for ALL categories and ALL vendors once.
          _categorizedVendors.forEach((category, vendors) {
            _ensureController(category, _categoryControllers);
            for (var row in vendors) {
              _ensureController(_getVendorUniqueId(row), _vendorControllers);
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading vendors: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  void _onSearchChanged() {
    // Debounce timer logic removed
    final query = _normalize(_searchController.text);

    Map<String, List<List<Object?>>> newFilteredCategories = {};

    // We still collapse all individual vendor tiles when search changes for a clean view,
    // as this is usually desired when new search results appear.
    _vendorControllers.values.forEach((controller) => controller.collapse());

    if (query.isEmpty) {
      newFilteredCategories = Map.from(_categorizedVendors);
      // When search is cleared, collapse all and reset states
      _categoryControllers.values.forEach((controller) => controller.collapse());
      _allCategoriesExpanded = false;
      _allVendorsExpanded = false;
    } else {
      final sortedCategories = _categorizedVendors.keys.toList()..sort();

      for (final category in sortedCategories) {
        final vendors = _categorizedVendors[category]!;
        final matching = vendors.where((row) {
          final fieldsToSearch = [
            category,
            row.length > 1 ? row[1] : '',
            row.length > 2 ? row[2] : '',
            row.length > 3 ? row[3] : '',
            row.length > 4 ? row[4] : '',
            row.length > 5 ? row[5] : '',
            row.length > 6 ? row[6] : '',
            row.length > 7 ? row[7] : '',
          ].map((field) => _normalize(field?.toString() ?? '')).toList();

          return fieldsToSearch.any((field) => field.contains(query));
        }).toList();

        if (matching.isNotEmpty) {
          newFilteredCategories[category] = matching;
        } else {
          _categoryControllers[category]?.collapse();
        }
      }
      // Trigger "Expand Vendors" when search is active
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_searchController.text.isNotEmpty) { // Only expand if still searching
          _expandAllVendors();
        }
      });
    }

    setState(() {
      _filteredCategories = newFilteredCategories;
    });
  }

  void _expandAllCategories() {
    setState(() {
      _filteredCategories.keys.forEach((categoryName) {
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
      bool anyCategoryOpenInFilteredView = _filteredCategories.keys.any(
        (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
      );

      if (anyCategoryOpenInFilteredView) {
        // Scenario 1: Some categories are open. Expand only vendors in *those* categories.
        _filteredCategories.forEach((categoryName, vendorsList) {
          if (_categoryControllers[categoryName]?.isExpanded == true) {
            for (var row in vendorsList) {
              final vendorUniqueId = _getVendorUniqueId(row);
              _vendorControllers[vendorUniqueId]?.expand();
            }
          }
        });
      } else {
        // Scenario 2: No categories are open. Expand all categories and all vendors.
        // First expand all categories
        _filteredCategories.keys.forEach((categoryName) {
          _categoryControllers[categoryName]?.expand();
        });
        // Then expand all vendors within those categories
        _filteredCategories.forEach((categoryName, vendorsList) {
            for (var row in vendorsList) {
                final vendorUniqueId = _getVendorUniqueId(row);
                _vendorControllers[vendorUniqueId]?.expand();
            }
        });
      }
    }); // End of setState that performs all expansions

    // Call _updateExpansionStates after the current frame is built,
    // to reflect the new expansion states in the buttons.
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

  @override
  void dispose() {
    // _searchDebounce?.cancel(); // Removed timer cancellation
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _categoryControllers.values.forEach((controller) => controller.dispose());
    _vendorControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
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
          Flexible(
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
                    color: Colors.blue, decoration: TextDecoration.underline),
                softWrap: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getVendorUniqueId(List<Object?> row) {
    final company = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
    final phone = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
    final email = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
    return '$company-${phone.replaceAll(RegExp(r'\D'), '')}-${email.toLowerCase()}';
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
                          onPressed: _loading || _filteredCategories.isEmpty
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
                                  children: vendors.map((row) {
                                    final company = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
                                    final contact = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
                                    final phone = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
                                    final email = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
                                    final website = row.length > 5 ? row[5]?.toString().trim() ?? '' : '';
                                    final address = row.length > 6 ? row[6]?.toString().trim() ?? '' : '';
                                    final notes = row.length > 7 ? row[7]?.toString().trim() ?? '' : '';

                                    final String vendorUniqueId = _getVendorUniqueId(row);

                                    final vendorController = _vendorControllers[vendorUniqueId]!;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      child: ExpansionTile(
                                        key: ValueKey(vendorUniqueId),
                                        controller: vendorController,
                                        title: Text(
                                          company,
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        subtitle: notes.isNotEmpty ? Text(notes) : null,
                                        initiallyExpanded: vendorController.isExpanded,
                                        onExpansionChanged: (isExpanded) {
                                          setState(() {
                                            // THIS IS THE LINE THAT WAS REMOVED TO ALLOW MULTIPLE VENDOR EXPANSIONS
                                            // No longer collapsing other vendor tiles here.
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _updateExpansionStates();
                                            });
                                          });
                                        },
                                        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (contact.isNotEmpty)
                                                Text('Contact: $contact'),
                                              if (phone.isNotEmpty)
                                                _buildLinkRow(
                                                  icon: Icons.phone,
                                                  text: phone,
                                                  uri: Uri(scheme: 'tel', path: phone),
                                                ),
                                              if (email.isNotEmpty)
                                                _buildLinkRow(
                                                  icon: Icons.email,
                                                  text: email,
                                                  uri: Uri(scheme: 'mailto', path: email),
                                                ),
                                              if (website.isNotEmpty)
                                                _buildLinkRow(
                                                  icon: Icons.language,
                                                  text: website,
                                                  uri: Uri.parse(
                                                    website.startsWith('http') ? website : 'https://$website',
                                                  ),
                                                ),
                                              if (address.isNotEmpty)
                                                _buildLinkRow(
                                                  icon: Icons.location_on,
                                                  text: address,
                                                  uri: Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': Uri.encodeComponent(address)}),
                                                ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.share),
                                                    onPressed: () {
                                                      String shareText = '$company';
                                                      if (contact.isNotEmpty) shareText += '\nContact: $contact';
                                                      if (phone.isNotEmpty) shareText += '\nPhone: $phone';
                                                      if (email.isNotEmpty) shareText += '\nEmail: $email';
                                                      if (website.isNotEmpty) shareText += '\nWebsite: $website';
                                                      if (address.isNotEmpty) shareText += '\nAddress: $address';
                                                      if (notes.isNotEmpty) shareText += '\nNotes: $notes';
                                                      Share.share(shareText);
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.bookmark_add_outlined),
                                                    onPressed: () async {
                                                      final user = FirebaseAuth.instance.currentUser;
                                                      if (user != null) {
                                                        try {
                                                          await FirebaseFirestore.instance
                                                              .collection('users')
                                                              .doc(user.uid)
                                                              .collection('saved_vendors')
                                                              .add({
                                                            'company': company,
                                                            'contactName': contact,
                                                            'phone': phone,
                                                            'email': email,
                                                            'website': website,
                                                            'address': address,
                                                            'notes': notes,
                                                            'services': category,
                                                            'savedAt': FieldValue.serverTimestamp(),
                                                          });

                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Vendor saved!')),
                                                            );
                                                          }
                                                        } catch (e) {
                                                          debugPrint('Error saving vendor: $e');
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Failed to save vendor.')),
                                                            );
                                                          }
                                                        }
                                                      } else {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Please sign in to save vendors.')),
                                                          );
                                                        }
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
      ),
    );
  }

  void _updateExpansionStates() {
    bool areAllCatsExpanded = _filteredCategories.keys.every(
      (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true,
    );

    bool areAllVendorsExp = true; // Assume true, prove false

    // If there are no categories to display, then no vendors are "expanded"
    if (_filteredCategories.isEmpty) {
      areAllVendorsExp = false;
    } else {
      // Get a list of only the currently expanded categories
      var expandedCategories = _filteredCategories.keys.where(
          (categoryKey) => _categoryControllers[categoryKey]?.isExpanded == true
      ).toList();

      // If no categories are expanded, then no vendors are considered "expanded" by the button's definition
      if (expandedCategories.isEmpty) {
        areAllVendorsExp = false;
      } else {
        // Iterate only through vendors of categories that ARE expanded
        for (var categoryKey in expandedCategories) {
          for (var row in _filteredCategories[categoryKey]!) {
            final vendorId = _getVendorUniqueId(row);
            if (_vendorControllers[vendorId]?.isExpanded != true) {
              areAllVendorsExp = false;
              break;
            }
          }
          if (!areAllVendorsExp) break;
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
}