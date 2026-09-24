import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/services.dart';

bool requireAuth(BuildContext context, PendingAuthAction action) {
  final isLoggedIn = AuthService.instance.isLoggedIn;
  if (isLoggedIn) return true;

  AuthRedirectService.setPendingAction(action);

  // ✅ إصلاح: كان هنا Navigator.of(context).pushNamed('/auth/login')، لكن
  // التطبيق يعتمد GoRouter (MaterialApp.router بلا onGenerateRoute)، فكان
  // الاستدعاء يرمي "Navigator.onGenerateRoute was null" ولا يحدث أي
  // انتقال — الضيف يضغط (المفضلة/الحجوزات/حسابي/احجز الآن/القلب) ولا يحصل
  // شيء. تأكدت من ذلك بتشغيل التطبيق على الويب.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    context.push('/auth/login');
  });

  return false;
}

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل الدخول مطلوب'),
      content: const Text('يجب تسجيل الدخول للاستمرار في هذه العملية.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/auth/login');
          },
          child: const Text('تسجيل الدخول'),
        ),
      ],
    );
  }
}
