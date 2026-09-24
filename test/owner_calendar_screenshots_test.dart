// لقطات شاشة لتقويم المالك بعرض 360 و390 و820 (منطقي، بكثافة 2×).
//
// تنبيه: كل اللقطات من بيانات تجريبية داخل الاختبار (FakeOwnerCalendarDataSource،
// اليوم مثبّت 10 مارس 2030) وليست من التطبيق الحقيقي ولا من قاعدة البيانات.
// الخط المستخدم هو Segoe UI من نظام Windows بديلاً عن Cairo.
// تُحفظ في build/calendar_screenshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/presentation/screens/owner/owner_calendar_data_source.dart';

import 'helpers/owner_calendar_test_harness.dart';
import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

const _outDir = 'build/calendar_screenshots';

Finder _cell(String iso) => find.byKey(ValueKey('cal_cell_$iso'));

Future<void> _capture(WidgetTester tester, CalendarHarness h, String name) async {
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

Future<void> _tap(WidgetTester t, String iso) async {
  await t.tap(_cell(iso));
  await t.pumpAndSettle();
}

final _sizes = {360.0: 780.0, 390.0: 844.0, 820.0: 1000.0};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadArabicTestFont();
  });

  for (final entry in _sizes.entries) {
    final w = entry.key.toInt();
    final height = entry.value;

    testWidgets('w$w 01 الشهر', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await _capture(tester, h, 'w${w}_01_month');
    });

    testWidgets('w$w 02 ورقة يوم عليه حجز يدوي', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await _tap(tester, '2030-03-18');
      await _capture(tester, h, 'w${w}_02_day_manual_booking');
    });

    testWidgets('w$w 03 ورقة يوم فارغ', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await _tap(tester, '2030-03-16');
      await _capture(tester, h, 'w${w}_03_day_empty');
    });

    testWidgets('w$w 04 ورقة يوم محجوب', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await _tap(tester, '2030-03-29');
      await _capture(tester, h, 'w${w}_04_day_blocked');
    });

    testWidgets('w$w 05 طلب معلّق', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await _tap(tester, '2030-03-24');
      await _capture(tester, h, 'w${w}_05_day_pending');
    });

    testWidgets('w$w 06 وضع تحديد الأيام', (tester) async {
      final h = await pumpCalendar(tester, sampleDataSource(),
          width: entry.key, height: height);
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await _tap(tester, '2030-03-16');
      await _tap(tester, '2030-03-21');
      await _capture(tester, h, 'w${w}_06_range_block');
    });
  }

  testWidgets('w390 07 عدة شاليهات (رقائق)', (tester) async {
    final ds = sampleDataSource(pending: {
      'c1': 1
    }, chalets: const [
      CalendarChalet(id: 'c1', name: 'شاليه الندى', pricePerNight: 1000),
      CalendarChalet(id: 'c2', name: 'شاليه الغروب الجميل', pricePerNight: 1200),
      CalendarChalet(id: 'c3', name: 'استراحة الزيتون', pricePerNight: 900),
    ]);
    final h = await pumpCalendar(tester, ds, width: 390, height: 844);
    await _capture(tester, h, 'w390_07_multi_chalet');
  });

  testWidgets('w390 08 حجب النطاق مع تخطي المحجوز', (tester) async {
    final h = await pumpCalendar(tester, sampleDataSource(),
        width: 390, height: 844);
    await tester.tap(find.byKey(const Key('action_range_mode')));
    await tester.pumpAndSettle();
    await _tap(tester, '2030-03-16');
    await _tap(tester, '2030-03-19');
    await _capture(tester, h, 'w390_08_range_skips_booked');
  });

  testWidgets('w390 09 خط مكبّر 1.5×', (tester) async {
    final h = await pumpCalendar(tester, sampleDataSource(),
        width: 360, height: 780, textScale: 1.5);
    await _capture(tester, h, 'w360_09_text_scale_1_5');
  });
}
