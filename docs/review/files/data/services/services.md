### lib/data/services/services.dart

- **الوظيفة:** الملف المركزي لطبقة البيانات — يجمّع `AuthService`, `ChaletService`, `BookingService`, `FavoritesService`, `ReviewsService`, `NotificationsService` (كل واحد singleton بنمط `instance`)، بالإضافة لدالة ترجمة أخطاء Supabase المشتركة (`_translateSupabaseError`) وآلية بسيطة لتخزين "إجراء ضيف معلّق" (`PendingAuthAction`/`AuthRedirectService`). هذا هو أكبر وأهم ملف بطبقة `data/` (1064 سطر) وأكثرها استدعاءً من الشاشات.

- **الشرح التفصيلي (بحسب الأقسام):**

  **`_translateSupabaseError` (سطر 24-75):** تفحص نص الخطأ (lowercased) وتُرجع رسالة عربية مفهومة لحالات محددة بالترتيب: يوم محجوب (`availability unavailable`) ← تعارض حجز فعلي (`exclusion constraint`/`23P01`/`23505`/...) ← تعديل حقل محمي ← نقص صلاحيات أدمن ← دفعة لحجز لا يخص المستخدم ← وإلا `PostgrestException.message` الخام أو نص الاستثناء. **كل** دوال الملف تقريباً تمرّ عبر `catch (e) { throw Exception(_translateSupabaseError(e)); }` — نمط متّسق وموحّد.

  **`AuthService`** (سطر 80-287): تسجيل دخول/خروج/تسجيل جديد (Supabase Auth مباشرة)، بروفايل (`getCurrentProfile`/`updateProfile`)، تبديل دور (`becomeOwner`/`becomeCustomer` عبر RPC)، وفحص أدمن مكاش (`isAdmin`/`clearAdminCache`، مُفصَّل بمراجعة [app_router.dart](../../core/router/app_router.md)).
  - `signUp`: يستدعي `supabase.auth.signUp` ثم (فقط لو توجد جلسة فوراً) يعمل `upsert` ثانوي لجدول `profiles` بمحاولة `try/catch` **صامتة تماماً** (سطر 111-118) — موثّقة بتعليق أن السبب تفادي فشل التسجيل بسبب RLS عند عدم وجود جلسة (تأكيد بريد مفعّل). 
  - `resetPassword`/`verifyPasswordRecoveryOtp`/`updatePassword`: تدفق استرداد كلمة مرور **بدون** deep link (موثّق بتعليق طويل صريح) — يعتمد على OTP مكوّن من 6 أرقام بدل رابط، **بشرط إعداد يدوي خارجي بلوحة Supabase** (قالب بريد "Reset Password" يجب أن يتضمن `{{ .Token }}`) لا يمكن التحقق منه أو فرضه من الكود.
  - `getCurrentProfile`: `.single()` (يرمي استثناء لو لا يوجد صف، رغم أن توقيع الدالة `Future<UserProfile?>` يوحي أن `null` مسار متوقع).
  - `isAdmin`/`clearAdminCache`: كاش بسيط بمتغيّر `bool? _isAdminCache`، يُمسَح عند `signOut` (`finally`) وعند تغيّر حالة المصادقة بـ[main.dart](../../../main.md).

  **`PendingAuthAction` / `AuthRedirectService`** (سطر 289-311): تخزين ذاكرة مؤقت (متغيّر `static` واحد `_pending`، بدون تخزين دائم) لإجراء طلبه ضيف (مثل "أضف للمفضلة") قبل تحويله لتسجيل الدخول، ليُستأنف بعد الدخول عبر `consumePendingAction()` (نمط استهلاك لمرة واحدة — one-shot).

  **`ChaletService`** (سطر 316-594):
  - `getChalets`: فلاتر متعددة (مدينة/سعر/مسبح/واي فاي/شواء/مواقف/عدد ضيوف/بحث نصي) على جدول `chalets` بشرط `is_available = true AND is_approved = true` ثابت دائماً، مع **pagination حقيقي** (`range(offset, offset+limit-1)`, `limit` افتراضي 20). البحث النصي يُطهَّر (`replaceAll(RegExp(r'[(),%*\\:"]'), ' ')`) قبل بناء شرط `or()` من عدة `ilike` — إصلاح موثّق لمشكلة حقيقية (رموز PostgREST الخاصة داخل نص البحث كانت تكسر الطلب).
  - `getChaletById`: `.single()` — نفس ملاحظة `getCurrentProfile` (يرمي بدل إرجاع `null` رغم التوقيع `ChaletModel?`).
  - `isAvailable`: فحص تعارض **من جهة التطبيق** (استعلام `bookings` بحالة `pending`/`confirmed` وتقاطع تواريخ) — **مؤكَّد الاستخدام فعلياً** بـ[booking_screen.dart](../../presentation/screens/booking/booking_screen.md) سطر 146. هذا فحص تفاؤلي (optimistic) فقط لتحسين تجربة المستخدم قبل الإرسال؛ الحارس الحقيقي والنهائي يبقى قيد الـ exclusion بقاعدة البيانات (حسب وصف المستخدم)، وأي تعارض حقيقي عند الإرسال الفعلي يُترجَم لاحقاً لرسالة مفهومة عبر `_translateSupabaseError`. **هذا بالضبط النمط الصحيح المطلوب** (فحص محلي للتجربة + مصدر الحقيقة النهائي بالسيرفر).
  - `uploadChaletImages`: رفع لكل صورة على حدة إلى `Storage` bucket باسم `chalet-images`، بمسار `chalets/$chaletId/<timestamp>_$i.<ext>`. **أي صورة تفشل برفعها تُتجاهَل بصمت تماماً** (`catch (_) { continue; }`، سطر 488-490) بدون أي إشارة للمستدعي عن عدد/هوية الصور الفاشلة.
  - `createOrUpdateChaletWithImages`: عند إنشاء شاليه جديد، يُدرَج أولاً بـ `is_available: false, is_approved: false` (آمن افتراضياً — غير ظاهر للعامة لحين اكتمال البيانات/الموافقة)، ثم تُرفع الصور، ثم `update` بكل البيانات + روابط الصور. عند أي فشل بالمسار: تنظيف تعويضي (حذف الصور المرفوعة فعلاً + حذف صف الشاليه لو كان إنشاءً جديداً) قبل `rethrow` — نمط "compensating transaction" معقول بديل عن غياب transaction حقيقية بواجهة Supabase client.

  **`BookingService`** (سطر 599-834):
  - `calculateBookingPrice`: يستدعي RPC **`calculate_chalet_stay_price`** على السيرفر لحساب السعر (وليس ضرباً محلياً لسعر ثابت × عدد الليالي) — **هذا بالضبط ما طلب المستخدم التحقق منه**: الاعتماد على السيرفر لحساب السعر. فحص `nights <= 0` محلي أولاً (يتفادى نداء شبكة لا داعي له لمدخلات غير صالحة أصلاً).
  - `createBooking`: يُدرِج بـ `'total_price': totalPrice` — **القيمة قادمة من المستدعي مباشرة (Map argument)، لا يُعاد حسابها هنا**. حسب وصف المستخدم للباك إند، trigger على السيرفر "يفرض السعر الإجمالي للحجز" (يُفترض أنه يتجاوز/يتحقق من القيمة المُرسَلة). **يحتاج تأكيد دقيق بملف [booking_screen.dart](../../presentation/screens/booking/booking_screen.md):** هل القيمة المرسَلة هنا هي نفسها فعلياً ناتج `calculateBookingPrice()` المحسوب بالسيرفر مباشرة قبل النداء، أم قيمة مُعدَّلة/محسوبة جزئياً بالتطبيق (مثل جمع رسوم عرض من [pricing_constants.dart](../../core/constants/pricing_constants.md))؟ هذا الملف نفسه (services.dart) لا يحتوي أي خطأ بهذا الخصوص — فقط ناقل بيانات؛ الفحص الحاسم بملف الشاشة المستهلكة.
  - `getIncomingBookings`: **بدون أي pagination** (`select('*, chalets!inner(...), profiles(...)')` بدون `.range()`/`.limit()`) — يجلب **كل** حجوزات شاليهات المالك (كل الحالات، كل التاريخ) دفعة واحدة في كل مرة تُفتح شاشة حجوزات المالك. لمالك بحجم عمليات كبير أو بتاريخ طويل، هذا نمو غير محدود بحجم البيانات المحمّلة والذاكرة المستخدمة.
  - `confirmIncomingBooking`/`rejectIncomingBooking`/`cancelBooking`: تحديثات مباشرة لجدول `bookings` (`update({...}).eq('id', bookingId)`) **بدون** `.select()` لاحقاً، وبدون أي فحص لعدد الصفوف المتأثرة. سلوك PostgREST/RLS القياسي: لو سياسة RLS استثنت الصف (مثلاً لأنه لم يعد `pending`، أو تغيّرت الملكية) فإن التحديث **لا يرمي أي استثناء** — فقط يؤثر على صفر صف بصمت تامة، وتُرجع الدالة بنجاح ظاهري رغم عدم حدوث أي تغيير فعلي بقاعدة البيانات. هذا يتقاطع تماماً مع مخاوف "Race conditions" و"try/catch يبلع الخطأ بصمت" التي طلب المستخدم فحصها. **يحتاج تأكيد بالشاشات المستهلكة** (owner_booking_actions.dart، manual_booking_actions.dart): هل تُحدَّث الواجهة بافتراض النجاح دائماً بعد هذه النداءات، أم تُعاد قراءة الحجز/القائمة للتأكد الفعلي من التغيير؟
  - `cancelExternalBooking`/`createExternalBooking`: عبر RPC (`cancel_external_booking`/`create_external_booking` — **مطابقة تماماً** لأسماء الدوال بوصف المستخدم للباك إند). تعليقات الكود تشرح بدقة قواعد عمل حقيقية أعادها السيرفر (رفض لغير المالك، رفض لحجز غير يدوي، `stay_type` الافتراضي `'default'` تحديداً لأن `'خارجي'` يرفضه قيد `bookings_stay_type_check`) — دليل واضح على تعامل صحيح مع قيود trigger/CHECK بدل تجاهلها.

  **`FavoritesService`** (سطر 839-907): `getFavorites`/`getFavoriteIds` بسيطتان ومحدودتان بـ `user_id`. **`toggleFavorite`**: تعليق مطوَّل يوثّق **إصلاح Race Condition حقيقي** كان موجوداً (SELECT ثم INSERT/DELETE منفصلين، قابل لنتيجة خاطئة عند ضغط سريع مزدوج) — الحل الحالي RPC ذرّية واحدة **`toggle_favorite`** (مطابقة لاسم دالة الباك إند بوصف المستخدم) تُرجع الحالة الحقيقية النهائية. **هذا أفضل مثال بكل الملف على معالجة صحيحة وموثّقة لمشكلة Race Condition مطلوب فحصها.**

  **`ReviewsService`** (سطر 912-1012):
  - `getChaletReviews`: RPC `get_chalet_reviews_with_author`، يعيد تشكيل النتيجة يدوياً لتضمين `profiles: {full_name, avatar_url}` متوافقة مع شكل `ReviewModel.fromJson`.
  - `addReview`: منطق أهلية متعدد الخطوات: (أ) يتحقق من وجود حجز **مكتمل** (`status == 'completed'`) للمستخدم على هذا الشاليه (عبر `bookingId` محدد أو بحث عام)، وإلا `throw Exception('not_eligible_review')` — **استثناء مُعرَّف بنص حر (magic string) لا class مخصص**، ما يجعل مطابقته من طرف المستدعي هشّة (`.toString().contains('not_eligible_review')`) بدل `is SpecificException`. (ب) لو لم يُمرَّر `bookingId`، يبحث محلياً (عبر استعلامين متتاليين: كل حجوزات المستخدم المكتملة لهذا الشاليه، ثم كل مراجعاته لتلك الحجوزات) عن أول حجز مكتمل لم يُقيَّم بعد — موثّق بتعليق أنه إصلاح لمشكلة حقيقية (كان يُرسَل `booking_id = null` دائماً فيرفضه RLS/قيد `unique_review_per_booking`). **لا يوجد فرع خاص بـ `_translateSupabaseError` لرسالة قيد `unique_review_per_booking`** (تقييم مكرر لنفس الحجز) — لو حدث تعارض توقيت نادر (تقديم تقييمين شبه متزامنين) فالخطأ الخام من قاعدة البيانات (نص تقني عن unique constraint) سيصل للمستخدم كما هو، بخلاف حالات أخرى مشابهة (تعارض حجز، حقل محمي) المُترجَمة بعناية بنفس الملف.

  **`NotificationsService`** (سطر 1017-1064): CRUD بسيط على جدول `notifications` (`getNotifications`, `markAsRead`, `markAllAsRead`) محدود بـ `user_id`. **لا يوجد أي اشتراك Realtime هنا** (لا `.stream()`/`.channel()`) — فقط جلب لمرة واحدة عند الطلب. **ملاحظة تسمية:** يوجد أيضاً ملف منفصل [notification_service.dart](notification_service.md) (اسم شبه مطابق بالمفرد) — سيُوضَّح عند مراجعته هل هو تكرار/تخصص مختلف أو مسار قديم غير مستخدم.

