import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // Primary Palette (LIGHT) — محدّث ليطابق اللون الزيتي بالصورة المرجعية
  // اللون الأساسي #5A5C32 مأخوذ مباشرة من زر "احجز الأن" و"مميز" badge
  // ============================================================
  static const Color background =
      Color(0xFFFBF8F3); // كريمي دافئ (خلفية الشاشات)
  static const Color scaffold = Color(0xFFFBF8F3); // #FBF8F3
  static const Color card = Color(0xFFFFFFFF); // #FFFFFF (البطاقات)

  static const Color primary =
      Color(0xFF5A5C32); // #5A5C32 — الأخضر الزيتي (مطابق تماماً)
  static const Color primaryDark =
      Color(0xFF43451F); // أغمق، لحالات الضغط/التمييز
  static const Color primaryMedium =
      Color(0xFF6E7140); // درجة وسطى من نفس العائلة

  // primaryLight: كان سابقاً يساوي accentLight (ذهبي) بالغلط — تم فصله ليصير
  // درجة فاتحة حقيقية من الأخضر الزيتي
  static const Color primaryLight = Color(0xFF9A9D6B);

  // Alias يستخدم ببعض الشاشات القديمة
  static const Color primaryContainer = primaryLight;
  static const Color primaryFixedDim = primary;

  // primaryPale: تينت فاتح جداً من الزيتي — يُستخدم كخلفية للشارات (badges)
  // والمرافق المتاحة بدل الاعتماد على اللون الذهبي كما كان سابقاً
  static const Color primaryPale = Color(0xFFE9EAE0);

  // Gold/Accent — بقي كما هو، يُستخدم فقط لنجوم التقييم ولا علاقة له بالأخضر
  static const Color accent = Color(0xFFF5A623); // #F5A623
  static const Color accentLight = Color(0xFFFFC65A);
  static const Color accentDark = Color(0xFF9A7A2A);

  // Text
  static const Color textPrimary =
      Color(0xFF2A2A22); // أسود دافئ (يقارب الصورة)
  static const Color textSecondary = Color(0xFF7C7768); // رمادي دافئ
  static const Color textMuted = Color(0xFFA6A092);
  static const Color textHint = textMuted;
  static const Color textOnSurfaceVariant = textSecondary;

  // UI neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFBF8F3);
  static const Color cream = Color(0xFFFBF8F3);
  static const Color charcoal = Color(0xFF2A2A22);

  // Borders/dividers/shadows — تحويل من تينت ذهبي إلى تينت محايد دافئ
  // مطابق للون حدود البطاقات بالصورة (#F0EAE1 تقريباً)
  static const Color sand = Color(0xFFF0EAE1);
  static const Color border = Color(0xFFEDE7DD);
  static const Color divider = Color(0xFFEFE9DF);
  static const Color shadow = Color(0x1F000000);
  static const Color overlay = Color(0x990D1B2A);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF2980B9);

  // Status colors / badges
  static const Color pending = warning;
  static const Color confirmed = success;
  static const Color cancelled = error;
  static const Color completed = info;
}
