import 'package:supabase_flutter/supabase_flutter.dart';

import 'rpc_caller.dart' show RpcCaller;

/// توفر يوم واحد بشاليه: هل الفترة الصباحية محجوزة، هل الفترة المسائية
/// محجوزة، وهل اليوم محجوب بالكامل من المالك (بغض النظر عن الحجوزات).
///
/// بعد أن صار الشاليه يقبل حجزاً صباحياً وآخر مسائياً بنفس اليوم، لم يعد
/// "اليوم محجوز/غير محجوز" كافياً — كل فترة تُتابَع لحالها.
class ChaletDaySlot {
  final bool morningBooked;
  final bool eveningBooked;
  final bool blocked;

  const ChaletDaySlot({
    required this.morningBooked,
    required this.eveningBooked,
    required this.blocked,
  });

  /// محجوز بالكامل (الفترتان مشغولتان) أو محجوب من المالك: لا فائدة من
  /// عرضه "جزئياً" — لا يوجد نوع إقامة يقدر يستخدمه.
  bool get isFullyUnavailable => blocked || (morningBooked && eveningBooked);

  /// جزئي: فترة واحدة فقط محجوزة والثانية حرة، واليوم غير محجوب.
  bool get isPartiallyBooked => !blocked && (morningBooked != eveningBooked);
}

/// المصدر الموحّد لتوفر الفترات (صباحية/مسائية) لكل يوم بشاليه: دالة القاعدة
/// get_chalet_slot_availability. يحل محل نموذج "الليلة الواحدة" القديم
/// (get_chalet_unavailable_dates) بشاشة حجز الضيف بعد تغيير الباك اند
/// للسماح بحجز صباحي وآخر مسائي بنفس اليوم.
///
/// أقصى نافذة تقبلها الدالة 400 يوم وإلا ترجع فارغة، لذلك النافذة تُقصّ هنا.
class ChaletSlotAvailability {
  ChaletSlotAvailability._();

  static const rpcName = 'get_chalet_slot_availability';
  static const maxWindowDays = 400;

  /// نافذة تقويم الضيف: من اليوم لسنة (365) + يوم إضافي لأن قاعدة
  /// full_day_evening تحتاج معرفة صباح اليوم التالي لآخر يوم ظاهر بالتقويم
  /// + يوم احتياطي لأن حدّ p_to غير مؤكد كونه شاملاً أم لا.
  static const guestWindowDays = 367;

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

  /// الجدول المُرجَع: day, morning_booked, evening_booked, blocked. أي صف
  /// بلا day صالح يُهمل.
  static Map<DateTime, ChaletDaySlot> parse(dynamic rows) {
    final result = <DateTime, ChaletDaySlot>{};
    if (rows is! List) return result;
    for (final row in rows) {
      if (row is! Map) continue;
      final raw = row['day'];
      if (raw is! String) continue;
      final d = DateTime.tryParse(raw);
      if (d == null) continue;
      result[DateTime(d.year, d.month, d.day)] = ChaletDaySlot(
        morningBooked: row['morning_booked'] as bool? ?? false,
        eveningBooked: row['evening_booked'] as bool? ?? false,
        blocked: row['blocked'] as bool? ?? false,
      );
    }
    return result;
  }

  /// يقرأ توفر الفترات لنافذة [from]..[to]. الأخطاء تُرمى كما هي ليترجمها
  /// المستدعي.
  static Future<Map<DateTime, ChaletDaySlot>> load(
    String chaletId, {
    required DateTime from,
    DateTime? to,
    RpcCaller? rpc,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    var end =
        to ?? DateTime(start.year, start.month, start.day + guestWindowDays);
    final limit =
        DateTime(start.year, start.month, start.day + maxWindowDays);
    if (end.isAfter(limit)) end = limit;

    final call = rpc ??
        (String fn, {Map<String, dynamic>? params}) =>
            Supabase.instance.client.rpc(fn, params: params);
    final rows = await call(rpcName, params: rpcParams(chaletId, start, end));
    return parse(rows);
  }
}

/// توفر يوم واحد [day] لنوع إقامة [stayType]، مطابقة بالضبط لدالة القاعدة
/// booking_slots (المسؤولة عن حجز الفترات فعلياً):
/// - morning: لا حجز صباحي ولا حجب على D
/// - evening: لا حجز مسائي ولا حجب على D
/// - full_day_morning: لا حجز صباحي ولا مسائي ولا حجب على D
/// - full_day_evening: لا حجز مسائي على D، ولا حجز صباحي على D+1، ولا حجب
///   على D (الإقامة تمتد من مساء D لصباح D+1)
/// - أي قيمة أخرى (بما فيها 'default'، السلوك القديم): لا حجز صباحي ولا
///   مسائي ولا حجب على D — الفترتان يجب أن تكونا حرّتين معاً.
bool isDayAvailableForStayType(
  DateTime day, {
  required String stayType,
  required Map<DateTime, ChaletDaySlot> slots,
}) {
  final d = DateTime(day.year, day.month, day.day);
  final slot = slots[d];
  if (slot?.blocked ?? false) return false;

  final morningBooked = slot?.morningBooked ?? false;
  final eveningBooked = slot?.eveningBooked ?? false;

  switch (stayType) {
    case 'morning':
      return !morningBooked;
    case 'evening':
      return !eveningBooked;
    case 'full_day_morning':
      return !morningBooked && !eveningBooked;
    case 'full_day_evening':
      final next = slots[DateTime(d.year, d.month, d.day + 1)];
      final nextMorningBooked = next?.morningBooked ?? false;
      return !eveningBooked && !nextMorningBooked;
    default:
      return !morningBooked && !eveningBooked;
  }
}

/// هل في يوم من [from] (شاملاً) حتى [to] (غير شامل) يوم غير متاح لنوع
/// الإقامة [stayType]؟ المغادرة غير شاملة لأن الـ trigger يفحص الأيام من
/// الوصول حتى ما قبل المغادرة.
bool rangeHasUnavailableDayForStayType(
  DateTime? from,
  DateTime? to, {
  required String stayType,
  required Map<DateTime, ChaletDaySlot> slots,
}) {
  if (from == null || to == null) return false;
  final end = DateTime(to.year, to.month, to.day);
  for (var d = DateTime(from.year, from.month, from.day);
      d.isBefore(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    if (!isDayAvailableForStayType(d, stayType: stayType, slots: slots)) {
      return true;
    }
  }
  return false;
}

/// قاعدة تعطيل أيام تقويم اختيار التواريخ لنوع إقامة معيّن (مشتركة بين شاشة
/// الضيف وورقة الحجز اليدوي): اليوم غير المتاح لا يُختار كوصول، ويجوز
/// اختياره كمغادرة إذا كانت أيام الفترة قبله متاحة. [selectingEnd] = الوصول
/// محدد ويُنتظر اليوم التالي (مغادرة أو وصول جديد أبكر).
bool isDayDisabledForStaySlot(
  DateTime day, {
  required Map<DateTime, ChaletDaySlot> slots,
  required String stayType,
  DateTime? checkIn,
  required bool selectingEnd,
}) {
  final d = DateTime(day.year, day.month, day.day);
  if (selectingEnd && checkIn != null && d.isAfter(checkIn)) {
    return rangeHasUnavailableDayForStayType(checkIn, d,
        stayType: stayType, slots: slots);
  }
  return !isDayAvailableForStayType(d, stayType: stayType, slots: slots);
}
