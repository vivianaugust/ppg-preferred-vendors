// lib/pages/vendor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Import the new files
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/services/sheet_data.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart'; // Import the new shared widget

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  // Only state specific to fetching and favorite status remains here
  List<Vendor> _allVendorsFromSheet = []; // The complete list of vendors from the sheet
  bool _loading = true;
  final Map<String, bool> _isFavorite = {}; // To track favorite status for each vendor

  // All other controllers and expansion states are now managed by VendorListDisplay

  @override
  void initState() {
    super.initState();
    _loadVendorsAndFavorites();
  }

  Future<void> _loadVendorsAndFavorites() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadVendorsFromSheet();
    // After loading vendors, ensure _isFavorite map is initialized for all of them
    _isFavorite.clear();
    for (final vendor in _allVendorsFromSheet) {
      _isFavorite[vendor.uniqueId] = false; // Default to false, then load actual status
    }
    await _loadFavoriteStatuses();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadVendorsFromSheet() async {
    try {
      final jsonString = await rootBundle.loadString(
        AppConstants.googleSheetJsonAssetPath,
      );

      final sheetService = SheetDataService(
        spreadsheetUrl: AppConstants.googleSheetUrl,
      );

      await sheetService.initializeFromJson(jsonString);
      final data = await sheetService.getSheetData(AppConstants.mainSheetName);

      if (data == null || data.length <= 2) {
        debugPrint('No data or only headers found in the sheet.');
        return;
      }

      final cleanedRows = data
          .sublist(2)
          .where(
            (row) => row.any(
              (cell) => cell != null && cell.toString().trim().isNotEmpty,
            ),
          )
          .toList();

      if (cleanedRows.isEmpty) {
        debugPrint('No meaningful data rows after cleaning.');
        return;
      }

      final List<Vendor> tempAllVendors = [];

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
          debugPrint(
            'Skipping row ${i + 3} due to empty service ("$service") or company name ("$company").',
          );
          continue;
        }

        final int originalSheetRowIndex = i + 3;
        final Vendor vendor = Vendor.fromSheetRow(row, originalSheetRowIndex);
        tempAllVendors.add(vendor);
      }

      if (mounted) {
        setState(() {
          _allVendorsFromSheet = tempAllVendors;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendors from sheet: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load vendors: $e')));
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
        // _isFavorite is already cleared and initialized with falses in _loadVendorsAndFavorites
        // No extra action needed here if user is null
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .get();

      final Set<String> favoritedVendorIds = snapshot.docs
          .map((doc) => doc.id)
          .toSet();

      if (!mounted) {
        return;
      }
      setState(() {
        // Update favorite status based on fetched data
        for (final vendor in _allVendorsFromSheet) {
          _isFavorite[vendor.uniqueId] = favoritedVendorIds.contains(
            vendor.uniqueId,
          );
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
          const SnackBar(
            content: Text('You must be logged in to favorite vendors.'),
          ),
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
        // Unfavorite
        await vendorDocRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$vendorCompanyName removed from Favorites.'),
            ),
          );
        }
        if (!mounted) return;
        setState(() {
          _isFavorite[vendor.uniqueId] = false;
        });
      } else {
        // Favorite
        await vendorDocRef.set(
          vendor.toFirestore()..['savedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$vendorCompanyName added to Favorites!')),
          );
        }
        if (!mounted) return;
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

  Future<void> _sendRatingAndComment(
    Vendor vendor,
    int newRating,
    String newComment,
  ) async {
    try {
      final sheetService = SheetDataService(
        spreadsheetUrl: AppConstants.googleSheetUrl,
      );

      final jsonString = await rootBundle.loadString(
        AppConstants.googleSheetJsonAssetPath,
      );
      await sheetService.initializeFromJson(jsonString);

      int? sheetRowIndexToUpdate = vendor.sheetRowIndex;

      if (sheetRowIndexToUpdate == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Could not find vendor row to update in sheet.',
              ),
            ),
          );
        }
        debugPrint(
          'Invalid sheetRowIndexToUpdate: $sheetRowIndexToUpdate for vendor ${vendor.uniqueId}',
        );
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
        updatedCommentsString = newComment.trim().isNotEmpty
            ? '$existingCommentsString;${newComment.trim()}'
            : existingCommentsString;
      }

      final Map<String, Object> cellsToUpdate = {
        'K': updatedRatingList,
        'L': updatedCommentsString,
      };

      await sheetService.updateCells(
        AppConstants.mainSheetName,
        sheetRowIndexToUpdate,
        cellsToUpdate,
      );

      // After updating the sheet, reload all vendors to reflect the new rating/comment
      await _loadVendorsAndFavorites(); // This will refresh the data displayed

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rating and comment submitted! Average rating updated.',
            ),
          ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            // Use the new VendorListDisplay widget
            child: VendorListDisplay(
              // Pass the raw list of vendors
              initialVendors: _allVendorsFromSheet,
              loading: _loading,
              onToggleFavorite: _toggleFavorite,
              onSendRatingAndComment: _sendRatingAndComment,
              // Pass the _isFavorite map directly to VendorListDisplay
              favoriteStatusMap: _isFavorite,
            ),
          ),
        ),
      ),
    );
  }
}