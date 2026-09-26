import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/chalet/chalet_detail_screen.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

/// نفس minimumSize لأزرار AppTheme (عرض لا نهائي) بلا GoogleFonts.
final _appButtonTheme = ThemeData(
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52))),
  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52))),
);

Finder _button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

void main() {
  setUpAll(loadArabicTestFont);

  testWidgets(
      'تفاصيل الشاليه: حالة فشل التحميل تُظهر "رجوع" و"إعادة المحاولة" '
      'بثيم التطبيق', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // بلا Supabase مهيّأ يفشل جلب الشاليه فتظهر حالة الخطأ.
    final router = GoRouter(
      initialLocation: '/c',
      routes: [
        GoRoute(
            path: '/c',
            builder: (_, __) => const ChaletDetailScreen(chaletId: 'missing')),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: _appButtonTheme,
        routerConfig: router,
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل بيانات الشاليه'), findsOneWidget);
    for (final label in ['رجوع', 'إعادة المحاولة']) {
      final f = _button(label);
      expect(f, findsOneWidget, reason: label);
      expect(f.hitTestable(), findsOneWidget, reason: label);
      expect(tester.getSize(f).width, greaterThan(56), reason: label);
    }
  });
}
