import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/manual_booking.dart';
import '../../../../data/models/models.dart';
import '../../../../data/services/chalet_slot_availability.dart';

/// منطق تقويم المالك الخالص (بلا واجهة ولا قاعدة بيانات) حتى يُختبر مباشرة.
///
/// قواعد القاعدة التي يحترمها:
/// - الحجز يوم واحد + فترة (check_out = اليوم التالي)، ويشغل الأيام من
///   check_in حتى check_out غير شاملة (الحجوزات القديمة الممتدة أكثر من يوم
///   تبقى صحيحة)، وpending أو confirmed فقط يشغل التقويم. قد يحمل اليوم
///   حجزاً صباحياً وآخر مسائياً.
/// - الحجب صف availability بـ is_available=false لكل يوم.
/// - توفر الفترتين (صباحية/مسائية) لكل يوم من get_chalet_slot_availability:
///   يوم فترة واحدة منه محجوزة يُعلَّم "محجوز جزئياً".

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// حالة الليلة كما تُلوَّن بالتقويم.
enum CalendarDayKind { available, appConfirmed, manual, pending, blocked }

/// حالة الحجز على الليلة: pending أولاً، ثم اليدوي، وإلا مؤكد من التطبيق.
CalendarDayKind kindOfBooking(BookingModel b) {
  if (b.status == BookingStatus.pending) return CalendarDayKind.pending;
  if (b.isManual) return CalendarDayKind.manual;
  return CalendarDayKind.appConfirmed;
}

/// هل يشغل هذا الحجز ليالي التقويم؟ (الملغى والمرفوض والمكتمل لا).
bool occupiesCalendar(BookingModel b) =>
    b.status == BookingStatus.pending || b.status == BookingStatus.confirmed;

/// معلومات يوم واحد جاهزة للعرض.
class CalendarDay {
  final DateTime date;

  /// الحجز الأساسي بهذا اليوم (يحدد اللون)، أي أول [bookings].
  final BookingModel? booking;

  /// كل حجوزات اليوم (حجز صباحي وآخر مسائي بنفس اليوم ممكن)، مرتبة
  /// حسب الفترة: الصباحية أولاً.
  final List<BookingModel> bookings;

  /// حجز "يوم كامل - مسائي" من اليوم السابق يمتد لصباح هذا اليوم (معلومة
  /// فقط؛ باقي اليوم يظهر بحالته الفعلية).
  final BookingModel? departing;

  /// اليوم محجوب (صف availability بـ false).
  final bool blocked;
  final bool isPast;
  final bool isToday;

  /// توفر الفترتين بهذا اليوم (null إن لم يُحمَّل أو لا حجز عليه).
  final ChaletDaySlot? slot;

  CalendarDay({
    required this.date,
    required this.booking,
    required this.departing,
    required this.blocked,
    required this.isPast,
    required this.isToday,
    this.slot,
    List<BookingModel>? bookings,
  }) : bookings = bookings ?? (booking == null ? const [] : [booking]);

  bool get isBooked => booking != null;

  /// فترة واحدة فقط محجوزة (صباحية أو مسائية) والأخرى حرة.
  bool get isPartiallyBooked => slot?.isPartiallyBooked ?? false;

  /// وصف الحجز الجزئي للعرض ولقارئ الشاشة، أو null إن لم يكن جزئياً.
  String? get partialLabel {
    final s = slot;
    if (s == null || !s.isPartiallyBooked) return null;
    return s.morningBooked
        ? 'الفترة الصباحية محجوزة، والمسائية متاحة'
        : 'الفترة المسائية محجوزة، والصباحية متاحة';
  }

  /// حجز وحجب معاً على نفس الليلة (لا يمنعه الـ trigger): يغلب الحجز لوناً
  /// وتظهر شارة منع فوقه.
  bool get hasBlockAndBooking => booking != null && blocked;

  CalendarDayKind get kind {
    final b = booking;
    if (b != null) return kindOfBooking(b);
    return blocked ? CalendarDayKind.blocked : CalendarDayKind.available;
  }

