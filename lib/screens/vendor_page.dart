// lib/pages/vendor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/services/sheet_data.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

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
    AppLogger.info('VendorPage initialized. Starting to load vendors and favorites.');
    _loadVendorsAndFavorites();
  }

  Future<void> _loadVendorsAndFavorites() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadVendorsFromSheet();
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

      final List<List<Object?>> rawDataRows = data.skip(AppConstants.dataRowStartIndex).toList();
      final Set<String> uniqueIdTracker = {};
      final List<int> rowsToDelete = [];
      final List<Vendor> tempAllVendors = [];

      for (int i = 0; i < rawDataRows.length; i++) {
        List<Object?> row = rawDataRows[i];
        final int originalSheetRowIndex = i + AppConstants.dataRowStartIndex + 1;

        if (row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          continue;
        }

        const int minExpectedColumns = 2;
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
            continue;
          }

          if (uniqueIdTracker.contains(vendor.uniqueId)) {
            AppLogger.warning('Duplicate vendor detected for ${vendor.uniqueId}. Marking row $originalSheetRowIndex for deletion.');
            rowsToDelete.add(originalSheetRowIndex);
          } else {
            uniqueIdTracker.add(vendor.uniqueId);
            tempAllVendors.add(vendor);
          }
        } catch (e, s) {
          AppLogger.error('Error parsing vendor from row $originalSheetRowIndex: $e. Row data: $row', e, s);
        }
      }

      if (rowsToDelete.isNotEmpty) {
        rowsToDelete.sort((a, b) => b.compareTo(a));
        try {
          await sheetService.deleteRows(AppConstants.mainSheetName, rowsToDelete);
          return _loadVendorsFromSheet();
        } catch (e, s) {
          AppLogger.error('Failed to delete duplicate rows from sheet: $e', e, s);
        }
      }

      if (mounted) {
        setState(() {
          _allVendorsFromSheet = tempAllVendors;
        });
      }
    } catch (e, s) {
      AppLogger.fatal('Fatal Error loading vendors from sheet: $e', e, s);
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
    } catch (e, s) {
      AppLogger.error('Error loading favorite statuses from Firestore: $e', e, s);
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
        if (!mounted) return;
        setState(() {
          _isFavorite[vendor.uniqueId] = false;
        });
      } else {
        await vendorDocRef.set(
          vendor.toFirestore()..['savedAt'] = FieldValue.serverTimestamp(),
          SetOptions(merge: true),
        );
        if (!mounted) return;
        setState(() {
          _isFavorite[vendor.uniqueId] = true;
        });
      }
    } catch (e, s) {
      AppLogger.error('Error toggling favorite for $vendorCompanyName: $e', e, s);
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
        AppLogger.error('Invalid sheetRowIndexToUpdate: $sheetRowIndexToUpdate for vendor ${vendor.uniqueId}. Cannot update rating/comment.');
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
        'K': updatedRatingList,
        'L': updatedCommentsString,
      };
      await sheetService.updateCells(
        AppConstants.mainSheetName,
        sheetRowIndexToUpdate,
        cellsToUpdate,
      );
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
    } catch (e, s) {
      AppLogger.error('Error sending rating/comment to sheet: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send rating/comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    AppLogger.info('VendorPage is being disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Image.asset(
                'assets/ppg.png',
                height: 48,
              ),
            ),
          ),
          Expanded(
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