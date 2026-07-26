import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette (LIGHT)
  static const Color background = Color(0xFFFFFFFF); // #FFFFFF
  static const Color scaffold = Color(0xFFF5F5F5); // #F5F5F5
  static const Color card = Color(0xFFFFFFFF); // #FFFFFF

  static const Color primary = Color(0xFF00450D); // #00450d

  // Alias used by some UI conversions (maps to primary-fixed variant in HTML)
  static const Color primaryContainer = primaryLight;

  // Gold/Accent
  static const Color accent = Color(0xFFF5A623); // #F5A623
  static const Color accentLight = Color(0xFFFFC65A); // light variant

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A); // #1A1A1A
  static const Color textSecondary = Color(0xFF757575); // #757575
  static const Color textMuted = Color(0xFF9E9E9E);

  // UI neutrals (kept for backwards compatibility with existing code)
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color cream = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF1A1A1A);

  // Backwards-compat aliases (some legacy UI uses primaryLight)
  static const Color primaryLight = accentLight;

  // Borders/dividers/shadows
  // Note: avoid methods inside const; define ARGB directly.
  static const Color sand = Color(0x5EC8963E); // 0xC8963E with ~0.35 alpha
  static const Color border = Color(0xFFE0E0E0); // #E0E0E0

  static const Color divider = Color(0x2EC8963E); // ~0.18 alpha
  static const Color shadow = Color(0x40000000);
  static const Color overlay = Color(0x990D1B2A);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF2980B9);

  // Additional aliases used across the repo
  static const Color textHint = textMuted;

  // Status colors / badges
  static const Color pending = warning; // F39C12
  static const Color confirmed = success; // 27AE60
  static const Color cancelled = error; // E74C3C
  static const Color completed = info;

  // Legacy names referenced in some screens
  static const Color primaryMedium = Color(0xFF2A3F55);
  static const Color primaryPale = accentLight;
  static const Color accentDark = Color(0xFF9A7A2A);

  // Aliases used by onboarding conversion (keep UI compile without adding new colors)
  static const Color textOnSurfaceVariant = textSecondary;
  static const Color primaryFixedDim = primary;
}
