import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// شاشة الترحيب الوحيدة بالتطبيق — تفتح أول ما يشتغل التطبيق،
/// وتبقى معروضة لحد ما يضغط المستخدم على أحد الأزرار (بدون أي
/// انتقال تلقائي أو تايمر).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const Color _darkGreen = Color(0xFF3D5228);
  static const Color _cream = Color(0xFFF6EFE3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية: صورة الاستراحة/المسبح
          Image.asset(
            'assets/images/onboarding_bg.jpg',
            fit: BoxFit.cover,
          ),

          // تدرّج من الأسفل يخلي النص واضح فوق الخلفية
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  _cream,
                  _cream,
                ],
                stops: [0.0, 0.45, 0.62, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // اللوغو + اسم "مكان"
                Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Text(
                        'مرحباً بك في مكان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _darkGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: Color(0xFF6B6B6B),
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(text: 'منصة واحدة لاكتشاف وحجز\n'),
                            TextSpan(text: 'أجمل الأماكن في '),
                            TextSpan(
                              text: 'فلسطين',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _darkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // زر "ابدأ الاستكشاف" → يدخل التطبيق كضيف
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => context.go('/home'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _darkGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chevron_left, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'ابدأ الاستكشاف',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _OutlinedNavButton(
                              label: 'تسجيل الدخول',
                              icon: Icons.person_outline,
                              onTap: () => context.go('/auth/login'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OutlinedNavButton(
                              label: 'إنشاء حساب',
                              icon: Icons.person_add_alt,
                              onTap: () => context.go('/auth/register'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedNavButton extends StatelessWidget {
  const _OutlinedNavButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD9D2C2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D3D3D),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: const Color(0xFF3D3D3D)),
          ],
        ),
      ),
    );
  }
}
