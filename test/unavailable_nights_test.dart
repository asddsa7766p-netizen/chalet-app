import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/chalet_slot_availability.dart';
import 'package:makan/data/services/services.dart';

const _full = ChaletDaySlot(morningBooked: true, eveningBooked: true, blocked: false);
const _morningOnly =
    ChaletDaySlot(morningBooked: true, eveningBooked: false, blocked: false);
const _eveningOnly =
    ChaletDaySlot(morningBooked: false, eveningBooked: true, blocked: false);
const _blocked =
    ChaletDaySlot(morningBooked: false, eveningBooked: false, blocked: true);

/// مصدر الأيام غير المتاحة الوحيد بعد إزالة نموذج "الليالي" القديم
/// (get_chalet_unavailable_dates): توفر الفترات get_chalet_slot_availability.
void main() {
  dayRuleTests();

  group('rpc get_chalet_slot_availability', () {
    test('يُستدعى بالاسم والمعاملات p_chalet_id وp_from وp_to بالضبط', () async {
      String? fn;
      Map<String, dynamic>? sent;

      await ChaletSlotAvailability.load(
        'chalet-1',
        from: DateTime(2030, 3, 10),
        to: DateTime(2030, 4, 1),
        rpc: (name, {params}) async {
          fn = name;
          sent = params;
          return [];
        },
      );

      expect(fn, 'get_chalet_slot_availability');
      expect(sent, {
        'p_chalet_id': 'chalet-1',
        'p_from': '2030-03-10',
        'p_to': '2030-04-01',
      });
    });

    test('التواريخ تُرسل يوماً فقط بصيغة yyyy-MM-dd حتى مع وقت أو أشهر بخانة واحدة',
        () async {
      Map<String, dynamic>? sent;
      await ChaletSlotAvailability.load(
        'c',
        from: DateTime(2030, 1, 5, 23, 40),
        to: DateTime(2030, 2, 9, 8),
        rpc: (name, {params}) async {
          sent = params;
          return [];
        },
      );
      expect(sent!['p_from'], '2030-01-05');
      expect(sent!['p_to'], '2030-02-09');
    });

    test('النتيجة: day وفترتان وحجب، والصفوف بلا day صالح تُهمل', () async {
      final slots = await ChaletSlotAvailability.load(
        'c',
        from: DateTime(2030, 3, 1),
        rpc: (name, {params}) async => [
          {
            'day': '2030-03-14',
            'morning_booked': true,
            'evening_booked': false,
            'blocked': false,
          },
          {'day': '2030-03-15', 'blocked': true},
          {'other': '2030-03-20'},
          {'day': null},
          {'day': 'not-a-date'},
        ],
      );
      expect(slots.keys, [DateTime(2030, 3, 14), DateTime(2030, 3, 15)]);
      expect(slots[DateTime(2030, 3, 14)]!.isPartiallyBooked, isTrue);
      expect(slots[DateTime(2030, 3, 15)]!.isFullyUnavailable, isTrue);
    });

    test('ناتج غير قائمة يعطي خريطة فارغة', () {
      expect(ChaletSlotAvailability.parse(null), isEmpty);
      expect(ChaletSlotAvailability.parse({'day': '2030-03-14'}), isEmpty);
    });

    test('الافتراضي: من اليوم لـ 367 يوماً، وأي نافذة تُقصّ على 400 يوم',
        () async {
      Map<String, dynamic>? sent;
      Future<dynamic> capture(String name, {Map<String, dynamic>? params}) async {
        sent = params;
        return [];
      }

      await ChaletSlotAvailability.load('c',
          from: DateTime(2030, 1, 1), rpc: capture);
      expect(sent!['p_from'], '2030-01-01');
      expect(sent!['p_to'], '2031-01-03'); // +367

      await ChaletSlotAvailability.load('c',
          from: DateTime(2030, 1, 1), to: DateTime(2035, 1, 1), rpc: capture);
      expect(sent!['p_to'], '2031-02-05'); // +400
    });

    test('BookingService.getDaySlots يمرّر الأسماء ويرجع الفترات', () async {
      Map<String, dynamic>? sent;
      final slots = await BookingService.instance.getDaySlots(
        'chalet-9',
        from: DateTime(2030, 3, 10),
        rpc: (name, {params}) async {
          sent = params;
          return [
            {'day': '2030-03-16', 'evening_booked': true},
          ];
        },
      );
      expect(sent!['p_chalet_id'], 'chalet-9');
      expect(slots[DateTime(2030, 3, 16)]!.eveningBooked, isTrue);
    });

    test('خطأ الـ rpc يُترجم برسالة عربية بدل الخام', () async {
      expect(
        () => BookingService.instance.getDaySlots(
          'c',
          from: DateTime(2030, 3, 10),
          rpc: (name, {params}) async =>
              throw Exception('Booking conflict: availability unavailable'),
        ),
        throwsA(predicate((e) => e.toString().contains(unavailableDatesMessage))),
      );
    });
  });

  group('ترجمة خطأ الـ trigger', () {
    test('availability unavailable ← رسالة الأيام غير المتاحة (لا "محجوز")', () {
      final msg = translateSupabaseError(
          'PostgrestException(message: Booking conflict: availability unavailable, code: P0001)');
      expect(msg, unavailableDatesMessage);
      expect(msg, 'هذا اليوم غير متاح للحجز. اختر يوماً آخر.');
      expect(msg.contains('محجوز'), isFalse);
      // محايدة: لا تكشف أن المالك هو من حجب.
      expect(msg.contains('مالك'), isFalse);
    });

    test('رفض الحجز متعدد الأيام يُعرض بنص السيرفر كما هو', () {
      const raw = 'PostgrestException(message: الحجز يكون ليوم واحد وفترة '
          'واحدة فقط, code: 22023, details: null, hint: null)';
      expect(translateSupabaseError(raw), 'الحجز يكون ليوم واحد وفترة واحدة فقط');
      expect(translateSupabaseError('code: 23505 الحجز يكون ليوم واحد وفترة واحدة فقط'),
          singleDayOnlyMessage);
    });

    test('حروف كبيرة وصغيرة لا تهم', () {
      expect(translateSupabaseError('BOOKING CONFLICT: AVAILABILITY UNAVAILABLE'),
          unavailableDatesMessage);
    });

    test('تعارض فترة محجوزة', () {
      const overlap = 'هذه الفترة محجوزة، جرّب فترة أو يوماً آخر';
      expect(periodTakenMessage, overlap);
      expect(translateSupabaseError('Booking conflict: overlapping dates'),
          overlap);
      expect(
          translateSupabaseError(
              'conflicting key value violates exclusion constraint "bookings_no_overlap"'),
          overlap);
      expect(translateSupabaseError('code: 23P01'), overlap);
      // "booking conflict" وحدها بلا availability تبقى تداخلاً.
      expect(translateSupabaseError('Booking conflict'), overlap);
    });
  });
}