- **الاعتماديات:** يستورد `data/models/chalet_model.dart`, `data/models/models.dart`, `unavailable_nights.dart`. **من يستخدمه:** عملياً كل شاشة تقريباً بالتطبيق (auth, home, chalet detail, booking, favorites, owner/*, profile, notifications...) — أكثر ملف استيراداً بالمشروع، سيُؤكَّد اسم كل مستهلك تراكمياً.

- **التعامل مع Supabase (ملخّص الجداول/RPC المُستخدَمة فعلياً بهذا الملف):**
  جداول: `profiles` (select/update/upsert)، `chalets` (select بفلاتر متعددة/insert/update/delete)، `bookings` (select بجوين مع chalets/profiles، insert، update status)، `favorites` (select)، `reviews` (select via RPC، insert)، `notifications` (select/update). Storage bucket: `chalet-images`. RPC: `become_owner`, `become_customer`, `calculate_chalet_stay_price`, `cancel_external_booking`, `create_external_booking`, `toggle_favorite`, `get_chalet_reviews_with_author`.

- **نقاط القوة:**
  - طبقة ترجمة أخطاء مركزية وموحّدة (`_translateSupabaseError`) مُطبَّقة بشبه كل دالة — يمنع تسرّب رسائل PostgreSQL خام للمستخدم في أغلب الحالات.
  - إصلاحان موثّقان بعناية لمشكلتي Race Condition حقيقيتين (`toggleFavorite` عبر RPC ذرّية، والتحقق من الأهلية بـ `addReview`)، بالإضافة لتوثيق واضح لسبب اعتماد OTP بدل deep link لاسترداد كلمة المرور.
  - اعتماد فعلي وصريح على السيرفر لحساب سعر الحجز (`calculate_chalet_stay_price`) بدل حساب محلي — يطابق تماماً المطلوب التحقق منه.
  - إدراج الشاليهات الجديدة بحالة غير ظاهرة (`is_available: false, is_approved: false`) بشكل افتراضي آمن، مع تنظيف تعويضي عند فشل أي خطوة بمسار الإنشاء/التعديل (لا صور يتيمة أو صفوف ناقصة معلَّقة).
  - استخدام الدوال الصحيحة (RPC) لعمليات تحتاج قواعد عمل خاصة على السيرفر (`create_external_booking`, `cancel_external_booking`) بدل محاولة تنفيذها بمنطق تطبيق مباشر.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 729-782، `confirmIncomingBooking`/`rejectIncomingBooking`/`cancelBooking`):** تحديثات مباشرة بدون فحص عدد الصفوف المتأثرة — لو رفضت RLS الصف بصمت (حالة تغيّرت، أو سباق بين طلبين)، الدالة "تنجح" رغم عدم حدوث أي تعديل فعلي بقاعدة البيانات. **مؤكَّد بمراجعة [owner_booking_actions.dart](../../presentation/screens/owner/owner_booking_actions.md):** `confirmBookingFlow`/`rejectBookingFlow` بذلك الملف تستدعي هاتين الدالتين بالضبط وتعرض "تم تأكيد الحجز بنجاح"/"تم رفض الحجز" لمجرد عدم رمي استثناء — أي أن **رسالة نجاح كاذبة فعلية للمالك** هي الأثر المباشر المؤكَّد لهذه الفجوة، وليس مجرد قلق نظري. (بالمقابل، `cancelExternalBooking` عبر RPC أقل خطورة لأن دوال RPC عادة تفحص الشرط وترمي استثناءً صريحاً بدل صمت — راجع [manual_booking_actions.dart](../../presentation/screens/owner/manual_booking_actions.md)).
  - 🟠 **متوسطة (سطر 439-494، `uploadChaletImages`):** فشل رفع أي صورة يُبتلَع بصمت تامة (`catch (_) { continue; }`) بدون أي معلومة تصل للمستدعي/المستخدم عن الصور الفاشلة أو عددها.
  - 🟠 **متوسطة (سطر 708-726، `getIncomingBookings`):** لا يوجد pagination إطلاقاً — يجلب كل حجوزات كل شاليهات المالك تاريخياً بكل مرة.
  - 🟡 **بسيطة (سطر 210-222 و391-400، `getCurrentProfile`/`getChaletById`):** استخدام `.single()` بدل `.maybeSingle()` مع توقيع دالة يُرجع نوعاً nullable (`UserProfile?`/`ChaletModel?`) — الحالة "غير موجود" لا تُعاد كـ`null` عملياً بل تُرمى كاستثناء مُترجَم، ما قد يفاجئ أي مستدعٍ يتوقع فعلياً التعامل مع قيمة `null` بدل `try/catch`.
  - 🟡 **بسيطة (سطر 962-963، `addReview`):** استثناء بنص حر (`'not_eligible_review'`) بدل نوع Exception مخصص — هشّ لمطابقة المستدعي.
  - 🟡 **بسيطة (سطر 966-998، `addReview`):** لا فرع ترجمة مخصص لتعارض قيد `unique_review_per_booking` — سيصل كنص خطأ تقني خام بدل رسالة عربية مفهومة عند تعارض توقيت نادر.
  - 🟡 **بسيطة (سطر 111-118، `signUp`):** لو تأكيد البريد مفعّل بمشروع Supabase الحالي (سيناريو موثّق صراحة بالتعليق)، يبقى `phone` (وربما بيانات أخرى غير مضبوطة من الـ trigger التلقائي) غير محفوظ بجدول `profiles` حتى يُحدِّثها المستخدم يدوياً لاحقاً — **يحتاج تأكيد** هل شاشة البروفايل تطلب هذه البيانات لاحقاً لو كانت ناقصة، وهل تأكيد البريد فعلياً مفعّل بمشروع الإنتاج (لا يمكن التأكد من هنا).

- **اقتراح الإصلاح:**
  - لتحديثات الحالة الحرجة (تأكيد/رفض/إلغاء حجز)، إضافة `.select()` بعد `.update()` وفحص أن القائمة المُعادة غير فارغة، ورمي رسالة واضحة ("لم يعد بالإمكان تنفيذ هذا الإجراء، ربما تغيّرت حالة الحجز") لو فارغة:
    ```dart
    final rows = await supabase
        .from('bookings')
        .update({'status': 'confirmed'})
        .eq('id', bookingId)
        .select();
    if (rows.isEmpty) {
      throw Exception('لم يعد بالإمكان تأكيد هذا الحجز (قد تكون حالته تغيّرت)');
    }
    ```
  - في `uploadChaletImages`: تجميع أخطاء كل صورة فاشلة بدل تجاهلها، وإرجاعها للمستدعي (مثلاً `({List<String> urls, List<String> failedFileNames})`) ليعرض المستخدم تنبيهاً دقيقاً بعدد الصور التي لم تُرفع.
  - في `getIncomingBookings`: إضافة `.range()`/`.limit()` مع تحميل تدريجي (pagination) بشاشة حجوزات المالك، خصوصاً مع نمو تاريخ الحجوزات.
  - إضافة فرع بـ `_translateSupabaseError` لأي نص يحتوي `unique_review_per_booking` أو ما يعادله من رمز خطأ، يُرجع رسالة مثل "لقد قيّمت هذا الحجز مسبقاً".
  - **يوجد بالفعل نمط مرجعي صحيح لهذه المشكلة بنفس المشروع** — [chalet_edit_data_source.dart](../../presentation/screens/owner/chalet_edit_data_source.md) (`SupabaseChaletEditDataSource.updateChalet`) يستخدم `.update(...).select()` ويتحقق من عدد الصفوف المُعادة صراحة (`rows.isEmpty ? null : rows.first`) بدل افتراض النجاح — نفس الحل المقترح أعلاه، مطبَّق فعلياً هناك. يُنصَح بتعميم هذا النمط بالذات على `confirmIncomingBooking`/`rejectIncomingBooking`/`cancelBooking` هنا.
