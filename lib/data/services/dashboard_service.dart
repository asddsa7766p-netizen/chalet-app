import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/error_reporter.dart';

// Supabase client
final supabase = Supabase.instance.client;

enum OwnerDashboardRange { today, yesterday, last7Days, lastMonth }

extension OwnerDashboardRangeX on OwnerDashboardRange {
  String get arLabel {
    switch (this) {
      case OwnerDashboardRange.today:
        return 'اليوم';
      case OwnerDashboardRange.yesterday:
        return 'أمس';
      case OwnerDashboardRange.last7Days:
        return 'آخر 7 أيام';
      case OwnerDashboardRange.lastMonth:
        return 'الشهر الماضي';
    }
  }

  /// نطاق التاريخ [start, end] شامل الطرفين، بحساب تقويمي بسيط بدون
  /// الاعتماد على فروقات توقيت أو منطقة زمنية معقدة (نستخدم تاريخ اليوم
  /// المحلي للجهاز كأساس، وهو نفس الأساس الذي كانت تعتمده الـ SQL views
  /// السابقة عبر CURRENT_DATE في قاعدة البيانات).
  (DateTime start, DateTime end) get dateRange => dateRangeFor(DateTime.now());

  /// [dateRange] مع "الآن" قابل للتمرير (للاختبارات).
  ///
  /// كل الحسابات بتواريخ تقويمية `DateTime(y, m, d ± n)` لا بـ `Duration(days:)`:
  /// الأخيرة تطرح 24 ساعة بالضبط، فبعد يوم تغيير التوقيت (23 أو 25 ساعة)
  /// تقع على اليوم الخطأ.
  (DateTime start, DateTime end) dateRangeFor(DateTime now) {
    final y = now.year, m = now.month, d = now.day;
    final today = DateTime(y, m, d);

    switch (this) {
      case OwnerDashboardRange.today:
        return (today, today);
      case OwnerDashboardRange.yesterday:
        final yesterday = DateTime(y, m, d - 1);
        return (yesterday, yesterday);
      case OwnerDashboardRange.last7Days:
        return (DateTime(y, m, d - 6), today);
      case OwnerDashboardRange.lastMonth:
        // اليوم 0 من الشهر الحالي = آخر يوم بالشهر الماضي.
        return (DateTime(y, m - 1, 1), DateTime(y, m, 0));
    }
  }
}

class OwnerDashboardStats {
  // Totals (legacy / used in some cards)
  final int totalBookings;
  final double totalRevenue;

  // Split totals (Chalet Spot design)
  final int totalBookingsSpot;
  final double totalRevenueSpot;
  final int totalBookingsExternal;
  final double totalRevenueExternal;

  // Cancelled / Rejected split
  final int cancelledOrRejectedByOwner;
  final int cancelledByUser;

  /// percentage of cancelled/rejected by owner vs total for the selected range (legacy)
  final double cancelledOrRejectedRatioPercent;

  final double avgDailyBookings;

  /// الحجوزات المؤكدة (confirmed أو completed) بالنطاق — نفس الحجوزات التي
  /// تُحسب بالإيرادات، بلا المعلّقة ولا الملغاة/المرفوضة.
  final int confirmedBookings;

  /// Per chalet breakdown (legacy)
  final List<OwnerDashboardChaletBreakdown> byChalet;
  final List<OwnerDashboardChaletRevenueBreakdown> byChaletRevenue;

  const OwnerDashboardStats({
    required this.totalBookings,
    required this.totalRevenue,
    required this.totalBookingsSpot,
    required this.totalRevenueSpot,
    required this.totalBookingsExternal,
    required this.totalRevenueExternal,
    required this.cancelledOrRejectedByOwner,
    required this.cancelledByUser,
    required this.cancelledOrRejectedRatioPercent,
    required this.avgDailyBookings,
    required this.confirmedBookings,
    required this.byChalet,
    required this.byChaletRevenue,
  });

  /// إحصائيات فاضية، لغير المسجّل فقط. فشل التحميل لا يُرجعها بل يُرمى، حتى
  /// لا تظهر أصفار كأنها بيانات حقيقية.
  factory OwnerDashboardStats.empty() => const OwnerDashboardStats(
        totalBookings: 0,
        totalRevenue: 0,
        totalBookingsSpot: 0,
        totalRevenueSpot: 0,
        totalBookingsExternal: 0,
        totalRevenueExternal: 0,
        cancelledOrRejectedByOwner: 0,
        cancelledByUser: 0,
        cancelledOrRejectedRatioPercent: 0,
        avgDailyBookings: 0,
        confirmedBookings: 0,
        byChalet: [],
        byChaletRevenue: [],
      );
}

