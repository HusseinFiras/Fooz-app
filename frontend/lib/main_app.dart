// lib/main_app.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/brands_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'constants/theme_constants.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  
  // Define the screens that will appear in the bottom navigation
  final List<Widget> _screens = const [
    HomePage(),
    BrandsScreen(),
    CartScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      // Wrap NavigationBar with SafeArea to respect device safe area
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          // Add subtle shadow for better visual separation
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
          color: Colors.white,
        ),
        // Make sure the navigation bar extends to the bottom edge
        child: SafeArea(
          bottom: true,
          child: NavigationBar(
            height: 65, // Explicitly set height for consistency
            backgroundColor: Colors.white,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined, 
                  color: _selectedIndex == 0 ? LuxuryTheme.primaryRosegold : Colors.grey,
                ),
                selectedIcon: Icon(
                  Icons.home,
                  color: LuxuryTheme.primaryRosegold,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.shopping_bag_outlined,
                  color: _selectedIndex == 1 ? LuxuryTheme.primaryRosegold : Colors.grey,
                ),
                selectedIcon: Icon(
                  Icons.shopping_bag,
                  color: LuxuryTheme.primaryRosegold,
                ),
                label: 'Brands',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: _selectedIndex == 2 ? LuxuryTheme.primaryRosegold : Colors.grey,
                ),
                selectedIcon: Icon(
                  Icons.shopping_cart,
                  color: LuxuryTheme.primaryRosegold,
                ),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.favorite_outline,
                  color: _selectedIndex == 3 ? LuxuryTheme.primaryRosegold : Colors.grey,
                ),
                selectedIcon: Icon(
                  Icons.favorite,
                  color: LuxuryTheme.primaryRosegold,
                ),
                label: 'Favorites',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.settings_outlined,
                  color: _selectedIndex == 4 ? LuxuryTheme.primaryRosegold : Colors.grey,
                ),
                selectedIcon: Icon(
                  Icons.settings,
                  color: LuxuryTheme.primaryRosegold,
                ),
                label: 'Settings',
              ),
            ],
            indicatorColor: LuxuryTheme.accentLightBlush.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}