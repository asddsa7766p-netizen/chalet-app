import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/admin_service.dart';

void main() {
  group('AdminOverviewStats.fromJson (ناتج admin_get_overview_stats)', () {
    test('يقرأ كل المفاتيح، والأرقام قد تأتي int أو double', () {
      final s = AdminOverviewStats.fromJson({
        'totalUsers': 120,
        'totalOwners': 14,
        'activeUsers': 118,
        'totalChalets': 20,
        'approvedChalets': 17,
        'pendingChalets': 3,
        'totalBookings': 55,
        'externalBookings': 9,
        'bookingsByStatus': {'confirmed': 30, 'pending': 5, 'cancelled': 20},
        'totalRevenue': 45250.5,
        'platformRevenue': 3620,
        'from': null,
        'to': null,
      });
      expect(s.totalUsers, 120);
      expect(s.totalOwners, 14);
      expect(s.activeUsers, 118);
      expect(s.totalChalets, 20);
      expect(s.approvedChalets, 17);
      expect(s.pendingChalets, 3);
      expect(s.totalBookings, 55);
      expect(s.externalBookings, 9);
      expect(s.bookingsByStatus, {'confirmed': 30, 'pending': 5, 'cancelled': 20});
      expect(s.totalRevenue, 45250.5);
      expect(s.platformRevenue, 3620.0);
    });

    test('مفاتيح ناقصة أو bookingsByStatus فارغ: أصفار بدل استثناء', () {
      final s = AdminOverviewStats.fromJson({'bookingsByStatus': {}});
      expect(s.totalUsers, 0);
      expect(s.totalRevenue, 0);
      expect(s.bookingsByStatus, isEmpty);
    });
  });

  test('AdminActionException يعرض رسالة الدالة كما هي', () {
    expect(const AdminActionException('لا يمكنك تعطيل حسابك الخاص').toString(),
        'لا يمكنك تعطيل حسابك الخاص');
  });
}
