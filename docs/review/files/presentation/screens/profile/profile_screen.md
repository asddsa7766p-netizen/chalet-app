### lib/presentation/screens/profile/profile_screen.dart

- **⚠️ ملاحظة هيكلية جوهرية أولاً:** هذا الملف (964 سطر) يحتوي **أيضاً** (تماماً كنمط [favorites_screen.dart](../favorites/favorites_screen.md)) شاشة ثانية كاملة غير مترابطة منطقياً: كلاس **آخر باسم `NotificationsScreen`** (سطر 785-882) + `_NotifTile` (سطر 884-964) — بنفس الاسم الحرفي تماماً لكلاس **آخر منفصل تماماً** بملف [notifications/notifications_screen.dart](../notifications/notifications_screen.md). **الفرق الجوهري هنا: هذه النسخة (المُضمَّنة هنا) هي النسخة الفعلية المستخدمة فعلياً بالتطبيق (عبر `home_tab.dart` و`profile_screen.dart` نفسه)، بينما النسخة الأكثر اكتمالاً بالملف المنفصل غير مستخدمة إطلاقاً (كود ميت) — تحقّقت بالبحث الشامل بكامل `lib/`.**

---

#### القسم 1: `ProfileScreen` (سطر 19-780)

- **الوظيفة:** شاشة "حسابي" — بيانات المستخدم، إحصائيات (حجوزات مكتملة/مفضلة)، أزرار لوحة تحكم حسب الدور (أدمن/مالك/العودة لوضع مالك)، قوائم إعدادات، وتسجيل خروج.

- **الشرح التفصيلي:**
  - **إدارة الدور تفاعلياً عبر `profileProvider`**: `ref.watch(profileProvider)` + `ref.listen(profileProvider, (previous, next) => _onProfileChanged())` — تعليقات موثَّقة بعناية (معلَّمة "Problem #5" بالكود) تشرح أن `_hasApprovedChalet` سابقاً كانت تُحسب مرة واحدة فقط بـ`initState` ولا تتحدث لاحقاً طالما الشاشة باقية بالذاكرة ضمن `IndexedStack` بالتنقل السفلي — أُصلِح بالاستماع لتغيّرات `profileProvider` نفسها (بدون أي Timer/Polling).
  - **`isHost` محسوبة بفحص مزدوج**: `profile?.isOwner == true || profile?.role == 'owner'` — تتحقق من عمودين مختلفين معاً (`is_owner` boolean و`role` نصي). **يحتاج توضيح:** هل هذان العمودان يُفترض أن يبقيا متطابقين دائماً بالباك إند (فالفحص المزدوج مجرد حذر إضافي غير ضروري لكنه غير ضار)، أم أن هناك تاريخ عدم اتساق حقيقي بينهما دفع لهذا الفحص المزدوج تحديداً؟ لا يمكن الجزم من الكود وحده.
  - **`_becomeOwnerAgain`**: يعيد استخدام `becomeOwner()` الموجودة أصلاً (بدون RPC جديد) لمن كان مالكاً سابقاً وله شاليه معتمد، بدل إجباره على تعبئة نموذج شاليه جديد — تصميم عملي جيد.
  - **`_showEditProfile`**: Bottom sheet لتعديل الاسم/الهاتف، يستدعي `AuthService.updateProfile` ثم `Navigator.pop(ctx)` و`ref.invalidate(profileProvider)`.
  - **`_buildHeader`**: صورة رمزية (بحرف أول من `fullName`)، اسم، بريد، هاتف، شارتا دور (أدمن/مالك).

