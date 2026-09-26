import 'package:flutter/material.dart';

/// هوية الإدارة البصرية: كحلي داكن + ذهبي، مختلفة عمداً عن أخضر واجهة
/// الزبون ([AppColors.primary]) حتى يعرف الأدمن دائماً أنه في وضع الإدارة.
class AdminColors {
  AdminColors._();

  /// خلفية ترويسة الإدارة وشريط "وضع الإدارة".
  static const Color navy = Color(0xFF1F2A44);

  /// درجة أفتح للأسطح الثانوية فوق الكحلي.
  static const Color navyLight = Color(0xFF2E3B5B);

  /// لون التمييز (الأيقونة، مؤشّر التبويب، الشارة).
  static const Color gold = Color(0xFFC9A24B);

  /// نص فوق الكحلي.
  static const Color onNavy = Colors.white;
}
