import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/saved_vendors_page.dart';
import 'vendor_page.dart';
import 'profile_page.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const VendorPage(),
    const SavedVendorsPage(),
    const ProfilePage(),
  ];

  void _onTap(int index) {
    setState(() => _selectedIndex = index);
  }

  // Function to launch the URL
  Future<void> _launchPollockPropertiesWebsite() async {
    final Uri url = Uri.parse('https://pollockpropertiesgroup.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // If the URL cannot be launched, show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open website.')),
        );
      }
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Logo with even padding above and below, now wrapped in GestureDetector
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: GestureDetector( // Added GestureDetector
                onTap: _launchPollockPropertiesWebsite, // Call the launch function on tap
                child: Image.asset(
                  'assets/ppg.png',
                  height: 48,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Vendors'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_add_outlined), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}