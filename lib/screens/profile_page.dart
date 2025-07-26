import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_page.dart'; // Assuming auth_page.dart is in the same directory or adjust path

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Uri _feedbackUrl = Uri.parse('https://forms.gle/3SpAvkP3uaqSXHP76');

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

  Future<void> _resetPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email associated with this account.')),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.message ?? "Failed to send reset email."}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, User user) async {
    final TextEditingController nameController = TextEditingController(text: user.displayName ?? '');

    return showDialog<void>(
      context: context,
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
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty.')),
                    );
                  }
                  return;
                }
                try {
                  await user.updateDisplayName(nameController.text.trim());
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully!')),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Failed to update profile: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // --- NEW: Confirmation Dialog ---
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
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
                Navigator.of(dialogContext).pop(false); // User cancelled
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete Account'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    );

    // Only proceed if the user confirmed deletion
    if (confirmDelete == true) {
      try {
        await user.delete();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            _createAuthPageRoute(),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully.')),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          if (context.mounted) {
            _showReauthenticateAndDeleteDialog(context, user);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete account: ${e.message}')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')),
          );
        }
      }
    }
  }

  Future<void> _showReauthenticateAndDeleteDialog(BuildContext context, User user) async {
    final TextEditingController passwordController = TextEditingController();
    bool obscurePassword = true;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Re-authenticate to Delete Account'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text('For security reasons, please re-enter your your password to confirm account deletion.'),
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
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: const Text('Re-authenticate & Delete'),
                  onPressed: () async {
                    if (passwordController.text.isEmpty) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Password cannot be empty.')),
                        );
                      }
                      return;
                    }

                    try {
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: passwordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);

                      await user.delete();

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pushAndRemoveUntil(
                          _createAuthPageRoute(),
                          (route) => false,
                        );
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Account deleted successfully.')),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      if (dialogContext.mounted) {
                        String errorMessage = 'Re-authentication failed. Please check your password.';
                        if (e.code == 'wrong-password') {
                          errorMessage = 'Incorrect password.';
                        } else {
                          errorMessage += ' ${e.message}';
                        }
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(errorMessage)),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('An unexpected error occurred: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _launchFeedbackSurvey() async {
    if (!await launchUrl(_feedbackUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the feedback survey.')),
        );
      }
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
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
                    // User Information Card
                    Container(
                      decoration: _buttonBoxDecoration(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Name: ${user.displayName ?? "Not set"}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
                                ),
                              ),
                              // Edit Icon for Name
                              IconButton(
                                icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                                onPressed: () => _showEditProfileDialog(context, user),
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Email: ${user.email ?? "Unknown"}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Reset Password Button
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: () => _resetPassword(context),
                        icon: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
                        label: Text('Reset Password', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16)),
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

                    // Feedback Survey Button
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: _launchFeedbackSurvey,
                        icon: Icon(Icons.feedback, color: Theme.of(context).colorScheme.primary),
                        label: Text('Feedback Survey', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16)),
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

                    // Sign Out Button
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              _createAuthPageRoute(),
                              (route) => false,
                            );
                          }
                        },
                        icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                        label: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16)),
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

                    // Delete Account Button
                    Container(
                      decoration: _buttonBoxDecoration(),
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteAccountDialog(context),
                        icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                        label: Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16)),
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