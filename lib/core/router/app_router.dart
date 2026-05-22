import 'package:flutter/material.dart';
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
import '../../presentation/screens/host/host_dashboard_screen.dart';
import '../../presentation/screens/host/host_chalet_screen.dart';
import '../../presentation/screens/host/host_bookings_screen.dart';
import '../../presentation/screens/host/host_reels_screen.dart';
import '../../presentation/screens/host/host_statistics_screen.dart';
import '../../presentation/screens/map/palestine_chalets_map_screen.dart';
import '../../data/models/chalet_model.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isAuthPath = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding';

      // Allow splash and onboarding always
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding') {
        return null;
      }

      // Redirect to login if not authenticated
      if (!isLoggedIn && !isAuthPath) return '/auth/login';

      // Redirect to home if already logged in and going to auth
      if (isLoggedIn && isAuthPath) return '/home';

      return null;
    },
    routes: [
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
            totalPrice: (extra['totalPrice'] as num).toDouble(),
          );
        },
      ),
      GoRoute(
        path: '/reels',
        builder: (_, __) => const ReelsScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'chalet/:id',
            builder: (context, state) {
              final chalet = state.extra as ChaletModel?;
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
        path: '/host-dashboard',
        builder: (context, state) => const HostDashboardScreen(),
      ),
      GoRoute(
        path: '/host-chalet',
        builder: (context, state) => const HostChaletScreen(),
      ),
      GoRoute(
        path: '/host-bookings',
        builder: (context, state) => const HostBookingsScreen(),
      ),
      GoRoute(
        path: '/host-reels',
        builder: (context, state) => const HostReelsScreen(),
      ),
      GoRoute(
        path: '/host-statistics',
        builder: (context, state) => const HostStatisticsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const PalestineChaletsMapScreen(),
      ),
    ],
  );
}
