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

## المرحلة 5: التسعير والنماذج — ✅ منتهية (بعد 4.5)
استُعيدت من الـ stash؛ التعارض الوحيد استيرادان بـ manual_booking_sheet (كلاهما مطلوب).
- `lib/core/utils/number_utils.dart`: `normalizeDigits` (نُقلت من ChaletEditValidation) + `parseLocalizedInt/Double`؛ مستخدمة بحقول الأسعار والأرقام في: شاشة الأسعار (كل الحقول وحوار السعر الخاص)، إضافة الشاليه (السعر والضيوف والعدّادات)، تعديل الشاليه، البحث (السعر الأدنى/الأعلى)، وسعر الحجز اليدوي.
- `pricing_service`: كل دوال الكتابة السبع عبر `_write` (try/catch + `translateSupabaseError` الذي صار API عاماً).
- `chalet_pricing_screen`: حوار السعر الخاص صار StatefulWidget يملك Controllers ويتخلّص منها (كانت تُنشأ ولا تُحرَّر)، وفحص `mounted` بعد الحذف ومنتقي الوقت.
- `owner_add_chalet_screen`: حُذفت `_uploadNewImages` الميتة (لا مستدعٍ، grep)، وربط `_handleStepCancel`: زر "السابق" بالشريط السفلي، والرجوع (النظام/السهم) يعود خطوة قبل مغادرة المعالج.
- رسالة السيرفر الجديدة "الحجز يكون ليوم واحد وفترة واحدة فقط" (trigger `enforce_single_day_booking`، ERRCODE 22023) تُعرض كما هي (`singleDayOnlyMessage`، أول فرع بـ `_translateSupabaseError`).
- اختبارات: `number_utils_test`، أرقام عربية بحقل السعر الأسبوعي تُحفظ، رسالة اليوم الواحد.

**البوابة:** analyze 226 (0 جديد). test: 344 نجاح.

## المرحلة 6: البروفايل والإعدادات والإشعارات — ✅ منتهية
- **شاشة إشعارات واحدة:** قورنت النسختان؛ أُبقيت `notifications/notifications_screen.dart` (فلاتر الكل/غير المقروءة/العروض، حالة خطأ بإعادة محاولة، وقت نسبي، رسالة عند فشل التعليم كمقروء) وأُضيف لها السحب للتحديث (الميزة الوحيدة التي كانت بالنسخة الأخرى). حُذفت النسخة المضمَّنة (`NotificationsScreen` + `_NotifTile`) من `profile_screen.dart` (كود داخل ملف، لا ملف كامل). الجرس والقائمة يمرّان عبر `/notifications`.
- **خدمة واحدة:** `NotificationService` (notification_service.dart) بكل العمليات مع ترجمة الأخطاء، `.limit(100)`، وعدّ غير المقروءة على السيرفر (`count`) بدل جلب الصفوف. حُذف `NotificationsService` من services.dart.
- **نموذج واحد:** `NotificationModel` في notification_model.dart فقط (مطابق لأعمدة الجدول الحية؛ أُزيل `relatedId` لأنه لا عمود له، وأُضيف `copyWith`). حُذفت النسخة من models.dart.
- **profile_screen:** حارس النص الفارغ قبل `.characters.first` (كان يُسقط "حسابي")؛ ورقة تعديل البيانات صارت StatefulWidget تملك حقولها وتتخلّص منها، مع `mounted` ورسالة خطأ داخل الورقة بدل استثناء غير معالَج؛ Sentry لعدّاد الإشعارات؛ حُذف استيرادان غير مستخدمين.
- **settings_screen:** اللغة بـ `ref.watch(localeNotifierProvider)` (تتحدث فوراً)؛ حُذفت ميزة العملة كاملة (+ `AppStrings.currency`)؛ أُخفي مفتاح "الإشعارات" لأنه يحفظ تفضيلاً لا يقرؤه أي جزء بالتطبيق؛ الشاشة صارت ConsumerWidget بلا SharedPreferences.
- ⚠️ للمراجعة: شاشة "الشروط والأحكام" تعرض نصاً مؤقتاً ("يمكنك لاحقاً استبدال هذا النص…") — تحتاج النص الرسمي قبل النشر.
- اختبار جديد: `settings_and_notifications_test.dart`.

