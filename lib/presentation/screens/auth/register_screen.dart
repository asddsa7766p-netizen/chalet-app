import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/custom_button.dart';

// ============================================
// REGISTER SCREEN
// ============================================
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
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على الشروط والأحكام')),
      );
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
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تم إنشاء الحساب! ✅',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            content: const Text(
                'تم إنشاء حسابك بنجاح. يرجى تأكيد بريدك الإلكتروني ثم تسجيل الدخول.',
                style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/auth/login');
                },
                child: const Text('تسجيل الدخول',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.charcoal),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.register,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('إنشاء حساب جديد للاستمتاع بتجربة حجز مميزة',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              CustomTextField(
                  controller: _nameCtrl,
                  label: AppStrings.fullName,
                  hint: 'محمد أحمد',
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? AppStrings.fieldRequired : null),
              const SizedBox(height: 14),
              CustomTextField(
                  controller: _emailCtrl,
                  label: AppStrings.email,
                  hint: 'example@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return AppStrings.fieldRequired;
                    if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.]+$').hasMatch(v!))
                      return AppStrings.invalidEmail;
                    return null;
                  }),
              const SizedBox(height: 14),
              CustomTextField(
                  controller: _phoneCtrl,
                  label: AppStrings.phone,
                  hint: '05xxxxxxxx',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? AppStrings.fieldRequired : null),
              const SizedBox(height: 14),
              CustomTextField(
                  controller: _passwordCtrl,
                  label: AppStrings.password,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textHint,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass)),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return AppStrings.fieldRequired;
                    if (v!.length < 8) return AppStrings.passwordTooShort;
                    return null;
                  }),
              const SizedBox(height: 14),
              CustomTextField(
                  controller: _confirmCtrl,
                  label: AppStrings.confirmPassword,
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textHint,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm)),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return AppStrings.fieldRequired;
                    if (v != _passwordCtrl.text)
                      return AppStrings.passwordsNotMatch;
                    return null;
                  }),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      )),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(AppStrings.agreeToTerms,
                        style: TextStyle(fontSize: 13, fontFamily: 'Cairo')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                  label: AppStrings.register,
                  onPressed: _register,
                  loading: _loading),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(AppStrings.haveAccount,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// FORGOT PASSWORD SCREEN
// ============================================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.resetPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.charcoal),
            onPressed: () => context.pop()),
        title: Text(AppStrings.forgotPassword.replaceAll('?', ''),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 24),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  size: 40, color: AppColors.primary),
            ),
            Text(AppStrings.forgotPassword,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(AppStrings.forgotPasswordSub,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _emailCtrl,
              label: AppStrings.email,
              hint: 'example@email.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty ?? true) return AppStrings.fieldRequired;
                if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.]+$').hasMatch(v!))
                  return AppStrings.invalidEmail;
                return null;
              },
            ),
            const SizedBox(height: 28),
            AppButton(
                label: AppStrings.sendResetLink,
                onPressed: _sendReset,
                loading: _loading),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('العودة لتسجيل الدخول',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildSuccessView() => Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
                color: Color(0xFFDFF0D8), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                size: 54, color: AppColors.success),
          ),
          const SizedBox(height: 28),
          Text(AppStrings.resetSuccess,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
                'تم إرسال رابط إعادة تعيين كلمة المرور إلى ${_emailCtrl.text}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'العودة لتسجيل الدخول',
              onPressed: () => context.go('/auth/login'),
            ),
          ),
        ],
      );
}
