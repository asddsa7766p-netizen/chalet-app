import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../services/pricing_service.dart';
import 'models.dart';

/// الحجز في مكان = يوم واحد + فترة واحدة (لا مبيت ولا مدى تاريخين).
///
/// الفترات هي أنواع الإقامة المفعّلة للشاليه (chalet_stay_types حيث
/// is_enabled)؛ والشاليه بلا أي نوع مفعّل له فترة واحدة "يوم كامل"
/// (stay_type = 'default'). الحجز يُرسل دائماً check_in = اليوم المختار
/// و check_out = اليوم التالي، فتحدد دالة القاعدة booking_slots الفترات
/// المشغولة من stay_type.
class BookingPeriod {
  final String stayType;
  final String label;
  final IconData icon;

  /// "10:00 ص - 9:00 م"، أو null لفترة "يوم كامل" الافتراضية بلا أوقات.
  final String? timeLabel;

  const BookingPeriod({
    required this.stayType,
    required this.label,
    required this.icon,
    this.timeLabel,
  });

  /// فترة الشاليه الذي لم يعرّف أي نوع إقامة.
  static const fullDayDefault = BookingPeriod(
    stayType: 'default',
    label: 'يوم كامل',
    icon: Icons.calendar_month_rounded,
  );

  factory BookingPeriod.fromConfig(ChaletStayTypeConfig c) => BookingPeriod(
        stayType: c.type.dbValue,
        label: c.type.label,
        icon: c.type.icon,
        timeLabel: periodTimeRange(
          c.checkinTime.hour,
          c.checkinTime.minute,
          c.checkoutTime.hour,
          c.checkoutTime.minute,
        ),
      );

  /// فترات الحجز لشاليه من أنواع إقامته المفعّلة.
  static List<BookingPeriod> forChalet(List<ChaletStayTypeConfig> enabled) =>
      enabled.isEmpty
          ? const [fullDayDefault]
          : [for (final c in enabled) BookingPeriod.fromConfig(c)];
}

/// اسم الفترة لقيمة stay_type المخزّنة بالحجز.
String stayTypeLabel(String stayType) {
  switch (stayType) {
    case 'morning':
      return ChaletStayType.morning.label;
    case 'evening':
      return ChaletStayType.evening.label;
    case 'full_day_morning':
      return ChaletStayType.fullDayMorning.label;
    case 'full_day_evening':
      return ChaletStayType.fullDayEvening.label;
    default:
      return BookingPeriod.fullDayDefault.label;
  }
}

/// "9:00 م" — ساعة 12 مع ص/م.
String formatClock(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'ص' : 'م';
  return '$h12:${minute.toString().padLeft(2, '0')} $suffix';
}

String periodTimeRange(int startH, int startM, int endH, int endM) =>
    '${formatClock(startH, startM)} - ${formatClock(endH, endM)}';

/// من نصوص وقت Postgres ("HH:MM:SS")؛ null إن نقص أحدهما أو لم يُقرأ.
String? periodTimeRangeFromDb(String? start, String? end) {
  (int, int)? parse(String? raw) {
    final parts = (raw ?? '').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  final s = parse(start);
  final e = parse(end);
  if (s == null || e == null) return null;
  return periodTimeRange(s.$1, s.$2, e.$1, e.$2);
}

/// عرض الحجز كيوم + فترة، مع بقاء الحجوزات القديمة الممتدة لعدة أيام صحيحة.
extension BookingPeriodDisplay on BookingModel {
  /// حجز قديم من قبل نموذج اليوم الواحد (أكثر من يوم).
  bool get isMultiDay => nightsCount > 1;

  /// آخر يوم محجوز فعلاً (check_out غير شامل).
  DateTime get lastBookedDay {
    final d = dayOnly(checkOut);
    return DateTime(d.year, d.month, d.day - 1);
  }

  String get periodLabel => stayTypeLabel(stayType);

  /// وقت الفترة المضبوط بإعدادات الشاليه (إن جُلب مع الحجز).
  String? get periodTimeLabel => periodTimeRangeFromDb(periodStart, periodEnd);

  /// "الخميس 14 مارس 2030"، أو "من 14 مارس إلى 16 مارس 2030 (3 أيام)"
  /// للحجز القديم الممتد.
  String get dateLabel {
    if (!isMultiDay) return arabicDayLabel(checkIn);
    final last = lastBookedDay;
    final sameYear = checkIn.year == last.year;
    return 'من ${arabicShortDate(checkIn, withYear: !sameYear)} '
        'إلى ${arabicShortDate(last, withYear: true)} (${_daysCount(nightsCount)})';
  }

  static String _daysCount(int n) {
    if (n == 2) return 'يومان';
    if (n >= 3 && n <= 10) return '$n أيام';
    return '$n يوماً';
  }

  /// "إقامة صباحية · 10:00 ص - 9:00 م"
  String get periodWithTime {
    final t = periodTimeLabel;
    return t == null ? periodLabel : '$periodLabel · $t';
  }
}
