import 'package:flutter/material.dart';

/// ملاحظة: هاي الألوان مأخوذة من تصميم شاشات الدفع.
/// إذا عندك ملف theme/colors مركزي بالمشروع (AppColors)، استبدل هاي القيم
/// بالقيم يلي عندك حتى تضمن التطابق مع باقي الشاشات.
class PaymentColors {
  static const Color primaryDark =
      Color(0xFF3E4A2E); // أخضر زيتوني غامق (الأزرار الرئيسية)
  static const Color primaryDarker =
      Color(0xFF2E3722); // أخضر أغمق (شاشة النجاح)
  static const Color background = Color(0xFFFAF8F3); // خلفية كريمية فاتحة
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E2D9);
  static const Color textPrimary = Color(0xFF1F241A);
  static const Color textSecondary = Color(0xFF6B7060);
  static const Color success = Color(0xFF3E4A2E);
  static const Color error = Color(0xFFE05B5B);
  static const Color errorBackground = Color(0xFFFCEAEA);
  static const Color goldAccent = Color(0xFFC9A24B);
}

class PaymentTextStyles {
  static const String fontFamily = 'Cairo';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: PaymentColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: PaymentColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: PaymentColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: PaymentColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: PaymentColors.textSecondary,
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: PaymentColors.textPrimary,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}

class PaymentSpacing {
  static const double screenPadding = 20.0;
  static const double cardPadding = 16.0;
  static const double sectionGap = 20.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
}
