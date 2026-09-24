import '../../../data/models/manual_booking.dart';
import '../../../data/models/models.dart';

/// منطق تقويم المالك الخالص (بلا واجهة ولا قاعدة بيانات) حتى يُختبر مباشرة.
///
/// قواعد القاعدة التي يحترمها:
/// - الحجز يشغل الليالي من check_in حتى check_out غير شاملة، وpending أو
///   confirmed فقط يشغل التقويم. يوم المغادرة يظهر متاحاً.
/// - الحجب صف availability بـ is_available=false لكل ليلة.

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

  /// الحجز الذي يشغل ليلة هذا اليوم (إن وُجد).
  final BookingModel? booking;

  /// حجز تنتهي إقامته صباح هذا اليوم (معلومة فقط، اليوم نفسه متاح).
  final BookingModel? departing;

  /// اليوم محجوب (صف availability بـ false).
  final bool blocked;
  final bool isPast;
  final bool isToday;

  const CalendarDay({
    required this.date,
    required this.booking,
    required this.departing,
    required this.blocked,
    required this.isPast,
    required this.isToday,
  });

  bool get isBooked => booking != null;

  /// حجز وحجب معاً على نفس الليلة (لا يمنعه الـ trigger): يغلب الحجز لوناً
  /// وتظهر شارة منع فوقه.
  bool get hasBlockAndBooking => booking != null && blocked;

  CalendarDayKind get kind {
    final b = booking;
    if (b != null) return kindOfBooking(b);
    return blocked ? CalendarDayKind.blocked : CalendarDayKind.available;
  }

  /// رقم هذه الليلة داخل الحجز (تبدأ من 1).
  int? get nightNumber {
    final b = booking;
    if (b == null) return null;
    return DateTime.utc(date.year, date.month, date.day)
            .difference(DateTime.utc(b.checkIn.year, b.checkIn.month, b.checkIn.day))
            .inDays +
        1;
  }
}

/// بيانات الأشهر المحمَّلة لشاليه واحد.
class CalendarData {
  final Map<String, BookingModel> _bookings = {};
  final Set<DateTime> _blocked = {};

  Iterable<BookingModel> get bookings => _bookings.values;
  Set<DateTime> get blocked => _blocked;

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
  }

  BookingModel? bookingOnNight(DateTime day) {
    final d = dateOnly(day);
    for (final b in _bookings.values) {
      if (!d.isBefore(dateOnly(b.checkIn)) && d.isBefore(dateOnly(b.checkOut))) {
        return b;
      }
    }
    return null;
  }

  BookingModel? bookingDepartingOn(DateTime day) {
    final d = dateOnly(day);
    for (final b in _bookings.values) {
      if (dateOnly(b.checkOut) == d) return b;
    }
    return null;
  }

  bool isBlocked(DateTime day) => _blocked.contains(dateOnly(day));

  CalendarDay dayInfo(DateTime day, {required DateTime today}) {
    final d = dateOnly(day);
    final t = dateOnly(today);
    return CalendarDay(
      date: d,
      booking: bookingOnNight(d),
      departing: bookingDepartingOn(d),
      blocked: isBlocked(d),
      isPast: d.isBefore(t),
      isToday: d == t,
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

/// جمل تعدّد الليالي بالعربية الصحيحة: ليلة / ليلتان / N ليالٍ.
String nightsLabel(int n) {
  if (n == 1) return 'ليلة واحدة';
  if (n == 2) return 'ليلتان';
  if (n >= 3 && n <= 10) return '$n ليالٍ';
  return '$n ليلة';
}

String daysLabel(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n >= 3 && n <= 10) return '$n أيام';
  return '$n يوماً';
}
