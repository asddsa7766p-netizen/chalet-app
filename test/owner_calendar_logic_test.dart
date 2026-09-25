import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/presentation/screens/owner/calendar/owner_calendar_logic.dart';

BookingModel booking(
  String id,
  DateTime checkIn,
  DateTime checkOut, {
  BookingStatus status = BookingStatus.confirmed,
  String source = 'app',
  String stayType = 'default',
}) =>
    BookingModel(
      id: id,
      chaletId: 'c1',
      userId: 'u1',
      checkIn: checkIn,
      checkOut: checkOut,
      guestsCount: 2,
      totalPrice: 1000,
      status: status,
      createdAt: DateTime(2030, 1, 1),
      source: source,
      stayType: stayType,
    );

void main() {
  final today = DateTime(2030, 3, 10);

  group('إشغال الأيام', () {
    test('الحجز يشغل من check_in حتى ما قبل check_out (حجز قديم ممتد)', () {
      final data = CalendarData()
        ..addBookings([booking('b', DateTime(2030, 3, 14), DateTime(2030, 3, 16))]);

      expect(data.dayInfo(DateTime(2030, 3, 13), today: today).isBooked, isFalse);
      expect(data.dayInfo(DateTime(2030, 3, 14), today: today).isBooked, isTrue);
      expect(data.dayInfo(DateTime(2030, 3, 15), today: today).isBooked, isTrue);
      final after = data.dayInfo(DateTime(2030, 3, 16), today: today);
      expect(after.isBooked, isFalse);
      expect(after.kind, CalendarDayKind.available);
      // 'default' ينتهي بنفس يومه (booking_slots): لا "امتداد" لليوم التالي.
      expect(after.departing, isNull);
    });

    test('يوم كامل مسائي يمتد لصباح اليوم التالي (معلومة فقط)', () {
      final data = CalendarData()
        ..addBookings([
          booking('e', DateTime(2030, 3, 14), DateTime(2030, 3, 15),
              stayType: 'full_day_evening'),
        ]);
      final next = data.dayInfo(DateTime(2030, 3, 15), today: today);
      expect(next.isBooked, isFalse);
      expect(next.departing?.id, 'e');
    });

    test('يوم واحد بفترتين: حجز صباحي وآخر مسائي معاً، الصباحي أولاً', () {
      final data = CalendarData()
        ..addBookings([
          booking('eve', DateTime(2030, 3, 14), DateTime(2030, 3, 15),
              stayType: 'evening'),
          booking('mor', DateTime(2030, 3, 14), DateTime(2030, 3, 15),
              stayType: 'morning', source: 'external'),
        ]);
      final d = data.dayInfo(DateTime(2030, 3, 14), today: today);
      expect(d.bookings.map((b) => b.id), ['mor', 'eve']);
      expect(d.booking?.id, 'mor');
      expect(d.kind, CalendarDayKind.manual);
    });

    test('pending وconfirmed فقط يشغلان التقويم', () {
      final data = CalendarData()
        ..addBookings([
          booking('p', DateTime(2030, 3, 12), DateTime(2030, 3, 13),
              status: BookingStatus.pending),
          booking('x', DateTime(2030, 3, 14), DateTime(2030, 3, 15),
              status: BookingStatus.cancelled),
          booking('r', DateTime(2030, 3, 16), DateTime(2030, 3, 17),
              status: BookingStatus.rejected),
          booking('d', DateTime(2030, 3, 18), DateTime(2030, 3, 19),
              status: BookingStatus.completed),
        ]);
      expect(data.dayInfo(DateTime(2030, 3, 12), today: today).kind,
          CalendarDayKind.pending);
      for (final d in [14, 16, 18]) {
        expect(data.dayInfo(DateTime(2030, 3, d), today: today).isBooked, isFalse,
            reason: 'يوم $d');
      }
    });

    test('تصنيف الحالة: مؤكد من التطبيق، يدوي، معلّق، محجوب، متاح', () {
      final data = CalendarData()
        ..addBookings([
          booking('a', DateTime(2030, 3, 11), DateTime(2030, 3, 12)),
          booking('m', DateTime(2030, 3, 13), DateTime(2030, 3, 14),
              source: 'external'),
          booking('p', DateTime(2030, 3, 15), DateTime(2030, 3, 16),
              status: BookingStatus.pending),
        ])
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 20)});
      CalendarDayKind k(int d) =>
          data.dayInfo(DateTime(2030, 3, d), today: today).kind;
      expect(k(11), CalendarDayKind.appConfirmed);
      expect(k(13), CalendarDayKind.manual);
      expect(k(15), CalendarDayKind.pending);
      expect(k(20), CalendarDayKind.blocked);
      expect(k(25), CalendarDayKind.available);
    });

    test('حجز وحجب معاً: يغلب الحجز وتظهر شارة', () {
      final data = CalendarData()
        ..addBookings([booking('a', DateTime(2030, 3, 11), DateTime(2030, 3, 12))])
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 11)});
      final d = data.dayInfo(DateTime(2030, 3, 11), today: today);
      expect(d.kind, CalendarDayKind.appConfirmed);
      expect(d.hasBlockAndBooking, isTrue);
    });

    test('رقم اليوم داخل حجز قديم ممتد', () {
      final data = CalendarData()
        ..addBookings([booking('a', DateTime(2030, 3, 11), DateTime(2030, 3, 14))]);
      expect(data.dayInfo(DateTime(2030, 3, 11), today: today).nightNumber, 1);
      expect(data.dayInfo(DateTime(2030, 3, 13), today: today).nightNumber, 3);
    });

    test('الماضي واليوم', () {
      final data = CalendarData();
      expect(data.dayInfo(DateTime(2030, 3, 9), today: today).isPast, isTrue);
      final t = data.dayInfo(DateTime(2030, 3, 10, 15), today: today);
      expect(t.isPast, isFalse);
      expect(t.isToday, isTrue);
    });

    test('replaceBlocked يستبدل نطاقه فقط ولا يمسّ الأشهر الأخرى', () {
      final data = CalendarData()
        ..replaceBlocked(DateTime(2030, 2, 1), DateTime(2030, 2, 28),
            {DateTime(2030, 2, 5)})
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 5), DateTime(2030, 3, 6)});
      data.replaceBlocked(
          DateTime(2030, 3, 1), DateTime(2030, 3, 31), {DateTime(2030, 3, 7)});
      expect(data.blocked, {DateTime(2030, 2, 5), DateTime(2030, 3, 7)});
    });
  });

  group('حجب نطاق (النهاية شاملة)', () {
    test('"من 12 إلى 14" تحجب 3 أيام', () {
      final plan =
          planBlock(DateTime(2030, 3, 12), DateTime(2030, 3, 14), CalendarData(), today: today);
      expect(plan.dates,
          [DateTime(2030, 3, 12), DateTime(2030, 3, 13), DateTime(2030, 3, 14)]);
      expect(plan.skipped, 0);
    });

    test('الترتيب المعكوس يعطي نفس النطاق', () {
      final plan =
          planBlock(DateTime(2030, 3, 14), DateTime(2030, 3, 12), CalendarData(), today: today);
      expect(plan.dates.length, 3);
      expect(plan.dates.first, DateTime(2030, 3, 12));
    });

    test('يتخطى الأيام المحجوزة ويعدّها، ولا يكتب فوقها', () {
      final data = CalendarData()
        ..addBookings([booking('a', DateTime(2030, 3, 13), DateTime(2030, 3, 15))]);
      final plan =
          planBlock(DateTime(2030, 3, 12), DateTime(2030, 3, 16), data, today: today);
      // يوما 13 و14 محجوزان. 15 (check_out) حرّ.
      expect(plan.skippedBooked, 2);
      expect(plan.dates,
          [DateTime(2030, 3, 12), DateTime(2030, 3, 15), DateTime(2030, 3, 16)]);
    });

    test('يتخطى المحجوب أصلاً والماضي', () {
      final data = CalendarData()
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 12)});
      final plan =
          planBlock(DateTime(2030, 3, 8), DateTime(2030, 3, 13), data, today: today);
      expect(plan.skippedPast, 2); // 8 و9
      expect(plan.alreadyBlocked, 1); // 12
      expect(plan.dates, [DateTime(2030, 3, 10), DateTime(2030, 3, 11), DateTime(2030, 3, 13)]);
    });

    test('نطاق كله محجوز لا يكتب شيئاً', () {
      final data = CalendarData()
        ..addBookings([booking('a', DateTime(2030, 3, 12), DateTime(2030, 3, 15))]);
      final plan =
          planBlock(DateTime(2030, 3, 12), DateTime(2030, 3, 14), data, today: today);
      expect(plan.dates, isEmpty);
      expect(plan.skippedBooked, 3);
    });
  });

  group('إلغاء حجب نطاق', () {
    test('يشمل المحجوب فقط ويعدّ غير المحجوب', () {
      final data = CalendarData()
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 12), DateTime(2030, 3, 13)});
      final plan = planUnblock(
          DateTime(2030, 3, 11), DateTime(2030, 3, 14), data, today: today);
      expect(plan.dates, [DateTime(2030, 3, 12), DateTime(2030, 3, 13)]);
      expect(plan.skippedNotBlocked, 2);
    });

    test('الماضي لا يُلغى حجبه', () {
      final data = CalendarData()
        ..replaceBlocked(DateTime(2030, 3, 1), DateTime(2030, 3, 31),
            {DateTime(2030, 3, 5), DateTime(2030, 3, 12)});
      final plan = planUnblock(
          DateTime(2030, 3, 5), DateTime(2030, 3, 12), data, today: today);
      expect(plan.dates, [DateTime(2030, 3, 12)]);
      expect(plan.skippedPast, greaterThan(0));
    });
  });

  group('نصوص عربية', () {
    test('الأيام', () {
      expect(daysLabel(1), 'يوم واحد');
      expect(daysLabel(2), 'يومان');
      expect(daysLabel(4), '4 أيام');
    });

    test('تسمية اليوم الكامل', () {
      // 14 أكتوبر 2025 كان يوم الثلاثاء.
      expect(fullDayLabel(DateTime(2025, 10, 14)), 'الثلاثاء 14 أكتوبر');
    });
  });
}
