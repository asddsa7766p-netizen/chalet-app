import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// رسائل رفض trigger validate_app_booking (migration harden_booking_writes)
/// يجب أن تصل للضيف كما هي، لا "حدث خطأ أثناء الحجز".
void main() {
  const messages = [
    guestsNotAllowedMessage,
    periodNotOfferedMessage,
    periodPriceUnavailableMessage,
    bookingTooFarAheadMessage,
    periodAlreadyStartedMessage,
    bookingNotesTooLongMessage,
    pendingBookingsLimitMessage,
  ];

  for (final m in messages) {
    test('تُعرض كما هي خاماً وبعد الترجمة: $m', () {
      final raw = PostgrestException(message: m, code: 'P0001');
      expect(bookingServerMessageIn(raw), m);
      expect(translateSupabaseError(raw), m);
      expect(bookingServerMessageIn(Exception(translateSupabaseError(raw))), m);
    });
  }

  // trigger التداخل أعمى تحت RLS (الضيف لا يرى حجوزات غيره)، فتعارض الضيف مع
  // حجز شخص آخر يصل دائماً من قيد bookings_no_overlap بهذا الشكل، لا من الـ trigger.
  group('23P01 من قيد bookings_no_overlap', () {
    const exclusion = PostgrestException(
      message: 'conflicting key value violates exclusion constraint '
          '"bookings_no_overlap"',
      code: '23P01',
      details: 'Key (chalet_id, occupied_slots)=(…) conflicts with existing '
          'key (chalet_id, occupied_slots)=(…).',
    );

    test('يُترجم لـ "هذه الفترة محجوزة"', () {
      expect(translateSupabaseError(exclusion), periodTakenMessage);
    });

    test('بالرمز وحده حتى لو تغيّر نص الرسالة', () {
      expect(
          translateSupabaseError(
              const PostgrestException(message: 'x', code: '23P01')),
          periodTakenMessage);
    });

    test('شاشة الحجز تعامله كتعارض: ليس رسالة خادم، والنص المترجم فيه "محجوز"',
        () {
      final wrapped = Exception(translateSupabaseError(exclusion));
      expect(bookingServerMessageIn(wrapped), isNull);
      expect(wrapped.toString().contains('محجوز'), isTrue);
    });
  });

  test('لا تُصنَّف كتعارض فترة محجوزة', () {
    for (final m in messages) {
      expect(m.contains('محجوز'), isFalse, reason: m);
      expect(
          translateSupabaseError(PostgrestException(message: m, code: 'P0001')),
          isNot(periodTakenMessage));
    }
  });
}
