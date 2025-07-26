import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home_page.dart'; // Import HomePage directly for navigation
import '../screens/email_verification_screen.dart'; // Import EmailVerificationScreen
import '../services/sheet_data.dart'; // Assuming SheetDataService is defined here

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  // Removed: final _phoneController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _wantsFridayFeatures = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    // Removed: final phone = _phoneController.text.trim();

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        // Signup Flow
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        await userCredential.user?.updateDisplayName(name);
        await userCredential.user?.sendEmailVerification();

        if (!mounted) return;

        if (_wantsFridayFeatures) {
          // Updated: Removed phone from newsletter signup
          await _submitNewsletterSignup(name, email);
          if (!mounted) return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
        );
      }

      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String errorMessage = 'An error occurred. Please check your credentials.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      setState(() {
        _error = errorMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Updated: Removed phone parameter
  Future<void> _submitNewsletterSignup(String name, String email) async {
    try {
      final sheetService = SheetDataService(
        spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      final jsonString = await DefaultAssetBundle.of(context).loadString(
        'assets/ppg-vendors-d80304679d8f.json',
      );

      if (!mounted) return;

      await sheetService.initializeFromJson(jsonString);
      // Updated: Removed phone from row data
      await sheetService.appendRow('Newsletter', [name, email]);
    } catch (e) {
      debugPrint('Failed to write to Newsletter sheet: $e');
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email first to reset password.')),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Check your inbox and spam.')),
      );
      setState(() {
        _error = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Failed to send reset email.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred during password reset: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign In' : 'Sign Up'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Image.asset(
                'assets/Welcome IN..png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          // UPDATED: Using Color.fromARGB for error box background
                          color: const Color.fromARGB(229, 255, 255, 255), // 90% opacity white
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    if (!_isLogin) ...[
                      _styledTextField(_nameController, 'Full Name'),
                      const SizedBox(height: 16),
                    ],
                    _styledTextField(
                      _emailController,
                      'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _styledTextField(
                      _passwordController,
                      'Password',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
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
                    const SizedBox(height: 12),
                    if (!_isLogin) ...[
                      Container(
                        decoration: BoxDecoration(
                          // UPDATED: Using Color.fromARGB for checkbox list tile background
                          color: const Color.fromARGB(204, 255, 255, 255), // 80% opacity white
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          Container(
                            decoration: _buttonBoxDecoration(),
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: _buttonBoxDecoration(),
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _error = null;
                                });
                              },
                              child: Text(
                                _isLogin
                                    ? 'Don’t have an account? Sign up'
                                    : 'Already have an account? Sign in',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledTextField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        // UPDATED: Using Color.fromARGB for text field background
        color: const Color.fromARGB(204, 255, 255, 255), // 80% opacity white
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  BoxDecoration _buttonBoxDecoration() {
    return BoxDecoration(
      // UPDATED: Using Color.fromARGB for button box decoration
      color: const Color.fromARGB(204, 255, 255, 255), // 80% opacity white
      borderRadius: BorderRadius.circular(8),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}