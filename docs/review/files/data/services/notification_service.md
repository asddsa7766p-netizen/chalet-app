### lib/data/services/notification_service.dart

- **الوظيفة:** خدمة إشعارات (`NotificationService`، **بصيغة المفرد**): جلب الإشعارات، عدد غير المقروء، تعليم واحد/الكل كمقروء.

- **الشرح التفصيلي:** `getNotifications()`, `getUnreadCount()`, `markAsRead(id)`, `markAllAsRead()` — كلها استعلامات مباشرة بسيطة على جدول `notifications` مفلترة بـ `user_id` (ومُتحقَّق من `currentUser?.id != null` أولاً بكل دالة). `getNotifications` يستخدم `NotificationModel.fromMap(...)`.

- **الاعتماديات:** يستورد `supabase_flutter` و`../models/notification_model.dart`. **من يستخدمه (مؤكَّد بالبحث الفعلي بكل `lib/presentation`):**
  - `getUnreadCount()`: [home_tab.dart](../../presentation/screens/home/home_tab.md)، [profile_screen.dart](../../presentation/screens/profile/profile_screen.md) (مرتين)، [owner_bookings_screen.dart](../../presentation/screens/owner/owner_bookings_screen.md)، [owner_chalets_screen.dart](../../presentation/screens/owner/owner_chalets_screen.md)، [owner_dashboard_screen.dart](../../presentation/screens/owner/owner_dashboard_screen.md) (مرتين)، [owner_calendar_data_source.dart](../../presentation/screens/owner/owner_calendar_data_source.md) — **أكثر من نصف شاشات التطبيق الرئيسية تعتمد على هذه الدالة تحديداً لشارة عدد الإشعارات.**
  - `getNotifications`/`markAsRead`/`markAllAsRead`: [owner_notifications_screen.dart](../../presentation/screens/notifications/owner_notifications_screen.md) حصراً.

- **التعامل مع Supabase:** قراءة/تحديث مباشر لجدول `notifications` (نفس الجدول تماماً الذي تتعامل معه `NotificationsService` بـ[services.dart](services.md)).

- **نقاط القوة:** بساطة ووضوح الكود نفسه — لا تعقيد غير ضروري بمنطق بسيط كهذا.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة — ازدواجية كاملة مع `NotificationsService` (بصيغة الجمع) بملف [services.dart](services.md):** يوجد بالتطبيق **كلاسان منفصلان بالكامل** لنفس الغرض تماماً (قراءة/تحديث جدول `notifications`)، باسمين شبه متطابقين يختلفان بحرف "s" فقط: `NotificationService` (هذا الملف) و`NotificationsService` (بـ services.dart). **تأكدت فعلياً بالبحث بالكود** أن هذه ليست ازدواجية نظرية فقط بل **مُستخدَمة فعلياً بشكل متزامن ومتداخل**: [profile_screen.dart](../../presentation/screens/profile/profile_screen.md) بالتحديد يستخدم **كلا الكلاسين معاً بنفس الملف** — `NotificationService.instance.getUnreadCount()` بسطر 63/343، **و** `NotificationsService.instance.getNotifications()`/`markAllAsRead()` بسطر 804/825/864.
  - 🟠 **متوسطة (نفس هذا الملف بالكامل، الأسطر 11-55):** **لا يوجد أي `try/catch` بأي دالة من الأربع** — بخلاف `NotificationsService` الشقيقة بـ services.dart التي تلتقط كل خطأ وتترجمه عبر `_translateSupabaseError`. بما أن `getUnreadCount()` من هذا الملف تحديداً تُستدعى من **7 نقاط استهلاك مختلفة** (أهمها `home_tab.dart` — الشاشة الرئيسية الأولى التي يراها كل مستخدم)، فإن أي خطأ شبكة عابر أثناء جلب "عدد الإشعارات غير المقروءة" (استدعاء صغير هامشي الأهمية نسبياً) قد يرمي استثناءً غير مُترجَم قد يكسر تحميل شاشة كاملة (الرئيسية أو لوحة المالك) لسبب لا علاقة له فعلياً بمحتوى الشاشة الأساسي. **الأثر الفعلي يعتمد على معالجة كل نقطة استهلاك لهذا الاستدعاء على حدة** (هل ملفوف بـ try/catch خاص بالشاشة نفسها؟) — سيُتحقَّق بدقة عند مراجعة كل شاشة مستهلكة بالدفعات القادمة، وستُحدَّث هذه الملاحظة إن لزم.
  - 🟡 **بسيطة:** استخدام `NotificationModel.fromMap` هنا مقابل `NotificationModel.fromJson` بالكلاس الشقيق — **يحتاج تأكيد** بمراجعة [notification_model.dart](../../models/notification_model.md): هل هما دالتا factory مختلفتان فعلاً بنفس الكلاس (فيبقى الأمر مجرد ازدواجية تسمية غير ضارة وظيفياً)، أم أن إحداهما فعلياً alias للأخرى؟

- **اقتراح الإصلاح:**
  - **الأولوية:** توحيد الكلاسين بكلاس واحد فقط (الأفضل الإبقاء على النسخة المحمية بـ try/catch من `services.dart` مع إضافة `getUnreadCount()` إليها)، وتحديث كل نقاط الاستهلاك التسع لتستخدم الكلاس الموحّد الجديد، ثم حذف هذا الملف بالكامل. هذا يزيل الحاجة لصيانة نفس المنطق بمكانين، ويوحّد مستوى معالجة الأخطاء.
  - لحين التوحيد: على الأقل إضافة try/catch لكل دالة هنا بنفس أسلوب `_translateSupabaseError`، خصوصاً `getUnreadCount()` نظراً لانتشار استخدامها الواسع.
