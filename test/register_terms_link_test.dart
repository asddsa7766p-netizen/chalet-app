import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/presentation/screens/auth/register_screen.dart';
import 'package:makan/presentation/screens/settings/terms_screen.dart';

void main() {
  testWidgets('رابط "الشروط والأحكام" بالتسجيل يفتح شاشة الشروط',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.tapOnText(find.textRange.ofSubstring('الشروط والأحكام'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsScreen), findsOneWidget);
  });
}
