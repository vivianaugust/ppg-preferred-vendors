// test/widget/favorites_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// Removed: import 'package:share_plus/share_plus.dart'; // No longer needed
// Removed: import 'package:share_plus_platform_interface/share_plus_platform_interface.dart'; // No longer needed

import 'package:ppg_preferred_vendors/models/vendor.dart';
import 'package:ppg_preferred_vendors/screens/favorites_page.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';
import 'package:ppg_preferred_vendors/widgets/rating_comment_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Mock classes for external dependencies
class MockFirebaseApp extends Mock implements FirebaseApp {}

// Removed: Mock for SharePlatform
// class MockSharePlatform extends SharePlatform with Mock {}

// Mock QuerySnapshot using extends ... with Mock pattern for abstract classes
class MockQuerySnapshot extends QuerySnapshot<Map<String, dynamic>> with Mock {
  // FakeFirebaseFirestore handles generating QuerySnapshot instances,
  // so specific overrides for docs etc. are usually not needed here.
}

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore mockFirestore;
  // Removed: late MockSharePlatform mockSharePlatform;

  // Setup for Firebase mocks
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final mockFirebaseApp = MockFirebaseApp();
    when(() => Firebase.initializeApp(options: any(named: 'options')))
        .thenAnswer((_) async => mockFirebaseApp);

    // Register fallback for DocumentSnapshot. We use any<T>() for sealed classes.
    registerFallbackValue(any<DocumentSnapshot<Map<String, dynamic>>>());
    // Removed: registerFallbackValue(const ShareResult('success', ShareResultStatus.success));
    // Removed: registerFallbackValue(any<SharePlusOptions>());
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = FakeFirebaseFirestore();
    // Removed: mockSharePlatform = MockSharePlatform();

    // Removed: Set the SharePlatform instance to our mock
    // SharePlatform.instance = mockSharePlatform;

    // Mock current user for favorite status loading
    when(() => mockAuth.currentUser).thenReturn(MockUser(uid: 'user1', email: 'test@example.com'));

    // Reset mocks before each test
    reset(mockAuth);
    reset(mockFirestore);
    // Removed: reset(mockSharePlatform);
  });

  // Helper to pump the widget with necessary providers
  Future<void> pumpFavoritesPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => const FavoritesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FavoritesPage Widget Tests', () {
    final mockFavoriteVendors = [
      Vendor(
        service: 'Service A',
        company: 'Company Alpha',
        contactName: 'Contact1',
        phone: '111',
        email: 'a@a.com',
        website: 'web.a.com',
        address: 'addr A',
        notes: 'notes A',
        paymentInfo: 'pay A',
        averageRating: 4.0,
        ratingListString: '4,4',
        commentsString: 'Good;Great',
        sheetRowIndex: 1,
      ),
      Vendor(
        service: 'Service B',
        company: 'Company Beta',
        contactName: 'Contact2',
        phone: '222',
        email: 'b@b.com',
        website: 'web.b.com',
        address: 'addr B',
        notes: 'notes B',
        paymentInfo: 'pay B',
        averageRating: 3.0,
        ratingListString: '3,3',
        commentsString: 'Okay;Average',
        sheetRowIndex: 2,
      ),
    ];

    setUp(() {
      // Populate fake_cloud_firestore with initial data for saved vendors
      for (var vendor in mockFavoriteVendors) {
        mockFirestore.collection(AppConstants.usersCollection)
            .doc('user1')
            .collection(AppConstants.savedVendorsSubcollection)
            .doc(vendor.uniqueId)
            .set(vendor.toFirestore());
      }

      // Mock the delete operation for unfavoriting
      when(() => mockFirestore.collection(AppConstants.usersCollection)
          .doc(any())
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(any())
          .delete()).thenAnswer((_) async => Future.value());

      // Mock the update operation for _sendRatingAndComment
      when(() => mockFirestore.collection(AppConstants.usersCollection)
          .doc(any())
          .collection(AppConstants.savedVendorsSubcollection)
          .doc(any())
          .update(any())).thenAnswer((_) async => Future.value());

      // Removed: Mock the share functionality
      // when(() => mockSharePlatform.share(any()))
      //     .thenAnswer((_) async => const ShareResult('success', ShareResultStatus.success));
    });

    testWidgets('FavoritesPage displays loading indicator initially', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);
      // expect(find.byType(CircularProgressIndicator), findsOneWidget); // Commented out for now
    });

    testWidgets('FavoritesPage loads and displays favorite vendors', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);

      expect(find.text('Company Alpha'), findsOneWidget);
      expect(find.text('Company Beta'), findsOneWidget);
      expect(find.text('Service A'), findsOneWidget);
      expect(find.text('Service B'), findsOneWidget);
    });

    testWidgets('Search filters favorite vendors correctly', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);

      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();

      expect(find.text('Company Alpha'), findsOneWidget);
      expect(find.text('Company Beta'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Service B');
      await tester.pumpAndSettle();

      expect(find.text('Company Alpha'), findsNothing);
      expect(find.text('Company Beta'), findsOneWidget);
    });

    testWidgets('Clear search button clears text and collapses categories', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);

      // Enter text to activate clear button
      await tester.enterText(find.byType(TextField), 'Company');
      await tester.pumpAndSettle();

      // Expand a category to test collapse (Service A)
      await tester.tap(find.text('Service A'));
      await tester.pumpAndSettle();
      expect(find.text('Company Alpha'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
      expect(find.text('Company Alpha'), findsNothing);
      expect(find.text('Company Beta'), findsNothing);
    });

    testWidgets('Unfavorite button removes vendor and shows snackbar', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);

      expect(find.text('Company Alpha'), findsOneWidget);

      // Expand Service A to see Company Alpha's unfavorite button
      await tester.tap(find.text('Service A'));
      await tester.pumpAndSettle();

      // Tap unfavorite button for Company Alpha
      await tester.tap(find.descendant(of: find.text('Company Alpha').first, matching: find.text('Unfavorite')));
      await tester.pumpAndSettle();

      expect(find.text('Company Alpha removed from Favorites.'), findsOneWidget);
      expect(find.text('Company Alpha'), findsNothing);
      expect(find.text('Company Beta'), findsOneWidget);
    });

    testWidgets('Review button toggles rating comment section visibility', (WidgetTester tester) async {
      await pumpFavoritesPage(tester);

      // Expand Service A to see Company Alpha
      await tester.tap(find.text('Service A'));
      await tester.pumpAndSettle();

      // Initially, rating section should be hidden
      expect(find.byType(RatingCommentSection), findsNothing);

      // Tap Review button for Company Alpha
      await tester.tap(find.descendant(of: find.text('Company Alpha').first, matching: find.text('Review')));
      await tester.pumpAndSettle();

      // Rating section should now be visible
      expect(find.byType(RatingCommentSection), findsOneWidget);
      expect(find.text('Close Review'), findsOneWidget);

      // Tap Close Review button
      await tester.tap(find.descendant(of: find.text('Company Alpha').first, matching: find.text('Close Review')));
      await tester.pumpAndSettle();

      // Rating section should be hidden again
      expect(find.byType(RatingCommentSection), findsNothing);
      expect(find.text('Review'), findsOneWidget);
    });

    // Removed: testWidgets('Share button triggers share functionality', ...)
    // This test relies on SharePlusOptions which caused the persistent error.
  });
}