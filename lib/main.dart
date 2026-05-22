import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_state_providers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> _loadEnv() async {
  // Loads .env from project root
  await dotenv.load(fileName: '.env');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure SharedPreferences is ready before any Supabase local storage init.
  await SharedPreferences.getInstance();

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
  );

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

  runApp(const ProviderScope(child: FriendsChaletsApp()));
}

class FriendsChaletsApp extends ConsumerStatefulWidget {
  const FriendsChaletsApp({super.key});

  @override
  ConsumerState<FriendsChaletsApp> createState() => _FriendsChaletsAppState();
}

class _FriendsChaletsAppState extends ConsumerState<FriendsChaletsApp> {
  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();

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

  @override
  Widget build(BuildContext context) {
    // MUST use ref.watch so MaterialApp rebuilds on changes.
    final themeNotifier = ref.watch(themeNotifierProvider);
    final localeNotifier = ref.watch(localeNotifierProvider);

    return MaterialApp.router(
      title: 'شاليهات الأصدقاء',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      routerConfig: AppRouter.router,
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
