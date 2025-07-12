// lib/models/vendor.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vendor {
  final String service;
  final String company;
  final String contactName;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String notes;
  final String paymentInfo;
  final double averageRating;
  final String ratingListString;
  final String commentsString;
  final int sheetRowIndex; // Original row index in Google Sheet
  final List<VendorComment> comments; // Parsed comments

  Vendor({
    required this.service,
    required this.company,
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.notes = '',
    this.paymentInfo = '',
    this.averageRating = 0.0,
    this.ratingListString = '',
    this.commentsString = '',
    this.sheetRowIndex = 0, // Default to 0, should be set when loaded
    List<VendorComment>? comments,
  }) : comments = comments ?? [];

  // Helper to parse a row from Google Sheet data into a Vendor object
  static Vendor fromSheetRow(List<Object?> row, int originalSheetRowIndex) {
    final String ratingListString = row.length > 10 ? row[10]?.toString() ?? '' : '';
    final String commentsString = row.length > 11 ? row[11]?.toString().trim() ?? '' : '';

    List<int> ratings = ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
    List<String> rawComments = commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    List<VendorComment> parsedComments = [];
    for (int k = 0; k < rawComments.length; k++) {
      final int rating = k < ratings.length ? ratings[k] : 0;
      final String comment = rawComments[k];
      if (comment.isNotEmpty) {
        parsedComments.add(VendorComment(rating, comment));
      }
    }

    return Vendor(
      service: row[0]?.toString().trim() ?? '',
      company: row[1]?.toString().trim() ?? '',
      contactName: row.length > 2 ? row[2]?.toString().trim() ?? '' : '',
      phone: row.length > 3 ? row[3]?.toString().trim() ?? '' : '',
      email: row.length > 4 ? row[4]?.toString().trim() ?? '' : '',
      website: row.length > 5 ? row[5]?.toString().trim() ?? '' : '',
      address: row.length > 6 ? row[6]?.toString().trim() ?? '' : '',
      notes: row.length > 7 ? row[7]?.toString().trim() ?? '' : '',
      paymentInfo: row.length > 8 ? row[8]?.toString().trim() ?? '' : '',
      averageRating: row.length > 9 ? double.tryParse(row[9]?.toString() ?? '0.0') ?? 0.0 : 0.0,
      ratingListString: ratingListString,
      commentsString: commentsString,
      sheetRowIndex: originalSheetRowIndex,
      comments: parsedComments,
    );
  }

  // Helper to create a Vendor from a Firestore DocumentSnapshot
  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String ratingListString = data['ratingListString'] ?? '';
    final String commentsString = data['commentsString'] ?? '';

    List<int> ratings = ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
    List<String> rawComments = commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    List<VendorComment> parsedComments = [];
    for (int k = 0; k < rawComments.length; k++) {
      final int rating = k < ratings.length ? ratings[k] : 0;
      final String comment = rawComments[k];
      if (comment.isNotEmpty) {
        parsedComments.add(VendorComment(rating, comment));
      }
    }

    return Vendor(
      service: data['services'] ?? '',
      company: data['company'] ?? '',
      contactName: data['contactName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      website: data['website'] ?? '',
      address: data['address'] ?? '',
      notes: data['notes'] ?? '',
      paymentInfo: data['paymentInfo'] ?? '',
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingListString: ratingListString,
      commentsString: commentsString,
      comments: parsedComments,
      sheetRowIndex: 0, // Not applicable for Firestore saved data, or store if needed
    );
  }


  // Converts a Vendor object to a map suitable for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'services': service,
      'company': company,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'website': website,
      'address': address,
      'notes': notes,
      'paymentInfo': paymentInfo,
      'averageRating': averageRating,
      'ratingListString': ratingListString,
      'commentsString': commentsString,
      'reviewCount': comments.length,
      // 'savedAt' would be added separately in the _toggleFavorite function
    };
  }

  // Generates a unique, Firestore-safe ID for a vendor
  String get uniqueId {
    String normalize(String input) {
      return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]+'), '').trim().replaceAll(' ', '_');
    }
    return '${normalize(service)}_${normalize(company)}';
  }
}

// Helper class for comments (can be in the same file or a separate 'comment.dart')
class VendorComment {
  final int rating;
  final String comment;
  VendorComment(this.rating, this.comment);
}