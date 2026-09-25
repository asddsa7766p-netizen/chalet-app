/// نداء RPC (اسم الدالة + معاملاتها). الافتراضي هو supabase.rpc، ويُمرَّر
/// بديل في الاختبارات لفحص الأسماء المرسلة دون اتصال.
///
/// ملاحظة: نموذج "الليالي غير المتاحة" القديم (get_chalet_unavailable_dates)
/// أُزيل بعد أن صار الشاليه يقبل حجزاً صباحياً وآخر مسائياً بنفس اليوم؛ كل
/// التقاويم (الضيف، ورقة الحجز اليدوي، تقويم المالك) تقرأ توفر الفترات من
/// `ChaletSlotAvailability` بملف chalet_slot_availability.dart.
typedef RpcCaller = Future<dynamic> Function(
  String fn, {
  Map<String, dynamic>? params,
});
