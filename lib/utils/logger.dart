// lib/utils/logger.dart
import 'package:logging/logging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Import Crashlytics
import 'package:flutter/foundation.dart'; // Import kDebugMode

class AppLogger {
  static void initialize() {
    // Set to Level.ALL for development, or a stricter level for production.
    // In a real app, you might use a build configuration to control this.
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // Console output only in debug mode
      if (kDebugMode) {
        debugPrint('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');

        if (record.error != null) {
          debugPrint('ERROR: ${record.error}');
        }
        if (record.stackTrace != null) {
          debugPrint('STACK TRACE: ${record.stackTrace}');
        }
      }

      // Send severe errors to Firebase Crashlytics
      // This should ideally only happen in production builds.
      // You might add a conditional check like !kDebugMode here.
      if (record.level >= Level.SEVERE) {
        FirebaseCrashlytics.instance.recordError(
          record.error,
          record.stackTrace,
          reason: '${record.loggerName}: ${record.message}',
          fatal: record.level == Level.SHOUT, // Consider SHOUT as fatal
        );
      }
    });
  }

  static Logger get _appLogger => Logger('App'); // General app logger

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _appLogger.fine(message, error, stackTrace);
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _appLogger.info(message, error, stackTrace);
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _appLogger.warning(message, error, stackTrace);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _appLogger.severe(message, error, stackTrace);
  }

  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _appLogger.shout(message, error, stackTrace);
  }
}