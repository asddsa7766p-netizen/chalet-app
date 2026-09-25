import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// موحّدة الآن مع AppColors المركزي بدل تعريف تدرّج ألوان مستقل لشاشات
/// الدفع فقط — كانت سابقاً قيماً منفصلة تماماً (أخضر زيتوني مختلف عن
/// AppColors.primary) وهو ما كان يخلي شاشات الدفع تبدو كتطبيق مختلف عن
/// باقي Makan.
class PaymentColors {
  static const Color primaryDark = AppColors.primary;
  static const Color primaryDarker = AppColors.primaryDark;
  static const Color background = AppColors.background;
  static const Color cardBackground = AppColors.card;
  static const Color borderLight = AppColors.border;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color success = AppColors.success;
  static const Color error = AppColors.error;
  static const Color errorBackground = Color(0xFFFCEAEA);
  static const Color goldAccent = AppColors.accentMuted;
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
