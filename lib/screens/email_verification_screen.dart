import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart'; // Make sure this import points to your actual home screen

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();

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
      body: Padding( // Added Padding for better spacing
        padding: const EdgeInsets.all(24.0), // Increased padding for better appearance
        child: Center(
          child: Column( // Changed to Column to stack text messages
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'A verification email has been sent.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18), // Slightly larger font for main message
              ),
              SizedBox(height: 10), // Spacing between messages
              Text(
                'Please check your inbox, and also your spam or junk folder.', // Added spam/junk instruction
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey), // Smaller and grey for secondary instruction
              ),
              SizedBox(height: 20), // More spacing
              CircularProgressIndicator(), // Keep the loading indicator
            ],
          ),
        ),
      ),
    );
  }
}