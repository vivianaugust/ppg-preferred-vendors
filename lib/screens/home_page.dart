import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/screens/favorites_page.dart';
import 'vendor_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isImagePrecached = false; // Flag to ensure precaching happens only once

  final List<Widget> _pages = [
    const VendorPage(),
    const FavoritesPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // No context-dependent operations here
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache the background image used in ProfilePage
    // This ensures it's loaded into memory before ProfilePage tries to display it.
    // Call this only once to avoid unnecessary re-precaching if dependencies change.
    if (!_isImagePrecached) {
      final ImageProvider backgroundProfileImage = const AssetImage('assets/Welcome IN..png');
      precacheImage(backgroundProfileImage, context);
      _isImagePrecached = true; // Set the flag to true after precaching
    }
  }

  void _onTap(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _pages[_selectedIndex],
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Vendors'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}