import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ppg_preferred_vendors/screens/home_page.dart';
import 'package:ppg_preferred_vendors/screens/auth_page.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  String? _userEmail;
  late BuildContext _safeContext;

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;
    AppLogger.info('EmailVerificationScreen initialized for user: $_userEmail');

    // Send the verification email once
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        user.sendEmailVerification();
        AppLogger.info('Verification email sent to $_userEmail');
      } catch (e, s) {
        AppLogger.error('Failed to send verification email: $e', e, s);
      }
    }

    // Start polling every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      AppLogger.info('Checking email verification status for $_userEmail...');
      await FirebaseAuth.instance.currentUser?.reload();
      final reloadedUser = FirebaseAuth.instance.currentUser;

      if (reloadedUser != null && reloadedUser.emailVerified) {
        AppLogger.info('Email verified successfully! Navigating to home page.');
        _timer.cancel();

        if (mounted) {
          Navigator.of(_safeContext).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } else {
        AppLogger.info('Email not yet verified. Continuing to poll.');
      }
    });
  }

  @override
  void dispose() {
    AppLogger.info('EmailVerificationScreen is being disposed. Canceling timer.');
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _safeContext = context;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'A verification email has been sent to:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 5),
              Text(
                _userEmail ?? 'No email available',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please check your inbox, and also your spam or junk folder.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 30),

              TextButton(
                onPressed: () async {
                  AppLogger.info('Wrong Email? button tapped. Signing out and navigating back to AuthPage.');
                  _timer.cancel();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(_safeContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Wrong Email? Go back to Sign In/Up',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}