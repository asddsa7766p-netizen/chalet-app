import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_notifier.dart';
import 'theme_notifier.dart';

/// Theme + Locale providers.
///
/// These are set up as plain ChangeNotifierProviders, then loaded from
/// SharedPreferences during app startup in `main.dart`.
final themeNotifierProvider = ChangeNotifierProvider<ThemeNotifier>((ref) {
  return ThemeNotifier();
});

final localeNotifierProvider =
    ChangeNotifierProvider<LocaleNotifier>((ref) => LocaleNotifier());
