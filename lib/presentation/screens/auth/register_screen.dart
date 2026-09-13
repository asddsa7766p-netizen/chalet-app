import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/auth/auth_shared.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController(); // ✅ حقل جديد
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false; // ✅ موافقة على الشروط والأحكام
  bool _sent = false; // ✅ حالة نجاح كاملة الشاشة بدل AlertDialog

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ إصلاح: التحقق من الموافقة على الشروط قبل إرسال الطلب.
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى الموافقة على الشروط والأحكام للمتابعة',
            style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      // ✅ إصلاح UX: حالة نجاح كاملة الشاشة موحّدة مع أسلوب ForgotPasswordScreen
      // بدل AlertDialog صغير غير متسق بصرياً.
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        // ✅ إصلاح: رسالة خطأ مفصّلة حسب نوع المشكلة بدل رسالة عامة ثابتة.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyAuthError(e),
              style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _sent ? _buildSuccessState() : _buildFormState(),
      ),
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إنشاء حساب جديد',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AuthColors.darkGreen)),
                  const SizedBox(height: 6),
                  const Text('أنشئ حسابك وابدأ رحلتك معنا ✨',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  AuthField(
                    controller: _nameCtrl,
                    label: AppStrings.fullName,
                    hint: 'أدخل اسمك الكامل',
                    icon: Icons.person_outline,
                    validator: (v) => Validators.required(v,
                        message: AppStrings.fieldRequired),
                  ),
                  const SizedBox(height: 16),
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
                    controller: _phoneCtrl,
                    label: AppStrings.phone,
                    hint: '05xxxxxxxx',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    // ✅ إصلاح: تحقق فعلي من صيغة رقم الهاتف بدل required فقط.
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  AuthField(
                    controller: _passwordCtrl,
                    label: AppStrings.password,
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: _obscurePass,
                    suffix: PasswordVisibilityToggle(
                      obscured: _obscurePass,
                      onToggle: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 14, color: AppColors.textHint),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AppColors.textHint)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ✅ حقل جديد: تأكيد كلمة المرور لتجنّب أخطاء الكتابة عند التسجيل.
                  AuthField(
                    controller: _confirmPasswordCtrl,
                    label: 'تأكيد كلمة المرور',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscure: _obscureConfirm,
                    suffix: PasswordVisibilityToggle(
                      obscured: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) =>
                        Validators.confirmPassword(v, _passwordCtrl.text),
                  ),
                  const SizedBox(height: 20),
                  // ✅ إصلاح: checkbox موافقة على الشروط والأحكام، مهم خصوصاً
                  // أن التطبيق يجمع بيانات شخصية (رقم هاتف، بريد إلكتروني).
                  _buildTermsCheckbox(),
                  const SizedBox(height: 24),
                  AuthGradientButton(
                    label: 'إنشاء حساب',
                    loading: _loading,
                    onTap: _register,
                  ),
                  const SizedBox(height: 20),
                  const AuthDivider(),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: AppColors.textSecondary),
                          children: [
                            TextSpan(text: 'لديك حساب بالفعل؟ '),
                            TextSpan(
                              text: 'تسجيل الدخول',
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
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _acceptedTerms,
            activeColor: AuthColors.darkGreen,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'أوافق على '),
                  TextSpan(
                    text: 'الشروط والأحكام',
                    style: const TextStyle(
                        color: AuthColors.darkGreen,
                        fontWeight: FontWeight.w800),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // TODO: افتح شاشة/رابط الشروط والأحكام الفعلي هنا.
                      },
                  ),
                  const TextSpan(text: ' وسياسة الخصوصية'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded,
                  size: 40, color: Colors.green),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'تم إنشاء الحساب! ✅',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'يرجى تأكيد بريدك الإلكتروني عبر الرابط المرسل إليك، ثم تسجيل الدخول.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AuthGradientButton(
            label: 'الذهاب لتسجيل الدخول',
            loading: false,
            icon: Icons.login_rounded,
            onTap: () => context.go('/auth/login'),
          ),
        ],
      ),
    );
  }
}
