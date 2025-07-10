import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Assuming AuthGate is defined here
import 'sheet_data.dart'; // Assuming SheetDataService is defined here

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
    // Initial setState outside the try-catch for immediate UI feedback
    if (!mounted) return; // Important: check mounted before the first setState as well
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

        // These operations don't directly require mounted checks unless they update UI
        // and you expect the widget to still be there. For simple Firebase calls,
        // it's less critical, but good practice if they were more complex.
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();

        if (_wantsFridayFeatures) {
          await _submitNewsletterSignup(name, email, phone);
        }

        if (mounted) { // Check mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
          );
        }
      }

      if (mounted) { // Check mounted before navigating
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } on FirebaseAuthException catch (e) { // Catch the exception
      if (mounted) { // Check mounted BEFORE calling setState in the catch block
        setState(() {
          // Provide more specific error messages if possible
          if (e.code == 'user-not-found' || e.code == 'wrong-password') {
            _error = 'Invalid email or password.';
          } else if (e.code == 'email-already-in-use') {
            _error = 'The email address is already in use by another account.';
          } else if (e.code == 'weak-password') {
            _error = 'The password provided is too weak.';
          } else {
            _error = 'An authentication error occurred. Please try again.';
            debugPrint('FirebaseAuthException: ${e.message}'); // Log for debugging
          }
        });
      }
    } catch (e) { // Catch any other unexpected errors
      if (mounted) { // Check mounted BEFORE calling setState for generic errors
        setState(() {
          _error = 'An unexpected error occurred: ${e.toString()}';
          debugPrint('Generic error during auth: $e'); // Log for debugging
        });
      }
    } finally {
      if (mounted) { // Ensure setState is only called if widget is still mounted
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitNewsletterSignup(String name, String email, String phone) async {
    try {
      final sheetService = SheetDataService(
        spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049',
      );

      // Using DefaultAssetBundle.of(context) inside an async function requires `mounted` check
      // if context might not be available. However, since this is called from _submit
      // which has just passed a mounted check, it's generally safe here unless `_submit`
      // continues running long after navigation. For robust async ops, it's safer.
      if (!mounted) return; // Added check here for extra safety
      final jsonString = await DefaultAssetBundle.of(context).loadString(
        'assets/ppg-vendors-d80304679d8f.json',
      );

      await sheetService.initializeFromJson(jsonString);
      await sheetService.appendRow('Newsletter', [name, email, phone]);
    } catch (e) {
      debugPrint('Failed to write to Newsletter sheet: $e');
      // No setState here, so no mounted check needed for this specific catch
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) { // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your email first.')),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) { // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) { // Check mounted BEFORE calling setState in the catch block
        setState(() {
          // More specific error for password reset
          if (e.code == 'user-not-found') {
            _error = 'No user found for that email.';
          } else {
            _error = 'Failed to send reset email: ${e.message}';
          }
        });
      }
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (!_isLogin) ...[
                      _styledTextField(_nameController, 'Full Name'),
                      const SizedBox(height: 16),
                      _styledTextField(
                        _phoneController,
                        'Phone Number',
                        keyboardType: TextInputType.phone,
                      ),
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
                          // This setState is always safe as it's directly tied to a UI interaction.
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
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CheckboxListTile(
                          value: _wantsFridayFeatures,
                          onChanged: (value) {
                            // This setState is always safe as it's directly tied to a UI interaction.
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
                                // This setState is always safe as it's directly tied to a UI interaction.
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
        color: Colors.white.withOpacity(0.8),
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
      color: Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(8),
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