class OwnerDashboardChaletBreakdown {
  final String chaletId;
  final String chaletName;
  final int bookingsCount;
  final double revenue;
  final double ratioPercent;

  const OwnerDashboardChaletBreakdown({
    required this.chaletId,
    required this.chaletName,
    required this.bookingsCount,
    required this.revenue,
    required this.ratioPercent,
  });
}

class OwnerDashboardChaletRevenueBreakdown {
  final String chaletId;
  final String chaletName;
  final int bookingsCount;
  final double revenue;
  final double ratioPercent;

  const OwnerDashboardChaletRevenueBreakdown({
    required this.chaletId,
    required this.chaletName,
    required this.bookingsCount,
    required this.revenue,
    required this.ratioPercent,
  });
}

class DashboardService {
  static DashboardService? _instance;
  static DashboardService get instance => _instance ??= DashboardService._();
  DashboardService._();

  /// سقف أمان لصفوف استعلام الإحصائيات (أطول نطاق = شهر واحد).
  static const statsRowsLimit = 5000;

  /// إحصائيات لوحة تحكم المالك.
  ///
  /// ⚠️ تعديل بنيوي مهم عن النسخة السابقة: لم تعد هذه الدالة تعتمد على
  /// SQL Views محسوبة مسبقًا بقاعدة البيانات (owner_dashboard_stats_*).
  /// السبب: عند الفحص الفعلي لقاعدة البيانات، تبيّن أن 16 من أصل 24 view
  /// متوقعة كانت غائبة بالكامل، والـ 8 الموجودة فعليًا كانت تُرجع أسماء
  /// أعمدة مختلفة تمامًا عما يتوقعه هذا الملف أصلًا (totalBookings/confirmed
  /// بدل totalBookingsSpot/totalBookingsExternal مثلاً)، أي أن الحساب كان
  /// صامتًا يعيد أصفارًا دون أي خطأ ظاهر.
  ///
  /// الحل: نجلب صفوف الحجوزات الخاصة بشاليهات المالك الحالي مباشرة (مع
  /// فلتر صريح وآمن على owner_id)، ثم نحسب كل الإحصائيات محليًا في Dart.
  /// هذا أبسط للمراجعة والصيانة من تنسيق عشرات الـ SQL views، ولا يعتمد
  /// على أي بنية قاعدة بيانات إضافية غير الجداول الأساسية الموجودة فعلًا.
  Future<OwnerDashboardStats> getOwnerDashboardStats({
    required OwnerDashboardRange range,
  }) async {
    final ownerId = Supabase.instance.client.auth.currentUser?.id;
    if (ownerId == null) return OwnerDashboardStats.empty();

    final (start, end) = range.dateRange;
    // اليوم التالي لآخر يوم بالنطاق (تقويمياً، لا +24 ساعة) حتى يشمل كل
    // حجوزات اليوم الأخير.
    final endExclusive = nextDay(end);

    // فشل الاستعلام يُرمى للمستدعي: اللوحة والتقارير تعرضان "تعذر التحميل"
    // مع إعادة المحاولة. (كان يُرجع إحصائيات فاضية، فتظهر أصفار تبدو حقيقية.)
    final List<dynamic> rows = await supabase
        .from('bookings')
        .select(
          'id, chalet_id, check_in, check_out, total_price, status, cancelled_by, '
          'chalets!inner(id, name, owner_id, booking_type)',
        )
        .eq('chalets.owner_id', ownerId)
        .gte('check_in', start.toIso8601String().split('T').first)
        .lt('check_in', endExclusive.toIso8601String().split('T').first)
        .limit(statsRowsLimit);
    if (rows.length >= statsRowsLimit) {
      // لا يُتوقَّع بلوغه (أطول نطاق شهر)، لكن إن حدث فالأرقام ناقصة: يُسجَّل.
      reportError(
        StateError('owner stats hit row limit $statsRowsLimit'),
        StackTrace.current,
        context: 'dashboard.owner_stats_limit',
      );
    }

    int totalBookingsSpot = 0;
    int totalBookingsExternal = 0;
    double totalRevenueSpot = 0;
    double totalRevenueExternal = 0;
    int cancelledOrRejectedByOwner = 0;
    int cancelledByUser = 0;
    int confirmedBookings = 0;

    // تجميع لكل شاليه: عدد الحجوزات والإيرادات (فقط الحجوزات confirmed أو
    // completed تُحتسب ضمن "الإيرادات"، بما يطابق منطق الـ views السابقة
    // التي كانت تحسب الإيرادات فقط لحالة confirmed).
    final Map<String, _ChaletAgg> byChaletAgg = {};

    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final status = map['status'] as String? ?? '';
      final cancelledBy = map['cancelled_by'] as String? ?? 'owner';
      final totalPrice = (map['total_price'] as num?)?.toDouble() ?? 0;
      final chaletData = map['chalets'] as Map<String, dynamic>?;
      final chaletId = map['chalet_id'] as String? ?? '';
      final chaletName = chaletData?['name'] as String? ?? 'شاليه';
      final bookingType = chaletData?['booking_type'] as String? ?? 'يومي';
      final isExternal = bookingType == 'خارجي';

      final isRevenueCounted = status == 'confirmed' || status == 'completed';
      final isCancelledOrRejected =
          status == 'rejected' || status == 'cancelled';

      if (isExternal) {
        totalBookingsExternal++;
        if (isRevenueCounted) totalRevenueExternal += totalPrice;
      } else {
        totalBookingsSpot++;
        if (isRevenueCounted) totalRevenueSpot += totalPrice;
      }

      if (isCancelledOrRejected) {
        if (status == 'rejected' || cancelledBy == 'owner') {
          cancelledOrRejectedByOwner++;
        } else if (cancelledBy == 'user') {
          cancelledByUser++;
        }
      }

      if (isRevenueCounted) confirmedBookings++;

      if (isRevenueCounted && chaletId.isNotEmpty) {
        final agg =
            byChaletAgg.putIfAbsent(chaletId, () => _ChaletAgg(chaletName));
        agg.bookingsCount++;
        agg.revenue += totalPrice;
      }
    }

