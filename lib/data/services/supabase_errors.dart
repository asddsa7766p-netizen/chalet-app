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

/// رفض السيرفر لحجز على شاليه محذوف أو غير معتمد (trigger
/// enforce_bookable_chalet، ERRCODE P0001).
const chaletNotBookableMessage = 'هذا الشاليه لم يعد متاحاً للحجز';

/// رفض السيرفر لحجز أو إضافة شاليه من حساب الإدارة (trigger
/// block_admin_customer_actions على bookings وchalets، ERRCODE P0001).
const adminCannotBookMessage = 'حساب الإدارة لا يمكنه الحجز أو إضافة شاليهات';

/// رفض السيرفر لحجز التطبيق من مالك الشاليه نفسه (enforce_bookable_chalet،
/// ERRCODE P0001): يستخدم الحجز اليدوي.
const ownChaletBookingMessage =
    'لا يمكنك حجز شاليهك من التطبيق، استخدم الحجز اليدوي';

/// رفض السيرفر لحجز التطبيق من trigger validate_app_booking (ERRCODE P0001).
const guestsNotAllowedMessage = 'عدد الضيوف غير مسموح لهذا الشاليه';
const periodNotOfferedMessage = 'هذه الفترة غير متاحة في هذا الشاليه';
const periodPriceUnavailableMessage = 'سعر هذه الفترة غير متوفر حالياً';
const bookingTooFarAheadMessage = 'لا يمكن الحجز لأكثر من سنة مقدماً';
const periodAlreadyStartedMessage =
    'هذه الفترة بدأت أو انتهت، اختر يوماً أو فترة أخرى';
const bookingNotesTooLongMessage = 'الملاحظات طويلة جداً (الحد 1000 حرف)';
const pendingBookingsLimitMessage =
    'لديك 3 طلبات حجز بانتظار رد المالك. انتظر الرد أو ألغِ أحدها قبل طلب جديد';

/// رسائل رفض الحجز الموجّهة للمستخدم من triggers الحجوزات، تُعرض كما هي.
const bookingServerMessages = [
  ownChaletBookingMessage,
  chaletNotBookableMessage,
  adminCannotBookMessage,
  singleDayOnlyMessage,
  guestsNotAllowedMessage,
  periodNotOfferedMessage,
  periodPriceUnavailableMessage,
  bookingTooFarAheadMessage,
  periodAlreadyStartedMessage,
  bookingNotesTooLongMessage,
  pendingBookingsLimitMessage,
];

/// رسالة الخادم الموجّهة للمستخدم داخل [error] (مترجماً أو خاماً)، أو null.
String? bookingServerMessageIn(Object? error) {
  final msg = error.toString();
  for (final m in bookingServerMessages) {
    if (msg.contains(m)) return m;
  }
  return null;
}

/// تعارض فترة محجوزة (exclusion/overlap بالقاعدة).
const periodTakenMessage = 'هذه الفترة محجوزة، جرّب فترة أو يوماً آخر';

/// رفض الشاليه بلا سبب (admin_reject_chalet، ERRCODE P0001).
const rejectReasonRequiredMessage =
    'اكتب سبب الرفض حتى يعرف المالك ما يجب تعديله';

/// إعادة إرسال شاليه ليس مرفوضاً أو ليس للمالك (resubmit_chalet، P0001).
const nothingToResubmitMessage =
    'لا يوجد شاليه مرفوض بهذا الرقم لإعادة إرساله';

/// الشاليه محذوف أو غير موجود (admin_approve_chalet/admin_reject_chalet).
const chaletNotFoundMessage = 'الشاليه غير موجود';

/// رسائل دوال اعتماد الشاليهات الموجّهة للمستخدم، تُعرض كما هي.
const chaletReviewServerMessages = [
  rejectReasonRequiredMessage,
  nothingToResubmitMessage,
  chaletNotFoundMessage,
];

/// أوقات فترات الشاليه، تُضمَّن داخل chalets(...) باستعلامات الحجوزات حتى
/// يُعرض كل حجز بتاريخه واسم فترته ووقتها (BookingModel.periodStart/End).
const bookingPeriodColumns =
    'chalet_stay_types(stay_type, checkin_time, checkout_time)';

/// حساب محظور (is_active = false): الخادم يرفض به الحجز وإضافة الشاليه
/// والتقييم، وGoTrue يرفض الدخول وتجديد الجلسة (user_banned).
const accountSuspendedMessage = 'تم إيقاف هذا الحساب. تواصل مع الدعم.';

/// هل الخطأ رفضٌ لحساب محظور؟ يطابق خطأ GoTrue (`user_banned`) ورسالة
/// الخادم العربية، حتى بعد تغليفها بـ Exception من طبقة الخدمات.
bool isAccountSuspendedError(Object? error) {
  if (error is AuthException &&
      (error.code == 'user_banned' ||
          error.message.toLowerCase().contains('user is banned'))) {
    return true;
  }
  return error.toString().contains(accountSuspendedMessage);
}

/// تحديث لم يعدّل أي صف: رفض صامت من RLS أو أن الحجز لم يعد موجوداً.
const bookingNotUpdatedMessage =
    'تعذر تحديث الحجز: غير مصرح لك به أو لم يعد موجوداً.';

/// ترجمة خطأ Supabase لرسالة عربية للمستخدم — للخدمات خارج هذا الملف
/// (مثل ChaletPricingService) حتى تعرض نفس الرسائل.
String translateSupabaseError(dynamic error) => _translateSupabaseError(error);

String _translateSupabaseError(dynamic error) {
  final msg = error.toString();
  final normalized = msg.toLowerCase();

  // حساب محظور: يسبق كل الفروع (رفض الخادم قد يحمل أيضاً "permission denied").
  if (isAccountSuspendedError(error)) {
    return accountSuspendedMessage;
  }

  // trigger enforce_single_day_booking (ERRCODE 22023): رسالة السيرفر نفسها
  // موجّهة للمستخدم، فتُعرض كما هي. تسبق كل الفروع الأخرى.
  if (msg.contains(singleDayOnlyMessage)) {
    return singleDayOnlyMessage;
  }

  // trigger enforce_bookable_chalet: شاليه محذوف أو غير معتمد، أو المالك
  // يحجز شاليهه. رسائل موجّهة للمستخدم فتُعرض كما هي، قبل أي فرع قد يطابق.
  if (msg.contains(chaletNotBookableMessage)) {
    return chaletNotBookableMessage;
  }
  if (msg.contains(ownChaletBookingMessage)) {
    return ownChaletBookingMessage;
  }

  // trigger block_admin_customer_actions: حساب الإدارة لا يحجز ولا يضيف
  // شاليهات. رسالة موجّهة للمستخدم فتُعرض كما هي.
  if (msg.contains(adminCannotBookMessage)) {
    return adminCannotBookMessage;
  }

  // دوال اعتماد الشاليهات ورفضها وإعادة إرسالها: رسائلها موجّهة للمستخدم.
  for (final m in chaletReviewServerMessages) {
    if (msg.contains(m)) return m;
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
