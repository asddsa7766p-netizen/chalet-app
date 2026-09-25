import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/presentation/screens/auth/login_screen.dart';

void main() {
  testWidgets('login screen renders the main auth form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('تسجيل الدخول'), findsAtLeastNWidgets(1));
    expect(find.text('أهلاً بعودتك 👋'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('login screen hides Google sign-in while OAuth is not configured',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.textContaining('Google'), findsNothing);
  });
}
