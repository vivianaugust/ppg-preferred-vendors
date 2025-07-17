// test/widget/main_auth_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mocktail/mocktail.dart'; // For mocking Firebase.initializeApp

import 'package:ppg_preferred_vendors/main.dart'; // Your main app file
import 'package:ppg_preferred_vendors/screens/auth_page.dart';
import 'package:ppg_preferred_vendors/screens/home_page.dart';
import 'package:ppg_preferred_vendors/screens/email_verification_screen.dart';

// Mock Firebase.initializeApp
class MockFirebaseApp extends Mock implements FirebaseApp {}
// Removed: class MockFirebase extends Mock implements Firebase {} // This class was unused

void main() {
  // Mock Firebase.initializeApp before any tests run
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock the Firebase.initializeApp call
    final mockFirebaseApp = MockFirebaseApp();
    when(() => Firebase.initializeApp(options: any(named: 'options')))
        .thenAnswer((_) async => mockFirebaseApp);
  });

  group('AuthGate', () {
    testWidgets('shows CircularProgressIndicator when connection is waiting', (WidgetTester tester) async {
      // Create a MockFirebaseAuth instance. This automatically sets FirebaseAuth.instance
      // to this mock within the test environment.
      MockFirebaseAuth(signedIn: false);

      await tester.pumpWidget(
        const MaterialApp( // Added const for MaterialApp
          home: AuthGate(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('navigates to AuthPage when user is null', (WidgetTester tester) async {
      MockFirebaseAuth(signedIn: false); // User is null

      await tester.pumpWidget(
        const MaterialApp( // Added const for MaterialApp
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle(); // Wait for stream to settle

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(EmailVerificationScreen), findsNothing);
    });

    testWidgets('navigates to EmailVerificationScreen when user is not email verified', (WidgetTester tester) async {
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          isEmailVerified: false, // Not verified
        ),
      );

      await tester.pumpWidget(
        const MaterialApp( // Added const for MaterialApp
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('navigates to HomePage when user is signed in and email verified', (WidgetTester tester) async {
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          isEmailVerified: true, // Verified
        ),
      );

      await tester.pumpWidget(
        const MaterialApp( // Added const for MaterialApp
          home: AuthGate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(EmailVerificationScreen), findsNothing);
    });
  });
}