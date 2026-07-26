import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/common/common_widgets.dart';

/// شاشة "نسيت كلمة المرور"
///
/// ترسل رابط إعادة تعيين كلمة المرور عبر Supabase Auth (resetPasswordForEmail).
/// لا تحتاج أي إعداد إضافي — Supabase يرسل الإيميل تلقائياً بناءً على إعدادات
/// المشروع في Authentication → Email Templates.
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
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
          child: Padding(
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
          // أيقونة
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'أدخل بريدك الإلكتروني';
              final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
              if (!emailRegex.hasMatch(v.trim()))
                return 'بريد إلكتروني غير صالح';
              return null;
            },
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
    return Column(
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
          'تحقق من بريدك الإلكتروني واضغط على الرابط الموجود فيه.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'العودة لتسجيل الدخول',
          icon: Icons.login_rounded,
          onPressed: () => context.go('/auth/login'),
        ),
        const SizedBox(height: 12),
        // إعادة الإرسال لو ما وصل الإيميل
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text(
            'لم يصلني الإيميل — إعادة المحاولة',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textSecondary,
                fontSize: 12),
          ),
        ),
      ],
    );
  }
}
