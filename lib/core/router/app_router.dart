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

import '../../presentation/screens/owner/owner_add_chalet_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) async {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isAuthPath = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding';

      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding') {
        return null;
      }

      if (!isLoggedIn && !isAuthPath) return '/auth/login';
      if (isLoggedIn && isAuthPath) return '/home';

      if (state.matchedLocation == '/payment') {
        return isLoggedIn ? null : '/auth/login';
      }
      final isOwnerRoute = state.matchedLocation.startsWith('/owner-') &&
          state.matchedLocation != '/owner-add-chalet';
      if (isOwnerRoute) {
        final isHost = await HostService.instance.isHost();
        return isHost ? null : '/home';
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
