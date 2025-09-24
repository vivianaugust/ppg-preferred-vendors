import 'package:flutter/material.dart';
import 'package:ppg_preferred_vendors/screens/favorites_page.dart';
import 'vendor_page.dart';
import 'profile_page.dart';
import 'package:ppg_preferred_vendors/utils/logger.dart'; // Import the logger

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
    AppLogger.info('HomePage initialized.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isImagePrecached) {
      AppLogger.info('Precaching background image for ProfilePage.');
      try {
        final ImageProvider backgroundProfileImage = const AssetImage('assets/Welcome IN..png');
        precacheImage(backgroundProfileImage, context);
        _isImagePrecached = true;
        AppLogger.info('Image precaching successful.');
      } catch (e, s) {
        AppLogger.error('Failed to precache image: $e', e, s);
      }
    }
  }

  void _onTap(int index) {
    if (_selectedIndex == index) {
      AppLogger.debug('Tapping on the already selected index: $index. No state change.');
      return;
    }
    AppLogger.info('Bottom navigation tapped. Navigating from $_selectedIndex to $index.');
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('Building HomePage with selected index: $_selectedIndex.');
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
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
        child: _pages[_selectedIndex],
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