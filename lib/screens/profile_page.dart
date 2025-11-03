// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_page.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart';

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
    AppLogger.info('ProfilePage initialized.');
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
    // User is assumed non-null here
    final user = FirebaseAuth.instance.currentUser!; 
    final email = user.email;
    AppLogger.info('Password reset requested for email: $email');

    if (email == null || email.isEmpty) {
      if (!mounted) return;
      AppLogger.warning('Cannot reset password, no email associated with user.');
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('No email associated with this account.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      AppLogger.info('Password reset email sent to $email successfully.');
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppLogger.error('FirebaseAuthException during password reset: ${e.code}', e);
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
    AppLogger.info('Attempting to re-authenticate and delete account.');
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await user.delete();
      AppLogger.info('Account deleted successfully after re-authentication.');

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
      AppLogger.error('FirebaseAuthException during re-authentication for deletion: ${e.code}', e);
      String errorMessage = 'Re-authentication failed. Please check your password.';
      if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password.';
      } else {
        errorMessage += ' ${e.message}';
      }
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.fatal('An unexpected error occurred during re-authentication: $e', e, s);
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _showReauthenticateDialog() async {
    AppLogger.info('Showing re-authentication dialog for account deletion.');
    // User is assumed non-null here
    final user = FirebaseAuth.instance.currentUser!; 
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
                    AppLogger.info('Re-authentication dialog canceled.');
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
                      AppLogger.warning('Re-authentication attempted with empty password.');
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
    AppLogger.info('Attempting to update profile name to: $newName');
    try {
      await user.updateDisplayName(newName);
      if (!mounted) return;
      AppLogger.info('Profile updated successfully.');
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      setState(() {});
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.error('Failed to update profile: $e', e, s);
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  Future<void> _showEditProfileDialog(User user) async {
    AppLogger.info('Showing edit profile dialog.');
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
                AppLogger.info('Edit profile dialog canceled.');
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  AppLogger.warning('Name update attempted with empty name.');
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
    AppLogger.info('Attempting to delete account for user: ${user.email}');
    try {
      await user.delete();
      if (!mounted) return;
      AppLogger.info('Account deleted successfully.');
      Navigator.of(_safeContext).pushAndRemoveUntil(
        _createAuthPageRoute(),
        (route) => false,
      );
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppLogger.warning('Account deletion requires recent login. Showing re-authentication dialog.');
        if (!mounted) return;
        _showReauthenticateDialog();
      } else {
        if (!mounted) return;
        AppLogger.error('Failed to delete account due to FirebaseAuthException: ${e.code}', e);
        ScaffoldMessenger.of(_safeContext).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.message}')),
        );
      }
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.fatal('An unexpected error occurred during account deletion: $e', e, s);
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    AppLogger.info('Showing delete account confirmation dialog.');
    // User is assumed non-null here
    final user = FirebaseAuth.instance.currentUser!; 

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
                AppLogger.info('Delete account dialog canceled.');
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
                AppLogger.info('User confirmed account deletion.');
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
    AppLogger.info('Attempting to launch feedback survey URL.');
    if (!await launchUrl(_feedbackUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppLogger.error('Failed to launch feedback survey URL: $_feedbackUrl');
      ScaffoldMessenger.of(_safeContext).showSnackBar(
        const SnackBar(content: Text('Could not open the feedback survey.')),
      );
    } else {
      AppLogger.info('Successfully launched feedback survey.');
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
    // User is assumed non-null because VendorPage (the entry point) handles the redirection.
    final user = FirebaseAuth.instance.currentUser!; 

    // --- REDIRECTION LOGIC REMOVED ---

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
                                onPressed: () {
                                  AppLogger.info('Edit Name button tapped.');
                                  _showEditProfileDialog(user);
                                },
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
                          AppLogger.info('Sign Out button tapped.');
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          AppLogger.info('User signed out successfully. Navigating to AuthPage.');
                          // Navigating away after sign out requires _createAuthPageRoute
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
                        onPressed: () {
                          AppLogger.info('Delete Account button tapped.');
                          _showDeleteAccountDialog();
                        },
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