### lib/presentation/screens/notifications/owner_notifications_screen.dart

- **الوظيفة:** شاشة إشعارات **المالك** (منفصلة تماماً عن [notifications_screen.dart](notifications_screen.md) الخاصة بالعميل) — قائمة إشعارات، تعليم مقروء (فردي/الكل)، وفتح شاشة حجوزات المالك عند الضغط على إشعار حجز.

- **الشرح التفصيلي:**
  - يستخدم **`NotificationService`** (بصيغة المفرد، من [notification_service.dart](../../../data/services/notification_service.md) — النسخة **غير** المحمية بـtry/catch داخلياً).
  - **`_onTapItem` (سطر 48-68) — تعليق طويل وصادق يشرح قيداً حقيقياً بالباك إند:** جدول `notifications` بالإنتاج **لا يحتوي** عمود `booking_id`/`related_id` (ولا الـ trigger الذي ينشئ إشعارات الحجز `handle_booking_notifications()` يملأ حقلاً كهذا)، ولا توجد أصلاً شاشة "تفاصيل حجز" منفصلة بالتطبيق (فقط قائمة `/owner-bookings`). القرار العملي الموثَّق: إشعارات الحجز (`booking`/`booking_confirmed`) تفتح قائمة حجوزات المالك الموجودة فعلاً، بدل محاولة فتح رابط عميق مستحيل حالياً أو ترك الإشعار بلا أي إجراء (كما كان الحال سابقاً — نفس التعليق يوثّق أن النسخة القديمة كانت تُعلِّم الإشعار كمقروء وتعيد التحميل **بدون أي تنقّل فعلي إطلاقاً**، فيبدو للمالك وكأن شيئاً لم يحدث).
  - `Directionality(textDirection: TextDirection.rtl)` مفروضة صراحة (سطر 85-86) — بغض النظر عن لغة التطبيق الفعلية، نفس النمط الملاحَظ بـ[forgot_password_screen.dart](../auth/forgot_password_screen.md).

- **الاعتماديات:** `notification_model.dart` (`NotificationModel` — النسخة المنفصلة، ليست نسخة models.dart)، `notification_service.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/owner-notifications`).

- **التعامل مع Supabase:** عبر `NotificationService` (المفرد): `getNotifications`, `markAsRead`, `markAllAsRead`.

- **نقاط القوة:**
  - تعليق استثنائي الصدق والوضوح حول قيد باك إند حقيقي (عمود مفقود بجدول `notifications`) وكيفية التعامل معه بأقل تدخل ممكن — مثال ممتاز على توثيق قرار هندسي مبني على قيد فعلي لا افتراض.
  - إصلاح حقيقي (موثَّق): الضغط على إشعار حجز كان بلا أي أثر فعلي سوى تعليمه كمقروء — أصبح ينقل فعلياً لمكان مفيد.
  - `mounted` مُتحقَّق بعناية قبل التنقّل بعد `await` (سطر 64).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 61، 97) — تجسيد فعلي لخطر مُوثَّق مسبقاً بمراجعة [notification_service.dart](../../../data/services/notification_service.md):** `NotificationService.instance.markAsRead(item.id)` (تعليم عنصر واحد) و`markAllAsRead()` (تعليم الكل) **بلا أي `try/catch` محلي هنا**، والخدمة نفسها لا تحتوي حماية داخلية أيضاً. لو فشل النداء (شبكة/RLS)، يُرمى استثناء غير مُلتقَط من داخل معالج `onTap`/`onPressed` — على الأرجح يلتقطه معالج الأخطاء العام لفلاتر (`FlutterError.onError`, المرتبط بـSentry أصلاً) بدل تعطّل التطبيق بالكامل، لكن **المالك لن يرى أي رسالة تشرح له لماذا لم يحدث شيء** عند الضغط.
  - 🟡 **بسيطة:** `Directionality(rtl)` صريحة كما هو مذكور — تناقض بصري إضافي لو فُعِّلت الإنجليزية مستقبلاً.

- **اقتراح الإصلاح:**
  - إضافة try/catch حول نداءات `markAsRead`/`markAllAsRead` هنا مباشرة (أو الأفضل: إصلاح [notification_service.dart](../../../data/services/notification_service.md) نفسها لتحتوي الحماية داخلياً، فيستفيد كل مستهلكيها دفعة واحدة)، مع رسالة SnackBar واضحة عند الفشل بنفس أسلوب [notifications_screen.dart](notifications_screen.md).
  - إزالة `Directionality(rtl)` الصريحة والاعتماد على اتجاه التطبيق العام.
