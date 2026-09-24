import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../home/home_tab.dart';
import '../favorites/favorites_screen.dart';
import '../profile/profile_screen.dart';
import '../reels/reels_screen.dart';
import '../map/palestine_chalets_map_screen.dart';
import '../../widgets/common/login_prompt.dart';
import '../../../data/services/services.dart';

/// ✅ إصلاح: الانتقال لتبويب معيّن عبر context.go('/home', extra: N) كان
/// يعمل مرة واحدة فقط — لأن MainScreen لا تكتشف إلا "تغيّر" قيمة
/// initialIndex، فأي طلب ثانٍ لنفس التبويب (مثلاً "عرض حجوزاتي" بعد حجز
/// ثانٍ، أو صف "حجوزاتي" بصفحة حسابي بعد الرجوع لتبويب حسابي) كان يُتجاهل
/// ويبقى المستخدم بمكانه. هذا المساعد يرسل طلب تبويب صريحاً في كل مرة.
void goToMainTab(BuildContext context, int index) {
  MainScreen.tabRequest.value = index;
  context.go('/home', extra: index);
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  /// طلب تبديل تبويب من خارج MainScreen (يُستهلك ويُصفَّر فور تطبيقه).
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  // مفتاح يتغيّر عند فتح تبويب الحجوزات ليُعاد تحميل القائمة: MyBookingsScreen
  // كانت تُحمَّل مرة واحدة فقط (لحظة بناء IndexedStack، غالباً قبل تسجيل
  // الدخول أو قبل إنشاء الحجز)، فالحجز الجديد لا يظهر، ولا توجد طريقة
  // للتحديث بالسحب لأن حالة "لا يوجد حجوزات" لا تحتوي RefreshIndicator.
  Key _bookingsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    final pending = MainScreen.tabRequest.value;
    if (pending != null) {
      _currentIndex = pending;
      MainScreen.tabRequest.value = null;
    }
    MainScreen.tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    MainScreen.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final i = MainScreen.tabRequest.value;
    if (i == null) return;
    MainScreen.tabRequest.value = null;
    if (mounted) _selectTab(i);
  }

  void _selectTab(int i) {
    setState(() {
      if (i == 3) _bookingsKey = UniqueKey();
      _currentIndex = i;
    });
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _selectTab(widget.initialIndex);
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
      MyBookingsScreen(key: _bookingsKey),
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
          _selectTab(i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
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
