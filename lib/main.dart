import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // NEW: Import Crashlytics
import 'dart:ui'; // NEW: For PlatformDispatcher

import 'screens/auth_page.dart';
import 'screens/home_page.dart';
import 'screens/email_verification_screen.dart';
import 'utils/logger.dart'; // NEW: Import your custom logger

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // NEW: Initialize your custom logger
  AppLogger.initialize();

  // NEW: Pass all uncaught "Flutter" errors from the framework to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // NEW: Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // Return true to indicate that you handled the error.
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendor Directory',
      theme: ThemeData(
        fontFamily: 'GlacialIndifference', // 👈 Global font
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 183, 102, 58),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          if (!user.emailVerified) {
            return const EmailVerificationScreen();
          }
          return const HomePage();
        } else {
          return const AuthPage();
        }
      },
    );
  }
}