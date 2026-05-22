import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.sand, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryPale),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bullets
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '•',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                height: 1.7,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.privacy),
          leading: const BackButton(
            color: AppColors.charcoal,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header gradient
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(22),
                            border:
                                Border.all(color: AppColors.accent, width: 1),
                          ),
                        ),
                        const Icon(
                          Icons.shield_outlined,
                          size: 52,
                          color: AppColors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  '🔐 الخصوصية والأمان',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صفحة مبسطة وواضحة توضح كيف نتعامل مع بياناتك داخل تطبيق شاليهات الأصدقاء.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.8,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 14),

                _sectionCard(
                  icon: Icons.person_outline,
                  title: '1. البيانات التي نجمعها',
                  bullets: const [
                    'الاسم ورقم الهاتف',
                    'بيانات الحجز',
                    'معلومات الاستخدام داخل التطبيق',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.data_usage_outlined,
                  title: '2. كيف نستخدم البيانات',
                  bullets: const [
                    'تأكيد وإدارة الحجوزات',
                    'تحسين تجربة المستخدم',
                    'التواصل عند الحاجة بخصوص الحجز',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.share_outlined,
                  title: '3. مشاركة البيانات',
                  bullets: const [
                    'لا نقوم ببيع بياناتك لأي طرف ثالث.',
                    'قد نشارك البيانات فقط مع: أصحاب الشاليهات لإتمام الحجز',
                    'جهات الدفع (إن وجدت).',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.security_outlined,
                  title: '4. الأمان والحماية',
                  bullets: const [
                    'نستخدم تقنيات حماية لضمان حفظ بياناتك بشكل آمن.',
                    'منع الوصول غير المصرح به.',
                    'تشفير البيانات عند الحاجة.',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.gavel_outlined,
                  title: '5. حقوق المستخدم',
                  bullets: const [
                    'لديك الحق في طلب حذف بياناتك.',
                    'تعديل معلوماتك.',
                    'معرفة البيانات المخزنة عنك.',
                  ],
                ),

                const SizedBox(height: 12),

                _sectionCard(
                  icon: Icons.phone_outlined,
                  title: '6. تواصل معنا',
                  bullets: const [
                    '📞 +972 52-965-0635',
                    '📧 support@yourapp.com',
                  ],
                ),

                const SizedBox(height: 18),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'الإصدار 1.0.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '© 2026 شاليهات الأصدقاء',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
