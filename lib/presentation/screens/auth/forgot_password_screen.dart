import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/auth/auth_shared.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

/// شاشة "نسيت كلمة المرور"
///
/// ترسل رابط إعادة تعيين كلمة المرور عبر Supabase Auth (resetPasswordForEmail).
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

  // ✅ إصلاح: تبريد (cooldown) لإعادة الإرسال حتى لا يقدر المستخدم يسبم
  // طلبات reset متتالية على Supabase (تجنّب rate limiting وسوء استخدام).
  static const int _resendCooldownSeconds = 30;
  int _remainingCooldown = 0;
  Timer? _cooldownTimer;

  // ✅ إصلاح (Forgot Password كامل): التطبيق لا يملك deep link مُعدّ، فبدل
  // انتظار ضغط رابط بالبريد (ما إلو أي مكان يفتحه بالتطبيق)، نطلب من
  // المستخدم إدخال رمز التحقق (OTP) المُرسَل بنفس البريد + كلمة المرور
  // الجديدة مباشرة بهاي الشاشة.
  final _resetFormKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _verifying = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _remainingCooldown = _resendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingCooldown <= 1) {
        timer.cancel();
        setState(() => _remainingCooldown = 0);
      } else {
        setState(() => _remainingCooldown--);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.resetPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      // ✅ إصلاح: رسالة عربية ودّية بدل عرض نص الاستثناء التقني الخام.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyAuthError(e),
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      await AuthService.instance.verifyPasswordRecoveryOtp(
        email: _emailCtrl.text.trim(),
        token: _codeCtrl.text.trim(),
      );
      await AuthService.instance.updatePassword(_newPasswordCtrl.text);
      // نسجّل الخروج من جلسة الاسترداد المؤقتة حتى يدخل المستخدم بكلمة
      // المرور الجديدة بشكل صريح وواضح.
      await AuthService.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تغيير كلمة المرور بنجاح، يرجى تسجيل الدخول',
            style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/auth/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyAuthError(e),
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'نسيت كلمة المرور',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          // ✅ إصلاح: خطوة رمز التحقق + كلمة المرور الجديدة زادت طول
          // محتوى شاشة النجاح، فلفّيناها بـ SingleChildScrollView حتى ما
          // تفيض (overflow) بالشاشات الصغيرة أو مع ظهور الكيبورد.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  size: 36, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'إعادة تعيين كلمة المرور',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          const Text(
            'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            controller: _emailCtrl,
            label: 'البريد الإلكتروني',
            hint: 'example@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            // ✅ إصلاح: استخدام Validators الموحّد بدل regex محلي مختلف عن باقي الشاشات.
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _loading ? 'جارٍ الإرسال...' : 'إرسال رابط الاسترداد',
            loading: _loading,
            icon: Icons.send_rounded,
            onPressed: _loading ? null : _submit,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text(
              'العودة لتسجيل الدخول',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    final canResend = _remainingCooldown == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                size: 40, color: Colors.green),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'تم الإرسال! ✅',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى:\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        const Text(
          'أدخل رمز التحقق المكوّن من 6 أرقام الموجود بالرسالة، مع كلمة المرور الجديدة.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        Form(
          key: _resetFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _codeCtrl,
                label: 'رمز التحقق',
                hint: '123456',
                prefixIcon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'أدخل رمز التحقق';
                  if (value.length < 6) return 'الرمز مكوّن من 6 أرقام';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _newPasswordCtrl,
                label: 'كلمة المرور الجديدة',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmPasswordCtrl,
                label: 'تأكيد كلمة المرور الجديدة',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                validator: (v) =>
                    Validators.confirmPassword(v, _newPasswordCtrl.text),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: _verifying ? 'جارٍ التأكيد...' : 'تأكيد وتغيير كلمة المرور',
                loading: _verifying,
                icon: Icons.check_circle_outline,
                onPressed: _verifying ? null : _confirmReset,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ✅ إصلاح: زر إعادة المحاولة معطّل خلال فترة التبريد + عدّاد تنازلي مرئي.
        TextButton(
          onPressed: canResend ? _submit : null,
          child: Text(
            canResend
                ? 'لم يصلني الرمز — إعادة الإرسال'
                : 'يمكنك إعادة المحاولة بعد $_remainingCooldown ث',
            style: TextStyle(
                fontFamily: 'Cairo',
                color:
                    canResend ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text(
            'العودة لتسجيل الدخول',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ),
      ],
    );
  }
}
