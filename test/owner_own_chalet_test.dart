import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/chalet_model.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/presentation/screens/chalet/widgets/own_chalet_booking_note.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

BookingModel _booking({
  String userId = 'me',
  String? ownerId = 'someone-else',
  String source = 'app',
  BookingStatus status = BookingStatus.completed,
}) =>
    BookingModel(
      id: 'b1',
      chaletId: 'c1',
      userId: userId,
      checkIn: DateTime(2030, 3, 14),
      checkOut: DateTime(2030, 3, 15),
      guestsCount: 2,
      totalPrice: 300,
      status: status,
      createdAt: DateTime(2030, 3, 1),
      source: source,
      chaletOwnerId: ownerId,
    );

void main() {
  group('رسالة رفض حجز المالك لشاليهه (P0001)', () {
    const raw = PostgrestException(
        message: ownChaletBookingMessage, code: 'P0001');

    test('تُعرض كما هي: خاماً أو بعد ترجمة طبقة الخدمات', () {
      expect(bookingServerMessageIn(raw), ownChaletBookingMessage);
      expect(translateSupabaseError(raw), ownChaletBookingMessage);
      expect(bookingServerMessageIn(Exception(translateSupabaseError(raw))),
          ownChaletBookingMessage);
    });

    test('رسائل الحجز الأخرى من الخادم كما هي، والأخطاء العامة لا', () {
      expect(
          bookingServerMessageIn(
              const PostgrestException(message: chaletNotBookableMessage)),
          chaletNotBookableMessage);
      expect(bookingServerMessageIn(Exception('network down')), isNull);
    });
  });

  test('ChaletModel.isOwnedBy', () {
    final chalet = ChaletModel.fromJson(
        {'id': 'c1', 'name': 'شاليه', 'owner_id': 'owner-1'});
    expect(chalet.isOwnedBy('owner-1'), isTrue);
    expect(chalet.isOwnedBy('guest-2'), isFalse);
    expect(chalet.isOwnedBy(null), isFalse, reason: 'الضيف');
  });

  group('ReviewsService.canReview (مثل سياسة إدراج التقييم)', () {
    test('حجز تطبيق مكتمل لشاليه غيري: نعم', () {
      expect(ReviewsService.canReview(_booking(), 'me'), isTrue);
    });

    test('شاليهي: لا', () {
      expect(ReviewsService.canReview(_booking(ownerId: 'me'), 'me'), isFalse);
    });

    test('حجز يدوي، أو غير مكتمل، أو لغيري، أو ضيف: لا', () {
      expect(ReviewsService.canReview(_booking(source: 'external'), 'me'),
          isFalse);
      expect(
          ReviewsService.canReview(
              _booking(status: BookingStatus.confirmed), 'me'),
          isFalse);
      expect(ReviewsService.canReview(_booking(userId: 'other'), 'me'),
          isFalse);
      expect(ReviewsService.canReview(_booking(), null), isFalse);
    });

    test('المالك غير مضمَّن بالاستعلام: لا يمنع (الخادم يحسم)', () {
      expect(ReviewsService.canReview(_booking(ownerId: null), 'me'), isTrue);
    });

    test('owner_id يُقرأ من chalets بالحجز', () {
      final b = BookingModel.fromJson({
        'id': 'b1',
        'chalet_id': 'c1',
        'user_id': 'me',
        'check_in': '2030-03-14',
        'check_out': '2030-03-15',
        'status': 'completed',
        'created_at': '2030-03-01T00:00:00Z',
        'chalets': {'name': 'شاليه', 'owner_id': 'me'},
      });
      expect(b.chaletOwnerId, 'me');
      expect(ReviewsService.canReview(b, 'me'), isFalse);
    });
  });

  testWidgets('ملاحظة المالك مكان "احجز الآن" تفتح الحجز اليدوي',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 240, // عرض الجزء المتاح بجانب السعر على شاشة 360
            child: OwnChaletBookingNote(onManualBooking: () => opened++),
          ),
        ),
      ),
    ));
    expect(find.text('هذا شاليهك'), findsOneWidget);
    expect(find.text('احجز الآن'), findsNothing);
    await tester.tap(find.byKey(const Key('own_chalet_manual_booking')));
    expect(opened, 1);
    expect(tester.takeException(), isNull, reason: 'لا overflow بعرض ضيق');
  });
}
