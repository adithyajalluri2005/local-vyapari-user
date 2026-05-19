import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/home_screen.dart';
import 'package:local_vyapari_user/features/profile/presentation/screens/profile_screen.dart';
import 'package:local_vyapari_user/features/search/presentation/screens/search_screen.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/offers_screen.dart';
import 'package:local_vyapari_user/features/favorites/presentation/screens/favorites_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          onSearchTap: () {
            setState(() {
              _currentIndex = 1;
            });
          },
        );
      case 1:
        return const SearchScreen();
      case 2:
        return const OffersScreen();
      case 3:
        return const FavoritesScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreen(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppTheme.primaryColor),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer, color: AppTheme.primaryColor),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite, color: AppTheme.primaryColor),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
