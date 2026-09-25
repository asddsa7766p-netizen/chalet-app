import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/booking_period.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/pricing_service.dart';

BookingModel _b(DateTime checkIn, DateTime checkOut,
        {String stayType = 'default', String? start, String? end}) =>
    BookingModel(
      id: 'b',
      chaletId: 'c',
      userId: 'u',
      checkIn: checkIn,
      checkOut: checkOut,
      guestsCount: 2,
      totalPrice: 500,
      status: BookingStatus.confirmed,
      createdAt: DateTime(2030, 1, 1),
      stayType: stayType,
      periodStart: start,
      periodEnd: end,
    );

void main() {
  group('BookingPeriod.forChalet', () {
    test('بلا أنواع مفعّلة: فترة واحدة "يوم كامل" بـ default', () {
      final periods = BookingPeriod.forChalet(const []);
      expect(periods, hasLength(1));
      expect(periods.single.stayType, 'default');
      expect(periods.single.label, 'يوم كامل');
      expect(periods.single.timeLabel, isNull);
    });

    test('الأنواع المفعّلة بأسمائها وأوقاتها', () {
      final periods = BookingPeriod.forChalet(const [
        ChaletStayTypeConfig(
          type: ChaletStayType.morning,
          checkinTime: TimeOfDay(hour: 10, minute: 0),
          checkoutTime: TimeOfDay(hour: 21, minute: 30),
        ),
      ]);
      expect(periods.single.stayType, 'morning');
      expect(periods.single.label, 'إقامة صباحية');
      expect(periods.single.timeLabel, '10:00 ص - 9:30 م');
    });
  });

  test('stayTypeLabel لكل القيم المخزّنة', () {
    expect(stayTypeLabel('morning'), 'إقامة صباحية');
    expect(stayTypeLabel('evening'), 'إقامة مسائية');
    expect(stayTypeLabel('full_day_morning'), 'يوم كامل - صباحي');
    expect(stayTypeLabel('full_day_evening'), 'يوم كامل - مسائي');
    expect(stayTypeLabel('default'), 'يوم كامل');
  });

  test('formatClock: ساعة 12 بص/م', () {
    expect(formatClock(0, 5), '12:05 ص');
    expect(formatClock(12, 0), '12:00 م');
    expect(formatClock(22, 0), '10:00 م');
    expect(periodTimeRangeFromDb('09:00:00', '13:15:00'), '9:00 ص - 1:15 م');
    expect(periodTimeRangeFromDb(null, '13:00:00'), isNull);
    expect(periodTimeRangeFromDb('bad', '13:00:00'), isNull);
  });

  test('BookingModel.fromJson يقرأ وقت الفترة المطابقة من chalet_stay_types', () {
    final b = BookingModel.fromJson({
      'id': 'b',
      'chalet_id': 'c',
      'user_id': 'u',
      'check_in': '2030-03-12',
      'check_out': '2030-03-13',
      'created_at': '2030-03-01T00:00:00Z',
      'stay_type': 'evening',
      'chalets': {
        'name': 'x',
        'chalet_stay_types': [
          {'stay_type': 'morning', 'checkin_time': '10:00:00', 'checkout_time': '21:00:00'},
          {'stay_type': 'evening', 'checkin_time': '22:00:00', 'checkout_time': '09:00:00'},
        ],
      },
    });
    expect(b.periodStart, '22:00:00');
    expect(b.periodWithTime, 'إقامة مسائية · 10:00 م - 9:00 ص');
  });

  group('عرض الحجز كيوم + فترة', () {
    test('حجز يوم واحد: التاريخ فقط، وآخر يوم = يوم الحجز', () {
      final b = _b(DateTime(2030, 3, 12), DateTime(2030, 3, 13));
      expect(b.isMultiDay, isFalse);
      expect(b.dateLabel, 'الثلاثاء 12 مارس 2030');
      expect(b.lastBookedDay, DateTime(2030, 3, 12));
      expect(b.periodWithTime, 'يوم كامل');
    });

    test('حجز قديم ممتد يبقى يُعرض كمدى أيام صحيح', () {
      final b = _b(DateTime(2030, 3, 12), DateTime(2030, 3, 14));
      expect(b.isMultiDay, isTrue);
      expect(b.dateLabel, 'من 12 مارس إلى 13 مارس 2030 (يومان)');
      expect(_b(DateTime(2030, 12, 30), DateTime(2031, 1, 2)).dateLabel,
          'من 30 ديسمبر 2030 إلى 1 يناير 2031 (3 أيام)');
    });
  });
}
