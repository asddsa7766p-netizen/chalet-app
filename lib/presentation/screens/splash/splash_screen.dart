import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep the splash visible for a minimum time.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final seen = prefs.getBool('onboarding_seen') ?? false;
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      context.go('/home');
    } else if (!seen) {
      context.go('/onboarding');
    } else {
      // Logged-out user who has already seen onboarding: go straight to the
      // public browsing screen as a guest. Login is only prompted when they
      // tap a protected action (requireAuth in router / widgets).
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Keffiyeh background (UI-only)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.03),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon cluster
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1B5E20),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.home_work_rounded,
                              size: 76,
                              color: AppColors.textOnSurfaceVariant,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.border.withOpacity(0.4),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.nature_people_rounded,
                              size: 26,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.appTagline,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        color: AppColors.textSecondary.withOpacity(0.8),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Loading dots
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryFixedDim,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                AppColors.textOnSurfaceVariant.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom fixed text
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Column(
              children: [
                Text(
                  'Palestinian Premium Hospitality',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withOpacity(0.9),
                    letterSpacing: 1.6,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: 0.1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.border,
                          margin: const EdgeInsets.only(right: 14),
                        ),
                      ),
                      const Icon(
                        Icons.vignette_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.border,
                          margin: const EdgeInsets.only(left: 14),
                        ),
                      ),
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
