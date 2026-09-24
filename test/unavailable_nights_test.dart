import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/data/services/unavailable_nights.dart';

void main() {
  dayRuleTests();
  group('rpc get_chalet_unavailable_dates', () {
    test('يُستدعى بالاسم والمعاملات p_chalet_id وp_from وp_to بالضبط', () async {
      String? fn;
      Map<String, dynamic>? sent;

      await UnavailableNights.load(
        'chalet-1',
        from: DateTime(2030, 3, 10),
        to: DateTime(2030, 4, 1),
        rpc: (name, {params}) async {
          fn = name;
          sent = params;
          return [];
        },
      );

      expect(fn, 'get_chalet_unavailable_dates');
      expect(sent, {
        'p_chalet_id': 'chalet-1',
        'p_from': '2030-03-10',
        'p_to': '2030-04-01',
      });
      // لا معاملات زائدة ولا بأسماء أخرى.
      expect(sent!.keys.toSet(), {'p_chalet_id', 'p_from', 'p_to'});
    });

    test('التواريخ تُرسل يوماً فقط بصيغة yyyy-MM-dd حتى مع وقت أو أشهر بخانة واحدة',
        () async {
      Map<String, dynamic>? sent;
      await UnavailableNights.load(
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

    test('النتيجة عمود night: تُقرأ الليالي وتُهمل الصفوف بلا night', () async {
      final nights = await UnavailableNights.load(
        'c',
        from: DateTime(2030, 3, 1),
        rpc: (name, {params}) async => [
          {'night': '2030-03-14'},
          {'night': '2030-03-15'},
          {'night': '2030-03-14'}, // مكرر
          {'other': '2030-03-20'}, // لا night
          {'night': null},
          {'night': 'not-a-date'},
        ],
      );
      expect(nights, {DateTime(2030, 3, 14), DateTime(2030, 3, 15)});
    });

    test('ناتج غير قائمة يعطي مجموعة فارغة', () {
      expect(UnavailableNights.parse(null), isEmpty);
      expect(UnavailableNights.parse({'night': '2030-03-14'}), isEmpty);
    });

    test('الافتراضي: من اليوم لـ 366 يوماً، وأي نافذة تُقصّ على 400 يوم',
        () async {
      Map<String, dynamic>? sent;
      Future<dynamic> capture(String name, {Map<String, dynamic>? params}) async {
        sent = params;
        return [];
      }

      await UnavailableNights.load('c',
          from: DateTime(2030, 1, 1), rpc: capture);
      expect(sent!['p_from'], '2030-01-01');
      expect(sent!['p_to'], '2031-01-02'); // +366

      await UnavailableNights.load('c',
          from: DateTime(2030, 1, 1), to: DateTime(2035, 1, 1), rpc: capture);
      expect(sent!['p_to'], '2031-02-05'); // +400
    });

    test('BookingService.getUnavailableNights يرجع قائمة مرتبة ويمرّر الأسماء',
        () async {
      Map<String, dynamic>? sent;
      final list = await BookingService.instance.getUnavailableNights(
        'chalet-9',
        from: DateTime(2030, 3, 10),
        rpc: (name, {params}) async {
          sent = params;
          return [
            {'night': '2030-03-16'},
            {'night': '2030-03-12'},
          ];
        },
      );
      expect(sent!['p_chalet_id'], 'chalet-9');
      expect(list, [DateTime(2030, 3, 12), DateTime(2030, 3, 16)]);
    });

    test('خطأ الـ rpc يُترجم برسالة عربية بدل الخام', () async {
      expect(
        () => BookingService.instance.getUnavailableNights(
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
      expect(msg, 'بعض الأيام المختارة غير متاحة للحجز. اختر تواريخ أخرى.');
      expect(msg.contains('محجوز'), isFalse);
      // محايدة: لا تكشف أن المالك هو من حجب.
      expect(msg.contains('مالك'), isFalse);
    });

    test('حروف كبيرة وصغيرة لا تهم', () {
      expect(translateSupabaseError('BOOKING CONFLICT: AVAILABILITY UNAVAILABLE'),
          unavailableDatesMessage);
    });

    test('تعارض التداخل العادي لا يتغيّر', () {
      const overlap = 'هذا التاريخ محجوز، جرب تواريخ تانية';
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

// قاعدة تعطيل الأيام المشتركة بين شاشة الضيف وورقة الحجز اليدوي.
void dayRuleTests() {
  group('isDayDisabledForStay (الأيام المحجوزة/المحجوبة معطّلة)', () {
    // ليالي 14 و15 غير متاحة (محجوزة أو محجوبة).
    final unavailable = {DateTime(2030, 3, 14), DateTime(2030, 3, 15)};

    bool disabled(int day, {int? checkIn, bool selectingEnd = false}) =>
        isDayDisabledForStay(
          DateTime(2030, 3, day),
          unavailable: unavailable,
          checkIn: checkIn == null ? null : DateTime(2030, 3, checkIn),
          selectingEnd: selectingEnd,
        );

    test('كوصول: الليلة غير المتاحة معطّلة والحرة مفعّلة', () {
      expect(disabled(14), isTrue);
      expect(disabled(15), isTrue);
      expect(disabled(13), isFalse);
      expect(disabled(16), isFalse);
    });

    test('كمغادرة: يجوز اختيار يوم غير متاح إن كانت الليالي قبله خالية', () {
      // وصول 12 → مغادرة 14 (ليلتا 12 و13 خاليتان) — يجوز رغم أن 14 غير متاح.
      expect(disabled(14, checkIn: 12, selectingEnd: true), isFalse);
      expect(disabled(13, checkIn: 12, selectingEnd: true), isFalse);
    });

    test('كمغادرة: فترة تعبر ليلة غير متاحة معطّلة', () {
      expect(disabled(15, checkIn: 12, selectingEnd: true), isTrue);
      expect(disabled(17, checkIn: 12, selectingEnd: true), isTrue);
    });

    test('أثناء اختيار المغادرة: يوم أبكر من الوصول يبقى وصولاً جديداً بنفس القاعدة',
        () {
      expect(disabled(11, checkIn: 12, selectingEnd: true), isFalse);
      // وصول 16 والنقر على 15 (غير متاح) كوصول جديد أبكر: معطّل.
      expect(disabled(15, checkIn: 16, selectingEnd: true), isTrue);
    });

    test('بلا selectingEnd: نفس اليوم بلا تأثير للوصول المحدد', () {
      expect(disabled(17, checkIn: 12), isFalse);
    });

    test('rangeHasUnavailableNight: المغادرة غير شاملة', () {
      expect(
          rangeHasUnavailableNight(
              DateTime(2030, 3, 12), DateTime(2030, 3, 14), unavailable),
          isFalse);
      expect(
          rangeHasUnavailableNight(
              DateTime(2030, 3, 12), DateTime(2030, 3, 15), unavailable),
          isTrue);
      expect(rangeHasUnavailableNight(null, null, unavailable), isFalse);
    });
  });
}
