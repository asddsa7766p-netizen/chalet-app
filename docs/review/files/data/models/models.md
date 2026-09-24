### lib/data/models/models.dart

- **الوظيفة:** ملف نماذج متعدد (315 سطر): `BookingModel` (+ `BookingStatus` enum)، `UserProfile`، `ReviewModel`، `NotificationModel` (⚠️ راجع تنبيه التكرار أدناه) — ثاني أهم ملف نماذج بالمشروع بعد `chalet_model.dart`.

- **الشرح التفصيلي:**

  **`_extractChaletImage`** (سطر 6-16): دالة مساعدة خاصة تستخرج أول صورة من خريطة شاليه مُجوينة (join)، آمنة تماماً ضد `null`/قائمة فارغة.

  **`BookingStatus`** (enum، سطر 21): `pending, confirmed, cancelled, rejected, completed` + `arabicLabel` — **يطابق تماماً** قيم `status` الموصوفة/المُستخدَمة عبر بقية المشروع (بما فيها `rejected` التي أُضيفت لاحقاً حسب سجل تطور السكيمة المحلية القديمة).

  **`BookingModel`** (سطر 40-151): حقول شاملة تشمل بيانات الحجز نفسه + بيانات مُجوينة (اسم/صورة/مدينة الشاليه، اسم/هاتف/صورة الضيف المسجَّل عبر `profiles`) + حقول خاصة بالحجز اليدوي (`stayType`, `source`, `externalGuestName/Phone` — موثّقة تفصيلياً بتعليقات، ومتّسقة تماماً مع [manual_booking.dart](manual_booking.md)).
  - **`nightsCount` getter (سطر 103-108): إصلاح موثّق ومؤكَّد بدقة لعطل توقيت صيفي حقيقي.** الحساب الساذج (`checkOut.difference(checkIn).inDays` على تواريخ محلية) يتأثر بانتقال التوقيت الصيفي (ليلة 23 ساعة بدل 24 تُنقِص `.inDays` بواحد) — مثال حقيقي موثّق بالتعليق: "25→27 مارس 2027 كانت تُعرض ليلة واحدة" (بدل ليلتين). الإصلاح: تحويل كلا التاريخين لـ `DateTime.utc(y, m, d)` أولاً ثم الطرح — يُلغي أثر التوقيت الصيفي تماماً لأن UTC لا تغيّره.
  - `fromJson`: يقرأ `checkIn`/`checkOut`/`createdAt` بـ `DateTime.parse` (**غير** `tryParse`) — الحقل الوحيد غير المحمي بـ fallback بهذا النموذج (باقي الحقول محمية بـ `as Type? ?? default`).
  - `toJson`: يُصدِّر فقط الحقول القابلة للإرسال من التطبيق عند الإنشاء (`chalet_id, user_id, check_in, check_out, guests_count, total_price, status, payment_method, notes, stay_type`) — **يستبعد عمداً** `source`/`guest_name`/`guest_phone`/`id`/`created_at` (متّسق مع كون `source` عموداً محمياً بـ trigger حسب توثيق [manual_booking.dart](manual_booking.md)). **يحتاج تأكيد استخدام:** [services.dart](../services/services.md) (`BookingService.createBooking`) يبني خريطة الإدراج **يدوياً بنفسه** بدل استدعاء `booking.toJson()` — هذه الدالة قد تكون غير مُستخدَمة فعلياً حالياً (يحتاج تأكيد بالبحث الشامل عند تجميع كل نقاط استهلاك النماذج).

  **`UserProfile`** (سطر 156-216): `id, fullName, phone, avatarUrl, email, createdAt, role, isOwner, isAdmin`.
  - `toJson()`: يُصدِّر **فقط** `id, full_name, phone, avatar_url` — يستبعد `email`/`role`/`isOwner`/`isAdmin` تماماً. **أثر إيجابي بغضّ النظر عن القصد**: لو استُخدمت هذه الدالة يوماً لإرسال تحديث بروفايل، فهي لا تستطيع تسريب/محاولة تعديل `is_admin`/`is_owner`/`role` بصمت (حقول امتياز حسّاسة) — طبقة حماية إضافية تتوافق مع مبدأ "لا يحاول التطبيق تعديل حقول محمية".
  - 🔴 **`copyWith` (سطر 201-215) — خلل حقيقي مؤكَّد بقراءة الكود:** الدالة تقبل فقط `fullName`/`phone`/`avatarUrl`/`email`، وعند بناء الكائن الجديد **لا تُمرَّر** `role`/`isOwner`/`isAdmin` إطلاقاً من الكائن الأصلي (`this.role`/`this.isOwner`/`this.isAdmin`) — فتأخذ قيم `UserProfile` الافتراضية بالباني (`role: null`, `isOwner: false`, `isAdmin: false`) **بغض النظر عن القيم الفعلية بالكائن الأصلي**. أي استدعاء لـ`profile.copyWith(fullName: '...')` على بروفايل مالك/أدمن حقيقي سيُنتج نسخة تبدو "مستخدماً عادياً" (isOwner=false, isAdmin=false) رغم أن قاعدة البيانات لم تتغيّر فعلياً. **تحقّقت بالبحث الشامل بكل `lib/presentation`:** لا يوجد حالياً أي استدعاء فعلي لـ`UserProfile.copyWith(...)` بأي شاشة — **الخلل موجود بكود غير مُستخدَم حالياً (dead code)**، فلا أثر فعلي على المستخدمين الآن، لكنه "فخ" حقيقي لأي مطوّر يستخدم `copyWith` مستقبلاً متوقعاً السلوك المعتاد (الحفاظ على الحقول غير المُمرَّرة).

  **`ReviewModel`** (سطر 221-265): يقرأ `profiles?['full_name']`/`avatar_url` من البيانات المُجوينة — **متّسق تماماً** مع إعادة التشكيل اليدوي لنفس الشكل بـ`ReviewsService.getChaletReviews` بـ[services.dart](../services/services.md) (التي تبني يدوياً مفتاح `profiles` من أعمدة RPC `author_full_name`/`author_avatar_url`). `toJson` يستبعد بحكمة `id`/`created_at`/اسم وصورة المستخدم.

  **`NotificationModel`** (سطر 270-315): ⚠️ **راجع القسم التالي — هذا اسم مكرر بملف مختلف تماماً.**