    final totalBookings = totalBookingsSpot + totalBookingsExternal;
    final totalRevenue = totalRevenueSpot + totalRevenueExternal;
    final cancelledTotal = cancelledOrRejectedByOwner + cancelledByUser;
    final cancelledOrRejectedRatioPercent =
        totalBookings > 0 ? (cancelledTotal / totalBookings * 100) : 0.0;

    // متوسط الحجوزات اليومية: عدد أيام النطاق المختار (شامل الطرفين).
    final daysInRange = nightsBetween(start, endExclusive);
    final avgDailyBookings =
        daysInRange > 0 ? totalBookings / daysInRange : 0.0;

    final byChaletRevenue = byChaletAgg.entries.map((e) {
      final ratio =
          totalRevenue > 0 ? (e.value.revenue / totalRevenue * 100) : 0.0;
      return OwnerDashboardChaletRevenueBreakdown(
        chaletId: e.key,
        chaletName: e.value.name,
        bookingsCount: e.value.bookingsCount,
        revenue: e.value.revenue,
        ratioPercent: ratio,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final byChalet = byChaletAgg.entries.map((e) {
      final ratio = totalBookings > 0
          ? (e.value.bookingsCount / totalBookings * 100)
          : 0.0;
      return OwnerDashboardChaletBreakdown(
        chaletId: e.key,
        chaletName: e.value.name,
        bookingsCount: e.value.bookingsCount,
        revenue: e.value.revenue,
        ratioPercent: ratio,
      );
    }).toList()
      ..sort((a, b) => b.bookingsCount.compareTo(a.bookingsCount));

    return OwnerDashboardStats(
      totalBookings: totalBookings,
      totalRevenue: totalRevenue,
      totalBookingsSpot: totalBookingsSpot,
      totalRevenueSpot: totalRevenueSpot,
      totalBookingsExternal: totalBookingsExternal,
      totalRevenueExternal: totalRevenueExternal,
      cancelledOrRejectedByOwner: cancelledOrRejectedByOwner,
      cancelledByUser: cancelledByUser,
      cancelledOrRejectedRatioPercent: cancelledOrRejectedRatioPercent,
      avgDailyBookings: avgDailyBookings,
      confirmedBookings: confirmedBookings,
      byChalet: byChalet,
      byChaletRevenue: byChaletRevenue,
    );
  }
}

/// مجمّع داخلي بسيط لحساب عدد الحجوزات والإيرادات لكل شاليه أثناء المرور
/// على صفوف الحجوزات مرة واحدة فقط (بدل عدة استعلامات منفصلة لكل شاليه).
class _ChaletAgg {
  final String name;
  int bookingsCount = 0;
  double revenue = 0;
  _ChaletAgg(this.name);
}
