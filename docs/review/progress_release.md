# سجل تقدّم تجهيز الإطلاق (release-cleanup)

الفرع: `release-cleanup`. المرجع: `docs/review/99_summary.md`.
بوابة كل مرحلة: `flutter analyze` (مقارنة بالتشغيل السابق، بلا مشاكل جديدة) + `flutter test` (كل الاختبارات تنجح).

## خط الأساس — commit `d140b5e`
- حُفظت حالة العمل غير المُلتزَمة من main كـ commit أساس، حتى يكون commit كل مرحلة معزولاً.
- analyze: 247 ملاحظة (0 أخطاء، 13 تحذيراً). test: 304 نجاح، 3 فشل (كلها `reels_screen_test.dart`، وهي اختبارات المرحلة 1 نفسها).

## المرحلة 1: الريلز — ✅ منتهية
**سبب الصفحة البيضاء:** جدول `reels` بالقاعدة الحية فارغ (0 صف، تحقق باستعلام قراءة فقط)، والكود الأصلي بلا حالة فارغة: كان يبني `PageView` بصفر عناصر فوق خلفية الشاشة، فتظهر صفحة فارغة. وكان هيكل التحميل (skeleton) يضع أيضاً شريطاً أبيض بارتفاع 56 تحت الـ AppBar الحقيقي.

**ما أُصلح:**
- نافذة مشغّلات: الحالي + واحد قبل + واحد بعد فقط؛ ما يخرج عن النافذة يُوقف ويُخرَّب بعد إعادة البناء التالية.
- تبويب Reels داخل `IndexedStack` بـ `main_screen.dart` كان يُحمَّل ويشغّل الفيديو (بالصوت) والمستخدم بتبويب آخر. أُضيف `ReelsScreen(active:)`: عند الإخفاء تُوقف وتُحرَّر كل المشغّلات، ولا يُنشأ أي مشغّل قبل فتح التبويب.
- إيقاف عند فتح تفاصيل الشاليه (بلا استئناف تحت الشاشة الأخرى عند رجوع التطبيق من الخلفية)، وعند خروج التطبيق للخلفية.
- الفيديو الظاهر لم يكن يبدأ تلقائياً بعد تحميله (كان `play()` يُستدعى فقط لو كان جاهزاً مسبقاً) — يبدأ الآن فور الجاهزية.
- Chewie يرسم `placeholder` دائماً تحت الفيديو، فكان مؤشّر التحميل الدوّار يعمل للأبد (وهو سبب timeout الاختبارات). أصبح placeholder هو الصورة المصغّرة، ومؤشّر التحميل طبقة تختفي فور الجاهزية، مع رسالة "تعذر تشغيل هذا الفيديو" عند فشل الفيديو نفسه.
- `initialize()` بلا `catchError` كان يُنتج خطأً غير معالَج — عولج.
- حالات: تحميل (skeleton)، فارغة ("لا توجد فيديوهات بعد")، خطأ مع "إعادة المحاولة".
- `ReelsService.fetchReels`: `.limit(50)`، واستبعاد صفوف بلا `video_url`/`chalet_id` (أعمدة nullable بالقاعدة) بدل إسقاط القائمة كلها؛ `ReelModel.fromJson` متسامح مع القيم null.

**الاختبارات:** `test/reels_screen_test.dart` — 7 اختبارات. أُضيفت دالة `_settleDisposal` لأن `VideoPlayerController.dispose()` يحتاج فجوة async حقيقية خارج FakeAsync (مُثبت باختبار عزل)؛ معنى كل توقّع أصلي لم يتغيّر. أُضيفت 3 اختبارات: تشغيل تلقائي، لا مشغّلات والتبويب مخفي، الإخفاء يحرّر المشغّلات.

**البوابة:** analyze 245 (0 جديد). test: 310 نجاح.