- **الاعتماديات:** لا يستورد شيئاً. **من يستخدمه:** [services.dart](../services/services.md) (`BookingService`, `AuthService.getCurrentProfile`, `ReviewsService`, `NotificationsService`)، وعدد كبير من الشاشات (`booking_screen.dart`, `favorites_screen.dart`, `chalet_detail_screen.dart`, `profile_screen.dart`, `profile_provider.dart`, شاشات owner/* متعددة، `notifications_screen.dart`) — مؤكَّد بالبحث الفعلي (18 ملفاً على الأقل يستوردون `models.dart`).

- **التعامل مع Supabase:** لا اتصال مباشر؛ يمثّل صفوف `bookings` (بجوين `chalets`/`profiles`)، `profiles`، `reviews` (بجوين `profiles`)، و`notifications`.

- **نقاط القوة:**
  - إصلاح `nightsCount` هو **ثاني إصلاح توقيت صيفي موثَّق ومؤكَّد بالتشغيل الفعلي** بنفس المشروع (الأول بـ[pricing_service.dart](../services/pricing_service.md)) — يدل على وعي حقيقي ومتكرر بهذه الفئة من الأخطاء، وليس إصلاحاً عرضياً لمرة واحدة.
  - `UserProfile.toJson()` يستبعد حقول الامتياز الحسّاسة بشكل يمنع تسريبها/محاولة تعديلها ولو بالخطأ.
  - `BookingStatus` enum متّسق تماماً مع كل استخدامات `status` بالنصوص عبر باقي المشروع.

- **الأخطاء والمخاطر المحتملة:**
  - 🔴 **حرجة من ناحية الصواب المنطقي، لكن أثرها الحالي صفري (كود غير مُستخدَم) — `UserProfile.copyWith` يُسقِط `role`/`isOwner`/`isAdmin` بصمت.** التفصيل أعلاه.
  - 🟡 **بسيطة (سطر 115-116، 125):** `checkIn`/`checkOut`/`createdAt` بـ `DateTime.parse` (غير `tryParse`) — الحقول الوحيدة غير المحمية بهذا النموذج، بخلاف نمط الحماية الشامل ببقية الدالة.
  - 🟡 **بسيطة — ازدواجية تسمية خطيرة الشكل، آمنة التنفيذ حالياً:** يوجد كلاس آخر بنفس الاسم **الحرفي** `NotificationModel` بملف منفصل تماماً: [notification_model.dart](notification_model.md)، بحقول مختلفة (`body`/`type` غير قابلين لـ null هناك مقابل قابلين هنا؛ لا يوجد `relatedId` هنا؛ `fromJson` هنا مقابل `fromMap` هناك). **تحقّقت بالبحث:** لا يوجد أي ملف يستورد كلا المصدرين معاً (فلا يوجد خطأ تصريف/ambiguous import فعلي)، لكنها ازدواجية منطق ونماذج بيانات موازية تخدم نفس الغرض تماماً (إشعارات) بأسماء متطابقة — خطر ارتباك حقيقي لأي مطوّر لاحق (خصوصاً IDE قد تقترح الاستيراد الخطأ تلقائياً). التفصيل الكامل والحل المقترح بمراجعة [notification_service.dart](../services/notification_service.md) و[notification_model.dart](notification_model.md).

- **اقتراح الإصلاح:**
  - **إصلاح `UserProfile.copyWith` فوراً** (قبل أن يبدأ أي كود جديد استخدامه):
    ```dart
    UserProfile copyWith({
      String? fullName,
      String? phone,
      String? avatarUrl,
      String? email,
    }) {
      return UserProfile(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        email: email ?? this.email,
        createdAt: createdAt,
        role: role,           // ← إضافة الثلاثة المفقودة
        isOwner: isOwner,
        isAdmin: isAdmin,
      );
    }
    ```
  - توحيد `NotificationModel` بنسخة واحدة فقط (راجع الاقتراح المفصّل بمراجعة notification_model.dart).
  - التأكد من كون `BookingModel.toJson()` مُستخدَمة فعلياً بمكان ما، أو حذفها لو كانت كوداً ميتاً لتقليل مصدرين محتملين للحقيقة (Map يدوي بـ `createBooking` مقابل `toJson()` هنا).