  /// رقم هذا اليوم داخل الحجز (تبدأ من 1) — يهم الحجوزات القديمة الممتدة.
  int? get nightNumber {
    final b = booking;
    if (b == null) return null;
    return nightsBetween(b.checkIn, date) + 1;
  }
}

/// ترتيب الفترات داخل اليوم الواحد (للعرض).
const _periodOrder = {
  'morning': 0,
  'full_day_morning': 1,
  'default': 2,
  'evening': 3,
  'full_day_evening': 4,
};

int _byPeriod(BookingModel a, BookingModel b) =>
    (_periodOrder[a.stayType] ?? 2).compareTo(_periodOrder[b.stayType] ?? 2);

/// بيانات الأشهر المحمَّلة لشاليه واحد.
class CalendarData {
  final Map<String, BookingModel> _bookings = {};
  final Set<DateTime> _blocked = {};
  final Map<DateTime, ChaletDaySlot> _slots = {};

  Iterable<BookingModel> get bookings => _bookings.values;
  Set<DateTime> get blocked => _blocked;

  /// يستبدل توفر الفترات ضمن [from]..[to] شاملة بالنتيجة الجديدة.
  void replaceSlots(
      DateTime from, DateTime to, Map<DateTime, ChaletDaySlot> fresh) {
    _slots.removeWhere((d, _) => !d.isBefore(from) && !d.isAfter(to));
    fresh.forEach((d, s) => _slots[dateOnly(d)] = s);
  }

  void addBookings(Iterable<BookingModel> list) {
    for (final b in list) {
      if (occupiesCalendar(b)) _bookings[b.id] = b;
    }
  }

  /// يستبدل الحجب ضمن [from]..[to] شاملة بالنتيجة الجديدة.
  void replaceBlocked(DateTime from, DateTime to, Set<DateTime> fresh) {
    _blocked.removeWhere((d) => !d.isBefore(from) && !d.isAfter(to));
    _blocked.addAll(fresh.map(dateOnly));
  }

  void clear() {
    _bookings.clear();
    _blocked.clear();
    _slots.clear();
  }

  /// كل حجوزات اليوم [day] (من check_in حتى ما قبل check_out)، الصباحية أولاً.
  List<BookingModel> bookingsOnDay(DateTime day) {
    final d = dateOnly(day);
    return [
      for (final b in _bookings.values)
        if (!d.isBefore(dateOnly(b.checkIn)) &&
            d.isBefore(dateOnly(b.checkOut)))
          b,
    ]..sort(_byPeriod);
  }

  /// الحجز الأساسي باليوم (أول حجوزاته)، أو null.
  BookingModel? bookingOnNight(DateTime day) {
    final list = bookingsOnDay(day);
    return list.isEmpty ? null : list.first;
  }

  /// حجز "يوم كامل - مسائي" ينتهي صباح [day]. بقية أنواع الإقامة تنتهي
  /// بنفس يومها (booking_slots) فلا "مغادرة" لها باليوم التالي.
  BookingModel? bookingDepartingOn(DateTime day) {
    final d = dateOnly(day);
    for (final b in _bookings.values) {
      if (b.stayType == 'full_day_evening' && dateOnly(b.checkOut) == d) {
        return b;
      }
    }
    return null;
  }

  bool isBlocked(DateTime day) => _blocked.contains(dateOnly(day));

  CalendarDay dayInfo(DateTime day, {required DateTime today}) {
    final d = dateOnly(day);
    final t = dateOnly(today);
    final onDay = bookingsOnDay(d);
    return CalendarDay(
      date: d,
      booking: onDay.isEmpty ? null : onDay.first,
      bookings: onDay,
      departing: bookingDepartingOn(d),
      blocked: isBlocked(d),
      isPast: d.isBefore(t),
      isToday: d == t,
      slot: _slots[d],
    );
  }
}