## المرحلة 2: الحجوزات والمالك — ✅ منتهية
(تحقق من القاعدة الحية بقراءة فقط: سياسة `bookings_update_unified` تسمح للمالك بتحديث حجوزات شاليهاته، و`availability_update_owner` كذلك؛ `create_external_booking` تقبل `p_stay_type` افتراضياً 'default'؛ `booking_slots` تطابق `isDayAvailableForStayType`.)
- **فحص عدد الصفوف:** `confirmIncomingBooking`/`rejectIncomingBooking` (دالة مشتركة `_setIncomingBookingStatus`) و`cancelBooking` للزبون و`unblockDates`: `.select()` ورمي استثناء عند 0 صف (`bookingNotUpdatedMessage`).
- **فك اقتران Future.wait:** `owner_bookings_screen` و`owner_chalets_screen` (أساسي تسلسلي + `catchError` للثانوي). `owner_dashboard_screen`: الطلبات الخمسة تبدأ متوازية لكن كل ثانوي بـ `catchError` مستقل؛ الإحصائيات وحدها أساسية. فشل الحجوزات يعرض "تعذر تحميل الحجوزات القادمة" و"—" بدل "لا توجد حجوزات"، وفشل الشاليهات لا يُظهر بانر الإعداد خطأً. `_refreshUnreadCount` لم يعد يرمي.
- **القبول/الرفض:** حوار تأكيد للقبول أيضاً (مشترك مع التقويم)، و`onStart` يضبط "مشغول" بعد موافقة الحوار وقبل الطلب، بالشاشتين (الحجوزات والتقويم).
- **الشهران:** "30 مارس - 2 أبريل" (مع السنة إن اختلفت).
- **أنواع الإقامة:** ورقة الحجز اليدوي تقرأ `getDaySlots` بدل الليالي، تعرض أنواع الإقامة المفعّلة (أول نوع افتراضياً كشاشة الضيف)، تعطّل الأيام بـ `isDayDisabledForStaySlot`، تعلّم الأيام الجزئية (شمس/قمر)، وترسل `stay_type` للتسعير ولـ `create_external_booking`. تقويم المالك يحمّل الفترات (`loadDaySlots`، ثانوي) ويعرض شارة وملاحظة "الفترة الصباحية/المسائية محجوزة" + وصف لقارئ الشاشة — يظهر الآن أيضاً صباح اليوم التالي لحجز "يوم كامل مسائي" الذي كان يبدو حراً.
- **unavailable_nights.dart:** نموذج الليالي القديم (`UnavailableNights`, `isDayDisabledForStay`, `rangeHasUnavailableNight`, `getUnavailableNights`) لم يعد له مستخدم بـ lib/ (مؤكَّد بـ grep) فأُزيل؛ الملف يحتفظ بـ `RpcCaller` فقط. الاختبارات نُقلت لـ `ChaletSlotAvailability` بنفس التغطية + اختبارات الأيام الجزئية لكل نوع إقامة.
- **nightsBetween:** `lib/core/utils/date_utils.dart` بـ `DateTime.utc`، مستخدمة في: `BookingModel.nightsCount`، `calculateBookingPrice`، `dashboard_service` (أيام النطاق)، `booking_screen._nights`، `payment_flow_entry`، `manual_booking_sheet`، `owner_calendar_logic.nightNumber`.
- حُذف حقل `_supabase` الميت من `owner_chalets_screen`.

**الاختبارات الجديدة/المعدّلة:** `date_utils_test` (DST)، `manual_booking_test` (+4: default، نوع أول افتراضي، المسائية ترسل stayType، تغيير النوع يمسح التواريخ)، `owner_calendar_screen_test` (+2: شارة جزئية، فشل الفترات لا يُسقط التقويم؛ اختبار القبول يمر الآن بالحوار)، `unavailable_nights_test` (أُعيدت كتابته على الفترات).

**البوابة:** analyze 244 (0 جديد). test: 322 نجاح.

