import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/services.dart'
    show accountSuspendedMessage, isAccountSuspendedError;

/// ألوان مشتركة لشاشات المصادقة (Login / Register / ForgotPassword)
///
/// موحّدة الآن مع AppColors المركزي بدل تعريف قيم منفصلة هون، حتى يصير
/// أي تعديل مستقبلي على هوية Makan اللونية بمكان واحد فقط.
class AuthColors {
  AuthColors._();
  static const Color darkGreen = AppColors.primaryDark;
  static const Color gold = AppColors.accentMuted;
  static const Color fieldBorder = AppColors.border;
}

/// دوال تحقق (Validation) موحّدة لكل حقول شاشات المصادقة.
/// استبدلت الـ regex المكررة والمختلفة بين الشاشات بمصدر واحد موثوق.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$');

  // صيغة أرقام فلسطين: 05 متبوعة بـ 8 أرقام (مثال: 0599123456)
  static final RegExp _phoneRegex = RegExp(r'^05\d{8}$');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'أدخل بريدك الإلكتروني';
    if (!_emailRegex.hasMatch(value)) return 'بريد إلكتروني غير صالح';
    return null;
  }

  static String? password(String? v, {int minLength = 8}) {
    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
    if (v.length < minLength) {
      return 'كلمة المرور يجب أن تكون $minLength أحرف على الأقل';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'أعد إدخال كلمة المرور';
    if (v != original) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  static String? required(String? v, {String message = 'هذا الحقل مطلوب'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'أدخل رقم هاتفك';
    if (!_phoneRegex.hasMatch(value)) {
      return 'رقم هاتف غير صالح (مثال: 0599123456)';
    }
    return null;
  }
}

/// يحوّل أخطاء الـ exceptions التقنية (من Supabase وغيرها) إلى رسائل عربية
/// مفهومة للمستخدم بدل عرض نص الاستثناء الخام.
///
/// ⚠️ عدّل رسائل الفحص (contains) بما يطابق نصوص أخطاء Supabase الفعلية عندك.
String friendlyAuthError(Object error) {
  // حساب محظور (رفض الدخول user_banned): الرسالة نفسها موجّهة للمستخدم.
  if (isAccountSuspendedError(error)) return accountSuspendedMessage;

  final msg = error.toString().toLowerCase();

  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  }
  if (msg.contains('email not confirmed')) {
    return 'يرجى تأكيد بريدك الإلكتروني أولاً عبر الرابط المرسل إليك';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already exists')) {
    return 'هذا البريد الإلكتروني مسجّل مسبقاً';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('timeout') ||
      msg.contains('failed host lookup')) {
    return 'تعذّر الاتصال بالإنترنت، تحقق من اتصالك وحاول مجدداً';
  }
  if (msg.contains('rate limit') || msg.contains('too many')) {
    return 'محاولات كثيرة متتالية، يرجى الانتظار قليلاً ثم المحاولة مرة أخرى';
  }
  if (msg.contains('token has expired') ||
      msg.contains('otp_expired') ||
      msg.contains('token expired')) {
    return 'انتهت صلاحية الرمز، يرجى طلب رمز جديد';
  }
  if (msg.contains('invalid') &&
      (msg.contains('otp') || msg.contains('token'))) {
    return 'الرمز الذي أدخلته غير صحيح، يرجى التحقق منه والمحاولة مجدداً';
  }
  return 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى';
}

/// شريط "أو" الفاصل، موحّد بين شاشات المصادقة بدل تكراره بكل ملف.
class AuthDivider extends StatelessWidget {
  final Color lineColor;
  const AuthDivider({super.key, this.lineColor = AuthColors.fieldBorder});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Container(height: 1, color: lineColor)),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('أو',
            style: TextStyle(
                fontFamily: 'Cairo', color: Colors.black45, fontSize: 13)),
      ),
      Expanded(child: Container(height: 1, color: lineColor)),
    ]);
  }
}

/// رأس شاشات المصادقة (صورة خلفية + لوغو + زر رجوع)، موحّد بدل التكرار
/// بين LoginScreen و RegisterScreen.
class AuthHeader extends StatelessWidget {
  final VoidCallback onBack;
  const AuthHeader({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/onboarding_bg.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.05)),
          Center(
            child: Image.asset('assets/images/logo.png',
                width: 110, height: 110, fit: BoxFit.contain),
          ),
          // ✅ إصلاح RTL: كان الزر بـ left:16 (يسار الشاشة) لكن سهم Icons.arrow_back
          // ينعكس تلقائياً بالعربية ليشير لليمين — سهم "رجوع" يشير لليمين على
          // اليسار! PositionedDirectional يضعه بجهة البداية (يمين بالعربية).
          PositionedDirectional(
            top: 16,
            start: 16,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back,
                        color: AuthColors.darkGreen, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل نص موحّد لشاشات المصادقة (يبني على تنسيق الحقول الموجود أصلاً).
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final String? semanticLabel;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(
            fontFamily: 'Cairo', fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Cairo', color: Colors.black38, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: Colors.black38, size: 20),
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthColors.fieldBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthColors.fieldBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AuthColors.darkGreen, width: 1.8)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent)),
        ),
      ),
    ]);
  }
}

/// زر إظهار/إخفاء كلمة المرور بمنطقة لمس كافية (44x44) + دعم Accessibility،
/// بدل GestureDetector الصغير غير القابل للوصول.
class PasswordVisibilityToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onToggle;
  const PasswordVisibilityToggle(
      {super.key, required this.obscured, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      tooltip: obscured ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Colors.black38,
        size: 20,
      ),
    );
  }
}

/// زر أساسي متدرّج اللون موحّد لشاشات المصادقة.
class AuthGradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData icon;

  const AuthGradientButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
    this.icon = Icons.arrow_back,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuthColors.gold, AuthColors.darkGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AuthColors.darkGreen.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }
}
