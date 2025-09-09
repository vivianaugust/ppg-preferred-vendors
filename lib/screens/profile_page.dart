import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Uri _feedbackUrl = Uri.parse('https://forms.gle/3SpAvkP3uaqSXHP76');
  late BuildContext _safeContext;

  @override
  void initState() {
    super.initState();
  }

  PageRouteBuilder _createAuthPageRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const AuthPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('No email associated with this account.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.message ?? "Failed to send reset email."}',
          ),
        ),
      );
    }
  }

  Future<void> _performReauthenticationAndDelete(User user, String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await user.delete();

      if (!mounted) return;
      Navigator.of(_safeContext).pushAndRemoveUntil(
        _createAuthPageRoute(),
        (route) => false,
      );
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Re-authentication failed. Please check your password.';
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      } else {
        errorMessage += ' ${e.message}';
      }
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _showReauthenticateDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final TextEditingController passwordController = TextEditingController();
    bool obscurePassword = true;

    await showDialog<void>(
      context: _safeContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setState) {
            return AlertDialog(
              title: const Text('Re-authenticate to Delete Account'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text('For security reasons, please re-enter your password to confirm account deletion.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  ),
                  child: const Text('Re-authenticate & Delete'),
                  onPressed: () {
                    if (passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Password cannot be empty.')),
                      );
                      return;
                    }
                    final String password = passwordController.text;
                    Navigator.of(dialogContext).pop();
                    _performReauthenticationAndDelete(user, password);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performProfileUpdate(User user, String newName) async {
    try {
      await user.updateDisplayName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<void> _showEditProfileDialog(User user) async {
    final TextEditingController nameController = TextEditingController(text: user.displayName ?? '');

    return showDialog<void>(
      context: _safeContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty.')),
                  );
                  return;
                }
                final String newName = nameController.text.trim();
                Navigator.of(dialogContext).pop();
                _performProfileUpdate(user, newName);
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _performAccountDeletion(User user) async {
    try {
      await user.delete();
      if (!mounted) return;
      Navigator.of(_safeContext).pushAndRemoveUntil(
        _createAuthPageRoute(),
        (route) => false,
      );
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (!mounted) return;
        _showReauthenticateDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(_safeContext).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: _safeContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Account Deletion'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone. All your saved data will be permanently lost.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              child: const Text('Delete Account'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmDelete == true) {
      _performAccountDeletion(user);
    }
  }

  Future<void> _launchFeedbackSurvey() async {
    if (!await launchUrl(_feedbackUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Could not open the feedback survey.')),
      );
    }
  }

  BoxDecoration _buttonBoxDecoration() {
    return BoxDecoration(
      color: Colors.white.withAlpha((255 * 0.8).round()),
      borderRadius: BorderRadius.circular(8),
    );
  }

  @override
  Widget build(BuildContext context) {
    _safeContext = context;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.microtask(() {
        if (!mounted) return;
        Navigator.of(_safeContext).pushReplacement(
          _createAuthPageRoute(),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Profile'),
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
                    Container(
                      decoration: _buttonBoxDecoration(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Theme.of(_safeContext).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Name: ${user.displayName ?? "Not set"}',
                                  style: Theme.of(_safeContext).textTheme.titleMedium?.copyWith(color: Colors.black87),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Theme.of(_safeContext).colorScheme.primary.withAlpha((255 * 0.7).round())),
                                onPressed: () => _showEditProfileDialog(user),
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.email, color: Theme.of(_safeContext).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Email: ${user.email ?? "Unknown"}',
                                  style: Theme.of(_safeContext).textTheme.titleMedium?.copyWith(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: _resetPassword,
                        icon: Icon(Icons.lock_reset, color: Theme.of(_safeContext).colorScheme.primary),
                        label: Text('Reset Password', style: TextStyle(color: Theme.of(_safeContext).colorScheme.primary, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: _launchFeedbackSurvey,
                        icon: Icon(Icons.feedback, color: Theme.of(_safeContext).colorScheme.primary),
                        label: Text('Feedback Survey', style: TextStyle(color: Theme.of(_safeContext).colorScheme.primary, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          Navigator.of(_safeContext).pushAndRemoveUntil(
                            _createAuthPageRoute(),
                            (route) => false,
                          );
                        },
                        icon: Icon(Icons.logout, color: Theme.of(_safeContext).colorScheme.error),
                        label: Text('Sign Out', style: TextStyle(color: Theme.of(_safeContext).colorScheme.error, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        icon: Icon(Icons.delete_forever, color: Theme.of(_safeContext).colorScheme.error),
                        label: Text('Delete Account', style: TextStyle(color: Theme.of(_safeContext).colorScheme.error, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
}