/// ما سيحدث عند حجب نطاق (نهايته شاملة: "من 10 إلى 12" = ليالي 10 و11 و12).
class BlockPlan {
  /// الليالي التي ستُكتب فعلاً (حرّة، غير محجوبة، غير ماضية).
  final List<DateTime> dates;
  final int skippedBooked;
  final int alreadyBlocked;
  final int skippedPast;

  const BlockPlan({
    required this.dates,
    required this.skippedBooked,
    required this.alreadyBlocked,
    required this.skippedPast,
  });

  int get skipped => skippedBooked + alreadyBlocked + skippedPast;
}

/// ما سيحدث عند إلغاء حجب نطاق.
class UnblockPlan {
  /// الليالي المحجوبة في النطاق (غير الماضية) التي سيُلغى حجبها.
  final List<DateTime> dates;
  final int skippedNotBlocked;
  final int skippedPast;

  const UnblockPlan({
    required this.dates,
    required this.skippedNotBlocked,
    required this.skippedPast,
  });
}

/// أيام النطاق من [a] إلى [b] شاملة (بأي ترتيب).
List<DateTime> daysInclusive(DateTime a, DateTime b) {
  var start = dateOnly(a);
  var end = dateOnly(b);
  if (end.isBefore(start)) {
    final t = start;
    start = end;
    end = t;
  }
  final out = <DateTime>[];
  for (var d = start; !d.isAfter(end); d = addDays(d, 1)) {
    out.add(d);
  }
  return out;
}

BlockPlan planBlock(
  DateTime a,
  DateTime b,
  CalendarData data, {
  required DateTime today,
}) {
  final t = dateOnly(today);
  final dates = <DateTime>[];
  var booked = 0, already = 0, past = 0;
  for (final d in daysInclusive(a, b)) {
    if (d.isBefore(t)) {
      past++;
    } else if (data.bookingOnNight(d) != null) {
      booked++;
    } else if (data.isBlocked(d)) {
      already++;
    } else {
      dates.add(d);
    }
  }
  return BlockPlan(
    dates: dates,
    skippedBooked: booked,
    alreadyBlocked: already,
    skippedPast: past,
  );
}

UnblockPlan planUnblock(
  DateTime a,
  DateTime b,
  CalendarData data, {
  required DateTime today,
}) {
  final t = dateOnly(today);
  final dates = <DateTime>[];
  var notBlocked = 0, past = 0;
  for (final d in daysInclusive(a, b)) {
    if (d.isBefore(t)) {
      past++;
    } else if (data.isBlocked(d)) {
      dates.add(d);
    } else {
      notBlocked++;
    }
  }
  return UnblockPlan(
    dates: dates,
    skippedNotBlocked: notBlocked,
    skippedPast: past,
  );
}

/// نوع إجراء وضع تحديد الأيام: يحدده أول يوم يُنقر (محجوب → إلغاء حجب،
/// وإلا حجب).
enum RangeAction { block, unblock }

const _monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _weekdayNames = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String monthName(int month) => _monthNames[month - 1];

String weekdayName(DateTime d) => _weekdayNames[d.weekday - 1];

/// "الثلاثاء 14 أكتوبر"
String fullDayLabel(DateTime d) => '${weekdayName(d)} ${d.day} ${monthName(d.month)}';

/// "14 أكتوبر"
String shortDayLabel(DateTime d) => '${d.day} ${monthName(d.month)}';

String kindLabel(CalendarDayKind k) {
  switch (k) {
    case CalendarDayKind.available:
      return 'متاح';
    case CalendarDayKind.appConfirmed:
      return 'محجوز من التطبيق';
    case CalendarDayKind.manual:
      return 'محجوز يدوياً';
    case CalendarDayKind.pending:
      return 'بانتظار التأكيد';
    case CalendarDayKind.blocked:
      return 'محجوب';
  }
}

String daysLabel(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n >= 3 && n <= 10) return '$n أيام';
  return '$n يوماً';
}
