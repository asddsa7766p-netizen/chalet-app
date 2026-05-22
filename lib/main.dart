import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_state_providers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const String supabaseUrl = 'https://jugnkxeqqgtoerlknadm.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1Z25reGVxcWd0b2VybGtuYWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxMDI0NTAsImV4cCI6MjA5NDY3ODQ1MH0.YMttbctq0jlSfP6lEWy1VhS8JWmoFxHuF3L8DFXUxg4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure SharedPreferences is ready before any Supabase local storage init.
  await SharedPreferences.getInstance();

  // Initialize Supabase
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
