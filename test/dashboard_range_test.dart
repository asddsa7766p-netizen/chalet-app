import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/dashboard_service.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('OwnerDashboardRange.dateRangeFor: تواريخ تقويمية', () {
    test('اليوم وأمس عبر حدّ السنة', () {
      final now = DateTime(2027, 1, 1, 0, 30);
      expect(OwnerDashboardRange.today.dateRangeFor(now),
          (d(2027, 1, 1), d(2027, 1, 1)));
      expect(OwnerDashboardRange.yesterday.dateRangeFor(now),
          (d(2026, 12, 31), d(2026, 12, 31)));
    });

    test('آخر 7 أيام = اليوم و6 قبله، عبر حدّ الشهر', () {
      expect(
          OwnerDashboardRange.last7Days.dateRangeFor(DateTime(2026, 3, 3, 23)),
          (d(2026, 2, 25), d(2026, 3, 3)));
    });

    test('الشهر الماضي: أول يوم وآخر يوم (فبراير الكبيسة وغير الكبيسة)', () {
      expect(OwnerDashboardRange.lastMonth.dateRangeFor(DateTime(2028, 3, 15)),
          (d(2028, 2, 1), d(2028, 2, 29)));
      expect(OwnerDashboardRange.lastMonth.dateRangeFor(DateTime(2027, 3, 1)),
          (d(2027, 2, 1), d(2027, 2, 28)));
      expect(OwnerDashboardRange.lastMonth.dateRangeFor(DateTime(2027, 1, 10)),
          (d(2026, 12, 1), d(2026, 12, 31)));
    });

    test('كل الحدود منتصف ليل (بلا ساعات متبقية من طرح 24 ساعة)', () {
      for (final r in OwnerDashboardRange.values) {
        final (start, end) = r.dateRangeFor(DateTime(2026, 10, 31, 13, 45));
        for (final x in [start, end]) {
          expect((x.hour, x.minute), (0, 0), reason: '$r');
        }
      }
    });
  });
}
