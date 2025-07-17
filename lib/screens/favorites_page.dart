// lib/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/widgets/vendor_list_display.dart'; // Import the new shared widget

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Vendor> _allFavoriteVendors = [];
  bool _loading = true;
  // This map will store the favorite status for vendors displayed on this page.
  // Since all vendors on the FavoritesPage *are* favorites, this map will always
  // mark them as true.
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
        _allFavoriteVendors = []; // Clear previous favorites if user logs out
        _favoriteStatusMap.clear(); // Clear map as well
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
        
        // Populate the _favoriteStatusMap: all loaded vendors are favorites
        _favoriteStatusMap.clear();
        for (final vendor in _allFavoriteVendors) {
          _favoriteStatusMap[vendor.uniqueId] = true;
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
    int rating,
    String comment,
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
      List<String> currentComments = [];

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
        currentComments = commentsString
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      currentRatings.add(rating);
      currentComments.add(comment);

      double newAverageRating = currentRatings.isNotEmpty
          ? currentRatings.reduce((a, b) => a + b) / currentRatings.length
          : 0.0;

      final String newRatingListString = currentRatings.join(',');
      final String newCommentsString = currentComments.join(';');

      await vendorDocRef.update({
        'ratingListString': newRatingListString,
        'commentsString': newCommentsString,
        'averageRating': newAverageRating,
        'reviewCount': currentComments.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
      _loadFavorites(); // Reload data to show updated ratings/comments
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
      _loadFavorites(); // Reload the list after unfavoriting
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
      body: MediaQuery.removePadding(
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
              // Pass the favorite status map to VendorListDisplay
              favoriteStatusMap: _favoriteStatusMap,
            ),
          ),
        ),
      ),
    );
  }
}