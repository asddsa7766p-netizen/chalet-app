### lib/presentation/screens/owner/owner_chalets_screen.dart

- **الوظيفة:** شاشة "شاليهاتي" — شبكة بطاقات كل شاليهات المالك (حالة/سعر/موقع)، مع أزرار تعديل وإدارة أسعار لكل بطاقة، وزر إضافة شاليه جديد.

- **الشرح التفصيلي:**
  - **تعليق ترويسة الملف يوثّق إعادة كتابة كاملة لعطلين حقيقيين خطيرين بالنسخة السابقة**: (1) كانت الشاشة تعرض **شاليهين ثابتين مكتوبين يدوياً بالكود** بغض النظر عن شاليهات المالك الحقيقية بقاعدة البيانات — أي أن شاشة "شاليهاتي" **لم تكن تعمل فعلياً إطلاقاً** كشاشة إدارة حقيقية؛ (2) عطل layout حقيقي (نفس فئة "BoxConstraints forces an infinite width" المتكررة بالمشروع) كان يُسقِط الشاشة بالكامل عند العرض.
  - `_load()`: `Future.wait([ChaletService.getOwnerChalets(ownerId), NotificationService.getUnreadCount()])` — تحميل متوازٍ لقائمة الشاليهات وعدد الإشعارات غير المقروءة معاً (لعرضها بشارة `OwnerBottomNav`).
  - `_goToEdit`/`_goToPricing`/`_goToAddChalet`: تفتح [owner_edit_chalet_screen.dart](owner_edit_chalet_screen.md)/[chalet_pricing_screen.dart](chalet_pricing_screen.md)/[owner_add_chalet_screen.dart](owner_add_chalet_screen.md) (عبر `Navigator.push`)، وتُعيد تحميل القائمة (`_load()`) بعد العودة من أي منها — تعليق يوثّح أن هذا أيضاً إصلاح (النسخة القديمة لم تكن تُحدِّث القائمة أبداً، لكن هذا لم يكن ملحوظاً لأنها كانت ثابتة أصلاً).
  - `_ChaletCard`: يعرض حالة الشاليه بوضوح (بانتظار الموافقة / متاح / غير متاح) حسب `is_approved`+`is_available` معاً — متّسق تماماً مع منطق [owner_edit_chalet_screen.dart](owner_edit_chalet_screen.md).
  - `OwnerBottomNav` مُضاف بتعليق يشرح السبب: الشاشة تُفتح عبر `context.go()` (لا `push`) من لوحة التحكم، فلا يوجد سجل تنقّل سابق يعرض سهم رجوع تلقائياً — بدون هذا الشريط كانت الشاشة "بلا مخرج" مرئي.

- **الاعتماديات:** `services.dart` (`ChaletService`, `AuthService`)، `notification_service.dart` (`NotificationService`)، `owner_add_chalet_screen.dart`, `owner_edit_chalet_screen.dart`, `chalet_pricing_screen.dart`, `owner_bottom_nav.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/owner-chalets`).

- **التعامل مع Supabase:** `ChaletService.getOwnerChalets(ownerId)` (`chalets` مفلترة بـ`owner_id`، أعمدة محددة)، `NotificationService.getUnreadCount()`.

- **نقاط القوة:**
  - توثيق صادق وواضح لإصلاح عطل جوهري جداً (شاشة كانت تعرض بيانات وهمية ثابتة بدل بيانات المالك الحقيقية) — شفافية قيّمة حول تاريخ حقيقي للشاشة.
  - إعادة تحميل القائمة بعد أي إجراء (إضافة/تعديل/تسعير) بدل الاعتماد على حالة قديمة قد لا تعكس التغييرات.
  - عرض حالة واضح وثلاثي (بانتظار موافقة/متاح/غير متاح) يطابق منطق الموافقة الفعلي بالباك إند.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 64-68، `_load`) — اقتران غير متناسب: فشل عدّاد إشعارات ثانوي يُخفي قائمة شاليهات المالك بأكملها:**
    ```dart
    final results = await Future.wait([
      ChaletService.instance.getOwnerChalets(ownerId),
      NotificationService.instance.getUnreadCount(),
    ]);
    ```
    `Future.wait` يفشل بالكامل لو **أي** Future بداخله فشل. بما أن `NotificationService.getUnreadCount()` (النسخة المفرد، راجع [notification_service.md](../../../data/services/notification_service.md)) **بلا أي حماية داخلية من الأخطاء**، فإن أي خطأ شبكة عابر بهذا الاستدعاء الثانوي (مجرد رقم لشارة إشعارات) سيُظهر للمالك رسالة "تعذر تحميل الشاليهات، حاول مرة أخرى" **رغم أن استعلام الشاليهات نفسه قد يكون نجح فعلياً أو كان سينجح لو انتظرناه بمعزل**. تأثير غير متناسب: ميزة ثانوية (عدّاد شارة) تُخفي المحتوى الأساسي للشاشة (شاليهات المالك، وربما مصدر دخله) بالكامل.
  - 🟡 **بسيطة:** استخدام `.withOpacity()` المهجورة (`deprecated_member_use`) بعدة مواضع بـ`_ChaletCard` — نفس الملاحظة العامة بمراجعة [app_theme.dart](../../../core/theme/app_theme.md).
  - 🟡 **بسيطة:** كل التنقلات (`_goToEdit`/`_goToPricing`/`_goToAddChalet`) عبر `Navigator.push` وليس GoRouter — نفس الملاحظة العامة المتكررة بالمشروع.

- **اقتراح الإصلاح:**
  - **يوجد إصلاح جاهز لنفس المشكلة بالضبط بنفس المشروع:** راجع `_init()` بـ[owner_calendar_screen.dart](owner_calendar_screen.md) (دفعة 11) — يحمّل الشاليهات أولاً ثم يستدعي كل طلب ثانوي بـ`.catchError` مستقل يُرجع قيمة افتراضية آمنة، فلا يتأثر عرض المحتوى الأساسي بفشل طلب ثانوي. الأسلوب أدناه مطابق لنفس الفكرة:
  - فصل تحميل عدّاد الإشعارات عن التحميل الأساسي — إما نداء منفصل غير حاجب (لا يدخل بـ`Future.wait` الحرج) مع `try/catch` خاص به يتجاهل الفشل بصمت مدروس (بنفس نمط `home_tab.dart`/`profile_screen.dart` لنفس العدّاد)، أو استخدام `Future.wait` مع معامل يسمح بفشل جزئي (تفكيك النتيجتين ومعالجة كل منهما بشكل مستقل بدل `try/catch` واحد شامل):
    ```dart
    final chaletsFuture = ChaletService.instance.getOwnerChalets(ownerId);
    final unreadFuture = NotificationService.instance.getUnreadCount()
        .catchError((_) => 0); // فشل العدّاد لا يوقف تحميل الشاليهات
    final chalets = await chaletsFuture; // يُترك ليرمي فعلياً لو فشل هو تحديداً
    final unread = await unreadFuture;
    ```
