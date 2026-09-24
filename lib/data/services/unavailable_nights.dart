import 'package:supabase_flutter/supabase_flutter.dart';

/// نداء RPC (اسم الدالة + معاملاتها). الافتراضي هو supabase.rpc، ويُمرَّر
/// بديل في الاختبارات لفحص الأسماء المرسلة دون اتصال.
typedef RpcCaller = Future<dynamic> Function(
  String fn, {
  Map<String, dynamic>? params,
});

/// المصدر الموحّد للأيام غير المتاحة (محجوزة أو محجوبة) لشاليه: دالة القاعدة
/// get_chalet_unavailable_dates. تعيد ليالي فقط (من الوصول حتى ما قبل
/// المغادرة) بلا أي بيانات عن الضيف، وهي متاحة للزائر والمسجّل معاً، بعكس
/// جدول الحجوزات الذي لا يقرأه الضيف إلا لحجوزاته.
///
/// أقصى نافذة تقبلها الدالة 400 يوم وإلا ترجع فارغة، لذلك النافذة تُقصّ هنا.
class UnavailableNights {
  UnavailableNights._();

  static const rpcName = 'get_chalet_unavailable_dates';
  static const maxWindowDays = 400;

  /// نافذة التقويم عند الضيف: من اليوم لسنة (مدى التقويم 365) + يوم احتياطي
  /// لأن حدّ p_to غير مؤكد كونه شاملاً أم لا؛ اليوم الزائد لا يضرّ.
  static const guestWindowDays = 366;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// المعاملات كما تتوقعها الدالة بالضبط.
  static Map<String, dynamic> rpcParams(
    String chaletId,
    DateTime from,
    DateTime to,
  ) =>
      {
        'p_chalet_id': chaletId,
        'p_from': _date(from),
        'p_to': _date(to),
      };

  /// الجدول المُرجَع بعمود واحد اسمه night (تاريخ). أي صف بلا night يُهمل.
  static Set<DateTime> parse(dynamic rows) {
    final nights = <DateTime>{};
    if (rows is! List) return nights;
    for (final row in rows) {
      final raw = row is Map ? row['night'] : null;
      if (raw is! String) continue;
      final d = DateTime.tryParse(raw);
      if (d == null) continue;
      nights.add(DateTime(d.year, d.month, d.day));
    }
    return nights;
  }

  /// يقرأ الليالي غير المتاحة لنافذة [from]..[to]. الأخطاء تُرمى كما هي
  /// ليترجمها المستدعي.
  static Future<Set<DateTime>> load(
    String chaletId, {
    required DateTime from,
    DateTime? to,
    RpcCaller? rpc,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    var end = to ?? DateTime(start.year, start.month, start.day + guestWindowDays);
    final limit = DateTime(start.year, start.month, start.day + maxWindowDays);
    if (end.isAfter(limit)) end = limit;

    final call = rpc ??
        (String fn, {Map<String, dynamic>? params}) =>
            Supabase.instance.client.rpc(fn, params: params);
    final rows = await call(rpcName, params: rpcParams(chaletId, start, end));
    return parse(rows);
  }
}

/// هل في ليالي [from] (شاملة) حتى [to] (غير شاملة) ليلة غير متاحة؟
bool rangeHasUnavailableNight(
  DateTime? from,
  DateTime? to,
  Set<DateTime> unavailable,
) {
  if (from == null || to == null) return false;
  final end = DateTime(to.year, to.month, to.day);
  for (var d = DateTime(from.year, from.month, from.day);
      d.isBefore(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    if (unavailable.contains(d)) return true;
  }
  return false;
}

/// قاعدة تعطيل أيام تقويم اختيار التواريخ (مشتركة بين شاشة الضيف وورقة
/// الحجز اليدوي): الليلة غير المتاحة لا تُختار كوصول، ويجوز اختيارها كمغادرة
/// إذا كانت ليالي الفترة قبلها خالية، لأن الـ trigger يفحص الليالي من الوصول
/// حتى ما قبل المغادرة فقط. [selectingEnd] = الوصول محدد ويُنتظر اليوم
/// التالي (مغادرة أو وصول جديد أبكر).
bool isDayDisabledForStay(
  DateTime day, {
  required Set<DateTime> unavailable,
  DateTime? checkIn,
  required bool selectingEnd,
}) {
  final d = DateTime(day.year, day.month, day.day);
  if (selectingEnd && checkIn != null && d.isAfter(checkIn)) {
    return rangeHasUnavailableNight(checkIn, d, unavailable);
  }
  return unavailable.contains(d);
}
