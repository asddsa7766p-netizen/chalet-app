import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// الشروط والأحكام (من الإعدادات ومن رابط الموافقة بشاشة التسجيل).
/// ⚠️ النص مؤقت بانتظار الصياغة الرسمية.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.termsAndConditions)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sand),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'هذه شاشة الشروط والأحكام.\n'
                'يتم عرض النصوص القانونية هنا بشكل واضح ومناسب للهوية البصرية للتطبيق.\n\n'
                'يمكنك لاحقاً استبدال هذا النص بالصياغة الرسمية للشركة.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.8,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
