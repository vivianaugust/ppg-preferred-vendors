// test/unit/vendor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for DocumentSnapshot

// IMPORTANT: This class is a "fake" or "stub" DocumentSnapshot.
// It does NOT implement the sealed DocumentSnapshot class (as that's forbidden).
// It only provides the specific methods/getters that Vendor.fromFirestore uses.
class FakeDocumentSnapshot {
  final String _id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this._id, this._data);

  // Provide the data() method that Vendor.fromFirestore expects
  Map<String, dynamic>? data() => _data;

  // Provide the id getter that Vendor.fromFirestore expects
  String get id => _id;

  // You do NOT need @override here because you're not implementing an interface,
  // nor overriding a method from a superclass (unless Mock provided them).
}

void main() {
  group('Vendor', () {
    test('Vendor.fromSheetRow creates Vendor object correctly', () {
      // Mock a row from Google Sheet data
      final List<Object?> sheetRow = [
        'Service A', // 0
        'Company A', // 1
        'Contact 1', // 2
        '111-222-3333', // 3
        'email@a.com', // 4
        'www.a.com', // 5
        'Address A', // 6
        'Notes A', // 7
        'Payment A', // 8
        '4.5', // 9 (averageRating)
        '5,4,4,5', // 10 (ratingListString)
        'Great service;Friendly staff', // 11 (commentsString)
      ];
      const int originalSheetRowIndex = 3; // 1-based index

      final vendor = Vendor.fromSheetRow(sheetRow, originalSheetRowIndex);

      expect(vendor.service, 'Service A');
      expect(vendor.company, 'Company A');
      expect(vendor.contactName, 'Contact 1');
      expect(vendor.phone, '111-222-3333');
      expect(vendor.email, 'email@a.com');
      expect(vendor.website, 'www.a.com');
      expect(vendor.address, 'Address A');
      expect(vendor.notes, 'Notes A');
      expect(vendor.paymentInfo, 'Payment A');
      expect(vendor.averageRating, 4.5);
      expect(vendor.ratingListString, '5,4,4,5');
      expect(vendor.commentsString, 'Great service;Friendly staff');
      expect(vendor.sheetRowIndex, originalSheetRowIndex);
      expect(vendor.comments.length, 2);
      expect(vendor.comments[0].rating, 5);
      expect(vendor.comments[0].comment, 'Great service');
      expect(vendor.comments[1].rating, 4);
      expect(vendor.comments[1].comment, 'Friendly staff');
    });

    test('Vendor.fromSheetRow handles missing data gracefully', () {
      final List<Object?> sheetRow = [
        'Service B',
        'Company B',
      ]; // Minimal data
      const int originalSheetRowIndex = 5;

      final vendor = Vendor.fromSheetRow(sheetRow, originalSheetRowIndex);

      expect(vendor.service, 'Service B');
      expect(vendor.company, 'Company B');
      expect(vendor.contactName, '');
      expect(vendor.averageRating, 0.0);
      expect(vendor.ratingListString, '');
      expect(vendor.commentsString, '');
      expect(vendor.comments, isEmpty);
      expect(vendor.sheetRowIndex, originalSheetRowIndex);
    });

    test('Vendor.fromFirestore creates Vendor object correctly', () {
      final Map<String, dynamic> firestoreData = {
        'services': 'Service C',
        'company': 'Company C',
        'contactName': 'Contact 3',
        'phone': '555-666-7777',
        'email': 'email@c.com',
        'website': 'www.c.com',
        'address': 'Address C',
        'notes': 'Notes C',
        'paymentInfo': 'Payment C',
        'averageRating': 3.8,
        'ratingListString': '3,4,4',
        'commentsString': 'Okay;Good;Nice',
        'reviewCount': 3,
        'savedAt': Timestamp.now(),
      };
      // Use the FakeDocumentSnapshot instead of a Mock.
      final fakeDoc = FakeDocumentSnapshot('vendor_c_id', firestoreData);

      // Explicitly cast to DocumentSnapshot<Object?>.
      // This cast asserts at compile-time that `fakeDoc` will behave
      // like a `DocumentSnapshot` at runtime for the methods/getters used by `Vendor.fromFirestore`.
      final vendor = Vendor.fromFirestore(fakeDoc as DocumentSnapshot<Object?>);

      expect(vendor.service, 'Service C');
      expect(vendor.company, 'Company C');
      expect(vendor.contactName, 'Contact 3');
      expect(vendor.averageRating, 3.8);
      expect(vendor.ratingListString, '3,4,4');
      expect(vendor.commentsString, 'Okay;Good;Nice');
      expect(vendor.comments.length, 3);
      expect(vendor.comments[0].rating, 3);
      expect(vendor.comments[0].comment, 'Okay');
    });

    test('Vendor.toFirestore converts Vendor object to map correctly', () {
      final vendor = Vendor(
        service: 'Service D',
        company: 'Company D',
        contactName: 'Contact 4',
        averageRating: 4.0,
        ratingListString: '4,4',
        commentsString: 'Good;Very good',
        comments: [VendorComment(4, 'Good'), VendorComment(4, 'Very good')],
        sheetRowIndex: 10,
      );

      final firestoreMap = vendor.toFirestore();

      expect(firestoreMap['services'], 'Service D');
      expect(firestoreMap['company'], 'Company D');
      expect(firestoreMap['contactName'], 'Contact 4');
      expect(firestoreMap['averageRating'], 4.0);
      expect(firestoreMap['ratingListString'], '4,4');
      expect(firestoreMap['commentsString'], 'Good;Very good');
      expect(firestoreMap['reviewCount'], 2);
      expect(firestoreMap.containsKey('sheetRowIndex'), false); // sheetRowIndex is not stored in Firestore
    });

    test('uniqueId getter generates correct ID', () {
      final vendor1 = Vendor(service: 'Plumbing', company: 'ABC Plumbing Co.', sheetRowIndex: 1);
      final vendor2 = Vendor(service: 'Electrical', company: 'XYZ Electric', sheetRowIndex: 2);
      final vendor3 = Vendor(service: 'Plumbing', company: 'ABC Plumbing Co.', sheetRowIndex: 3); // Same as vendor1

      expect(vendor1.uniqueId, 'plumbing_abc_plumbing_co');
      expect(vendor2.uniqueId, 'electrical_xyz_electric');
      expect(vendor1.uniqueId, vendor3.uniqueId); // Should be the same for identical service/company
    });

    test('VendorComment creates object correctly', () {
      final comment = VendorComment(5, 'Excellent service!');
      expect(comment.rating, 5);
      expect(comment.comment, 'Excellent service!');
    });
  });
}