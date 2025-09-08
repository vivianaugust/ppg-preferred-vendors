// lib/pages/favorites_page.dart
// (Content as you provided, only minimal refinement for clarity/consistency)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart';

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
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _allFavoriteVendors = [];
        _favoriteStatusMap.clear();
      });
      return;
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
          _favoriteStatusMap[vendor.uniqueId] = true; // All vendors here are favorites
        }

        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading favorite statuses: $e');
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to submit reviews.'),
          ),
        );
      }
      return;
    }

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
      _loadFavorites();
    } catch (e) {
      debugPrint('Error sending rating and comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    }
  }

  Future<void> _toggleFavorite(Vendor vendor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to unfavorite vendors.'),
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

      await vendorDocRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$vendorCompanyName removed from Favorites.')),
        );
      }
      _loadFavorites();
    } catch (e) {
      debugPrint('Error unfavoriting: $e');
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
                'assets/ppg.png', // Assuming your logo is named ppg.png and is in the assets folder
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