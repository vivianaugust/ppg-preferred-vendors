// lib/pages/vendor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/services/sheet_data.dart'; // Corrected import
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart';

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  List<Vendor> _allVendorsFromSheet = [];
  bool _loading = true;
  final Map<String, bool> _isFavorite = {};

  @override
  void initState() {
    super.initState();
    _loadVendorsAndFavorites();
  }

  Future<void> _loadVendorsAndFavorites() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadVendorsFromSheet(); // This will now handle duplicates and re-fetch
    _isFavorite.clear();
    for (final vendor in _allVendorsFromSheet) {
      _isFavorite[vendor.uniqueId] = false;
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

      if (data == null || data.length < AppConstants.dataRowStartIndex + 1) {
        if (mounted) {
          setState(() {
            _allVendorsFromSheet = [];
          });
        }
        return;
      }

      // `data` is 0-indexed. `AppConstants.dataRowStartIndex` is the 0-indexed row number where actual data begins.
      // E.g., if headers are in rows 1 & 2 (indices 0 & 1), data starts at row 3 (index 2).
      // So, AppConstants.dataRowStartIndex should be 2.
      final List<List<Object?>> rawDataRows = data.skip(AppConstants.dataRowStartIndex).toList();

      final Set<String> uniqueIdTracker = {};
      final List<int> rowsToDelete = [];
      final List<Vendor> tempAllVendors = [];

      // Loop through rawDataRows to process and detect duplicates
      for (int i = 0; i < rawDataRows.length; i++) {
        List<Object?> row = rawDataRows[i];
        // originalSheetRowIndex is the 1-based index in the actual Google Sheet
        final int originalSheetRowIndex = i + AppConstants.dataRowStartIndex + 1;

        // Skip entirely empty rows
        if (row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          continue;
        }

        const int minExpectedColumns = 2; // Service and Company
        if (row.length < minExpectedColumns) {
          final List<Object?> paddedRow = List.from(row);
          while (paddedRow.length < minExpectedColumns) {
            paddedRow.add(null);
          }
          row = paddedRow;
        }

        try {
          final Vendor vendor = Vendor.fromSheetRow(row, originalSheetRowIndex);

          final service = vendor.service;
          final company = vendor.company;

          if (service.isEmpty || company.isEmpty) {
            continue; // Skip rows where essential fields are empty
          }

          if (uniqueIdTracker.contains(vendor.uniqueId)) {
            // DUPLICATE DETECTED! Mark current row for deletion.
            rowsToDelete.add(originalSheetRowIndex);
          } else {
            // This is a unique vendor (so far). Add to tracker and temp list.
            uniqueIdTracker.add(vendor.uniqueId);
            tempAllVendors.add(vendor);
          }
        } catch (e) {
          // Error parsing this specific row, log it but don't stop the whole process
          debugPrint('Error parsing vendor from row $originalSheetRowIndex: $e. Row data: $row');
        }
      }

      // After identifying all duplicates, proceed with deletion
      if (rowsToDelete.isNotEmpty) {
        // Sort in descending order to delete rows from the bottom up.
        // This is CRITICAL to prevent indices from shifting unexpectedly
        // when deleting multiple rows in a batch or sequential calls.
        rowsToDelete.sort((a, b) => b.compareTo(a));

        try {
          await sheetService.deleteRows(AppConstants.mainSheetName, rowsToDelete);
          // Important: After deleting, recursively re-fetch the data to get the clean list.
          // This ensures the UI receives a truly cleaned list from the updated sheet.
          return _loadVendorsFromSheet();
        } catch (e) {
          // If deletion fails, the duplicates will persist, and the UI will error out.
          // Consider showing a user-facing error message here.
          debugPrint('Failed to delete rows $rowsToDelete from sheet "${AppConstants.mainSheetName}": $e');
        }
      }

      if (mounted) {
        setState(() {
          _allVendorsFromSheet = tempAllVendors;
        });
      }
    } catch (e) {
      debugPrint('Fatal Error loading vendors from sheet: $e');
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
        _isFavorite.clear();
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
        for (final vendor in _allVendorsFromSheet) {
          _isFavorite[vendor.uniqueId] = favoritedVendorIds.contains(vendor.uniqueId);
        }
      });
    } catch (e) {
      debugPrint('Error loading favorite statuses from Firestore: $e');
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
      debugPrint('Error toggling favorite for $vendorCompanyName: $e');
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
    String reviewerName,
    DateTime timestamp,
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
        debugPrint(
          'Invalid sheetRowIndexToUpdate: $sheetRowIndexToUpdate for vendor ${vendor.uniqueId}. Cannot update rating/comment.',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Could not find vendor row to update in sheet.',
              ),
            ),
          );
        }
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

      final formattedTimestamp = DateFormat('MM/dd/yyyy').format(timestamp);
      final commentWithMetadata = newComment.trim().isNotEmpty
          ? '[$reviewerName - $formattedTimestamp] ${newComment.trim()}'
          : '[$reviewerName - $formattedTimestamp] (No comment)';

      String updatedCommentsString;
      if (existingCommentsString.isEmpty) {
        updatedCommentsString = commentWithMetadata;
      } else {
        updatedCommentsString = '$existingCommentsString;$commentWithMetadata';
      }

      final Map<String, Object> cellsToUpdate = {
        'K': updatedRatingList, // Column K for ratings
        'L': updatedCommentsString, // Column L for comments
      };

      await sheetService.updateCells(
        AppConstants.mainSheetName,
        sheetRowIndexToUpdate,
        cellsToUpdate,
      );

      // After updating a comment/rating, reload all vendors to reflect changes.
      // This will also re-run the duplicate check, but shouldn't find any
      // if the initial load already cleaned them.
      await _loadVendorsAndFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Review submitted successfully!',
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
      body: Column( // Use a Column to stack logo and content
        children: [
          SafeArea( // SafeArea for the logo to avoid status bar
            bottom: false, // Only care about top padding here
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Image.asset(
                'assets/ppg.png',
                height: 48,
              ),
            ),
          ),
          Expanded( // Expanded takes the remaining space for the VendorListDisplay
            child: Center(
              child: VendorListDisplay(
                initialVendors: _allVendorsFromSheet,
                loading: _loading,
                onToggleFavorite: _toggleFavorite,
                onSendRatingAndComment: _sendRatingAndComment,
                favoriteStatusMap: _isFavorite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}