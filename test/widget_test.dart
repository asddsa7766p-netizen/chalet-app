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

  testWidgets('login screen exposes a clear Google unavailable message',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final googleButton = find.text('تسجيل الدخول عبر Google');
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Google غير متاح'), findsOneWidget);
  });
}
