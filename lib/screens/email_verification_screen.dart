import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ppg_preferred_vendors/screens/home_page.dart';
import 'package:ppg_preferred_vendors/screens/auth_page.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  Timer? _cooldownTimer;
  int _secondsRemaining = 60; 
  String? _userEmail;
  bool _isCheckingManually = false;

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;
    _sendInitialVerification();
    _startPolling();
    _startCooldown(); 
  }

  void _startCooldown() {
    setState(() => _secondsRemaining = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _sendInitialVerification() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
    } catch (e) {
      debugPrint("Initial verification send failed: $e");
    }
  }

  void _startPolling() {
    _timer?.cancel();
    // 5 seconds is the recommended safe interval for Firebase reload polling
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkEmailStatus());
  }

  Future<void> _checkEmailStatus() async {
    final navigator = Navigator.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      
      if (user != null && user.emailVerified) {
        _timer?.cancel();
        _cooldownTimer?.cancel();
        if (!mounted) return;
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _timer?.cancel(); 
        if (mounted) setState(() {}); 
      }
    }
  }

  Future<void> _handleManualRefresh() async {
    if (_isCheckingManually) return;
    
    setState(() => _isCheckingManually = true);
    
    await _checkEmailStatus();
    
    if (mounted) {
      setState(() => _isCheckingManually = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimerActive = _timer?.isActive ?? false;
    final navigator = Navigator.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 100, color: Colors.blue),
              const SizedBox(height: 30),
              const Text('We sent a link to:', style: TextStyle(fontSize: 16)),
              Text(
                _userEmail ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Don't see it? Check your spam or junk folder.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // --- POLING STATE ---
              if (isTimerActive) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  "Waiting for you to tap the link...", 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ] 
              // --- ERROR / MANUAL STATE ---
              else ...[
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                const SizedBox(height: 10),
                const Text(
                  "Auto-refresh paused due to request limits.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isCheckingManually ? null : _handleManualRefresh,
                  icon: _isCheckingManually 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh),
                  label: const Text('I have verified my email'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
                ),
              ],

              const SizedBox(height: 30),

              // --- RESEND COOLDOWN SECTION ---
              if (_secondsRemaining == 0) 
                TextButton.icon(
                  onPressed: () {
                    _sendInitialVerification();
                    _startCooldown();
                  },
                  icon: const Icon(Icons.send),
                  label: const Text("Resend Verification Email"),
                )
              else
                Text(
                  "You can resend the email in ${_secondsRemaining}s",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),

              const SizedBox(height: 60),
              
              TextButton(
                onPressed: () async {
                  _timer?.cancel();
                  _cooldownTimer?.cancel();
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthPage()),
                    (route) => false,
                  );
                },
                child: const Text('Use a different email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}