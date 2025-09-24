// lib/models/vendor.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

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
    AppLogger.info('Parsing vendor from sheet row at index $originalSheetRowIndex...');
    try {
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
      
      final vendor = Vendor(
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
      AppLogger.info('Successfully parsed vendor: ${vendor.company} from sheet.');
      return vendor;
    } catch (e, s) {
      AppLogger.error('Failed to parse vendor from sheet row: $e', e, s);
      rethrow;
    }
  }

  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    AppLogger.info('Parsing vendor from Firestore document with ID: ${doc.id}');
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      AppLogger.error('Firestore document data is null for ID: ${doc.id}');
      throw StateError('Document data is null');
    }

    try {
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
      final vendor = Vendor(
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
      AppLogger.info('Successfully parsed vendor: ${vendor.company} from Firestore.');
      return vendor;
    } catch (e, s) {
      AppLogger.error('Failed to parse vendor from Firestore: $e', e, s);
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    AppLogger.info('Converting vendor $company to Firestore map.');
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
    AppLogger.info('Creating a copy of vendor ${this.company}.');
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

  factory VendorComment.fromSheetString(String rawCommentString, int rawRating) {
    AppLogger.info('Parsing vendor comment: "$rawCommentString"');
    String parsedReviewerName = 'Anonymous';
    DateTime parsedTimestamp = DateTime.now();
    String actualCommentText = rawCommentString.trim();

    RegExp regExp = RegExp(r'^\[(.*?) - (.*?)\]\s*(.*)$', dotAll: true);
    Match? match = regExp.firstMatch(rawCommentString.trim());

    if (match != null) {
      parsedReviewerName = match.group(1)?.trim() ?? 'Anonymous';
      String dateString = match.group(2)?.trim() ?? '';
      actualCommentText = match.group(3)?.trim() ?? '';

      try {
        parsedTimestamp = DateFormat('MM/dd/yyyy').parseStrict(dateString);
        AppLogger.info('Successfully parsed date string: $dateString');
      } catch (e) {
        AppLogger.warning('Failed to parse date string "$dateString". Using current timestamp.');
        parsedTimestamp = DateTime.now();
      }
    } else {
      AppLogger.warning('Comment string format did not match expected pattern.');
      parsedReviewerName = 'Anonymous';
      parsedTimestamp = DateTime.now();
      actualCommentText = rawCommentString.trim();
    }

    if (actualCommentText.isEmpty) {
      actualCommentText = "(No comment provided)";
      AppLogger.info('Actual comment text was empty, replaced with placeholder.');
    }

    final comment = VendorComment(rawRating, actualCommentText, reviewerName: parsedReviewerName, timestamp: parsedTimestamp);
    AppLogger.info('Successfully parsed comment from reviewer: ${comment.reviewerName}');
    return comment;
  }

  // Convert to the string format for storage
  String toSheetString() {
    AppLogger.info('Converting comment to sheet string format.');
    final formattedTimestamp = DateFormat('MM/dd/yyyy').format(timestamp);
    return '[$reviewerName - $formattedTimestamp] ${commentText.trim()}';
  }
}