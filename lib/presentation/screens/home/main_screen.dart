import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../home/home_tab.dart';
import '../favorites/favorites_screen.dart';
import '../profile/profile_screen.dart';
import '../reels/reels_screen.dart';
import '../map/palestine_chalets_map_screen.dart';
import '../favorites/favorites_screen.dart';
import '../../widgets/common/login_prompt.dart';
import '../../../data/services/services.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... باقي الكود نفسه بدون تغيير
    // ... باقي الكود بدون تغيير، بس استخدم _currentIndex بدل تعريفه مباشرة
    final screens = [
      const HomeTab(),
      const PalestineChaletsMapScreen(),
      const FavoritesScreen(),
      const MyBookingsScreen(),
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
          // Profile tab (index 5) requires login for guests.
          if (i == 5) {
            final isLoggedIn = AuthService.instance.isLoggedIn;
            if (!isLoggedIn) {
              requireAuth(context, PendingAuthAction('open_tab', {'index': i}));
              return;
            }
          }
          // Favorites tab (index 2) and MyBookings tab (index 3) also require login.
          if ((i == 2 || i == 3) && !AuthService.instance.isLoggedIn) {
            requireAuth(context, PendingAuthAction('open_tab', {'index': i}));
            return;
          }
          setState(() => _currentIndex = i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A73E8),
        unselectedItemColor: const Color(0xFF9E9E9E),
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
        ),
        elevation: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'الخريطة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'المفضلة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: 'الحجوزات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_collection_outlined),
            activeIcon: Icon(Icons.video_collection_rounded),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
