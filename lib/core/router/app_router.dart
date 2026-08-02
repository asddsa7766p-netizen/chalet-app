import 'package:flutter/material.dart';
import 'package:friends_chalets/presentation/screens/favorites/favorites_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/main_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/payment/payment_screen.dart';
import '../../presentation/screens/reels/reels_screen.dart';
import '../../presentation/screens/chalet/chalet_detail_screen.dart';
import '../../presentation/screens/booking/booking_screen.dart';
import '../../presentation/screens/reviews/reviews_screen.dart';
import '../../presentation/screens/owner/owner_dashboard_screen.dart';
import '../../presentation/screens/owner/owner_chalets_screen.dart';
import '../../presentation/screens/owner/owner_bookings_screen.dart';
import '../../presentation/screens/owner/owner_external_screen.dart';
import '../../presentation/screens/owner/owner_profile_screen.dart';
import '../../presentation/screens/map/palestine_chalets_map_screen.dart';
import '../../data/models/chalet_model.dart';
import '../../data/services/host_service.dart';
import '../../data/services/services.dart';

import '../../presentation/screens/owner/owner_add_chalet_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// Routes that are public (no login required).
  static bool isPublicRoute(String location) {
    return location == '/splash' ||
        location == '/onboarding' ||
        location.startsWith('/auth/') ||
        location == '/home' ||
        location.startsWith('/home/chalet/') ||
        location == '/search' ||
        location == '/map' ||
        location == '/reels';
  }

  /// Routes that require login (redirect to /auth/login if not logged in).
  static bool isProtectedRoute(String location) {
    return location == '/home/booking' ||
        location == '/payment' ||
        location.startsWith('/home/reviews/') ||
        location.startsWith('/owner-') ||
        location == '/admin-dashboard';
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final location = state.matchedLocation;

      // Always allow splash and onboarding.
      if (location == '/splash' || location == '/onboarding') {
        return null;
      }

      // Logged-in users on auth pages go to home.
      if (isLoggedIn && location.startsWith('/auth/')) {
        return '/home';
      }

      // Public routes: allow guests.
      if (isPublicRoute(location)) {
        return null;
      }

      // Protected routes: require login.
      if (isProtectedRoute(location)) {
        if (!isLoggedIn) return '/auth/login';
      }

      // ✅ Owner routes (excluding add-chalet): require host role.
      if (location.startsWith('/owner-') && location != '/owner-add-chalet') {
        final isHost = await HostService.instance.isHost();
        return isHost ? null : '/home';
      }

      // ✅ Admin route protection
      if (location == '/admin-dashboard') {
        if (!isLoggedIn) return '/auth/login';
        final isAdmin = await AuthService.instance.isAdmin();
        return isAdmin ? null : '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/owner-add-chalet',
        builder: (_, __) => const OwnerAddChaletScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymentScreen(
            chalet: extra['chalet'] as ChaletModel,
            checkIn: extra['checkIn'] as DateTime,
            checkOut: extra['checkOut'] as DateTime,
            guestsCount: extra['guestsCount'] as int,
          );
        },
      ),
      GoRoute(
        path: '/reels',
        builder: (_, __) => const ReelsScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final initialIndex = state.extra as int? ?? 0;
          return MainScreen(initialIndex: initialIndex);
        },
        routes: [
          GoRoute(
            path: 'chalet/:id',
            builder: (context, state) {
              // ✅ تصحيح: كان `state.extra as ChaletModel?` — cast مباشر
              // يرمي Exception إذا وصل extra بنوع غير متوقع (مثلاً عند
              // تحديث المتصفح/Hot Restart على الويب، حيث لا ينتقل extra
              // عبر إعادة تحميل الصفحة). الآن نتحقق من النوع بأمان: لو
              // extra فعلاً ChaletModel نستخدمه كما كان تمامًا (لا تغيير
              // في السلوك الطبيعي)، وإلا نمرر null والصفحة نفسها مصممة
              // أصلاً لتحميل البيانات بنفسها عبر _load() في هذه الحالة.
              final extra = state.extra;
              final chalet = extra is ChaletModel ? extra : null;
              final id = state.pathParameters['id']!;
              return ChaletDetailScreen(chaletId: id, chalet: chalet);
            },
          ),
          GoRoute(
            path: 'booking',
            builder: (context, state) {
              final chalet = state.extra as ChaletModel;
              return BookingScreen(chalet: chalet);
            },
          ),
          GoRoute(
            path: 'reviews/:chaletId',
            builder: (context, state) {
              final chaletId = state.pathParameters['chaletId']!;
              final chaletName = state.extra as String? ?? '';
              return ReviewsScreen(chaletId: chaletId, chaletName: chaletName);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/owner-dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/owner-chalets',
        builder: (context, state) => const OwnerChaletsScreen(),
      ),
      GoRoute(
        path: '/owner-bookings',
        builder: (context, state) => const OwnerBookingsScreen(),
      ),
      GoRoute(
        path: '/owner-external',
        builder: (context, state) => const OwnerExternalScreen(),
      ),
      GoRoute(
        path: '/owner-profile',
        builder: (context, state) => const OwnerProfileScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const PalestineChaletsMapScreen(),
      ),
    ],
  );
}
