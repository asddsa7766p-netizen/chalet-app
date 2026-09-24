### lib/presentation/screens/owner/manual_booking_actions.dart

- **الوظيفة:** منطق التحقق من إمكانية إلغاء حجز يدوي/خارجي (تم إدخاله مباشرة من طرف المالك) وتنفيذ الإلغاء مع تأكيد المستخدم.

- **الشرح التفصيلي:**
  - `canCancelManualBooking(BookingModel booking, {DateTime? now})`: دالة منطقية خالصة (pure) تُحدِّد إن كان يمكن إلغاء الحجز بمقارنة تاريخ الوصول بـ`now` (أو `DateTime.now()` افتراضياً) وحالة الحجز الحالية. الحقن الاختياري لـ`now` يسمح باختبارها بسهولة بتواريخ ثابتة دون الاعتماد على ساعة النظام الفعلية.
  - `confirmAndCancelManualBooking(context, booking, {cancel})`: يعرض `AlertDialog` تأكيد أولاً، وعند الموافقة يستدعي `BookingService.instance.cancelExternalBooking` (أو دالة `cancel` البديلة للاختبار) — وهي **دالة مبنية على RPC** (`cancel_external_booking`، حسب سياق الـ backend المُعطى)، وليست تحديثاً مباشراً على الجدول.
  - يلتقط `ScaffoldMessenger.of(context)` قبل `await` (نفس النمط الآمن الموجود بـ[owner_booking_actions.dart](owner_booking_actions.md)).

- **الاعتماديات:** `models.dart` (`BookingModel`), `services.dart` (`BookingService`). **من يستخدمه:** على الأرجح [manual_booking_sheet.dart](manual_booking_sheet.md) و/أو [owner_bookings_screen.dart](owner_bookings_screen.md) (تُؤكَّد عند مراجعتها).

- **التعامل مع Supabase:** عبر `BookingService.instance.cancelExternalBooking`، أي عبر **RPC خادمي** (`cancel_external_booking` حسب وصف المستخدم) — وليس تحديث جدول مباشر، لذا فهو **أقل عرضة** لمشكلة "نجاح كاذب بسبب رفض RLS صامت" التي وُثِّقت بـ[owner_booking_actions.dart](owner_booking_actions.md)/[services.dart](../../../data/services/services.md): دالة RPC خادمية من المفترض أن ترمي خطأ SQL صريحاً عند الرفض بدل الفشل الصامت لتحديث مفلتَر بـRLS.

- **نقاط القوة:**
  - فصل منطق "هل يمكن الإلغاء؟" (دالة pure قابلة للاختبار بمعزل عن الواجهة) عن منطق التنفيذ — تصميم نظيف.
  - الاعتماد على RPC خادمي للإلغاء بدل تحديث مباشر، متّسق مع توجيه الـ backend المُعطى (منطق الحجوزات يجب أن يُنفَّذ خادمياً).
  - حقن `now`/`cancel` للاختبار، والتقاط `ScaffoldMessenger` قبل `await`.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة:** لم يُعثر على فحص `mounted` صريح بعد `await showDialog`/`await cancel(...)` قبل استخدام أي حالة محلية أخرى غير `messenger` الملتقَط مسبقاً؛ نظراً لأن `messenger` كافٍ لعرض النتيجة هنا، الأثر العملي ضئيل، لكن يُنصح بالتحقق عند أي تعديل مستقبلي يضيف استخدام `context` مباشرة بعد الـ`await`.
  - 🟡 **بسيطة (توثيقية):** `canCancelManualBooking` **غير معرَّضة** لعائلة أخطاء DST/التوقيت الصيفي الموثَّقة بملفات أخرى (مثل `_nights` بـ[booking_screen.dart](../../booking/booking_screen.md))، لأنها تقارن تواريخ زمنياً (`isBefore`/`isAfter` على الأرجح) دون حساب فرق أيام (`difference().inDays`) — يُذكَر هنا للتوثيق الإيجابي فقط، وليس كخطأ.

- **اقتراح الإصلاح:** لا إصلاح جوهري مطلوب؛ يُنصح فقط بإضافة فحص `mounted` كإجراء وقائي إن أُضيف مستقبلاً أي استخدام لـ`context` بعد `await` غير الملتقَط مسبقاً.
