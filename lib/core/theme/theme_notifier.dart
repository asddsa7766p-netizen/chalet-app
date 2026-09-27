import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const String kDarkModeKey = 'settings_dark_mode';

  /// أغلب الشاشات تستخدم ألواناً فاتحة ثابتة، فالوضع المظلم يخرج خليطاً
  /// مكسوراً. مغلق يعني: لا مفتاح بالواجهة، والتطبيق فاتح دائماً حتى لو
  /// حُفظ الوضع المظلم سابقاً.
  static const bool darkModeSupported = false;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadFromPrefs() async {
    if (!darkModeSupported) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kDarkModeKey) ?? false;
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool(kDarkModeKey, enabled);
    notifyListeners();
  }
}
