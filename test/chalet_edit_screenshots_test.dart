// لقطات شاشة تعديل الشاليه بعروض 360 و390 و820 (منطقي، بكثافة 2×).
//
// تنبيه: كل اللقطات من بيانات تجريبية داخل هذا الاختبار (FakeChaletEditDataSource)
// وليست من التطبيق الحقيقي ولا من قاعدة البيانات. الصور الموجودة أصلاً تظهر
// كمربعات بديلة (لا شبكة بالاختبار)، والصور "الجديدة" تدرجات لونية مولّدة.
// الخط Segoe UI من Windows بديلاً عن Cairo. تُحفظ في build/edit_screenshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers/chalet_edit_test_harness.dart';
import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

const _outDir = 'build/edit_screenshots';

Finder _k(String k) => find.byKey(ValueKey(k));

Future<void> _capture(
    WidgetTester tester, EditHarness h, String name) async {
  // فك الصور غير متزامن: ننتظره فعلياً قبل الالتقاط.
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)));
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

Future<void> _scrollTo(WidgetTester t, Finder f,
    {double alignment = 0.25}) async {
  if (f.evaluate().isEmpty) {
    final scrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    try {
      await t.scrollUntilVisible(f, 300, scrollable: scrollable, maxScrolls: 60);
    } catch (_) {
      await t.scrollUntilVisible(f, -300,
          scrollable: scrollable, maxScrolls: 60);
    }
  }
  await Scrollable.ensureVisible(t.element(f), alignment: alignment);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String k, String v) async {
  await _scrollTo(t, _k(k), alignment: 0.4);
  await t.enterText(_k(k), v);
  await t.pump();
}

Future<void> _tap(WidgetTester t, String k) async {
  await _scrollTo(t, _k(k), alignment: 0.4);
  await t.tap(_k(k));
  await t.pumpAndSettle();
}

const _sizes = <(int, double)>[(360, 800), (390, 844), (820, 1180)];

void main() {
  setUpAll(loadArabicTestFont);

  for (final (w, h) in _sizes) {
    final tag = 'w$w';

    testWidgets('$tag — 01 الأعلى: الحالة والمعلومات والسعة', (tester) async {
      final harness = await pumpEditScreen(
          tester, FakeChaletEditDataSource(row: sampleChaletRow()),
          width: w.toDouble(), height: h);
      await _capture(tester, harness, '${tag}_01_top');
    });

    testWidgets('$tag — 02 الموقع: حقول معدَّلة وتحذير خارج فلسطين',
        (tester) async {
      final harness = await pumpEditScreen(
          tester, FakeChaletEditDataSource(row: sampleChaletRow()),
          width: w.toDouble(), height: h);
      await _type(tester, 'field_location', 'حي الجبل');
      await _type(tester, 'field_address', 'شارع الجامعة، مقابل المسجد');
      await _type(tester, 'field_latitude', '10');
      await _type(tester, 'field_longitude', '10');
      await _scrollTo(tester, _k('section_location'), alignment: 0.05);
      await _capture(tester, harness, '${tag}_02_location_warning');
    });

    testWidgets('$tag — 03 الصور: إضافة وحذف وغلاف وخطأ حجم',
        (tester) async {
      final png1 = (await tester.runAsync(
          () => makeTestPng(const Color(0xFF3D5228), const Color(0xFFC9A24B))))!;
      final png2 = (await tester.runAsync(
          () => makeTestPng(const Color(0xFF2980B9), const Color(0xFFE9EAE0))))!;
      final harness = await pumpEditScreen(
        tester,
        FakeChaletEditDataSource(row: sampleChaletRow()),
        width: w.toDouble(),
        height: h,
        pickImages: () async => [
          XFile.fromData(png1,
              path: 'n1.png', name: 'n1.png', mimeType: 'image/png'),
          XFile.fromData(png2,
              path: 'n2.png', name: 'n2.png', mimeType: 'image/png'),
          testXFile('big.jpg', bytes: 10 * 1024 * 1024 + 1),
        ],
      );
      await _tap(tester, 'imgAdd'); // تُضاف الصورتان، وتُرفض الكبيرة
      await _scrollTo(tester, _k('imagePickError'), alignment: 0.6);
      await _capture(tester, harness, '${tag}_03b_image_error');
      await _tap(tester, 'imgCover_3'); // الجديدة الأولى صارت الغلاف
      await _tap(tester, 'imgDelete_2'); // حذف صورة موجودة
      await _scrollTo(tester, _k('section_media'), alignment: 0.05);
      await _capture(tester, harness, '${tag}_03_images_drafts');
    });

    testWidgets('$tag — 04 السعر والحجز: تنبيه السعر ونوع الحجز',
        (tester) async {
      final harness = await pumpEditScreen(
          tester,
          FakeChaletEditDataSource(
              row: sampleChaletRow(overrides: {'booking_type': 'خارجي'})),
          width: w.toDouble(),
          height: h);
      await _type(tester, 'field_price_per_night', '950');
      await tester.tap(_k('availableSwitch'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _k('section_pricing'), alignment: 0.05);
      await _capture(tester, harness, '${tag}_04_pricing');
    });

    testWidgets('$tag — 05 أخطاء التحقق', (tester) async {
      final ds = FakeChaletEditDataSource(row: sampleChaletRow());
      final harness = await pumpEditScreen(tester, ds,
          width: w.toDouble(), height: h);
      await _type(tester, 'field_name', '');
      await _type(tester, 'field_description', '');
      await _type(tester, 'field_max_guests', '0');
      await _type(tester, 'field_video_url', 'https://example.com');
      await _type(tester, 'field_price_per_night', '0');
      await _scrollTo(tester, _k('saveButton'));
      await tester.tap(_k('saveButton'));
      await tester.pump(const Duration(milliseconds: 300));
      await _scrollTo(tester, _k('section_basic'), alignment: 0.05);
      await _capture(tester, harness, '${tag}_05_validation_errors');
    });

    testWidgets('$tag — 06 حوار الخروج مع تعديلات', (tester) async {
      final harness = await pumpEditScreen(
          tester, FakeChaletEditDataSource(row: sampleChaletRow()),
          width: w.toDouble(), height: h);
      await _type(tester, 'field_name', 'شاليه الندى الجديد');
      await tester.tap(_k('amenity_has_bbq'));
      await tester.pump();
      harness.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _capture(tester, harness, '${tag}_06_leave_dialog');
    });

    testWidgets('$tag — 07 غير مالك الشاليه', (tester) async {
      final harness = await pumpEditScreen(
          tester,
          FakeChaletEditDataSource(
              row: sampleChaletRow(), userId: 'someone-else'),
          width: w.toDouble(),
          height: h);
      await _capture(tester, harness, '${tag}_07_forbidden');
    });
  }
}
