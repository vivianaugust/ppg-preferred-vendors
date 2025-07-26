import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ppg_preferred_vendors/screens/home_page.dart'; // Make sure this import points to your actual home screen
import 'package:ppg_preferred_vendors/screens/auth_page.dart'; // Import the AuthPage

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  String? _userEmail; // To store the user's email

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email; // Get email on init

    // Send the verification email once
    FirebaseAuth.instance.currentUser?.sendEmailVerification();

    // Start polling every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        _timer.cancel();

        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // Display the user's email
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
              const SizedBox(height: 30), // Spacing before the new button

              // Button to go back to AuthPage
              TextButton(
                onPressed: () async {
                  // Sign out the current user
                  await FirebaseAuth.instance.signOut();
                  // Navigate to the AuthPage and remove all other routes
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Wrong Email? Go back to Sign In/Up', // Changed button text
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