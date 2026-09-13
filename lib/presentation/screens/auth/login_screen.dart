import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/auth/auth_shared.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/services.dart';

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
  bool _googleLoading = false;
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
      final pending = AuthRedirectService.consumePendingAction();
      if (pending != null) {
        switch (pending.type) {
          case 'open_booking':
            final chaletId = pending.data['chaletId'] as String?;
            if (chaletId != null) {
              context.go('/home');
              Future.microtask(() =>
                  context.push('/home/booking', extra: {'chaletId': chaletId}));
            } else {
              context.go('/home');
            }
            break;
          case 'open_reviews':
            final chaletId = pending.data['chaletId'] as String?;
            final chaletName = pending.data['chaletName'] as String? ?? '';
            if (chaletId != null) {
              context.go('/home');
              Future.microtask(() =>
                  context.push('/home/reviews/$chaletId', extra: chaletName));
            } else {
              context.go('/home');
            }
            break;
          case 'toggle_favorite':
            final chaletId = pending.data['chaletId'] as String?;
            if (chaletId != null) {
              try {
                await FavoritesService.instance.toggleFavorite(chaletId);
              } catch (_) {
                // ⚠️ فشل صامت مقصود: تبديل المفضلة ثانوي هنا، لا نريد وقف تدفق تسجيل الدخول لأجله.
                // لكن يفضّل تسجيله عبر أداة Logging/Crashlytics بدل تجاهله كلياً.
              }
              context.go('/home/chalet/$chaletId');
            } else {
              context.go('/home');
            }
            break;
          case 'open_tab':
            final idx = pending.data['index'] as int? ?? 0;
            context.go('/home', extra: idx);
            break;
          default:
            context.go('/home');
        }
      } else {
        context.go('/home');
      }
    } catch (e) {
      // ✅ إصلاح: رسالة خطأ تعكس نوع المشكلة الفعلي (بيانات خاطئة/شبكة/إلخ)
      // بدل رسالة واحدة ثابتة لكل الحالات.
      if (mounted) _showError(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      // Google auth is intentionally not enabled in this build.
      // We do not fake a successful login.
      throw UnimplementedError('Google OAuth is not configured');
    } on UnimplementedError {
      if (!mounted) return;
      _showError('تسجيل الدخول عبر Google غير متاح حالياً. سيتم تفعيله لاحقاً');
    } catch (_) {
      if (!mounted) return;
      _showError('تعذّر تسجيل الدخول عبر Google');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
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
                      const SizedBox(height: 20),
                      const AuthDivider(),
                      const SizedBox(height: 20),
                      _googleBtn(),
                      const SizedBox(height: 20),
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

  Widget _googleBtn() => SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: _googleLoading ? null : _loginWithGoogle,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AuthColors.fieldBorder),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _googleLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: AuthColors.darkGreen))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ إصلاح: أيقونة Google محلية (asset) بدل تحميلها من الإنترنت
                    // في كل مرة (أبطأ، يفشل بدون إنترنت، وفيه استدعاء خارجي غير ضروري).
                    // ⚠️ ضِف asset باسم assets/images/google_logo.png في pubspec.yaml.
                    Image.asset(
                      'assets/images/google_logo.png',
                      width: 18,
                      height: 18,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('تسجيل الدخول عبر Google',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
        ),
      );
}
