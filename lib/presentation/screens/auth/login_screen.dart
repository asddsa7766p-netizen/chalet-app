import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/services/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('بيانات الدخول غير صحيحة',
                style: TextStyle(fontFamily: 'Cairo')),
          ]),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Gradient header
        Container(
          height: MediaQuery.of(context).size.height * 0.42,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1A2E0A), AppColors.primaryLight],
            ),
          ),
        ),
        // Decorative circles
        Positioned(top: -50, right: -50, child: _circle(200, 0.05)),
        Positioned(top: 80, left: -20, child: _circle(90, 0.1, accent: true)),
        Positioned(bottom: 100, right: -30, child: _circle(120, 0.04)),

        SafeArea(
            child: SingleChildScrollView(
                child: Column(children: [
          // Logo area
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 1.5),
                      ),
                      child: const Icon(Icons.home_work_rounded,
                          size: 44, color: AppColors.accent),
                    ),
                    const SizedBox(height: 14),
                    Text(AppStrings.appName,
                        style: GoogleFonts.cairo(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(AppStrings.appTagline,
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.65))),
                  ]),
            ),
          ),

          // White card
          SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F4EE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(children: [
                          Container(
                              width: 4,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppStrings.login,
                                    style: GoogleFonts.cairo(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.charcoal)),
                                Text('أهلاً بعودتك 👋',
                                    style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ]),
                        ]),
                        const SizedBox(height: 26),

                        _field(_emailCtrl, AppStrings.email,
                            'example@email.com', Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                          if (v == null || v.isEmpty) {
                            return AppStrings.fieldRequired;
                          }
                          if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.]+$')
                              .hasMatch(v)) return AppStrings.invalidEmail;
                          return null;
                        }),
                        const SizedBox(height: 14),

                        _field(_passwordCtrl, AppStrings.password, '••••••••',
                            Icons.lock_outline,
                            obscure: _obscure,
                            suffix: GestureDetector(
                                onTap: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textHint,
                                    size: 20)),
                            validator: (v) => (v == null || v.isEmpty)
                                ? AppStrings.fieldRequired
                                : null),
                        const SizedBox(height: 10),

                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  context.push('/auth/forgot-password'),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero),
                              child: Text(AppStrings.forgotPassword,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            )),
                        const SizedBox(height: 22),

                        // Gradient Login button
                        _gradientBtn(),
                        const SizedBox(height: 20),

                        Row(children: [
                          Expanded(
                              child:
                                  Container(height: 1, color: AppColors.sand)),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('أو',
                                  style: GoogleFonts.cairo(
                                      color: AppColors.textHint,
                                      fontSize: 13))),
                          Expanded(
                              child:
                                  Container(height: 1, color: AppColors.sand)),
                        ]),
                        const SizedBox(height: 20),

                        OutlinedButton(
                          onPressed: () => context.push('/auth/register'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('إنشاء حساب جديد',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.primary)),
                        ),
                        const SizedBox(height: 12),
                      ],
                    )),
              ),
            ),
          ),
        ]))),
      ]),
    );
  }

  Widget _circle(double size, double opacity, {bool accent = false}) =>
      Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (accent ? AppColors.accent : Colors.white)
                  .withOpacity(opacity)));

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: GoogleFonts.cairo(fontSize: 14, color: AppColors.charcoal),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sand)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sand)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.8)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error)),
        ),
      ),
    ]);
  }

  Widget _gradientBtn() => Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(AppStrings.login,
                  style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
        ),
      );
}
