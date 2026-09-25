import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/owner/chalet_pricing_screen.dart';

import 'helpers/pricing_test_harness.dart';

const _morning = ChaletStayType.morning;
const _evening = ChaletStayType.evening;

Finder _key(String k) => find.byKey(ValueKey(k));
String _fieldText(WidgetTester t, String k) =>
    t.widget<TextField>(_key(k)).controller!.text;

Future<void> _type(WidgetTester t, String k, String v) async {
  await t.enterText(_key(k), v);
  await t.pump();
}

Future<void> _tap(WidgetTester t, String k) async {
  await t.tap(_key(k));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadArabicTestFont);

  group('إشعار السعر الاحتياطي — الحالات الأربع', () {
    testWidgets('ignored: كل الأيام مغطّاة بـ«عام» ← لن يُطبَّق على أي يوم',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
        weekday: {'default': days(List.generate(7, (i) => i), 1200)},
      );
      await pumpPricingScreen(tester, ds);

      expect(_key('baseImpact_morning_ignored'), findsOneWidget);
      expect(_key('baseImpact_morning_partial'), findsNothing);
      expect(_key('baseImpact_morning_applied'), findsNothing);
      expect(find.textContaining('لن يُطبَّق على أي يوم'), findsOneWidget);
      expect(find.textContaining('لأن كل أيام الأسبوع لها سعر «عام»'),
          findsOneWidget);
      expect(_key('baseImpactAction_morning'), findsOneWidget);
    });

    testWidgets('ignored بسبب أسعار النوع نفسه: السبب يذكر النوع', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
        weekday: {'morning': days(List.generate(7, (i) => i), 700)},
      );
      await pumpPricingScreen(tester, ds);

      expect(_key('baseImpact_morning_ignored'), findsOneWidget);
      expect(find.textContaining('سعر يوم خاص بنوع "إقامة صباحية"'),
          findsOneWidget);
    });

    testWidgets('partial: يُطبَّق على الجمعة والسبت فقط، بلا عبارة "لن يُطبَّق"',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
        weekday: {'default': days([0, 1, 2, 3, 4], 1200)},
      );
      await pumpPricingScreen(tester, ds);

      expect(_key('baseImpact_morning_partial'), findsOneWidget);
      expect(_key('baseImpact_morning_ignored'), findsNothing);
      expect(find.textContaining('يُطبَّق على الجمعة والسبت فقط'),
          findsOneWidget);
      expect(find.textContaining('من الأحد إلى الخميس بأسعار «عام»'),
          findsOneWidget);
      expect(find.textContaining('لن يُطبَّق'), findsNothing);
      expect(_key('baseImpactAction_morning'), findsOneWidget);
    });

    testWidgets('applied: يُطبَّق على كل الأيام، بلا زر إجراء', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      expect(_key('baseImpact_morning_applied'), findsOneWidget);
      expect(find.textContaining('سيُطبَّق ₪600 على كل الأيام'),
          findsOneWidget);
      expect(_key('baseImpactAction_morning'), findsNothing);
      expect(find.textContaining('لن يُطبَّق'), findsNothing);
    });

    testWidgets('notSet: لا سعر احتياطي ← لا إشعار', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning)],
        weekday: {'default': days(List.generate(7, (i) => i), 1200)},
      );
      await pumpPricingScreen(tester, ds);

      for (final s in ['ignored', 'partial', 'applied']) {
        expect(_key('baseImpact_morning_$s'), findsNothing);
      }
    });

    testWidgets('يتحدّث فورًا أثناء الكتابة (يعكس المسودة لا المحفوظ)',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning)],
        weekday: {'default': days(List.generate(7, (i) => i), 1200)},
      );
      await pumpPricingScreen(tester, ds);
      expect(_key('baseImpact_morning_ignored'), findsNothing);

      await _type(tester, 'baseField_morning', '600');
      expect(_key('baseImpact_morning_ignored'), findsOneWidget);

      // نفرّغ سعر «عام» ليوم الجمعة (مسودة) ← يصير جزئيًا
      await _type(tester, 'weekdayField_default_5', '');
      expect(_key('baseImpact_morning_partial'), findsOneWidget);
      expect(find.textContaining('يُطبَّق على الجمعة فقط'), findsOneWidget);

      await _type(tester, 'baseField_morning', '');
      expect(_key('baseImpact_morning_partial'), findsNothing);
    });

    testWidgets('زر الإشعار ينقل لتبويب أسعار ذلك النوع', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
        weekday: {'default': days(List.generate(7, (i) => i), 1200)},
      );
      await pumpPricingScreen(tester, ds);
      expect(find.textContaining('أنت تعدّل: أسعار «عام»'), findsOneWidget);

      await _tap(tester, 'baseImpactAction_morning');
      expect(find.textContaining('أنت تعدّل: أسعار "إقامة صباحية"'),
          findsOneWidget);
    });
  });

  group('مقياس النص الكبير (حارس عيب التبويبات المقصوصة)', () {
    testWidgets('التبويب يكبر مع الخط (لا ارتفاع ثابت يقصّ النص) وبلا overflow',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600), stayConfig(_evening)],
      );
      await pumpPricingScreen(tester, ds, height: 3000);
      final small = tester.getSize(_key('editTab_morning')).height;

      await pumpPricingScreen(tester, ds, height: 4200, textScale: 2.0);
      await tester.pumpAndSettle();
      final big = tester.getSize(_key('editTab_morning')).height;

      expect(tester.takeException(), isNull);
      // تبويب بارتفاع ثابت (كـChoiceChip = 32) لا ينمو؛ المخصّص ينمو مع الخط
      expect(big, greaterThan(small));
      expect(big, greaterThan(40));
    });
  });

  group('إعادة التسمية', () {
    testWidgets('لا يظهر "السعر الأساسي" بأي مكان، والاسم الجديد موجود',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600), stayConfig(_evening)],
      );
      await pumpPricingScreen(tester, ds);

      expect(find.textContaining('السعر الأساسي'), findsNothing);
      expect(find.text('سعر احتياطي للأيام التي بلا سعر'), findsNWidgets(2));

      // ورسالة الخطأ لا تستخدم الاسم القديم
      await _type(tester, 'baseField_morning', 'abc');
      expect(find.text('سعر غير صحيح'), findsOneWidget);
      expect(find.textContaining('السعر الأساسي'), findsNothing);
    });
  });

  group('مسودة لكل نوع', () {
    testWidgets('تبديل التبويب لا يفقد ما كُتب ولا يعيد التحميل',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);
      final readsAfterLoad = ds.weekdayReads;
      // كل الأنواع + عام دفعة واحدة عند الفتح
      expect(readsAfterLoad, 1 + ChaletStayType.values.length);

      await _type(tester, 'weekdayField_default_0', '999');
      await _tap(tester, 'editTab_morning');
      await _type(tester, 'weekdayField_morning_1', '555');
      await _tap(tester, 'editTab_default');

      expect(_fieldText(tester, 'weekdayField_default_0'), '999');
      await _tap(tester, 'editTab_morning');
      expect(_fieldText(tester, 'weekdayField_morning_1'), '555');

      expect(_key('tabDot_default'), findsOneWidget);
      expect(_key('tabDot_morning'), findsOneWidget);
      expect(find.text('لديك 2 تعديل غير محفوظ'), findsOneWidget);
      expect(ds.weekdayReads, readsAfterLoad,
          reason: 'التبديل لا يعيد تحميل الأسعار');
      expect(ds.log, isEmpty, reason: 'لا حفظ بدون ضغط حفظ');
    });
  });

  group('وسم "بعد الحفظ"', () {
    testWidgets('يظهر على الخلايا المتأثرة فقط، ويختفي بعد الحفظ',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      Finder badgeIn(String cell) => find.descendant(
          of: _key(cell), matching: find.text('بعد الحفظ'));

      expect(find.text('بعد الحفظ'), findsNothing);

      await _type(tester, 'weekdayField_default_0', '1500');
      expect(badgeIn('effCell_morning_0'), findsOneWidget);
      expect(find.descendant(
          of: _key('effCell_morning_0'), matching: find.text('₪1500')),
          findsOneWidget);
      expect(badgeIn('effCell_morning_1'), findsNothing);
      expect(find.textContaining('تعكس تعديلاتك غير المحفوظة'),
          findsOneWidget);

      await _tap(tester, 'weekdaySave_default_0');
      expect(ds.log, ['weekday default:0=1500.0']);
      expect(find.text('بعد الحفظ'), findsNothing);
      expect(find.descendant(
          of: _key('effCell_morning_0'), matching: find.text('₪1500')),
          findsOneWidget);
    });

    testWidgets('أرقام عربية-هندية بحقل السعر مقبولة وتُحفظ كرقم',
        (tester) async {
      final ds = FakePricingDataSource();
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '١٥٠٠');
      expect(find.text('سعر غير صحيح'), findsNothing);
      await _tap(tester, 'weekdaySave_default_0');
      expect(ds.log, ['weekday default:0=1500.0']);
    });

    testWidgets('السعر الاحتياطي المكتوب يظهر بالجدول قبل الحفظ',
        (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'baseField_morning', '650');
      // كل الأيام بلا سعر يوم ← الاحتياطي يُطبَّق على السبعة، كلها "بعد الحفظ"
      expect(find.descendant(
          of: _key('effCell_morning_3'), matching: find.text('بعد الحفظ')),
          findsOneWidget);
      expect(find.descendant(
          of: _key('effCell_morning_3'), matching: find.text('₪650')),
          findsOneWidget);
    });
  });

  group('الحفظ', () {
    testWidgets('زر حفظ لكل صف + حفظ الكل يحفظ كل المعدَّل', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      // الأزرار معطّلة قبل أي تعديل
      expect(
          tester
              .widget<FilledButton>(_key('weekdaySave_default_0'))
              .onPressed,
          isNull);

      await _type(tester, 'weekdayField_default_0', '900');
      await _type(tester, 'baseField_morning', '650');
      await _tap(tester, 'editTab_morning');
      await _type(tester, 'weekdayField_morning_2', '710');
      expect(find.text('لديك 3 تعديل غير محفوظ'), findsOneWidget);

      await _tap(tester, 'saveAllButton');

      expect(
        ds.log,
        containsAll([
          'upsert morning enabled=true base=650.0',
          'weekday default:0=900.0',
          'weekday morning:2=710.0',
        ]),
      );
      expect(_key('dirtyBarText'), findsNothing);
      expect(_key('tabDot_default'), findsNothing);
    });

    testWidgets('حفظ صف واحد لا يمس الباقي', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '900');
      await _type(tester, 'weekdayField_default_1', '910');
      await _tap(tester, 'weekdaySave_default_1');

      expect(ds.log, ['weekday default:1=910.0']);
      expect(find.text('لديك 1 تعديل غير محفوظ'), findsOneWidget);
    });

    testWidgets('إفراغ حقل محفوظ ثم حفظه يحذف السعر', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning)],
        weekday: {'default': days([2], 1200)},
      );
      await pumpPricingScreen(tester, ds);

      expect(_fieldText(tester, 'weekdayField_default_2'), '1200');
      await _type(tester, 'weekdayField_default_2', '');
      await _tap(tester, 'weekdaySave_default_2');
      expect(ds.log, ['clear default:2']);
    });

    testWidgets('نص غير صالح: خطأ بالحقل ولا يُحفظ ولا يفسد الجدول',
        (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', 'abc');
      expect(find.text('سعر غير صحيح'), findsOneWidget);
      expect(find.text('بعد الحفظ'), findsNothing);

      await _tap(tester, 'weekdaySave_default_0');
      expect(ds.log, isEmpty);
    });
  });

  group('حماية التعديلات غير المحفوظة', () {
    testWidgets('الخروج مع مسودة: حوار، البقاء يبقي الشاشة', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      final h = await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '900');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
      expect(find.textContaining('عندك 1 تعديل'), findsOneWidget);

      await _tap(tester, 'leaveStay');
      expect(find.byType(ChaletPricingScreen), findsOneWidget);
      expect(_fieldText(tester, 'weekdayField_default_0'), '900');
    });

    testWidgets('تجاهل وخروج يغلق الشاشة بدون حفظ', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      final h = await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '900');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _tap(tester, 'leaveDiscard');

      expect(find.byType(ChaletPricingScreen), findsNothing);
      expect(ds.log, isEmpty);
    });

    testWidgets('حفظ وخروج يحفظ ثم يغلق', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      final h = await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '900');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _tap(tester, 'leaveSave');

      expect(ds.log, ['weekday default:0=900.0']);
      expect(find.byType(ChaletPricingScreen), findsNothing);
    });

    testWidgets('بدون تعديلات: الخروج مباشر بلا حوار', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      final h = await pumpPricingScreen(tester, ds);

      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(ChaletPricingScreen), findsNothing);
      expect(find.text('تعديلات غير محفوظة'), findsNothing);
    });

    testWidgets('إيقاف نوع له مسودة: تأكيد، الإلغاء يُبقيه مفعّلاً',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'baseField_morning', '700');
      await tester.tap(_key('stayToggle_morning'));
      await tester.pumpAndSettle();
      expect(find.text('تعديلات غير محفوظة'), findsOneWidget);

      await _tap(tester, 'dialogCancel');
      expect(ds.log, isEmpty);
      expect(_key('baseField_morning'), findsOneWidget);
      expect(_fieldText(tester, 'baseField_morning'), '700');
    });

    testWidgets(
        'إيقاف نوع له مسودة + تأكيد: يحفظ الإيقاف فقط بآخر سعر محفوظ '
        'ويتجاهل المسودة', (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      await _tap(tester, 'editTab_morning');
      await _type(tester, 'baseField_morning', '700');
      await _type(tester, 'weekdayField_morning_1', '555');
      await tester.tap(_key('stayToggle_morning'));
      await tester.pumpAndSettle();
      await _tap(tester, 'dialogConfirm');

      // حُفظ الإيقاف بالسعر المحفوظ 600 (لا المسودة 700)، بلا كتابة أسعار أيام
      expect(ds.log, ['upsert morning enabled=false base=600.0']);
      // التبويب اختفى والشاشة رجعت لـ"عام"
      expect(_key('editTab_morning'), findsNothing);
      expect(find.textContaining('أنت تعدّل: أسعار «عام»'), findsOneWidget);
      expect(_key('dirtyBarText'), findsNothing);
    });

    testWidgets('تفعيل/إيقاف نوع بدون مسودة لا يسأل ولا يحفظ سعرًا مكتوبًا',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
      );
      await pumpPricingScreen(tester, ds);

      await tester.tap(_key('stayToggle_evening'));
      await tester.pumpAndSettle();
      expect(ds.log, ['upsert evening enabled=true base=null']);
    });

    testWidgets('تجاهل (الشريط) يعيد كل الحقول للمحفوظ بعد تأكيد',
        (tester) async {
      final ds = FakePricingDataSource(
        stayTypes: [stayConfig(_morning, base: 600)],
        weekday: {'default': days([0], 1200)},
      );
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '1');
      await _type(tester, 'baseField_morning', '2');
      await _tap(tester, 'discardAllButton');
      await _tap(tester, 'dialogConfirm');

      expect(_fieldText(tester, 'weekdayField_default_0'), '1200');
      expect(_fieldText(tester, 'baseField_morning'), '600');
      expect(_key('dirtyBarText'), findsNothing);
    });

    testWidgets('السحب للتحديث مع مسودة: يطلب تأكيدًا', (tester) async {
      final ds = FakePricingDataSource(stayTypes: [stayConfig(_morning)]);
      await pumpPricingScreen(tester, ds);

      await _type(tester, 'weekdayField_default_0', '900');
      await tester.drag(find.byType(ListView), const Offset(0, 1700));
      await tester.pump();
      // مؤشر التحديث يدور طالما الحوار مفتوح، فلا نستخدم pumpAndSettle هنا.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
      await _tap(tester, 'dialogCancel');
      expect(_fieldText(tester, 'weekdayField_default_0'), '900');
    });
  });
}