**البوابة:** analyze 220 (0 جديد). test: 347 نجاح.

## المرحلة 7: الدفع (معطّل) — ✅ منتهية
- لم تُحذف أي شاشة دفع.
- `payment_flow_entry`: أُزيلت العمولة الوهمية 5% وحساب "سعر الليلة × الليالي"؛ الإجمالي = سعر الفترة من السيرفر (يُمرَّر من شاشة الحجز عبر `/payment` مع اسم الفترة، والراوتر يرفض المسار بدونهما). `BookingPaymentDetails` بلا ضريبة/ليالي/سعر ليلة/بريد. شاشة الحجز صارت تشترط سعر السيرفر للدفع الإلكتروني أيضاً (أُزيل `_canConfirmForUI`).
- أزرار بلا وظيفة: "عرض الحجز" رُبط بـ "حجوزاتي"؛ "مشاركة" و"إضافة للتقويم" أُخفيا؛ نص "تم إرسال تأكيد الحجز لبريدك" أُزيل (لا إرسال فعلي)؛ "حفظ البطاقة" أُخفي (لا حفظ فعلي)؛ "تحتاج مساعدة؟" يظهر فقط مع بيانات دعم.
- `payment_method_screen`: أُزيلت مزايا مكرّرة، و"دعم متواصل 24/7" لا يظهر بلا قنوات دعم.
- استيرادات `flutter/material as flutter_material` المزدوجة أُزيلت (intl بـ `show`).
- **بيانات الدعم:** `AppStrings.supportPhone/supportEmail` (فارغتان بانتظار المستخدم) + `core/utils/support_contact.dart`. شاشة الدعم تعرض فقط القنوات المعرَّفة وتفتحها فعلاً؛ مدخل "الدعم الفني" بحسابي والإعدادات وقسم "تواصل معنا" بالخصوصية مخفية ما دامت فارغة. (كان بالخصوصية رقم +972 52-965-0635 وبريد نائب مختلف عن شاشة الدعم — أُزيلا لصالح الثابت الموحّد.)
- اختبار جديد: `payment_and_support_test.dart`.

**البوابة:** analyze 215 (0 جديد). test: 351 نجاح.

## المرحلة 4.5: يوم واحد + فترة واحدة — ✅ منتهية
(تحقق من القاعدة الحية: لا دالة تستخدم min_nights؛ booking_slots وتحقق التداخل والسعر كلها تعمل بـ check_out = اليوم التالي؛ bookings_stay_type_check يقبل 'default'؛ نصوص الإشعارات يولّدها trigger بلا تواريخ فلا تغيير عليها؛ ~16 حجزاً قديماً ممتداً لعدة أيام موجودة فعلاً.)
- نموذج مشترك `data/models/booking_period.dart`: `BookingPeriod` (الأنواع المفعّلة أو "يوم كامل" = default)، `stayTypeLabel`، أوقات بـ ص/م، وامتداد عرض على BookingModel (`dateLabel`، `periodWithTime`، `lastBookedDay`، `isMultiDay`). BookingModel يقرأ وقت الفترة من `chalets.chalet_stay_types` المضمَّنة باستعلامات الحجوزات (`bookingPeriodColumns`).
- `booking_screen`: تقويم ليوم واحد (يوم مفعّل إن كانت فيه فترة متاحة)، ثم الفترات بأوقاتها والمحجوزة معطّلة (`isDayAvailableForStayType`)، اختيار تلقائي إن بقيت فترة واحدة، السعر للفترة المختارة فقط، والإرسال check_in = اليوم و check_out = التالي مع stay_type.
- `manual_booking_sheet`: نفس المنطق (يوم ← فترة)، زر "حجز الفترة".
- min_nights: أُزيل من ChaletModel (لم يكن بأي منطق حجز؛ الحقل كان مخفياً أصلاً من شاشتي الإضافة والتعديل). العمود باقٍ بالقاعدة.
- النصوص: ليلة/ليالي/وصول/مغادرة → يوم/فترة/تاريخ الحجز؛ price_per_night يُعرض "السعر يبدأ من" (بطاقات الرئيسية، ChaletCard، التفاصيل، الخريطة، شاليهاتي، الأدمن، البحث، نموذجا الإضافة والتعديل)؛ أوقات الفترة بشاشة الأسعار "بداية/نهاية الفترة"؛ رسائل التعارض "هذه الفترة محجوزة…" و"هذا اليوم غير متاح…".
- العرض: حجوزاتي، حجوزات المالك (قائمة بدل شبكة بنسبة ثابتة)، الحجوزات اليدوية، لوحة المالك، حوار إلغاء اليدوي، والتقويم: التاريخ + اسم الفترة + وقتها. الحجوزات القديمة الممتدة تُعرض "من X إلى Y (N أيام)" و"اليوم n من N".
- التقويم: عدة حجوزات باليوم (صباحي + مسائي) بطاقة لكل حجز مع إجراءاته، و"حجز يدوي للفترة المتاحة" باليوم الجزئي؛ ملاحظة الامتداد لصباح اليوم التالي فقط لـ "يوم كامل - مسائي"؛ الحجب يُعدّ بالأيام (أُزيل nightsLabel).
- `canCancelManualBooking` وتقسيم القادمة/المنتهية بالحجوزات اليدوية على آخر يوم محجوز بدل check_out.
- ⚠️ حُذف من خارج أوامري: `owner_bookings_screen.dart` (استُعيد من git وأُعيد تطبيق تعديلات المرحلة) ومجلد `assets/icons/` الفارغ (أُعيد إنشاؤه). كل الملفات المتتبَّعة بـ git موجودة (تحقق).
- الاختبارات: `booking_period_test` جديد، وإعادة كتابة اختبارات ورقة الحجز اليدوي لنموذج اليوم الواحد، وتحديث اختبارات التقويم (بطاقتان بيوم واحد، امتداد المسائي الكامل) والنصوص.

