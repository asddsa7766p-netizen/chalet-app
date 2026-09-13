import 'package:flutter/material.dart';

import '../../../data/services/services.dart';

bool requireAuth(BuildContext context, PendingAuthAction action) {
  final isLoggedIn = AuthService.instance.isLoggedIn;
  if (isLoggedIn) return true;

  AuthRedirectService.setPendingAction(action);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.of(context).pushNamed('/auth/login');
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
            Navigator.of(context).pushNamed('/auth/login');
          },
          child: const Text('تسجيل الدخول'),
        ),
      ],
    );
  }
}
