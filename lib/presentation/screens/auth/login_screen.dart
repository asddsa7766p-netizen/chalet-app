import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/auth/auth_shared.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../data/services/services.dart';
import '../home/main_screen.dart' show goToMainTab;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      if (!mounted) return;

      // بعد نجاح تسجيل الدخول، استكمل أي إجراء معلّق كان محفوظاً قبل الطلب من المستخدم بتسجيل الدخول.
      // الراوتر يُلتقط مرة واحدة: بعد go('/home') تُزال هذه الشاشة ويصبح context غير صالح
      // داخل microtask أو بعد await.
      final router = GoRouter.of(context);
      final pending = AuthRedirectService.consumePendingAction();
      if (pending != null) {
        switch (pending.type) {
          case 'open_booking':
            final chaletId = pending.data['chaletId'] as String?;
            router.go('/home');
            if (chaletId != null) {
              Future.microtask(() =>
                  router.push('/home/booking', extra: {'chaletId': chaletId}));
            }
            break;
          case 'open_reviews':
            final chaletId = pending.data['chaletId'] as String?;
            final chaletName = pending.data['chaletName'] as String? ?? '';
            router.go('/home');
            if (chaletId != null) {
              Future.microtask(() =>
                  router.push('/home/reviews/$chaletId', extra: chaletName));
            }
            break;
          case 'toggle_favorite':
            final chaletId = pending.data['chaletId'] as String?;
            if (chaletId != null) {
              try {
                // حساب الإدارة لا يستخدم المفضلة: يفتح الشاليه فقط.
                final profile = await AuthService.instance.getCurrentProfile();
                if (profile?.isAdmin != true) {
                  await FavoritesService.instance.toggleFavorite(chaletId);
                }
              } catch (e, st) {
                // تبديل المفضلة ثانوي هنا: لا نوقف تدفق تسجيل الدخول لأجله، لكن نسجّله.
                reportError(e, st, context: 'login.pending_toggle_favorite');
              }
              router.go('/home/chalet/$chaletId');
            } else {
              router.go('/home');
            }
            break;
          case 'open_tab':
            final idx = pending.data['index'] as int? ?? 0;
            goToMainTab(context, idx);
            break;
          case 'open_notifications':
            router.go('/home');
            Future.microtask(() => router.push('/notifications'));
            break;
          default:
            router.go('/home');
        }
      } else {
        router.go('/home');
      }
    } catch (e) {
      // ✅ إصلاح: رسالة خطأ تعكس نوع المشكلة الفعلي (بيانات خاطئة/شبكة/إلخ)
      // بدل رسالة واحدة ثابتة لكل الحالات.
      if (mounted) _showError(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // ✅ إصلاح UX: تفادي تغطية لوحة المفاتيح للحقول/الزر عبر تعديل الـ padding
        // السفلي تلقائياً حسب viewInsets.
        bottom: false,
        child: SingleChildScrollView(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/onboarding'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تسجيل الدخول',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AuthColors.darkGreen)),
                      const SizedBox(height: 6),
                      const Text('أهلاً بعودتك 👋',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      AuthField(
                        controller: _emailCtrl,
                        label: AppStrings.email,
                        hint: 'example@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      AuthField(
                        controller: _passwordCtrl,
                        label: AppStrings.password,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: PasswordVisibilityToggle(
                          obscured: _obscure,
                          onToggle: () => setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) => Validators.required(v,
                            message: AppStrings.fieldRequired),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              context.push('/auth/forgot-password'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Text('نسيت كلمة المرور؟',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AuthColors.darkGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      AuthGradientButton(
                        label: 'تسجيل الدخول',
                        loading: _loading,
                        onTap: _login,
                      ),
                      // تسجيل الدخول عبر Google غير مفعّل بهذا الإصدار (لا OAuth مضبوط)،
                      // فلا يُعرض زره بدل زر يُظهر رسالة "غير متاح".
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: () => context.push('/auth/register'),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                              children: [
                                TextSpan(text: 'ليس لديك حساب؟ '),
                                TextSpan(
                                  text: 'إنشاء حساب جديد',
                                  style: TextStyle(
                                      color: AuthColors.darkGreen,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
