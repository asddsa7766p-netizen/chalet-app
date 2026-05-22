import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../home/home_tab.dart';
import '../favorites/favorites_screen.dart';
import '../profile/profile_screen.dart';
import '../reels/reels_screen.dart';
import '../map/palestine_chalets_map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeTab(),
      const PalestineChaletsMapScreen(),
      _currentIndex == 2
          ? FavoritesScreen(key: UniqueKey())
          : const FavoritesScreen(),
      _currentIndex == 3
          ? MyBookingsScreen(key: UniqueKey())
          : const MyBookingsScreen(),
      const ReelsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'الخريطة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: AppStrings.favorites,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: AppStrings.bookings,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_collection_outlined),
            activeIcon: Icon(Icons.video_collection_rounded),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }
}
