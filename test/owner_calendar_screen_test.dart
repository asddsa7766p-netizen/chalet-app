import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/owner/owner_calendar_data_source.dart';
import 'package:makan/presentation/screens/owner/owner_calendar_logic.dart';
import 'package:makan/presentation/screens/owner/owner_calendar_widgets.dart';

import 'helpers/owner_calendar_test_harness.dart';
import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

Finder cellOf(String iso) => find.byKey(ValueKey('cal_cell_$iso'));

CalendarDayCell cellWidget(WidgetTester t, String iso) => t.widget<CalendarDayCell>(
    find.descendant(of: cellOf(iso), matching: find.byType(CalendarDayCell)));

CalendarDayKind kindOn(WidgetTester t, String iso) => cellWidget(t, iso).kind;

Future<void> tapDay(WidgetTester t, String iso) async {
  await t.tap(cellOf(iso));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadArabicTestFont();
  });

  group('التحميل والعرض', () {
    testWidgets('يحمّل ثلاثة أشهر بطلبين (حجوزات + حجب) ويعرض اسم الشاليه',
        (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);

      expect(find.byKey(const Key('chalet_title')), findsOneWidget);
      expect(find.text('شاليه الندى'), findsOneWidget);
      expect(find.byKey(const Key('month_title')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('month_title'))).data,
          'مارس 2030');

      // نافذة: فبراير..أبريل (الشهر الظاهر ± 1) — طلب حجوزات وطلب حجب فقط،
      // وليس تحميل كل الحجوزات.
      final reads =
          ds.log.where((l) => l.startsWith('bookings') || l.startsWith('blocked')).toList();
      expect(reads, [
        'bookings c1 2030-02-01..2030-05-01',
        'blocked c1 2030-02-01..2030-04-30',
      ]);
      // لا أسعار للشبكة.
      expect(ds.log.where((l) => l.startsWith('pricing')), isEmpty);
    });

    testWidgets('حالات الأيام: متاح، مؤكد، يدوي، معلّق، محجوب، ماضٍ', (tester) async {
      await pumpCalendar(tester, sampleDataSource());

      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.available);
      expect(kindOn(tester, '2030-03-13'), CalendarDayKind.appConfirmed);
      expect(kindOn(tester, '2030-03-18'), CalendarDayKind.manual);
      expect(kindOn(tester, '2030-03-24'), CalendarDayKind.pending);
      expect(kindOn(tester, '2030-03-29'), CalendarDayKind.blocked);
      expect(cellWidget(tester, '2030-03-05').isPast, isTrue);
      expect(cellWidget(tester, '2030-03-10').isToday, isTrue);

      // يوم المغادرة يظهر متاحاً (18→20: ليلتا 18 و19).
      expect(kindOn(tester, '2030-03-19'), CalendarDayKind.manual);
      expect(kindOn(tester, '2030-03-20'), CalendarDayKind.available);
    });

    testWidgets('الحجز متعدد الليالي شريط متصل داخل الأسبوع', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      // 12→15: ليالي 12 و13 و14 (الثلاثاء..): متصلة ببعضها.
      final a = cellWidget(tester, '2030-03-12');
      final b = cellWidget(tester, '2030-03-13');
      final c = cellWidget(tester, '2030-03-14');
      expect(a.nextConnected, isTrue);
      expect(b.prevConnected && b.nextConnected, isTrue);
      expect(c.prevConnected, isTrue);
      expect(c.nextConnected, isFalse);
      // الحجب 28..30 كذلك.
      expect(cellWidget(tester, '2030-03-29').prevConnected, isTrue);
    });

    testWidgets('مفتاح الألوان يعرض كل الحالات بأسمائها', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      final legend = find.byKey(const Key('calendar_legend'));
      expect(legend, findsOneWidget);
      for (final label in [
        'متاح',
        'محجوز من التطبيق',
        'محجوز يدوياً',
        'بانتظار التأكيد',
        'محجوب',
        'اليوم',
      ]) {
        expect(find.descendant(of: legend, matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
    });

    testWidgets('كل خلية لها وصف Semantics (لا اعتماد على اللون وحده)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCalendar(tester, sampleDataSource());
      expect(find.bySemanticsLabel(RegExp('الأربعاء 13 مارس.*محجوز من التطبيق')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('السبت 30 مارس.*محجوب')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('الأحد 24 مارس.*بانتظار التأكيد')),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('اليوم')), findsWidgets);
      handle.dispose();
    });

    testWidgets('التنقل للشهر التالي يحمّل الشهر الجديد فقط', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      ds.log.clear();

      await tester.tap(find.byKey(const Key('month_next')));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('month_title'))).data,
          'أبريل 2030');
      // فبراير ومارس وأبريل محمّلة، فيُجلب مايو فقط.
      expect(ds.log.where((l) => l.startsWith('bookings')),
          ['bookings c1 2030-05-01..2030-06-01']);
      // الحجب الذي على 3 أبريل ظهر ضمن النافذة الأولى.
      expect(kindOn(tester, '2030-04-03'), CalendarDayKind.blocked);

      // الرجوع لمارس لا يحمّل شيئاً.
      ds.log.clear();
      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('bookings')), isEmpty);
    });

    testWidgets('زر "اليوم" يعيد لشهر اليوم', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tester.tap(find.byKey(const Key('month_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month_next')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('month_title'))).data,
          'مايو 2030');

      await tester.tap(find.byKey(const Key('action_today')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('month_title'))).data,
          'مارس 2030');
      expect(cellOf('2030-03-10'), findsOneWidget);
    });

    testWidgets('لا شاليهات: دعوة لإضافة شاليه', (tester) async {
      await pumpCalendar(tester, FakeOwnerCalendarDataSource(chalets: const []));
      expect(find.textContaining('أضف شاليهاً أولاً'), findsOneWidget);
      expect(find.text('إضافة شاليه'), findsOneWidget);
    });

    testWidgets('فشل تحميل الشاليهات: خطأ مع إعادة محاولة تعمل', (tester) async {
      final ds = sampleDataSource()..chaletsError = Exception('boom');
      await pumpCalendar(tester, ds);
      expect(find.text('تعذر تحميل شاليهاتك، حاول مرة أخرى'), findsOneWidget);

      ds.chaletsError = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chalet_title')), findsOneWidget);
    });

    testWidgets('فشل تحميل الأشهر: شريط خطأ وإعادة محاولة', (tester) async {
      final ds = sampleDataSource()..bookingsError = Exception('net');
      await pumpCalendar(tester, ds);
      expect(find.byKey(const Key('month_error')), findsOneWidget);

      ds.bookingsError = null;
      await tester.tap(find.descendant(
          of: find.byKey(const Key('month_error')),
          matching: find.text('إعادة المحاولة')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month_error')), findsNothing);
      expect(kindOn(tester, '2030-03-13'), CalendarDayKind.appConfirmed);
    });
  });

  group('اختيار الشاليه', () {
    final two = [
      const CalendarChalet(id: 'c1', name: 'شاليه الندى', pricePerNight: 1000),
      const CalendarChalet(id: 'c2', name: 'شاليه الغروب', pricePerNight: 1200),
    ];

    testWidgets('أكثر من شاليه: رقائق، ويبدأ بصاحب الطلبات المعلّقة', (tester) async {
      final ds = sampleDataSource(chalets: two, pending: {'c2': 3});
      ds.bookings['c2'] = [
        fakeBooking('x', d(2030, 3, 20), d(2030, 3, 22),
            chaletId: 'c2',
            status: BookingStatus.pending,
            guestName: 'هدى'),
      ];
      await pumpCalendar(tester, ds);

      expect(find.byKey(const Key('chalet_chips')), findsOneWidget);
      expect(find.byKey(const Key('chalet_chip_badge_c2')), findsOneWidget);
      expect(find.byKey(const Key('chalet_chip_badge_c1')), findsNothing);
      // c2 هو المحمَّل أولاً (لديه طلبات معلّقة).
      expect(ds.log.where((l) => l.startsWith('bookings')).first,
          startsWith('bookings c2'));
      expect(kindOn(tester, '2030-03-20'), CalendarDayKind.pending);
    });

    testWidgets('بلا طلبات معلّقة: الأول بالترتيب، والتبديل يعيد التحميل',
        (tester) async {
      final ds = sampleDataSource(chalets: two);
      await pumpCalendar(tester, ds);
      expect(ds.log.where((l) => l.startsWith('bookings')).first,
          startsWith('bookings c1'));

      ds.log.clear();
      await tester.tap(find.byKey(const Key('chalet_chip_c2')));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('bookings')),
          ['bookings c2 2030-02-01..2030-05-01']);
      // بيانات c1 لم تعد ظاهرة.
      expect(kindOn(tester, '2030-03-13'), CalendarDayKind.available);
    });
  });

  group('ورقة اليوم', () {
    testWidgets('يوم فارغ: السعر + حجز يدوي + حجب + أسعار', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');

      expect(find.byKey(const Key('day_panel')), findsOneWidget);
      expect(find.text('السبت 16 مارس'), findsOneWidget);
      expect(find.text('سعر الليلة: ₪1,000'), findsOneWidget);
      expect(find.byKey(const Key('day_action_manual')), findsOneWidget);
      expect(find.byKey(const Key('day_action_block')), findsOneWidget);
      expect(find.byKey(const Key('day_action_pricing')), findsOneWidget);
      // السعر جُلب عند فتح الورقة فقط، وللشهر كاملاً مرة واحدة.
      expect(ds.log.where((l) => l.startsWith('pricing')), ['pricing c1 2030-3']);
    });

    testWidgets('سعر خاص لتاريخ يظهر بوسم', (tester) async {
      final ds = FakeOwnerCalendarDataSource(
        priceOf: (day) => day.day == 16
            ? const DayPriceInfo(originalPrice: 1000, finalPrice: 1400)
            : const DayPriceInfo(originalPrice: 1000, finalPrice: 1000),
      );
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');
      expect(find.text('سعر الليلة: ₪1,400'), findsOneWidget);
      expect(find.text('سعر خاص لهذا التاريخ'), findsOneWidget);
    });

    testWidgets('حجز يدوي من اليوم: يفتح الورقة بالشاليه واليوم', (tester) async {
      final ds = sampleDataSource();
      final h = await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');
      await tester.tap(find.byKey(const Key('day_action_manual')));
      await tester.pumpAndSettle();

      expect(h.manualCalls, ['c1 2030-03-16']);
      // الورقة أُغلقت.
      expect(find.byKey(const Key('day_panel')), findsNothing);
    });

    testWidgets('أسعار الشاليه: تفتح شاشة الأسعار', (tester) async {
      final ds = sampleDataSource();
      final h = await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');
      await tester.tap(find.byKey(const Key('day_action_pricing')));
      await tester.pumpAndSettle();
      expect(h.pricingCalls, ['c1']);
    });

    testWidgets('حجب يوم: كتابة واحدة، ثم "تراجع" يعكسها', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');
      await tester.tap(find.byKey(const Key('day_action_block')));
      await tester.pumpAndSettle();

      expect(ds.log.where((l) => l.startsWith('block ')), ['block c1 2030-03-16']);
      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.blocked);
      expect(find.text('تم حجب السبت 16 مارس'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('unblock ')),
          ['unblock c1 2030-03-16']);
      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.available);
    });

    testWidgets('يوم محجوب: إلغاء الحجب متاح، والحجز اليدوي معطّل بسبب',
        (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-29');

      expect(find.byKey(const Key('day_action_unblock')), findsOneWidget);
      final manual = tester.widget<OutlinedButton>(
          find.byKey(const Key('day_action_manual')));
      expect(manual.onPressed, isNull);
      expect(find.text('أزل الحجب أولاً لتتمكن من الحجز على هذا اليوم.'),
          findsOneWidget);
      // السعر يبقى ظاهراً.
      expect(find.byKey(const Key('day_price')), findsOneWidget);

      await tester.tap(find.byKey(const Key('day_action_unblock')));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('unblock ')),
          ['unblock c1 2030-03-29']);
      expect(kindOn(tester, '2030-03-29'), CalendarDayKind.available);
      // بقية الحجب لم تتأثر.
      expect(kindOn(tester, '2030-03-28'), CalendarDayKind.blocked);
    });

    testWidgets('يوم عليه حجز: لا أزرار حجب ولا حجز يدوي جديد', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-13');
      expect(find.byKey(const Key('day_action_block')), findsNothing);
      expect(find.byKey(const Key('day_action_manual')), findsNothing);
      expect(find.byKey(const Key('day_action_range_block')), findsNothing);
    });

    testWidgets('حجز التطبيق المؤكد: تفاصيل الضيف، بلا إلغاء ولا تأكيد',
        (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-13');

      final card = find.byKey(const Key('day_booking_card'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('سامي الخطيب')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('0599123456')),
          findsOneWidget);
      expect(find.text('من 12 مارس إلى 15 مارس · 3 ليالٍ'), findsOneWidget);
      expect(find.text('الليلة 2 من 3'), findsOneWidget);
      expect(find.text('الإجمالي ₪2,400'), findsOneWidget);
      // الرأس يوضح المصدر والحالة (لا شارة مكررة داخل البطاقة).
      expect(find.text('محجوز من التطبيق'), findsWidgets);
      expect(find.text('يصل بعد العصر'), findsOneWidget);
      expect(find.byKey(const Key('day_action_confirm')), findsNothing);
      expect(find.byKey(const Key('day_action_cancel_manual')), findsNothing);
    });

    testWidgets('حجز يدوي: تفاصيل بضيف من guest_name وزر إلغاء يعمل بتأكيد',
        (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-18');

      final card = find.byKey(const Key('day_booking_card'));
      expect(find.descendant(of: card, matching: find.text('أبو أحمد')),
          findsOneWidget);
      expect(find.text('محجوز يدوياً'), findsWidgets);

      // "تراجع" في الحوار لا يلغي شيئاً.
      await tester.tap(find.byKey(const Key('day_action_cancel_manual')));
      await tester.pumpAndSettle();
      expect(find.text('إلغاء الحجز اليدوي؟'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('cancelManual')), isEmpty);
      expect(find.byKey(const Key('day_panel')), findsOneWidget);

      // التأكيد يلغي عبر المصدر ويحرّر التواريخ.
      await tester.tap(find.byKey(const Key('day_action_cancel_manual')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء الحجز'));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('cancelManual')),
          ['cancelManual man']);
      expect(kindOn(tester, '2030-03-18'), CalendarDayKind.available);
      expect(find.byKey(const Key('day_panel')), findsNothing);
    });

    testWidgets('طلب معلّق: تأكيد ورفض (الرفض بحوار تأكيد)', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-24');

      expect(find.byKey(const Key('day_action_confirm')), findsOneWidget);
      expect(find.byKey(const Key('day_action_reject')), findsOneWidget);
      expect(find.text('بانتظار التأكيد'), findsWidgets);

      // رفض: حوار، "إلغاء" لا يرفض.
      await tester.tap(find.byKey(const Key('day_action_reject')));
      await tester.pumpAndSettle();
      expect(find.text('هل أنت متأكد من رفض هذا الحجز؟ لا يمكن التراجع عن هذا الإجراء.'),
          findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('reject')), isEmpty);

      // تأكيد.
      await tester.tap(find.byKey(const Key('day_action_confirm')));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('confirm')), ['confirm pend']);
      expect(kindOn(tester, '2030-03-24'), CalendarDayKind.appConfirmed);
      expect(find.text('تم تأكيد الحجز بنجاح'), findsOneWidget);
    });

    testWidgets('رفض طلب معلّق بعد التأكيد يحرّر التواريخ', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-24');
      await tester.tap(find.byKey(const Key('day_action_reject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفض الحجز').last);
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('reject')), ['reject pend']);
      expect(kindOn(tester, '2030-03-24'), CalendarDayKind.available);
    });

    testWidgets('يوم مغادرة: يظهر متاحاً مع ملاحظة المغادرة', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-20');
      expect(find.text('مغادرة أبو أحمد صباح هذا اليوم'), findsOneWidget);
      expect(find.byKey(const Key('day_action_block')), findsOneWidget);
    });

    testWidgets('يوم ماضٍ فارغ لا يفتح شيئاً', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-07');
      expect(find.byKey(const Key('day_panel')), findsNothing);
    });

    testWidgets('يوم ماضٍ عليه حجز منتهٍ: قراءة فقط بلا إلغاء', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-04');
      expect(find.byKey(const Key('day_booking_card')), findsOneWidget);
      expect(find.text('رنا حداد'), findsOneWidget);
      expect(find.byKey(const Key('day_action_cancel_manual')), findsNothing);
      expect(find.byKey(const Key('day_action_block')), findsNothing);
    });

    testWidgets('حجز يدوي جارٍ (وصل قبل اليوم) يمكن إلغاؤه', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-09'); // ليلة ماضية من حجز 8→12
      expect(find.text('خالد يوسف'), findsOneWidget);
      expect(find.byKey(const Key('day_action_cancel_manual')), findsOneWidget);
    });

    testWidgets('حجب مرفوض من القاعدة: رسالة خطأ والبيانات تُعاد', (tester) async {
      final ds = sampleDataSource()..writeError = Exception('rls');
      await pumpCalendar(tester, ds);
      await tapDay(tester, '2030-03-16');
      await tester.tap(find.byKey(const Key('day_action_block')));
      await tester.pumpAndSettle();
      expect(find.text('تعذر حجب الأيام، حاول مرة أخرى'), findsOneWidget);
      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.available);
    });
  });

  group('وضع تحديد الأيام', () {
    testWidgets('نقرتان تحجبان نطاقاً (النهاية شاملة) مع تخطي المحجوز بعدّاد',
        (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);

      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      expect(find.text('اختر أول يوم في النطاق'), findsOneWidget);

      await tapDay(tester, '2030-03-16');
      expect(find.textContaining('اختر آخر يوم'), findsOneWidget);
      // لا تفتح ورقة يوم بهذا الوضع.
      expect(find.byKey(const Key('day_panel')), findsNothing);

      // 16..19: ليلتا 18 و19 عليهما حجز يدوي.
      await tapDay(tester, '2030-03-19');
      expect(find.text('حجب من 16 مارس إلى 19 مارس'), findsOneWidget);
      expect(find.text('سيُتخطى يومان لوجود حجز عليه.'), findsOneWidget);
      expect(find.text('حجب ليلتان'), findsOneWidget);

      await tester.tap(find.byKey(const Key('range_confirm')));
      await tester.pumpAndSettle();

      expect(ds.log.where((l) => l.startsWith('block ')),
          ['block c1 2030-03-16,2030-03-17']);
      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.blocked);
      expect(kindOn(tester, '2030-03-17'), CalendarDayKind.blocked);
      expect(kindOn(tester, '2030-03-18'), CalendarDayKind.manual);
      expect(find.text('تم حجب ليلتان، وتم تخطي يومان لوجود حجز'),
          findsOneWidget);
      // خرج من الوضع.
      expect(find.byKey(const Key('range_bar')), findsNothing);
    });

    testWidgets('التراجع عن حجب النطاق يعيد الليالي المحجوبة فقط', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await tapDay(tester, '2030-03-16');
      await tapDay(tester, '2030-03-17');
      await tester.tap(find.byKey(const Key('range_confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('unblock ')),
          ['unblock c1 2030-03-16,2030-03-17']);
      expect(kindOn(tester, '2030-03-16'), CalendarDayKind.available);
    });

    testWidgets('البداية على يوم محجوب تعني إلغاء حجب النطاق', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();

      await tapDay(tester, '2030-03-28');
      await tapDay(tester, '2030-03-31');
      expect(find.text('إلغاء حجب من 28 مارس إلى 31 مارس'), findsOneWidget);
      expect(find.text('سيُتخطى يوم واحد غير محجوب.'), findsOneWidget);
      expect(find.text('إلغاء حجب 3 ليالٍ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('range_confirm')));
      await tester.pumpAndSettle();
      expect(ds.log.where((l) => l.startsWith('unblock ')),
          ['unblock c1 2030-03-28,2030-03-29,2030-03-30']);
      expect(kindOn(tester, '2030-03-29'), CalendarDayKind.available);
      expect(find.text('تم إلغاء حجب 3 ليالٍ'), findsOneWidget);
    });

    testWidgets('البداية على يوم عليه حجز مرفوضة برسالة', (tester) async {
      final ds = sampleDataSource();
      await pumpCalendar(tester, ds);
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await tapDay(tester, '2030-03-13');
      expect(find.text('هذا اليوم عليه حجز، لا يمكن حجبه'), findsOneWidget);
      expect(find.text('اختر أول يوم في النطاق'), findsOneWidget);
    });

    testWidgets('نطاق كله محجوز: لا زر تنفيذ وسبب مكتوب', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await tapDay(tester, '2030-03-16');
      // 16 → 19 يتضمن ليلتين محجوزتين. نضيّق: من 16 إلى 16 (يوم واحد حر).
      await tapDay(tester, '2030-03-16');
      expect(find.text('حجب ليلة واحدة'), findsOneWidget);
    });

    testWidgets('اليوم الماضي لا يُختار برسالة', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await tapDay(tester, '2030-03-07');
      expect(find.text('لا يمكن اختيار يوم منتهٍ'), findsOneWidget);
    });

    testWidgets('نقرة ثالثة تبدأ نطاقاً جديداً، و"إلغاء" يخرج من الوضع',
        (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tester.tap(find.byKey(const Key('action_range_mode')));
      await tester.pumpAndSettle();
      await tapDay(tester, '2030-03-16');
      await tapDay(tester, '2030-03-17');
      await tapDay(tester, '2030-03-21');
      expect(find.textContaining('من 21 مارس'), findsOneWidget);

      await tester.tap(find.byKey(const Key('range_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('range_bar')), findsNothing);
    });

    testWidgets('من ورقة اليوم: "حجب عدة أيام" تدخل الوضع وتبدأ من اليوم',
        (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tapDay(tester, '2030-03-21');
      await tester.tap(find.byKey(const Key('day_action_range_block')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('range_bar')), findsOneWidget);
      expect(find.textContaining('من 21 مارس'), findsOneWidget);
    });

    testWidgets('ضغطة مطوّلة على يوم حر تبدأ الوضع', (tester) async {
      await pumpCalendar(tester, sampleDataSource());
      await tester.longPress(cellOf('2030-03-21'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('range_bar')), findsOneWidget);
      expect(find.textContaining('من 21 مارس'), findsOneWidget);
    });
  });

  group('التخطيط', () {
    for (final width in [360.0, 390.0]) {
      testWidgets('هاتف $width: ورقة سفلية بلا تجاوز أو أخطاء تخطيط',
          (tester) async {
        await pumpCalendar(tester, sampleDataSource(), width: width);
        expect(find.byKey(const Key('side_panel')), findsNothing);
        await tapDay(tester, '2030-03-13');
        expect(find.byKey(const Key('day_panel')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('820: لوحة جانبية بدل الورقة، وتعرض اليوم المنقور', (tester) async {
      await pumpCalendar(tester, sampleDataSource(), width: 820, height: 1000);
      expect(find.byKey(const Key('side_panel')), findsOneWidget);
      expect(find.byKey(const Key('day_panel')), findsNothing);

      await tapDay(tester, '2030-03-13');
      expect(find.descendant(
          of: find.byKey(const Key('side_panel')),
          matching: find.byKey(const Key('day_panel'))), findsOneWidget);
      // الاسم على شريط الحجز (بالخلية) وفي بطاقة اللوحة الجانبية.
      expect(
          find.descendant(
              of: find.byKey(const Key('side_panel')),
              matching: find.text('سامي الخطيب')),
          findsOneWidget);
      expect(
          find.descendant(
              of: cellOf('2030-03-12'), matching: find.text('سامي الخطيب')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('خط مكبّر 2×: لا تجاوز بالخلايا', (tester) async {
      await pumpCalendar(tester, sampleDataSource(), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('الشريط السفلي والقائمة', () {
    testWidgets('زر التقويم فعّال، وزر القائمة يعرض عدد الطلبات المعلّقة',
        (tester) async {
      await pumpCalendar(tester, sampleDataSource(pending: {'c1': 2}));
      expect(find.byKey(const Key('action_bookings_list')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('التقويم'), findsWidgets);
    });
  });
}