- **الاعتماديات:** `profile_provider.dart`, `models.dart`, `services.dart`, `favorites_provider.dart`, `notification_service.dart` (المفرد — **فقط لعدّاد `getUnreadCount`**)، `common_widgets.dart`, `language_bottom_sheet.dart`, و**استيراد مباشر لأربع شاشات إعدادات** (`about_app_screen.dart`, `privacy_security_screen.dart`, `settings_screen.dart`, `help_support_screen.dart` — عبر `show` محدَّد لكل واحدة، ولاحظ [flutter_analyze_after_fix.log](../../../../../flutter_analyze_after_fix.log) القديم كان يُسجِّل استيرادين منهما (`about_app_screen`, `privacy_security_screen`) كـ`unused_import` — **يحتاج تأكيد** هل ما زالا غير مُستخدَمين فعلياً بالنسخة الحالية أم أن الاستخدام الوحيد لهما فعلياً من داخل `settings_screen.dart` نفسها لا من هنا مباشرة). **من يستخدمه:** [main_screen.dart](../home/main_screen.md) (تبويب "حسابي").

- **التعامل مع Supabase:** `BookingService.getMyBookings` (لحساب المكتملة)، `ChaletService.getOwnerChalets` (فحص شاليه معتمد)، `AuthService.updateProfile`/`becomeOwner`/`signOut`، `NotificationService.getUnreadCount` (المفرد).

- **نقاط القوة:**
  - توثيق ممتاز ومباشر لمشكلة حقيقية (`IndexedStack` + بيانات دور لا تتحدث) وحلها التفاعلي عبر Riverpod بدل Polling.
  - إعادة استخدام واعية لدوال موجودة (`becomeOwner`, `getOwnerChalets`) بدل إضافة RPC/جداول جديدة لميزات صغيرة.
  - عدّاد شارة الإشعارات فعلي الآن (ليس نصاً ثابتاً كما يوثّق تعليق قديم بالكود).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 624) — نفس عطل `.characters.first` على نص فارغ، مُصلَح مرتين بمكانين آخرين بنفس المشروع، لكن غير مُصلَح هنا رغم كونه على صورة المستخدم الرمزية بأعلى شاشة حسابه الخاصة:**
    ```dart
    child: Text((profile?.fullName ?? 'م').characters.first, ...)
    ```
    هذا **بالضبط** العطل الذي وثَّق كل من [chalet_detail_screen.dart](../chalet/chalet_detail_screen.md) (`_ReviewItem`) و[favorites_screen.dart](../favorites/favorites_screen.md) (`_ReviewTile`) أنه يرمي `StateError` فعلياً لو كانت السلسلة النصية **فارغة** (وليس `null` — الفحص `??` لا يلتقط الحالة الفارغة). هنا **لا يوجد** فحص `trim().isNotEmpty` المُطبَّق بالمكانين الآخرين. لو انتهى `profiles.full_name` لمستخدم معيّن كنص فارغ (سيناريو معقول: فشل صامت لخطوة `upsert` الثانوية بـ`AuthService.signUp` الموثَّق بمراجعة [services.dart](../../../data/services/services.md) عند تفعيل تأكيد البريد)، ستنهار شاشة "حسابي" بالكامل لذلك المستخدم بمجرد فتحها.
  - 🟠 **متوسطة (سطر 766-773، `_showEditProfile` زر "حفظ التغييرات") — فجوة `mounted` حقيقية:**
    ```dart
    onPressed: () async {
      await AuthService.instance.updateProfile(fullName: nameCtrl.text, phone: phoneCtrl.text);
      Navigator.pop(ctx);          // ⚠️ بدون فحص mounted بعد await
      ref.invalidate(profileProvider);
    },
    ```
    لا يوجد أي فحص `mounted` بعد `await AuthService.instance.updateProfile(...)` قبل استخدام `Navigator.pop(ctx)` أو `ref.invalidate(...)`. لو أُغلقت الشاشة (أو تبويب "حسابي" حتى لو محفوظاً بالخلفية عبر IndexedStack، الحالة نظرياً نادرة لكن ممكنة لو حدث تسجيل خروج متزامن مثلاً) أثناء انتظار هذا النداء، قد يُستخدَم `ctx`/`ref` على عنصر غير صالح.
  - 🟠 **متوسطة — تأكيد إضافي لملاحظة [notifications_screen.md](../notifications/notifications_screen.md): الكلاس المُستخدَم فعلياً (`NotificationsScreen` هنا بالقسم 2 أدناه) يحتوي بالضبط نفس عطل "فشل التحميل يُعرض كقائمة فارغة مضلِّلة" الذي وُثِّق ووُصلِح فقط بالنسخة غير المُستخدَمة بالملف المنفصل.**
  - 🟡 **بسيطة:** `_loadStats()` يستدعي `BookingService.getMyBookings()` (كل حجوزات المستخدم، بلا حدود) فقط لحساب عدد "المكتملة" — نفس البيانات بالضبط تُجلب مستقلاً ومرة أخرى بشاشة "حجوزاتي" ([favorites_screen.dart](../favorites/favorites_screen.md) قسم `MyBookingsScreen`) بلا أي تنسيق/تخزين مؤقت مشترك بين الشاشتين.

