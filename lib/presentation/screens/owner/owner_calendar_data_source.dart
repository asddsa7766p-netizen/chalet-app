import '../../../data/models/models.dart';
import '../../../data/services/chalet_slot_availability.dart';
import '../../../data/services/pricing_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/services.dart';
import 'owner_calendar_logic.dart';

/// شاليه كما يحتاجه تقويم المالك.
class CalendarChalet {
  final String id;
  final String name;
  final double pricePerNight;
  final int? maxGuests;
  final bool isApproved;

  const CalendarChalet({
    required this.id,
    required this.name,
    this.pricePerNight = 0,
    this.maxGuests,
    this.isApproved = true,
  });

  factory CalendarChalet.fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim() ?? '';
    return CalendarChalet(
      id: row['id'] as String,
      name: name.isEmpty ? 'بدون اسم' : name,
      pricePerNight: (row['price_per_night'] as num?)?.toDouble() ?? 0,
      maxGuests: (row['max_guests'] as num?)?.toInt(),
      isApproved: row['is_approved'] as bool? ?? true,
    );
  }
}

/// كل ما تحتاجه شاشة تقويم المالك من الخارج. الشاشة تعتمد على هذه الواجهة
/// فقط، فتُختبر ببيانات وهمية بلا اتصال بقاعدة البيانات.
abstract class OwnerCalendarDataSource {
  Future<List<CalendarChalet>> loadChalets();

  /// عدد طلبات pending القادمة لكل شاليه (لشارة الرقائق).
  Future<Map<String, int>> loadPendingCounts(List<String> chaletIds);

  /// حجوزات pending/confirmed التي تتقاطع مع [from] ≤ ليلة < [toExclusive].
  Future<List<BookingModel>> loadBookings(
    String chaletId,
    DateTime from,
    DateTime toExclusive,
  );

  /// الليالي المحجوبة (is_available=false) ضمن [from]..[to] شاملة.
  Future<Set<DateTime>> loadBlocked(String chaletId, DateTime from, DateTime to);

  /// توفر الفترتين (صباحية/مسائية) لكل يوم ضمن [from]..[to] شاملة، من
  /// نفس المصدر الذي يستخدمه تقويم الضيف (get_chalet_slot_availability).
  Future<Map<DateTime, ChaletDaySlot>> loadDaySlots(
      String chaletId, DateTime from, DateTime to);

  /// حجب الليالي: upsert بـ is_available=false في كتابة واحدة.
  Future<void> blockDates(String chaletId, List<DateTime> dates);

  /// إلغاء الحجب: تحديث نفس الصفوف إلى true (لا حذف صفوف).
  Future<void> unblockDates(String chaletId, List<DateTime> dates);

  /// سعر كل يوم بالشهر (سعر التقويم الفعلي، نفس مصدر شاشة الضيف).
  Future<Map<DateTime, DayPriceInfo>> loadMonthPricing(
    CalendarChalet chalet,
    int year,
    int month,
  );

  Future<int> loadUnreadCount();

  Future<void> confirmBooking(String bookingId);
  Future<void> rejectBooking(String bookingId);
  Future<void> cancelManualBooking(String bookingId);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// التنفيذ الحقيقي. المالك يقرأ bookings وavailability مباشرة (سياساته تسمح
/// بذلك)، ويكتب availability عبر INSERT/UPDATE فقط (لا DELETE).
class SupabaseOwnerCalendarDataSource implements OwnerCalendarDataSource {
  const SupabaseOwnerCalendarDataSource();

  static const _bookingColumns =
      'id, chalet_id, user_id, check_in, check_out, guests_count, total_price, '
      'status, payment_method, notes, created_at, stay_type, source, '
      'guest_name, guest_phone, profiles(full_name, phone, avatar_url), '
      'chalets($bookingPeriodColumns)';

  @override
  Future<List<CalendarChalet>> loadChalets() async {
    final ownerId = AuthService.instance.currentUser?.id;
    if (ownerId == null) return [];
    final rows = await ChaletService.instance.getOwnerChalets(ownerId);
    return rows.map(CalendarChalet.fromRow).toList();
  }

  @override
  Future<Map<String, int>> loadPendingCounts(List<String> chaletIds) async {
    if (chaletIds.isEmpty) return {};
    final rows = await supabase
        .from('bookings')
        .select('chalet_id')
        .eq('status', 'pending')
        .inFilter('chalet_id', chaletIds)
        .gte('check_out', _isoDate(DateTime.now()));
    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = row['chalet_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<BookingModel>> loadBookings(
    String chaletId,
    DateTime from,
    DateTime toExclusive,
  ) async {
    final rows = await supabase
        .from('bookings')
        .select(_bookingColumns)
        .eq('chalet_id', chaletId)
        .inFilter('status', ['pending', 'confirmed'])
        .lt('check_in', _isoDate(toExclusive))
        .gt('check_out', _isoDate(from))
        .order('check_in');
    return (rows as List)
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Set<DateTime>> loadBlocked(
    String chaletId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await supabase
        .from('availability')
        .select('date')
        .eq('chalet_id', chaletId)
        .eq('is_available', false)
        .gte('date', _isoDate(from))
        .lte('date', _isoDate(to));
    return {
      for (final row in rows as List)
        dateOnly(DateTime.parse(row['date'] as String)),
    };
  }

  @override
  Future<Map<DateTime, ChaletDaySlot>> loadDaySlots(
    String chaletId,
    DateTime from,
    DateTime to,
  ) =>
      ChaletSlotAvailability.load(chaletId, from: from, to: to);

  @override
  Future<void> blockDates(String chaletId, List<DateTime> dates) async {
    if (dates.isEmpty) return;
    await supabase.from('availability').upsert(
      [
        for (final d in dates)
          {
            'chalet_id': chaletId,
            'date': _isoDate(d),
            'is_available': false,
          },
      ],
      onConflict: 'chalet_id,date',
    );
  }

  @override
  Future<void> unblockDates(String chaletId, List<DateTime> dates) async {
    if (dates.isEmpty) return;
    // .select() لأن رفض RLS يعدّل صفر صفوف بلا خطأ، فيظهر "تم" كاذب.
    final rows = await supabase
        .from('availability')
        .update({'is_available': true})
        .eq('chalet_id', chaletId)
        .inFilter('date', [for (final d in dates) _isoDate(d)])
        .select('date');
    if (rows.isEmpty) {
      throw Exception('تعذر إلغاء الحجب: غير مصرح لك أو الأيام غير محجوبة.');
    }
  }

  @override
  Future<Map<DateTime, DayPriceInfo>> loadMonthPricing(
    CalendarChalet chalet,
    int year,
    int month,
  ) =>
      ChaletPricingService.instance.getMonthPricing(
        chaletId: chalet.id,
        year: year,
        month: month,
        defaultPrice: chalet.pricePerNight,
      );

  @override
  Future<int> loadUnreadCount() => NotificationService.instance.getUnreadCount();

  @override
  Future<void> confirmBooking(String bookingId) =>
      BookingService.instance.confirmIncomingBooking(bookingId);

  @override
  Future<void> rejectBooking(String bookingId) =>
      BookingService.instance.rejectIncomingBooking(bookingId);

  @override
  Future<void> cancelManualBooking(String bookingId) =>
      BookingService.instance.cancelExternalBooking(bookingId);
}
