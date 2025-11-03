// lib/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
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
    AppLogger.info('FavoritesPage initialized. Loading favorite vendors.');
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    AppLogger.info('Starting to load favorites from Firestore.');
    // Assuming user is logged in
    final user = FirebaseAuth.instance.currentUser!; 

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .get();

      AppLogger.info('Found ${snapshot.docs.length} favorite vendors for user ${user.uid}.');
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
      AppLogger.info('Finished loading favorites and updated state.');
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

  Future<void> _sendRatingAndComment(
    Vendor vendor,
    int newRating,
    String newComment,
    String reviewerName,
    DateTime timestamp,
  ) async {
    AppLogger.info('Submitting rating and comment for vendor: ${vendor.company}');
    // Assuming user is logged in
    final user = FirebaseAuth.instance.currentUser!; 

    try {
      final vendorDocRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(vendor.uniqueId);

      final docSnapshot = await vendorDocRef.get();
      List<int> currentRatings = [];
      List<String> currentRawComments = [];

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final String ratingListString = data?['ratingListString'] ?? '';
        final String commentsString = data?['commentsString'] ?? '';

        currentRatings = ratingListString
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.tryParse)
            .whereType<int>()
            .toList();
        
        currentRawComments = commentsString
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      currentRatings.add(newRating);
      
      final newVendorComment = VendorComment(
        newRating,
        newComment.trim(),
        reviewerName: reviewerName,
        timestamp: timestamp,
      );

      currentRawComments.add(newVendorComment.toSheetString());

      double newAverageRating = currentRatings.isNotEmpty
          ? currentRatings.reduce((a, b) => a + b) / currentRatings.length
          : 0.0;

      final String newRatingListString = currentRatings.join(',');
      final String newCommentsString = currentRawComments.join(';');

      await vendorDocRef.update({
        'ratingListString': newRatingListString,
        'commentsString': newCommentsString,
        'averageRating': newAverageRating,
        'reviewCount': currentRawComments.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
      AppLogger.info('Successfully updated vendor doc with new review.');
      _loadFavorites();
    } catch (e, s) {
      AppLogger.error('Error sending rating and comment: $e', e, s);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    }
  }

  Future<void> _toggleFavorite(Vendor vendor) async {
    AppLogger.info('Attempting to toggle favorite status for vendor: ${vendor.company}');
    // Assuming user is logged in
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
      AppLogger.info('Successfully removed $vendorCompanyName from favorites.');
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