---

#### القسم 2: `NotificationsScreen` المُضمَّنة هنا (سطر 785-882) + `_NotifTile` (سطر 884-964)

- **الوظيفة:** **هذه هي شاشة الإشعارات الفعلية التي يراها العميل** (عبر جرس [home_tab.dart](../../home/home_tab.md) وقائمة "التنبيهات" بالقسم 1 أعلاه) — أبسط بكثير من الشاشة المنفصلة غير المستخدمة بمجلد `notifications/`.
- **الشرح التفصيلي:** `_load()` بلا تمييز خطأ/فارغ (`catch (_) { if (mounted) setState(() => _loading = false); }` فقط — لا حقل `_loadError` إطلاقاً). عند تعليم إشعار كمقروء، **يُعاد بناء `NotificationModel` يدوياً حقلاً بحقل** (سطر 866-874) بدل `copyWith` — لأن [`NotificationModel`](../../../data/models/models.md) (نسخة models.dart) لا تملك `copyWith` أصلاً (نفس النقص الملاحَظ عموماً بنماذج المشروع، راجع [models.md](../../../data/models/models.md) لملاحظة `UserProfile.copyWith` المكسورة).
- **الاعتماديات:** `services.dart` (`NotificationsService`). **من يستخدمه (مؤكَّد):** [home_tab.dart](../../home/home_tab.md) (جرس الإشعارات، عبر `Navigator.push` مباشر لا GoRouter)، و`ProfileScreen` نفسها (قائمة "التنبيهات").
- **نقاط القوة:** بسيطة ومباشرة، تعليم كمقروء يُحدِّث الحالة محلياً فوراً (تفاؤلي) بدل إعادة تحميل كامل للقائمة.
- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 810-812) — نفس "فشل التحميل يظهر كقائمة فارغة" الذي وُثِّق كإصلاح بالنسخة الأخرى غير المستخدمة:** لا فرق بصري بين "لا توجد إشعارات فعلاً" و"فشل تحميلها" — يعرض المستخدم نفس رسالة "لا يوجد إشعارات" بالحالتين، بلا أي زر إعادة محاولة.
  - 🟡 **بسيطة:** إعادة بناء `NotificationModel` يدوياً حقلاً بحقل (بدل `copyWith`) — هش لأي إضافة حقل مستقبلي للنموذج (يجب تذكّر تحديث هذا المكان يدوياً أيضاً).

- **اقتراح الإصلاح (للقسمين معاً):**
  - **القرار الأهم مرة أخرى (مرتبط بملاحظة notifications_screen.md):** توحيد نسخة واحدة فقط من "شاشة إشعارات العميل" — إما نقل التحسينات (فلاتر، تمييز خطأ/فارغ) لهذه النسخة المُستخدَمة فعلياً، أو استبدال هذه النسخة بالكامل باستيراد النسخة الأكثر اكتمالاً من الملف المنفصل، مع تحديث كل نقاط الاستيراد (`home_tab.dart` وهنا) لمصدر واحد فقط.
  - إصلاح صورة المستخدم الرمزية بنفس حماية `trim().isNotEmpty` المُطبَّقة بالمكانين الآخرين.
  - إضافة `if (!mounted) return;` بزر "حفظ التغييرات" في `_showEditProfile` قبل `Navigator.pop(ctx)`/`ref.invalidate`.
  - إضافة `copyWith` لـ`NotificationModel` بـmodels.dart لتفادي إعادة البناء اليدوي الهش.
