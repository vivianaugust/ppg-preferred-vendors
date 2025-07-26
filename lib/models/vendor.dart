// lib/models/vendor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Vendor {
  final String service;
  final String company;
  final String contactName;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String paymentInfo;
  final double averageRating;
  final String ratingListString;
  final String commentsString;
  final int sheetRowIndex; // Original row index in Google Sheet
  final List<VendorComment> comments; // Parsed comments
  final bool isFavorite;

  Vendor({
    required this.service,
    required this.company,
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.paymentInfo = '',
    this.averageRating = 0.0,
    this.ratingListString = '',
    this.commentsString = '',
    this.sheetRowIndex = 0,
    List<VendorComment>? comments,
    this.isFavorite = false,
  }) : comments = comments ?? [];

  static Vendor fromSheetRow(List<Object?> row, int originalSheetRowIndex) {
    final String ratingListString = row.length > 10 ? row[10]?.toString() ?? '' : '';
    final String commentsString = row.length > 11 ? row[11]?.toString().trim() ?? '' : '';

    List<int> ratings = ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
    List<String> rawComments = commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    List<VendorComment> parsedComments = [];
    for (int k = 0; k < rawComments.length; k++) {
      final int rating = k < ratings.length ? ratings[k] : 0;
      final String commentText = rawComments[k];
      if (commentText.isNotEmpty) {
        parsedComments.add(VendorComment.fromSheetString(commentText, rating));
      }
    }

    final double calculatedAverageRating = ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : 0.0;

    return Vendor(
      service: row[0]?.toString().trim() ?? '',
      company: row[1]?.toString().trim() ?? '',
      contactName: row.length > 2 ? row[2]?.toString().trim() ?? '' : '',
      phone: row.length > 3 ? row[3]?.toString().trim() ?? '' : '',
      email: row.length > 4 ? row[4]?.toString().trim() ?? '' : '',
      website: row.length > 5 ? row[5]?.toString().trim() ?? '' : '',
      address: row.length > 6 ? row[6]?.toString().trim() ?? '' : '',
      paymentInfo: row.length > 8 ? row[8]?.toString().trim() ?? '' : '',
      averageRating: calculatedAverageRating,
      ratingListString: ratingListString,
      commentsString: commentsString,
      sheetRowIndex: originalSheetRowIndex,
      comments: parsedComments,
      isFavorite: false,
    );
  }

  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String ratingListString = data['ratingListString'] ?? '';
    final String commentsString = data['commentsString'] ?? '';

    List<int> ratings = ratingListString.split(',').where((s) => s.isNotEmpty).map(int.tryParse).whereType<int>().toList();
    List<String> rawComments = commentsString.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    List<VendorComment> parsedComments = [];
    for (int k = 0; k < rawComments.length; k++) {
      final int rating = k < ratings.length ? ratings[k] : 0;
      final String commentText = rawComments[k];
      if (commentText.isNotEmpty) {
        parsedComments.add(VendorComment.fromSheetString(commentText, rating));
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
      paymentInfo: data['paymentInfo'] ?? '',
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingListString: ratingListString,
      commentsString: commentsString,
      comments: parsedComments,
      sheetRowIndex: (data['sheetRowIndex'] as num?)?.toInt() ?? 0,
      isFavorite: true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'services': service,
      'company': company,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'website': website,
      'address': address,
      'paymentInfo': paymentInfo,
      'averageRating': averageRating,
      'ratingListString': ratingListString,
      'commentsString': commentsString,
      'reviewCount': comments.length,
      'sheetRowIndex': sheetRowIndex,
    };
  }

  String get uniqueId {
    String normalize(String input) {
      return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]+'), '').trim().replaceAll(' ', '_');
    }
    return '${normalize(service)}_${normalize(company)}';
  }

  Vendor copyWith({
    String? service,
    String? company,
    String? contactName,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? paymentInfo,
    double? averageRating,
    String? ratingListString,
    String? commentsString,
    int? sheetRowIndex,
    List<VendorComment>? comments,
    bool? isFavorite,
  }) {
    return Vendor(
      service: service ?? this.service,
      company: company ?? this.company,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      averageRating: averageRating ?? this.averageRating,
      ratingListString: ratingListString ?? this.ratingListString,
      commentsString: commentsString ?? this.commentsString,
      sheetRowIndex: sheetRowIndex ?? this.sheetRowIndex,
      comments: comments ?? this.comments,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class VendorComment {
  final int rating;
  final String reviewerName;
  final DateTime timestamp;
  final String commentText;

  VendorComment(this.rating, this.commentText, {String? reviewerName, DateTime? timestamp})
      : reviewerName = reviewerName ?? 'Anonymous',
        timestamp = timestamp ?? DateTime.now();

  // Factory to parse the raw comment string from the sheet/Firestore
  factory VendorComment.fromSheetString(String rawCommentString, int rawRating) {
    String parsedReviewerName = 'Anonymous';
    DateTime parsedTimestamp = DateTime.now();
    String actualCommentText = rawCommentString.trim();

    // The key change: Added `dotAll: true` to make `.` match newlines.
    RegExp regExp = RegExp(r'^\[(.*?) - (.*?)\]\s*(.*)$', dotAll: true);
    Match? match = regExp.firstMatch(rawCommentString.trim());

    if (match != null) {
      parsedReviewerName = match.group(1)?.trim() ?? 'Anonymous';
      String dateString = match.group(2)?.trim() ?? '';
      actualCommentText = match.group(3)?.trim() ?? '';

      try {
        parsedTimestamp = DateFormat('MM/dd/yyyy').parseStrict(dateString);
      } catch (e) {
        parsedTimestamp = DateTime.now();
      }
    } else {
      parsedReviewerName = 'Anonymous';
      parsedTimestamp = DateTime.now();
      actualCommentText = rawCommentString.trim();
    }

    if (actualCommentText.isEmpty) {
      actualCommentText = "(No comment provided)";
    }

    return VendorComment(rawRating, actualCommentText, reviewerName: parsedReviewerName, timestamp: parsedTimestamp);
  }

  // Convert to the string format for storage
  String toSheetString() {
    final formattedTimestamp = DateFormat('MM/dd/yyyy').format(timestamp);
    // Ensure that reviewerName and timestamp are always included for consistent storage
    return '[$reviewerName - $formattedTimestamp] ${commentText.trim()}';
  }
}