// لقطات شاشة لشاشة تسعير المالك بعرض 390 (منطقي، بكثافة 2×).
//
// تنبيه: كل اللقطات من بيانات تجريبية داخل هذا الاختبار (FakePricingDataSource)
// وليست من التطبيق الحقيقي ولا من قاعدة البيانات. الخط المستخدم هو Segoe UI
// من نظام Windows بديلاً عن Cairo. تُحفظ في build/pricing_screenshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/pricing_service.dart';

import 'helpers/pricing_test_harness.dart';

const _morning = ChaletStayType.morning;
const _evening = ChaletStayType.evening;
const _outDir = 'build/pricing_screenshots';

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _capture(
    WidgetTester tester, PricingHarness h, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  final boundary =
      h.boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _scrollTo(WidgetTester t, Finder f, {double alignment = 0.3}) async {
  // ListView كسول: العناصر البعيدة لا تُبنى، فنمرّر حتى تظهر (للأسفل ثم للأعلى).
  if (f.evaluate().isEmpty) {
    final scrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    try {
      await t.scrollUntilVisible(f, 300, scrollable: scrollable, maxScrolls: 40);
    } catch (_) {
      await t.scrollUntilVisible(f, -300,
          scrollable: scrollable, maxScrolls: 40);
    }
  }
  await Scrollable.ensureVisible(t.element(f), alignment: alignment);
  await t.pumpAndSettle();
}

Future<void> _scrollTop(WidgetTester t) =>
    _scrollTo(t, find.text('السعر الفعلي لكل يوم'), alignment: 0);

Future<void> _type(WidgetTester t, String k, String v) async {
  await _scrollTo(t, _key(k), alignment: 0.4);
  await t.enterText(_key(k), v);
  await t.pump();
}

Future<void> _tapKey(WidgetTester t, String k) async {
  await _scrollTo(t, _key(k), alignment: 0.4);
  await t.tap(_key(k));
  await t.pumpAndSettle();
}

/// نوعان مفعّلان (صباحية مع سعر احتياطي 600 + مسائية بلا احتياطي).
FakePricingDataSource _ds({Map<int, double> general = const {}}) =>
    FakePricingDataSource(
      stayTypes: [
        stayConfig(_morning, base: 600),
        stayConfig(_evening),
      ],
      weekday: {if (general.isNotEmpty) 'default': general},
    );

void main() {
  setUpAll(loadArabicTestFont);

  testWidgets('01 ignored', (tester) async {
    final h = await pumpPricingScreen(
        tester, _ds(general: days(List.generate(7, (i) => i), 1200)),
        height: 844);
    await _scrollTop(tester);
    await _capture(tester, h, '01a_panel_ignored');
    await _scrollTo(tester, _key('baseImpact_morning_ignored'), alignment: 0.55);
    await _capture(tester, h, '01b_warning_ignored');
  });

  testWidgets('02 partial', (tester) async {
    final h = await pumpPricingScreen(
        tester, _ds(general: days([0, 1, 2, 3, 4], 1200)),
        height: 844);
    await _scrollTop(tester);
    await _capture(tester, h, '02a_panel_partial');
    await _scrollTo(tester, _key('baseImpact_morning_partial'), alignment: 0.55);
    await _capture(tester, h, '02b_warning_partial');
  });

  testWidgets('03 applied', (tester) async {
    final h = await pumpPricingScreen(tester, _ds(), height: 844);
    await _scrollTop(tester);
    await _capture(tester, h, '03a_panel_applied');
    await _scrollTo(tester, _key('baseImpact_morning_applied'), alignment: 0.55);
    await _capture(tester, h, '03b_warning_applied');
  });

  testWidgets('04 notSet', (tester) async {
    final h = await pumpPricingScreen(
        tester,
        FakePricingDataSource(
          stayTypes: [stayConfig(_morning), stayConfig(_evening)],
          weekday: {'default': days(List.generate(7, (i) => i), 1200)},
        ),
        height: 844);
    await _scrollTo(tester, _key('baseField_morning'), alignment: 0.45);
    await _capture(tester, h, '04_notset_no_warning');
  });

  testWidgets('05 تبديل التبويب مع مسودة محفوظة', (tester) async {
    final h = await pumpPricingScreen(tester, _ds(), height: 844);
    // مسودة بتبويب "عام"
    await _type(tester, 'weekdayField_default_0', '1500');
    await _type(tester, 'weekdayField_default_1', '1400');
    // نبدّل لتبويب الصباحية ونكتب مسودة ثانية
    await _tapKey(tester, 'editTab_morning');
    await _type(tester, 'weekdayField_morning_2', '750');
    await _scrollTo(tester, _key('editingTitle'), alignment: 0.05);
    await _capture(tester, h, '05a_morning_tab_with_drafts');
    // رجعنا لـ"عام": المسودة ما زالت موجودة
    await _tapKey(tester, 'editTab_default');
    await _scrollTo(tester, _key('editingTitle'), alignment: 0.05);
    await _capture(tester, h, '05b_back_to_default_draft_kept');
  });

  testWidgets('06 وسم بعد الحفظ', (tester) async {
    final h = await pumpPricingScreen(tester, _ds(), height: 844);
    await _type(tester, 'weekdayField_default_0', '1500');
    await _type(tester, 'weekdayField_default_5', '1800');
    await _scrollTop(tester);
    await _capture(tester, h, '06_after_save_badge');
  });

  testWidgets('07 حوار الخروج مع تعديلات', (tester) async {
    final h = await pumpPricingScreen(tester, _ds(), height: 844);
    await _type(tester, 'weekdayField_default_0', '1500');
    h.navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    await _capture(tester, h, '07_leave_dialog');
  });
}
