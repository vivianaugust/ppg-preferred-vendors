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

  final List<Widget> _pages = [
    const VendorPage(),
    const FavoritesPage(),
    const ProfilePage(),
  ];

  void _onTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Logo with even padding above and below
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Image.asset(
                'assets/ppg.png',
                height: 48,
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
          // Changed the icon from Icons.star to Icons.favorite
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}