/// قاعدة تعطيل الأيام المشتركة بين شاشة الضيف وورقة الحجز اليدوي.
void dayRuleTests() {
  group('isDayDisabledForStaySlot (نوع default: الفترتان معاً)', () {
    // 14 و15 غير متاحين (محجوز بالكامل / محجوب).
    final slots = {
      DateTime(2030, 3, 14): _full,
      DateTime(2030, 3, 15): _blocked,
    };

    bool disabled(int day, {int? checkIn, bool selectingEnd = false}) =>
        isDayDisabledForStaySlot(
          DateTime(2030, 3, day),
          slots: slots,
          stayType: 'default',
          checkIn: checkIn == null ? null : DateTime(2030, 3, checkIn),
          selectingEnd: selectingEnd,
        );

    test('كوصول: اليوم غير المتاح معطّل والحر مفعّل', () {
      expect(disabled(14), isTrue);
      expect(disabled(15), isTrue);
      expect(disabled(13), isFalse);
      expect(disabled(16), isFalse);
    });

    test('كمغادرة: يجوز اختيار يوم غير متاح إن كانت الأيام قبله خالية', () {
      expect(disabled(14, checkIn: 12, selectingEnd: true), isFalse);
      expect(disabled(13, checkIn: 12, selectingEnd: true), isFalse);
    });

    test('كمغادرة: فترة تعبر يوماً غير متاح معطّلة', () {
      expect(disabled(15, checkIn: 12, selectingEnd: true), isTrue);
      expect(disabled(17, checkIn: 12, selectingEnd: true), isTrue);
    });

    test('أثناء اختيار المغادرة: يوم أبكر من الوصول يبقى وصولاً جديداً بنفس القاعدة',
        () {
      expect(disabled(11, checkIn: 12, selectingEnd: true), isFalse);
      expect(disabled(15, checkIn: 16, selectingEnd: true), isTrue);
    });

    test('rangeHasUnavailableDayForStayType: المغادرة غير شاملة', () {
      bool range(int from, int to) => rangeHasUnavailableDayForStayType(
          DateTime(2030, 3, from), DateTime(2030, 3, to),
          stayType: 'default', slots: slots);
      expect(range(12, 14), isFalse);
      expect(range(12, 15), isTrue);
      expect(
          rangeHasUnavailableDayForStayType(null, null,
              stayType: 'default', slots: slots),
          isFalse);
    });
  });

  group('أيام محجوزة جزئياً حسب نوع الإقامة (مطابقة booking_slots)', () {
    final d = DateTime(2030, 3, 12);
    bool ok(String type, Map<DateTime, ChaletDaySlot> slots) =>
        isDayAvailableForStayType(d, stayType: type, slots: slots);

    test('الصباحية محجوزة: المسائية فقط متاحة', () {
      final s = {d: _morningOnly};
      expect(ok('morning', s), isFalse);
      expect(ok('evening', s), isTrue);
      expect(ok('full_day_morning', s), isFalse);
      expect(ok('full_day_evening', s), isTrue);
      expect(ok('default', s), isFalse);
    });

    test('المسائية محجوزة: الصباحية فقط متاحة', () {
      final s = {d: _eveningOnly};
      expect(ok('morning', s), isTrue);
      expect(ok('evening', s), isFalse);
      expect(ok('full_day_evening', s), isFalse);
    });

    test('يوم كامل مسائي يحتاج صباح اليوم التالي حرّاً', () {
      final s = {DateTime(2030, 3, 13): _morningOnly};
      expect(ok('full_day_evening', s), isFalse);
      expect(ok('evening', s), isTrue);
    });

    test('المحجوب يغلب كل الأنواع', () {
      final s = {d: _blocked};
      for (final t in ['morning', 'evening', 'full_day_morning', 'default']) {
        expect(ok(t, s), isFalse, reason: t);
      }
    });
  });
}