## المرحلة 3: الأدمن — ✅ منتهية
(تحقق من القاعدة الحية: الدوال الخمس SECURITY DEFINER تتحقق من `is_current_user_admin()` وتسجّل بـ `admin_audit_log`؛ `admin_reject_chalet` **تحذف الشاليه نهائياً**؛ toggle ترفض تعديل حساب الأدمن نفسه برسالة عربية.)
- `AdminService.getOverviewStats({from, to})` ← RPC `admin_get_overview_stats` بنموذج مكتوب `AdminOverviewStats` (كل المفاتيح الـ11). لا جلب لكل صفوف الحجوزات بعد الآن.
- `approveChalet`/`rejectChalet`/`toggleUserActive`/`toggleUserAdmin` ← الدوال الموجودة؛ لا تحديث/حذف مباشر للجداول من الشاشة. أخطاء الدوال تُعرض برسالتها العربية (`AdminActionException`).
- حوار تأكيد قبل الحظر (جديد) وقبل تغيير صلاحية الأدمن ورفض/حذف الشاليه.
- ترقيم صفحات (20) + "تحميل المزيد" لقائمتي الشاليهات المعلّقة والمستخدمين، مع عدّاد جيل. البحث عن المستخدمين صار على السيرفر (ilike مع تنظيف رموز فلتر PostgREST) حتى يشمل الصفحات غير المحمَّلة. الشاليهات المعلّقة تستبعد `deleted_at`.
- النظرة العامة: مدى (كل الوقت/هذا الشهر/آخر 30 يوماً)، بطاقات إضافية (نشطون، معتمدة، يدوية، إيرادات المنصة) وتفصيل الحجوزات حسب الحالة.
- بعد الإجراء: تحديث الصف محلياً من ناتج الدالة بدل إعادة تحميل القائمة.
- أُزيلت حقول `_supabase` الميتة الثلاثة و`withOpacity` وتحذيرات الأقواس بالملف.
- اختبار جديد: `admin_service_test.dart` (تحليل ناتج الإحصائيات).

**البوابة:** analyze 232 (0 جديد). test: 325 نجاح.

## المرحلة 4: الرئيسية والبحث — ✅ منتهية
- **مقارنة إملاء المدن (قبل التغيير):** 6 قوائم (home_tab ×2، app_strings، search عبر AppStrings، owner_add، owner_edit) — **لا أي اختلاف إملائي**؛ كل مدينة مشتركة مكتوبة حرفياً بنفس الشكل (مثل "أريحا" بالهمزة). والقاعدة الحية (نابلس، جنين فقط) مطابقة. الفرق الوحيد: AppStrings كانت 8 مدن + "الكل" (بلا طوباس وسلفيت) وترتيب مختلف.
- `AppStrings.cities` = المدن العشر بترتيب home_tab، و`AppStrings.allCities` = "الكل" منفصلة. مستخدمة في: home_tab (`_chips`)، search_screen، owner_add_chalet_screen، owner_edit_chalet_screen، و`ChaletService.getChalets`.
- `search_screen`: `minGuests` صار `null` افتراضياً (لا فلتر سعة)، "مسح الكل" وحذف الشريحة يعيدانه null، والعدّاد يعرض "أي عدد" و"−" من 1 يعود لـ null.
- `home_tab`: `reportError` (Sentry + debugPrint، ملف جديد `core/utils/error_reporter.dart`) في catch الخاص بـ `_load()`؛ مسار `/notifications` جديد بـ app_router (محمي) بدل `Navigator.push`؛ الضيف يضغط الجرس ← `requireAuth` (تسجيل الدخول ثم فتح الإشعارات تلقائياً عبر إجراء `open_notifications` بـ login_screen)؛ حُذف جلب البروفايل المكرر و`_userName` (الترحيب من `profileProvider`)؛ `import 'dart:async';` عادي بدل الشرطي.
- `LuxurySearchBar`: يستمع للـ controller فيظهر/يختفي زر المسح أثناء الكتابة، ويمسح بنفسه إن لم يُمرَّر `onClear`.
- `common_widgets.dart`: `ChaletImagePlaceholder` محلي (أيقونة على خلفية رملية) بدل صورة Unsplash، ويُستخدم أيضاً عند فشل تحميل الصورة.
- اختبار جديد: `luxury_search_bar_test.dart` (زر المسح، قائمة المدن، العنصر النائب).

**مكتشفات للمرحلة 8:** `getOwnerChalets` لا يفلتر `deleted_at` (الحذف الناعم يضبط `is_available=false` فالقوائم العامة سليمة، لكن "شاليهاتي" تعرض المحذوف)؛ `login_screen.dart` يشير لـ `assets/images/google_logo.png` غير الموجود.

**البوابة:** analyze 231 (0 جديد). test: 328 نجاح.
