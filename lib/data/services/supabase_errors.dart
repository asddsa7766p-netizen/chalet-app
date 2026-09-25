part of 'services.dart';

// ============================================
// SUPABASE CLIENT
// ============================================
final supabase = Supabase.instance.client;

/// ترجمة رسائل أخطاء قاعدة البيانات (PostgreSQL/Supabase) لرسائل واضحة ومفهومة للمستخدم
/// رسالة اليوم الذي يرفضه الـ trigger لأنه غير متاح للحجز (محجوب). محايدة
/// عمداً: لا تذكر أن المالك حجبه، وتصلح للضيف وللمالك في الحجز اليدوي.
const unavailableDatesMessage =
    'هذا اليوم غير متاح للحجز. اختر يوماً آخر.';

/// رفض السيرفر لأي حجز ليس يوماً واحداً (enforce_single_day_booking).
const singleDayOnlyMessage = 'الحجز يكون ليوم واحد وفترة واحدة فقط';

/// تعارض فترة محجوزة (exclusion/overlap بالقاعدة).
const periodTakenMessage = 'هذه الفترة محجوزة، جرّب فترة أو يوماً آخر';

/// أوقات فترات الشاليه، تُضمَّن داخل chalets(...) باستعلامات الحجوزات حتى
/// يُعرض كل حجز بتاريخه واسم فترته ووقتها (BookingModel.periodStart/End).
const bookingPeriodColumns =
    'chalet_stay_types(stay_type, checkin_time, checkout_time)';

/// تحديث لم يعدّل أي صف: رفض صامت من RLS أو أن الحجز لم يعد موجوداً.
const bookingNotUpdatedMessage =
    'تعذر تحديث الحجز: غير مصرح لك به أو لم يعد موجوداً.';

/// ترجمة خطأ Supabase لرسالة عربية للمستخدم — للخدمات خارج هذا الملف
/// (مثل ChaletPricingService) حتى تعرض نفس الرسائل.
String translateSupabaseError(dynamic error) => _translateSupabaseError(error);

String _translateSupabaseError(dynamic error) {
  final msg = error.toString();
  final normalized = msg.toLowerCase();

  // trigger enforce_single_day_booking (ERRCODE 22023): رسالة السيرفر نفسها
  // موجّهة للمستخدم، فتُعرض كما هي. تسبق كل الفروع الأخرى.
  if (msg.contains(singleDayOnlyMessage)) {
    return singleDayOnlyMessage;
  }

  // يجب أن يسبق فرع "booking conflict" العام أدناه: رسالة الـ trigger
  // "Booking conflict: availability unavailable" تحتويه، وكانت ستُعرض
  // "هذا التاريخ محجوز" بينما اليوم محجوب لا محجوز.
  if (normalized.contains('availability unavailable')) {
    return unavailableDatesMessage;
  }

  // ✅ إصلاح: تأكدت فعلياً بتشغيل التطبيق أن تعارض حجز حقيقي (نفس التواريخ
  // على نفس الشاليه) يرمي PostgrestException برمز 23P01 ورسالة تقنية خام
  // ("conflicting key value violates exclusion constraint
  // \"bookings_no_overlap\"") — لم تكن هذه الحالة معروفة هنا، فكانت تمر
  // من الشرط أدناه (PostgrestException) وتُعرض كما هي حرفياً للمستخدم
  // (رسالة تقنية غير مفهومة)، بدل رسالة "هذا التاريخ محجوز" الجاهزة أصلاً.
  if (normalized.contains('booking conflict: overlapping dates') ||
      normalized.contains('overlapping dates') ||
      normalized.contains('booking conflict') ||
      normalized.contains('bookings_no_overlap') ||
      normalized.contains('exclusion constraint') ||
      normalized.contains('23p01') ||
      normalized.contains('23505')) {
    return periodTakenMessage;
  }

  if (normalized.contains('غير مسموح تعديل هذه الحقول من طرفك') ||
      normalized.contains('not allowed to update these fields')) {
    return 'حدث خطأ، حاول مرة أخرى';
  }

  if (normalized.contains('صلاحيات أدمن مطلوبة') ||
      normalized.contains('admin permissions required') ||
      normalized.contains('permission denied')) {
    return 'حدث خطأ، غير مصرح بهذا الإجراء';
  }

  if (normalized.contains('لا يمكن إنشاء دفعة لحجز لا يخصك') ||
      normalized
          .contains('cannot create payment for booking not owned by you')) {
    return 'حدث خطأ في معالجة الدفع';
  }

  if (error is PostgrestException) {
    return error.message;
  }
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return msg;
}
