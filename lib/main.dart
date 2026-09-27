import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_state_providers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'data/providers/favorites_provider.dart';
import 'data/services/services.dart'
    show AuthService, accountSuspendedMessage;
import 'data/services/suspension_aware_http_client.dart';
import 'presentation/screens/profile/profile_provider.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> _loadEnv() async {
  // Support both the repo-root .env and the app assets copy if present.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: 'assets/.env');
    } catch (_) {
      throw StateError('Missing .env file in project root or assets/.env');
    }
  }
}

/// تخزين آمن لجلسة تسجيل الدخول (access/refresh token) عبر
/// Android Keystore / iOS Keychain بدل SharedPreferences غير المشفّرة.
class _SecureSupabaseStorage extends LocalStorage {
  const _SecureSupabaseStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'sb-auth-token';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _key, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _key);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure SharedPreferences is ready before any Supabase local storage init.
  // لا تزال مطلوبة لأنها تُستخدم بأماكن أخرى بالتطبيق (اللغة/الثيم/onboarding).
  await SharedPreferences.getInstance();

  // ✅ إصلاح: بدون تهيئة بيانات intl العربية، كانت مكوّنات مثل تقويم شاشة
  // الحجز (TableCalendar) تعرض اسم الشهر وأيام الأسبوع بالإنجليزية
  // ("September 2026"، "Sat Fri Thu...") رغم أن كل التطبيق عربي —
  // تأكدت من هذا فعلياً بتشغيل التطبيق، وليس افتراضاً.
  await initializeDateFormatting('ar');

  // Load environment variables (.env)
  await _loadEnv();

  // Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: _SecureSupabaseStorage(),
    ),
    httpClient: SuspensionAwareHttpClient(
      onSuspended: AuthService.instance.reportSuspendedSession,
    ),
  );

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 1.0;
        options.environment = 'production';
      },
    );
  }

  FlutterError.onError = (details) {
    if (_sentryDsn.isNotEmpty) {
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
        hint: Hint.withMap({'source': 'flutter_error'}),
      );
    }
    FlutterError.presentError(details);
  };

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: MakanApp()));
}

class MakanApp extends ConsumerStatefulWidget {
  const MakanApp({super.key});

  @override
  ConsumerState<MakanApp> createState() => _MakanAppState();
}

class _MakanAppState extends ConsumerState<MakanApp> {
  bool _loadedPrefs = false;
  StreamSubscription<AuthState>? _authSub;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// آخر قيمة عولجت من [AuthService.suspendedSessions].
  int _handledSuspensions = 0;

  @override
  void initState() {
    super.initState();

    // حساب حُظر أثناء جلسته: رُفض تجديد الجلسة (قد يحدث عند استعادتها قبل
    // تشغيل الواجهة، فتُفحص القيمة الحالية أيضاً).
    AuthService.instance.suspendedSessions.addListener(_onSuspended);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSuspended());

    // ✅ إصلاح: favoritesProvider/profileProvider تُبنى مرة واحدة (غالباً كضيف:
    // قائمة مفضلة فارغة وبروفايل null) ولا تُحدَّث عند تسجيل الدخول — فبعد
    // "ضيف ← تسجيل دخول" تبقى القلوب/المفضلة/حسابي (زر لوحة المالك) بحالة
    // الضيف القديمة. الاستماع لتغيّر الجلسة يعيد جلبها عند الدخول/الخروج.
    _authSub = AuthService.instance.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userUpdated) {
        ref.invalidate(favoritesProvider);
        ref.invalidate(profileProvider);
      }
    });

    // Load preferences once. When notifiers load, they call notifyListeners(),
    // which triggers rebuild of MaterialApp thanks to ref.watch(...).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_loadedPrefs) return;
      _loadedPrefs = true;

      final themeNotifier = ref.read(themeNotifierProvider);
      final localeNotifier = ref.read(localeNotifierProvider);

      await themeNotifier.loadFromPrefs();
      await localeNotifier.loadFromPrefs();
    });
  }

  /// خروج محلي، ثم الرئيسية كضيف مع [accountSuspendedMessage].
  Future<void> _onSuspended() async {
    final count = AuthService.instance.suspendedSessions.value;
    if (count == _handledSuspensions) return;
    _handledSuspensions = count;
    await AuthService.instance.signOutLocally();
    if (!mounted) return;
    AppRouter.router.go('/home');
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text(accountSuspendedMessage,
            style: TextStyle(fontFamily: 'Cairo')),
        duration: Duration(seconds: 6),
      ));
  }

  @override
  void dispose() {
    AuthService.instance.suspendedSessions.removeListener(_onSuspended);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MUST use ref.watch so MaterialApp rebuilds on changes.
    final themeNotifier = ref.watch(themeNotifierProvider);
    final localeNotifier = ref.watch(localeNotifierProvider);

    return MaterialApp.router(
      title: 'مكان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: _messengerKey,
      locale: localeNotifier.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final lang = localeNotifier.locale.languageCode;
        return Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
