/// عدد الليالي (الأيام التقويمية) بين تاريخين، بتجاهل الوقت.
///
/// الفرق بين تاريخين محليين عبر تغيير التوقيت الصيفي (DST) يكون 23 أو 25
/// ساعة، فـ `checkOut.difference(checkIn).inDays` يعطي أحياناً ليلة أقل
/// (مثال: 25→27 مارس 2027). الحساب بتواريخ UTC يعطي العدد الفعلي دائماً.
/// سالب إن كان [checkOut] قبل [checkIn].
int nightsBetween(DateTime checkIn, DateTime checkOut) =>
    DateTime.utc(checkOut.year, checkOut.month, checkOut.day)
        .difference(DateTime.utc(checkIn.year, checkIn.month, checkIn.day))
        .inDays;

/// التاريخ بلا وقت.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// اليوم التالي (بالتقويم، لا بإضافة 24 ساعة — آمن مع التوقيت الصيفي).
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

const List<String> arabicMonthNames = [
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

const List<String> arabicWeekdayNames = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String arabicWeekday(DateTime d) => arabicWeekdayNames[d.weekday - 1];

/// "الخميس 14 مارس 2030" (السنة اختيارية).
String arabicDayLabel(DateTime d, {bool withYear = true}) =>
    '${arabicWeekday(d)} ${d.day} ${arabicMonthNames[d.month - 1]}'
    '${withYear ? ' ${d.year}' : ''}';

/// "14 مارس" أو "14 مارس 2030".
String arabicShortDate(DateTime d, {bool withYear = false}) =>
    '${d.day} ${arabicMonthNames[d.month - 1]}${withYear ? ' ${d.year}' : ''}';