**البوابة:** analyze 230 (0 جديد مقارنة بالمرحلة 4). test: 339 نجاح.

## المرحلة 8: صفر كود ميت وصفر ملاحظات — 🔄 جارية

### 8أ — الملاحظات (215 ← 0)
- `.withOpacity(x)` ← `.withValues(alpha: x)`: 97 موضعاً بـ 22 ملفاً (كل الوسائط أرقام حرفية، استبدال آلي بلا تغيير سلوك).
- `dart fix` لرموز آمنة فقط: `prefer_const_*`، الأقواس، `unnecessary_import`، `unnecessary_to_list_in_spreads`، `prefer_final_fields` (≈63 إصلاحاً).
- يدوياً:
  - `app_theme`: حُذفت `background`/`onBackground` المهجورة من ColorScheme (لا شيء بالتطبيق يقرؤها، و`scaffoldBackgroundColor` مضبوط صراحة بالثيمين، فلا تغيير لوني).
  - `login_screen`: الراوتر يُلتقط مرة واحدة قبل التنقّل (كان `context.push` داخل microtask بعد `context.go` يستخدم context شاشة أُزيلت، ونفس الشيء بعد await بالمفضلة)؛ فشل المفضلة المعلّقة ← `reportError`.
  - **زر Google أُخفي:** الدالة كانت ترمي `UnimplementedError` دائماً (لا OAuth مضبوط) — حُذف الزر ودالته وحالته وفاصل "أو" بشاشة الدخول؛ لا حاجة لـ `google_logo.png`. الاختبار صار "الزر غير ظاهر".
  - `booking_screen`: `RadioGroup` بدل `groupValue/onChanged` المهجورين (خيار الدفع الإلكتروني المعطّل عبر `Radio.enabled`)؛ حُذف `_chaletLoading` (يُكتب ولا يُقرأ).
  - `DropdownButtonFormField.value` ← `initialValue` (3 مواضع؛ بـ SDK 3.35.7 `value` يُمرَّر حرفياً لـ `initialValue`، فالسلوك مطابق)؛ `Switch.activeColor` ← `activeThumbColor`.
  - `owner_add_chalet_screen`: حُذف `_gold` واستيراد models غير المستخدمَين.

**البوابة:** analyze: No issues found. test: 351 نجاح.
