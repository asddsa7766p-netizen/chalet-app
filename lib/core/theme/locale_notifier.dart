import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  static const String kLanguageKey = 'settings_language'; // 'ar' | 'en'

  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(kLanguageKey) ?? 'ar';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    _locale = Locale(languageCode);
    await prefs.setString(kLanguageKey, languageCode);
    notifyListeners();
  }
}
