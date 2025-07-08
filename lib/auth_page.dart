import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // For AuthGate
import 'sheet_data.dart'; // Your Google Sheets service

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _wantsFridayFeatures = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();

        if (_wantsFridayFeatures) {
          await _submitNewsletterSignup(name, email, phone);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } on FirebaseAuthException {
      setState(() {
        _error = 'Email or password is invalid.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitNewsletterSignup(String name, String email, String phone) async {
    try {
      final sheetService = SheetDataService(
        spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      final jsonString = await DefaultAssetBundle.of(context).loadString(
        'assets/ppg-vendors-d80304679d8f.json',
      );

      await sheetService.initializeFromJson(jsonString);
      await sheetService.appendRow('Newsletter', [name, email, phone]);
    } catch (e) {
      debugPrint('Failed to write to Newsletter sheet: $e');
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException {
      setState(() => _error = 'Email or password is invalid.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign In' : 'Sign Up'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                if (!_isLogin) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),

                if (!_isLogin) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _wantsFridayFeatures,
                    onChanged: (value) {
                      setState(() {
                        _wantsFridayFeatures = value ?? false;
                      });
                    },
                    title: const Text(
                      'Get our FRIDAY FEATURES',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Sign up if you love real estate, home design, community events and OpEds from Broadway to the ‘Burbs — all in one place, delivered to your inbox every Friday morning for 20 years…',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],

                const SizedBox(height: 16),

                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
                      ),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    });
                  },
                  child: Text(_isLogin
                      ? 'Don’t have an account? Sign up'
                      : 'Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
