### lib/data/models/notification_model.dart

- **الوظيفة:** نموذج `NotificationModel` (نسخة مستقلة، ملف مخصص) لصف جدول `notifications` — يُستخدَم حصراً من طرف [notification_service.dart](../services/notification_service.md) (الخدمة بصيغة المفرد).

- **الشرح التفصيلي:** حقول: `id, userId, title, body (String غير قابل لـ null), type (String غير قابل لـ null), isRead, relatedId (String?), createdAt`. Factory واحدة: `fromMap(Map<String, dynamic> map)` — تقرأ `body`/`type` بـ `?? ''`/`?? 'general'` (fallback لنص فارغ/قيمة افتراضية بدل `null`)، و`relatedId` اختياري فعلاً.

- **الاعتماديات:** لا يستورد شيئاً. **من يستخدمه:** [notification_service.dart](../services/notification_service.md) حصراً (وبالتالي كل الشاشات التي تستخدم تلك الخدمة: `home_tab.dart`, `profile_screen.dart`, `owner_notifications_screen.dart`, وشاشات owner المتعددة لعدّاد غير المقروء).

- **التعامل مع Supabase:** لا اتصال مباشر؛ يمثّل صفوف `notifications`.

- **نقاط القوة:** حقل `relatedId` إضافي غير موجود بالنسخة الأخرى — لو مُستخدَم فعلياً (يحتاج تأكيد بمراجعة owner_notifications_screen.dart) فهو يسمح بالانتقال المباشر من إشعار لمصدره (حجز/شاليه معيّن)، ميزة مفيدة غير متوفرة بالنسخة الموازية.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة — هذا الملف هو نصف مشكلة ازدواجية `NotificationModel` الموثّقة بالتفصيل في [models.dart](models.md#الأخطاء-والمخاطر-المحتملة) و[notification_service.dart](../services/notification_service.md):** يوجد كلاس آخر بنفس الاسم الحرفي `NotificationModel` بملف `data/models/models.dart`، بحقول مختلفة جزئياً (`body`/`type` غير قابلين لـ null هنا مقابل قابلين هناك، لا يوجد `relatedId` هناك، `fromMap` هنا مقابل `fromJson` هناك). **لا يوجد خطأ تصريف فعلي** (لا ملف يستورد كلا المصدرين معاً حسب البحث الفعلي بالكود)، لكنها ازدواجية بيانات ومنطق كاملة لنفس المفهوم بالضبط.
  - 🟡 **بسيطة:** لا `copyWith`، لا `toJson` (غير مطلوبة فعلياً هنا بما أن الاستهلاك للقراءة فقط)، لا مشاكل null-safety حقيقية بهذا النموذج نفسه (الحقول المطلوبة `required` تتوافق مع أعمدة NOT NULL متوقعة بجدول notifications).

- **اقتراح الإصلاح:**
  - توحيد مع النسخة الأخرى بـ[models.dart](models.md): الأفضل نقل حقل `relatedId` (المفيد فعلياً) إلى نسخة `models.dart`، وحذف هذا الملف بالكامل بعد تحديث [notification_service.dart](../services/notification_service.md) (أو توحيده هو نفسه مع `NotificationsService`) ليستخدم النسخة الموحّدة الوحيدة.
