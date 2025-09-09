// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ppg_preferred_vendors/screens/home_page.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';

import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AppLogger.initialize();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
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
        fontFamily: 'GlacialIndifference',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 183, 102, 58),
        ),
      ),
      // Now, SplashScreen is the very first widget displayed when the app launches.
      home: const HomePage(),
    );
  }
}

// The AuthGate class is removed from here as its logic has been moved into SplashScreen.