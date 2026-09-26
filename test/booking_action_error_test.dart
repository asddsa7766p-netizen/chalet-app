import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/presentation/screens/owner/bookings/owner_booking_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const fallback = 'تعذر تأكيد الحجز، يرجى المحاولة لاحقاً';

  group('bookingActionErrorMessage', () {
    test('رسالة عربية واضحة من الخدمة تُعرض كما هي', () {
      expect(
          bookingActionErrorMessage(
              Exception(bookingNotUpdatedMessage), fallback),
          bookingNotUpdatedMessage);
      expect(bookingActionErrorMessage(Exception(periodTakenMessage), fallback),
          periodTakenMessage);
    });

    test('نص تقني خام (فيه حروف لاتينية) ← الرسالة العامة', () {
      expect(
          bookingActionErrorMessage(
              const PostgrestException(
                  message: 'permission denied for table bookings',
                  code: '42501'),
              fallback),
          fallback);
      expect(
          bookingActionErrorMessage(
              Exception('SocketException: Failed host lookup'), fallback),
          fallback);
    });

    test('بلا نص عربي ← الرسالة العامة', () {
      expect(bookingActionErrorMessage(Exception(''), fallback), fallback);
      expect(bookingActionErrorMessage(StateError('x'), fallback), fallback);
    });
  });
}
