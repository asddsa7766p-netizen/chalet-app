import 'package:flutter/material.dart';
import 'package:makan/presentation/screens/reviews/reviews_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/home/main_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import 'package:makan/presentation/screens/payment/payment_flow_entry.dart';
import '../../presentation/screens/chalet/chalet_detail_screen.dart';
import '../../presentation/screens/booking/booking_screen.dart';
import '../../presentation/screens/owner/owner_dashboard_screen.dart';
import '../../presentation/screens/owner/owner_chalets_screen.dart';
import '../../presentation/screens/owner/bookings/owner_bookings_screen.dart';
import '../../presentation/screens/owner/calendar/owner_calendar_screen.dart';
import '../../presentation/screens/owner/bookings/owner_external_screen.dart';
import '../../presentation/screens/owner/owner_profile_screen.dart';
import '../../presentation/screens/map/palestine_chalets_map_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../data/models/chalet_model.dart';
import '../../data/models/models.dart';
import '../../data/services/services.dart';
import '../utils/error_reporter.dart';

import '../../presentation/screens/owner/chalet_form/owner_add_chalet_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/owner/owner_notifications_screen.dart';
import '../../presentation/screens/owner/owner_reports_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  /// ⛔ الدفع الإلكتروني معطّل مؤقتاً لحين اختيار بوابة دفع حقيقية وربطها
  /// (MockPaymentGateway الحالي لا ينشئ حجزاً فعلياً بقاعدة البيانات).
  static const bool onlinePaymentEnabled = false;

  /// Routes that are public (no login required).
  static bool isPublicRoute(String location) {
    return location == '/onboarding' ||
        location.startsWith('/auth/') ||
        location == '/home' ||
        location.startsWith('/home/chalet/') ||
        location == '/search' ||
        location == '/map';
  }

  /// Routes that require login (redirect to /auth/login if not logged in).
  static bool isProtectedRoute(String location) {
    return location == '/home/booking' ||
        location == '/notifications' ||
        location == '/payment' ||
        location.startsWith('/home/reviews/') ||
        location.startsWith('/owner-') ||
        location == '/admin-dashboard';
  }

  /// مسارات الزبون والمالك الممنوعة على حساب الإدارة.
  static bool isAdminBlockedRoute(String location) {
    return location == '/home/booking' ||
        location == '/payment' ||
        location.startsWith('/owner-');
  }

  // ---- كاش صلاحيات المستخدم (مالك/أدمن) لحرّاس المسارات ----
  static Future<UserProfile?>? _profileFuture;
  static String? _profileUserId;
  static int? _profileEpoch;

  /// بروفايل المستخدم الحالي لفحص الصلاحيات (`isHost`/`isAdmin`)، مخزَّن
  /// مؤقتاً حتى لا يُستعلم عن profiles بكل تنقّل. يُعاد الجلب تلقائياً عند
  /// تغيّر المستخدم أو [AuthService.rolesEpoch] (دخول/خروج/become_owner/
  /// become_customer). عند الفشل يُرجع null (لا صلاحية) ولا يُخزَّن الفشل.
  static Future<UserProfile?> currentUserProfile() {
    final auth = AuthService.instance;
    final userId = auth.currentUser?.id;
    if (userId == null) return Future.value(null);
    if (_profileFuture != null &&
        _profileUserId == userId &&
        _profileEpoch == auth.rolesEpoch) {
      return _profileFuture!;
    }
    _profileUserId = userId;
    _profileEpoch = auth.rolesEpoch;
    final future = auth.getCurrentProfile().catchError((Object e, StackTrace st) {
      _profileFuture = null;
      reportError(e, st, context: 'router.current_user_profile');
      return null;
    });
    return _profileFuture = future;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/onboarding',
    redirect: (context, state) async {
      final location = state.matchedLocation;

      // Guard access before Supabase is initialized (for tests, hot reload, or early boot).
      if (!Supabase.instance.isInitialized) {
        if (location.startsWith('/auth/') || location == '/onboarding') {
          return null;
        }
        return '/onboarding';
      }

      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

      // Onboarding: لو مسجل دخول، وجّهه على الهوم مباشرة بدل شاشة الترحيب.
      if (location == '/onboarding') {
        if (isLoggedIn) return '/home';
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

      // حساب الإدارة لا يحجز ولا يدفع ولا يملك شاليهات (السيرفر يرفض ذلك
      // أيضاً): مسارات الحجز والدفع والمالك كلها تعيده للوحة الإدارة، حتى
      // عبر رابط مباشر أو إجراء معلّق بعد تسجيل الدخول.
      if (isAdminBlockedRoute(location)) {
        final profile = await currentUserProfile();
        if (profile?.isAdmin == true) return '/admin-dashboard';
      }

      // Owner routes (excluding add-chalet): require host role.
      if (location.startsWith('/owner-') && location != '/owner-add-chalet') {
        final profile = await currentUserProfile();
        return profile?.isHost == true ? null : '/home';
      }

      // Admin route protection
      if (location == '/admin-dashboard') {
        if (!isLoggedIn) return '/auth/login';
        final profile = await currentUserProfile();
        return profile?.isAdmin == true ? null : '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/owner-notifications',
        builder: (context, state) => const OwnerNotificationsScreen(),
      ),
      GoRoute(
        path: '/owner-reports',
        builder: (context, state) => const OwnerReportsScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/owner-add-chalet',
        builder: (_, __) => const OwnerAddChaletScreen(),
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
        // ✅ إصلاح: كانت query params مثل ?city=... و?type=pool القادمة من
        // الرئيسية (أقسام المدن/الفئات) تُبنى بالرابط لكن تُهمل هنا بالكامل
        // (SearchScreen() بدون أي معطيات) — الآن تُمرَّر فعليًا كفلتر أولي.
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return SearchScreen(
            initialCity: q['city'],
            initialHasPool: q['type'] == 'pool',
            initialHasWifi: q['type'] == 'wifi',
            initialQuery: q['q'],
          );
        },
      ),
      GoRoute(
        path: '/payment',
        // ⛔ الدفع الإلكتروني معطّل مؤقتاً لحين اختيار بوابة دفع حقيقية:
        // MockPaymentGateway الحالي لا ينشئ حجزاً فعلياً بقاعدة البيانات،
        // فأي وصول لهذا الـ route (حتى لو مباشر) يُعاد لـ /home. أزل هذا
        // الشرط فقط بعد ربط بوابة دفع حقيقية بمسار الدفع.
        // ✅ إصلاح: state.extra كان يُفترض دايمًا أنه Map صحيح، فأي وصول
        // مباشر لـ /payment بدون extra (رابط عميق، تحديث المتصفح على الويب،
        // Hot Restart) كان يرمي TypeError ويكسر التطبيق. نتحقق الآن من
        // الشكل والنوع قبل الدخول للشاشة، ولو ناقص/غلط نرجّع لـ /home
        // بدل ما نكسر. تدفق الدفع الصحيح (لما تجي extra سليمة) ما تغيّر.
        redirect: (context, state) {
          if (!onlinePaymentEnabled) return '/home';
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) return '/home';
          if (extra['chalet'] is! ChaletModel) return '/home';
          if (extra['checkIn'] is! DateTime) return '/home';
          if (extra['checkOut'] is! DateTime) return '/home';
          if (extra['guestsCount'] is! int) return '/home';
          if (extra['totalPrice'] is! double) return '/home';
          if (extra['periodLabel'] is! String) return '/home';
          return null;
        },
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return buildPaymentFlow(
            chalet: extra['chalet'] as ChaletModel,
            checkIn: extra['checkIn'] as DateTime,
            checkOut: extra['checkOut'] as DateTime,
            guestsCount: extra['guestsCount'] as int,
            totalPrice: extra['totalPrice'] as double,
            periodLabel: extra['periodLabel'] as String,
          );
        },
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
              final extra = state.extra;
              if (extra is ChaletModel) {
                return BookingScreen(chalet: extra);
              }
              if (extra is Map<String, dynamic>) {
                final chaletId = extra['chaletId'] as String?;
                return BookingScreen(chalet: null, chaletId: chaletId);
              }
              // Fallback: no extra — BookingScreen will load from route params if available
              return const BookingScreen(chalet: null);
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
        path: '/owner-calendar',
        builder: (context, state) => const OwnerCalendarScreen(),
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
