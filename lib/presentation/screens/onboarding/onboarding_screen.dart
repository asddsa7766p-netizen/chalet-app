import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';

// This file is UI-only onboarding conversion.
// Uses only AppColors fields that exist in this repo.

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: 3,
              itemBuilder: (context, index) {
                return _OnboardingStep(step: index);
              },
            ),

            // Step indicator (matches stitch dots style)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotHeight: 6,
                    dotWidth: indexDotWidth(_controller),
                    activeDotColor: AppColors.primary,
                    dotColor: AppColors.border,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double indexDotWidth(PageController controller) => 32;
}

class _OnboardingStep extends StatelessWidget {
  final int step;
  const _OnboardingStep({required this.step});

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return _Onboarding1();
      case 1:
        return _Onboarding2();
      case 2:
        return _Onboarding3();
      default:
        return _Onboarding1();
    }
  }
}

class _Onboarding1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hero
        Positioned.fill(
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAs2zmrrEOW6d5uzrW_JyvlOmfPoj6QwZAPTqSq3-YCHulTDBCz9GqHGulIx-FdykrzFddlnwiHeKpwhhdZ8cJnddv8ZakN329wGr9WEKlOMKiEzfaJ8rGUf5Zg8DzueZo1WOye1GzxWmoMij5nTP1K7ag5nK20VkQCSYiSqWvmUcmsKFToR00Zkj1_5HC-aflvQ7frq53LC6EyK4DDnucIXI1MRhda4tA87oUbntPVIVePGL8WzCt8GIEiwgZw3qCXJl7KvfzABylp',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFFF7FBF1),
                  Color(0x66F7FBF1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          child: const Center(
            child: Text(
              'فريندز شاليه',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

        // Canvas
        Positioned(
          left: 0,
          right: 0,
          top: 260,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'استكشف جمال فلسطين',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'اكتشف أرقى الشاليهات والمنتجعات الريفية التي تجمع بين أصالة التراث ورفاهية العصر في قلب الطبيعة الفلسطينية الخلابة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Pills
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_seen', true);
                      if (context.mounted) context.go('/auth/login');
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'ابدأ الاستكشاف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_seen', true);
                      if (context.mounted) context.go('/auth/login');
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Opacity(
                  opacity: 0.10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.grid_view_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'بالاستمرار أنت توافق على شروط الخدمة وسياسة الخصوصية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0x9900450D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Onboarding2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Background tint
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.03),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 26),
                  // Collage
                  SizedBox(
                    height: 280,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: const [
                        _BentoImg(
                          src:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuCaOiLcWNR_muT5BlYkqfkOu2SJ8Sp0wax6mkN34UnRqRV_vs2INCzubKSqkRPue7owxllQTbo4iC5d7PLb9S2lt9CzTUHylFZ8Uio0CBn6ygGrl9JAA_L7nKxkUA2feoGwyO7VqeN1uZcbcULOTso7UDzSenauummk8j2oeILqzmv4xxQtUz1iv-P8IytHvujXGTLG2Gsm5XGyuop3kSsR37W9y_Kzzi3yHNoNsWSzd8QDCGjDsrR4I4Q5La45VHEjKvci2m0wOhl8',
                        ),
                        _BentoImg(
                          src:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuBhDl477LgDCjINJ4Ny9RloMPZzMScdvzCObDeRAUhC9YQsFDIHB_mfjwwZswQOt63aOA0a_yA-HSUcnIBj4x__B5JiC1SaanvSGYcDi4ON2vlfByuVn-MH-WDpoOXRgYY1opn2WFyZ4qRDuPQ6TJpTsnaM-Kux0hAC6KxTPTuEaZdbydpxs-Br0gdy7oKxI7WZx4UXAY6UUdGt3sptv_NtGy2p1upkLRJnqOUvYNGwxOwQZZ_tcHSDwsjQdu5msFw1qDDGRPY-mZXD',
                        ),
                        _BentoImg(
                          src:
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuDy-b1cmJXnQ5XZKDC8Oirg5XY-RbwSy1zT2NXp_c6zF8RCQZkwjuXlNr40iRTXk-_Ng2F8o3mOhh6_KaC2cLOw8m5pvrSlC3TVxovPmvibf5LvDMIGOHzRnNkUOCt9r6KrMwXT6ECdcavCYMrWRcZSuH-Az6xydsIAEuR_RIlkwClrJl8wU_aPS1Suhc_jxzbjM4GPI0GIUukrPhbwNhFncL60lMBm4iil4WVknDTCa6kW5zZt96NZva6IIWmusruwEP7Wx9hdxSN0',
                        ),
                        SizedBox.shrink(),
                      ],
                    ),
                  ),

                  const Spacer(),

                  const Text(
                    'أفضل الشاليهات في مكان واحد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00450D),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'استكشف مجموعة متنوعة من الشاليهات الفاخرة في الخليل، رام الله، وأريحا. خصوصية تامة وجمال لا يقاوم.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF616363),
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stepper dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_seen', true);
                        if (context.mounted) context.go('/auth/login');
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'التالي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_seen', true);
                        if (context.mounted) context.go('/auth/login');
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.primary,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'تخطي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          const Positioned(
            bottom: 10,
            left: 16,
            child: Icon(
              Icons.grid_view_rounded,
              size: 64,
              color: Color(0xFF00450D),
            ),
          ),
        ],
      ),
    );
  }
}

class _Onboarding3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Keffiyeh pattern (UI-only approximation)
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF7FBF1),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 48),
              const Center(
                child: Text(
                  'Friends Chalets',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 0, // hidden label to avoid mismatch
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuA-V-aWrxIoo3K3TsRB_VY1YsMpXXuiajuHUQao92i-GGqVTQ1iJAA0fRwPL4YmzvDTS3lUMrL8kkj1ShT8mtGjT7RXlV8kQl5PLhUmVbOY0_lnUSI6wmdWs6aiM6fMGQIfWGZPyyqDPsSFkhnwVdyUjXVTXetWxILU9bu51PYc-cRXDQGBiHwQkKlEKTHQJXCNTX2LRomcLhcLxH_knzU514Rv7CXMrJAoDdnwShbgfoAXBToIDQRNRJ9QiiEgranBz-yMO2pWWT5s',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'احجز بكل سهولة وأمان',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'استكشف أفضل الشاليهات والفلل في فلسطين، قارن الأسعار، واحجز عطلتك القادمة بضغطة زر واحدة مع ضمان الخصوصية والراحة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF41493E),
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setBool(
                                        'onboarding_seen', true);
                                    if (context.mounted)
                                      context.go('/auth/login');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: AppColors.primaryFixedDim,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'ابدأ الآن',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool('onboarding_seen', true);
                                  if (context.mounted)
                                    context.go('/auth/login');
                                },
                                child: const Text(
                                  'تخطي الجولة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnSurfaceVariant,
                                  ),
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
            ],
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Divider(height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }
}

class _BentoImg extends StatelessWidget {
  final String src;
  const _BentoImg({required this.src});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(src, fit: BoxFit.cover),
    );
  }
}
