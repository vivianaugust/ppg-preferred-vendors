// lib/screens/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle; // FIX: Added for SheetDataService
import 'package:intl/intl.dart'; // Required for comment formatting
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/services/sheet_data.dart'; // FIX: Added for SheetDataService
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Vendor> _allFavoriteVendors = [];
  bool _loading = true;
  final Map<String, bool> _favoriteStatusMap = {};

  @override
  void initState() {
    super.initState();
    AppLogger.info('FavoritesPage initialized. Starting to load favorite vendors.');
    _loadFavorites();
  }

  // FIX: Use didChangeDependencies to reload data reliably when the page is focused (tab switch).
  // This ensures the page is always up-to-date, mimicking the VendorPage's reload after navigation.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final currentRoute = ModalRoute.of(context);
    
    // Check if the page is currently active (visible) and we are not already loading.
    if (currentRoute?.isCurrent == true && !_loading) {
      AppLogger.info('FavoritesPage route regained focus, reloading data.');
      setState(() {
        _loading = true; 
      });
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser; 
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!_loading && mounted) {
        setState(() {
            _loading = true;
        });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .get();

      if (!mounted) return;
      
      setState(() {
        _allFavoriteVendors = snapshot.docs
            .map((doc) => Vendor.fromFirestore(doc))
            .toList();
        
        _favoriteStatusMap.clear();
        for (final vendor in _allFavoriteVendors) {
          _favoriteStatusMap[vendor.uniqueId] = true;
        }

        _loading = false;
      });
    } catch (e, s) {
      AppLogger.error('Error loading favorite statuses: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load favorite statuses: $e')),
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // FIX: Logic is now identical to VendorPage's _sendRatingAndComment (updates sheet).
  Future<void> _sendRatingAndComment(
    Vendor vendor,
    int newRating,
    String newComment,
    String reviewerName,
    DateTime timestamp,
    int? reviewIndex,
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
        AppLogger.error('Invalid sheetRowIndex for vendor ${vendor.uniqueId}. Cannot update rating/comment.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not find vendor row to update in sheet.')),
          );
        }
        return;
      }

      // Read current lists from the vendor object (which holds the current sheet data)
      List<int> currentRatings = vendor.ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
      List<String> currentRawComments = vendor.commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final formattedTimestamp = DateFormat('MM/dd/yyyy').format(timestamp);
      final newCommentString = newComment.trim().isNotEmpty
          ? '[$reviewerName - $formattedTimestamp] ${newComment.trim()}'
          : '[$reviewerName - $formattedTimestamp] (No comment)';

      if (reviewIndex != null && reviewIndex < currentRawComments.length) {
          // Edit existing review
          currentRatings[reviewIndex] = newRating;
          currentRawComments[reviewIndex] = newCommentString;
      } else {
          // Add new review
          currentRatings.add(newRating);
          currentRawComments.add(newCommentString);
      }

      final String updatedRatingList = currentRatings.join(',');
      final String updatedCommentsString = currentRawComments.join(';');

      final Map<String, Object> cellsToUpdate = {
        'K': updatedRatingList, // Column K for ratingListString
        'L': updatedCommentsString, // Column L for commentsString
      };
      
      await sheetService.updateCells(
        AppConstants.mainSheetName,
        sheetRowIndexToUpdate,
        cellsToUpdate,
      );
      
      // OPTIONAL: Update the favorite document in Firestore to reflect the sheet change immediately
      final user = FirebaseAuth.instance.currentUser!; 
      final vendorDocRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(vendor.uniqueId);

      await vendorDocRef.update({
        'ratingListString': updatedRatingList,
        'commentsString': updatedCommentsString,
        'averageRating': currentRatings.isNotEmpty
          ? currentRatings.reduce((a, b) => a + b) / currentRatings.length
          : 0.0,
        'reviewCount': currentRawComments.length,
      });

      // Reload favorites to refresh the local state
      await _loadFavorites();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Review ${reviewIndex != null ? 'updated' : 'submitted'} successfully!',
            ),
          ),
        );
      }
    } catch (e, s) {
      AppLogger.error('Error sending rating/comment: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  // FIX: Logic is now identical to VendorPage's _deleteReview (updates sheet) and is type-safe.
  Future<void> _deleteReview(
    Vendor vendor, 
    int reviewIndex
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
        AppLogger.error('Invalid sheetRowIndex for vendor ${vendor.uniqueId}. Cannot delete rating/comment.');
        return;
      }

      // Read current lists from the vendor object
      List<int> currentRatings = vendor.ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
      List<String> currentRawComments = vendor.commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      if (reviewIndex >= 0 && reviewIndex < currentRawComments.length) {
          currentRatings.removeAt(reviewIndex);
          currentRawComments.removeAt(reviewIndex);

          final String updatedRatingList = currentRatings.join(',');
          final String updatedCommentsString = currentRawComments.join(';');

          final Map<String, Object> cellsToUpdate = {
            'K': updatedRatingList,
            'L': updatedCommentsString,
          };
          
          await sheetService.updateCells(
            AppConstants.mainSheetName,
            sheetRowIndexToUpdate,
            cellsToUpdate,
          );

          // OPTIONAL: Update the favorite document in Firestore to reflect the sheet change immediately
          final user = FirebaseAuth.instance.currentUser!;
          final vendorDocRef = FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .collection(AppConstants.savedVendorsSubcollection)
              .doc(vendor.uniqueId);

          await vendorDocRef.update({
            'ratingListString': updatedRatingList,
            'commentsString': updatedCommentsString,
            'averageRating': currentRatings.isNotEmpty
              ? currentRatings.reduce((a, b) => a + b) / currentRatings.length
              : 0.0,
            'reviewCount': currentRawComments.length,
          });
          
          // Reload favorites to refresh the local state
          await _loadFavorites();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review deleted successfully!')),
            );
          }
      } else {
          AppLogger.error('Invalid review index $reviewIndex for deletion on vendor ${vendor.uniqueId}.');
      }
    } catch (e, s) {
      AppLogger.error('Error deleting review: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete review: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Vendor vendor) async {
    final user = FirebaseAuth.instance.currentUser!; 
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
      // Reload the favorites list to remove the vendor from the screen immediately.
      _loadFavorites(); 
    } catch (e, s) {
      AppLogger.error('Error unfavoriting: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove from favorites: $e')),
        );
      }
    }
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
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: VendorListDisplay(
                    initialVendors: _allFavoriteVendors,
                    loading: _loading,
                    onToggleFavorite: _toggleFavorite,
                    onSendRatingAndComment: _sendRatingAndComment,
                    favoriteStatusMap: _favoriteStatusMap,
                    onDeleteReview: _deleteReview,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}