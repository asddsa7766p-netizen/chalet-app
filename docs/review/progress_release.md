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

## المرحلة 8: صفر كود ميت وصفر ملاحظات — ✅ منتهية (عدا حذف 4 ملفات كاملة بانتظار الإذن)

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

### 8ب — كود ميت داخل الملفات (−404 سطراً)
كل عنصر مؤكَّد بـ grep على lib/ و test/ (التعريف فقط، لا أي استخدام):
- ودجات: `SectionHeader` (common_widgets)، `LuxurySectionHeader` و`LuxuryEmptyState` و`LuxuryShimmerCard` (luxury_widgets صار `LuxurySearchBar` فقط)، كلاس `LoginPrompt` (بقيت `requireAuth` بنفس الملف).
- **Shimmer واحد:** `ShimmerCard` (الأعم: عرض ونصف قطر قابلان للضبط)؛ استخدامَا home_tab صارا `ShimmerCard(height: 230, borderRadius: 18)` — نفس الشكل حرفياً.
- `PricingService`: `setStayTypeEnabled`، `deleteStayType`، `getPriceForDate`، `calculateStayPrice` (لا مستدعٍ؛ السعر الفعلي من `get_booking_price`/السيرفر).
- `ReelsService`: `uploadReel`، `toggleLike` (نمط SELECT ثم كتابة غير ذرّي)، `isLiked`، `_uploadFile` — بقيت `fetchReels` وحدها.
- `AuthRedirectService.peek`، `UserProfile.copyWith` (كان يُسقط role/isOwner/isAdmin)، `ChaletModel.isPublic`، `kServiceFeePercentage`.
- مجلد `splash`: غير موجود أصلاً على القرص ولا بـ git (المجلدات الفارغة لا تُتتبَّع) — لا شيء للحذف.
- كل الأصول المشار إليها بالكود موجودة (logo، onboarding_bg، .env). `assets/.env` فيه URL والمفتاح العام فقط وغير متتبَّع بـ git.

**بانتظار إذن المستخدم (حذف ملف كامل):** `core/theme/shared_preferences_keys.dart` (ثابتان لا يستوردهما أحد)، `screens/bookings/my_bookings_screen.dart` (سطر export واحد لا يستورده أحد)، `screens/reviews/reviews_screen.dart` (سطر export واحد يستورده app_router فقط).

**البوابة:** analyze: No issues found. test: 351 نجاح.

### 8ج — صلاحيات موحّدة + MakanApp
(تحقق من القاعدة الحية بقراءة فقط: `become_owner` تضبط `is_owner=true, role='owner'` معاً — وتشترط شاليهاً معتمداً غير محذوف — و`become_customer` تمسحهما معاً؛ كل البروفايلات الـ19 متسقة: لا صف فيه role و is_owner مختلفان.)
- **قاعدة واحدة:** `UserProfile.isHost` (`isOwner || role == 'owner'`) و`UserProfile.isAdmin`. كانت 4 تطبيقات: `HostService.isHost` (role فقط)، `AuthService.isAdmin` (كاش خاص)، `AdminService.isCurrentUserAdmin`، وحساب مضمَّن بـ profile_screen.
- **استعلام واحد:** `AuthService.getCurrentProfile()`. حُذفت `AuthService.isAdmin`/`clearAdminCache` و`AdminService.isCurrentUserAdmin`؛ `HostService` لم يعد مستخدماً (الملف بانتظار الإذن).
- **كاش بـ app_router.dart:** `AppRouter.currentUserProfile()` يخزّن Future البروفايل لكل مستخدم + `AuthService.rolesEpoch`، الذي يزيد في `signIn`/`signOut`/`becomeOwner`/`becomeCustomer` (بـ finally). أي تغيير بالمستخدم أو الـ epoch ← جلب جديد، فلا يمكن لأي مستدعٍ أن ينسى مسح الكاش، ولا حاجة لاستيراد الراوتر من الشاشات (كان سيُنشئ استيراداً دائرياً). الفشل لا يُخزَّن ويُسجَّل بـ `reportError`، والنتيجة "لا صلاحية" (كان `isHost` يرمي داخل redirect).
- لوحة الأدمن تفحص الوصول بـ `getCurrentProfile()?.isAdmin` (السيرفر يفرض `is_current_user_admin()` بكل دالة على أي حال).
- `FriendsChaletsApp` ← `MakanApp`.
- اختبار جديد: `user_roles_test.dart`.

**البوابة:** analyze: No issues found. test: 355 نجاح.

### 8د — pubspec.yaml
- حُذف `riverpod_annotation` و`riverpod_generator` (لا `@riverpod` ولا ملفات `.g.dart`)، و`patrol` نُقل إلى dev_dependencies (لا استخدام بـ lib/).
- **حُذفت أيضاً** (صفر استيراد بـ lib/ و test/، مؤكَّد بـ grep): `connectivity_plus`، `flutter_rating_bar`، `flutter_svg`، `lottie`، `photo_view`، `smooth_page_indicator`، و`build_runner` (لم يبقَ أي مولّد كود). يقلّل حجم التطبيق وعدد الإضافات الأصلية.
- `flutter pub get` نجح؛ تحدّثت ملفات تسجيل الإضافات المولَّدة لـ macOS و Windows تلقائياً.

**البوابة:** analyze: No issues found. test: 355 نجاح.

### 8هـ — الشاليهات المحذوفة + الحدود وترقيم الصفحات + _gen
(تحقق من القاعدة الحية: الحذف من المالك يمر بـ trigger `prevent_hard_delete_chalet` فيصير `deleted_at = now(), is_available = false` (الأدمن وحده يحذف فعلياً)؛ سياسة `chalets_select_unified` **لا** تستبعد `deleted_at`، والمالك يستطيع إعادة `is_available=true` لاحقاً — فالفلتر بالعميل ضروري. `favorites.created_at` و`bookings.source` ('app'/'external') موجودان.)
- **المحذوفة لا تظهر:** `.isFilter('deleted_at', null)` بـ `getChalets` (الرئيسية/البحث/الخريطة)، `getFeaturedChalets`، `getOwnerChalets` (شاليهاتي، لوحة المالك، التقويم، الحجز اليدوي، حسابي). المفضلة والريلز: `chalets!inner` + فلتر `chalets.deleted_at`.
- **عطل مُصلَح بالمفضلة:** مفضلة لشاليه مخفي كانت ترجع `chalets = null` فيسقط `as Map` ويفشل تحميل المفضلة كلها.
- **ودجة مشتركة جديدة** `widgets/common/paged_list.dart`: `PagedList<T>` (صفحات + عدّاد جيل) و`LoadMoreFooter` — هي `_Pager` الخاصة بلوحة الأدمن بعد تعميمها؛ الأدمن صار يستخدمها (تطبيق واحد).
- `BookingService` (صفحات 30):
  - `getIncomingBookings({page})` ← "إدارة الحجوزات" بزر "تحميل المزيد".
  - `getUpcomingIncomingBookings(limit: 3)` + `countPendingIncomingBookings()` (عدّ بالسيرفر) ← لوحة المالك (كانت تجلب كل الحجوزات لتعرض 3 وعدداً). فشل كل منهما مستقل (`_upcomingFailed`/`_pendingFailed`).
  - `getManualBookings({upcoming, page})` ← الحجوزات اليدوية: `source='external'` والتقسيم على السيرفر (قادمة: `check_out > اليوم` بالأقرب؛ منتهية: الأحدث)، قسمان مرقّمان.
  - `getMyBookings({statuses, page})` ← "حجوزاتي": كل تبويب يُفلتر على السيرفر وله صفحاته (كانت تُجلب كلها ثم تُوزَّع).
  - `countMyBookings(status)` ← عدّاد "المكتملة" بحسابي.
- المفضلة `.limit(100)`، شاليهات المالك `.limit(200)` (سقف أمان).
- **محدودة أصلاً ولم تتغير:** التقويم (نافذة تواريخ)، إحصائيات المالك (أقصى مدى شهر)، جداول الأسعار (لكل شاليه)، قوائم الأدمن (مرقّمة من المرحلة 3)، الإشعارات (100)، الريلز (50)، الخريطة (1000 — العلامات تحتاج المجموعة كاملة؛ سقف ثابت مقصود).
- `owner_reports_screen`: عدّاد `_gen` — تبديل المدى بسرعة لم يعد يعرض نتيجة طلب أقدم.
- اختبار جديد: `paged_list_test.dart` (3).

**البوابة:** analyze: No issues found. test: 358 نجاح.

### 8و — كل catch فارغ
12 كتلة (فارغة أو تعليق فقط)، مسح آلي يؤكد صفر متبقٍّ بـ lib/:
- **SnackBar (إجراء من المستخدم):** زر "اتصال" بتقويم المالك — كان لا يفعل شيئاً إن لم يفتح تطبيق الاتصال؛ الآن يفحص ناتج `launchUrl` أيضاً ويعرض "تعذر فتح تطبيق الاتصال. الرقم: …".
- **Sentry عبر `reportError` (ثانوي/خلفي، السلوك المرئي كما هو):** upsert البروفايل بعد التسجيل، تنظيف شاليه فشل حفظه، أسعار شهر التقويم بشاشة الحجز، تقييمات تفاصيل الشاليه، قراءة/حفظ المدينة المفضلة وعدّاد الإشعارات بالرئيسية، شارات "قيد الانتظار" بتقويم المالك، حذف صور يتيمة بتعديل الشاليه، عدّاد الإشعارات بحسابي، `SupportContact.open` (المستدعي يعرض الرسالة أصلاً).
- `catchError((_) => …)` بقيم بديلة لم تُلمس: كلها تظهر بالواجهة ("—" أو "تعذر…").

**البوابة:** analyze: No issues found. test: 358 نجاح.

### ملفات كاملة بانتظار إذن الحذف (لم تُحذف)
| الملف | السبب |
|---|---|
| `lib/core/theme/shared_preferences_keys.dart` | ثابتان لا يستوردهما أي ملف |
| `lib/data/services/host_service.dart` | لم يعد له مستخدم بعد توحيد الصلاحيات (8ج) |
| `lib/presentation/screens/bookings/my_bookings_screen.dart` | سطر `export` واحد لا يستورده أحد |
| `lib/presentation/screens/reviews/reviews_screen.dart` | سطر `export` واحد؛ يستورده app_router فقط (يمكن استيراد favorites_screen مباشرة، أو يصير الملف الحقيقي بالمرحلة 9) |

### أسئلة التقرير
- **حذف الحساب:** غير موجود — لا خيار بالتطبيق ولا دالة بالقاعدة (بحث بالكود وبـ pg_proc). شاشة الخصوصية تقول "لديك الحق في طلب حذف بياناتك" بلا أي وسيلة للطلب (بيانات الدعم فارغة).
- **الخصوصية والشروط:** داخل التطبيق فقط (الإعدادات ← الخصوصية والأمان / الشروط والأحكام)، ولا أي رابط خارجي بالمشروع. الشروط نص مؤقت، ورابط "الشروط والأحكام" بشاشة التسجيل `onTap` فارغ (TODO).

## حذف الملفات الأربعة (بإذن) — ✅ `46ba737`
حُذفت: `shared_preferences_keys.dart`، `host_service.dart`، `bookings/my_bookings_screen.dart`، `reviews/reviews_screen.dart` (الراوتر يستورد `ReviewsScreen` من favorites_screen أصلاً). analyze نظيف، 358 نجاح.

## حذف الحساب — ✅ منتهية
(تحقق من القاعدة الحية بقراءة فقط: `delete_my_account()` بلا معاملات، SECURITY DEFINER، ترجع `{deleted: true}`؛ ترفض برمز P0001: الأدمن، "لديك شاليهات مسجلة…"، "لديك حجوزات قادمة…"؛ تفك ربط الحجوزات (`user_id = NULL`، `guest_name = COALESCE(guest_name,'مستخدم محذوف')`، `guest_phone = NULL`) ثم تحذف مستخدم auth. `bookings.user_id` صار nullable.)
- `AuthService.deleteMyAccount()`: الدالة، ثم **خروج محلي** (`SignOutScope.local`): المستخدم حُذف من auth فطلب الخروج من الخادم بلا معنى وقد يفشل؛ الخروج يطلق `signedOut` فتُحدَّث المفضلة/البروفايل (main.dart) ويزيد `rolesEpoch`.
- `accountDeletionErrorMessage`: رفض الخادم المقصود (P0001/42501) يُعرض **حرفياً**؛ أي خطأ آخر ← "تعذر حذف الحساب، يرجى المحاولة لاحقاً" + Sentry (المترجم العام يمرّر نص Postgres الخام، فلم أعتمد عليه هنا).
- **الخصوصية والأمان:** زر "حذف الحساب" أحمر (لصاحب الحساب فقط) ← حوار يشرح ما يُحذف (البيانات الشخصية، المفضلة، التقييمات، الإشعارات)، أن الحجوزات السابقة تبقى عند المالك باسم "مستخدم محذوف" بلا هاتف، وأنه نهائي؛ زر "حذف نهائياً" لا يتفعّل إلا بكتابة "حذف". النجاح ← "تم حذف حسابك" والرئيسية كضيف؛ الرفض ← رسالة الخادم ويبقى المستخدم.
- وعد "حقك في حذف بياناتك" صار: 'لديك الحق في حذف حسابك وبياناتك، من زر "حذف الحساب" أدناه.' والزر تحته مباشرة.
- **user_id = null:** `BookingModel.userId` صار `String?` (كان `as String` يُسقط كل قائمة حجوزات المالك عند أول حجز لحساب محذوف). قاعدة عرض واحدة بـ `ManualBookingX`: `displayGuestName/displayGuestPhone` (اليدوي وحجز الحساب المحذوف من أعمدة الحجز، غيرهما من البروفايل) + `isFromDeletedAccount`. مستخدمة في إدارة الحجوزات (بلا صورة بروفايل)، التقويم وورقة اليوم، ولوحة المالك. شاشات الأدمن لا تعرض صفوف حجوزات (الإحصائيات من RPC)، ولا مقارنة بـ `userId` بأي مكان.
- **رابط الشروط بالتسجيل:** `_TermsScreen` نُقلت إلى `settings/terms_screen.dart` (`TermsScreen` عامة)، والرابط يفتحها؛ الـ `TapGestureRecognizer` صار يملكه الـ State ويُحرَّر (كان يُنشأ بكل build).
- اختبارات: `account_deletion_test.dart` (10: نجاح، رفض بحجوزات، رفض بشاليهات، إلغاء الحوار، الضيف، الزر معطّل قبل "حذف"، رسائل الخطأ، 3 لحجز محذوف/قائم/يدوي) و`register_terms_link_test.dart`.

**البوابة:** analyze: No issues found. test: 369 نجاح.

## المرحلة 9: ترتيب الملفات — 🔄 جارية (tag `before-phase9` = `c2a8b35`)
**الآلية:** نقل فقط. النقل بين المجلدات بسكربت يعيد حساب كل import/export نسبي و`package:makan/` بعد `git mv`. التقسيم:
- الكلاسات المستقلة ← ملفات/مكتبات منفصلة كما هي.
- ما يتشارك رموزاً خاصة (`_x`) ← ملفات `part` (المكتبة نفسها، بلا أي إعادة تسمية)؛ `services.dart` و`models.dart` صارا مجرد imports + `part` فلا يتغير أي استيراد بالمشروع.
- الشاشات ذات الـ State الواحد الضخم: دوال `_build…` تُنقل **حرفياً** إلى ملفات `part` كـ extension خاص على الـ State. (الجدول قال "ودجات StatelessWidget"؛ عدلت للآلية الأقل خطراً لأن النص ينتقل كما هو.) extension لا يستطيع استدعاء `setState` المحمي بلا تحذير analyzer (مُثبت باختبار)، فالمنقول يستدعي `_setState` — سطر واحد بالـ State يمرّر لـ `setState`؛ والثوابت `static` التي يحتاجها تصير ثوابت خاصة بمستوى المكتبة.

| commit | ما نُفّذ |
|---|---|
| `042b97b` | `unavailable_nights.dart` ← `rpc_caller.dart`؛ `locale_notifier` و`app_state_providers` ← `core/settings/` |
| `dfe97ed` | `payment_widgets` ← `payment/widgets/`، `payment_theme` ← `payment/` (حُذف مجلدا `screens/widgets` و`screens/theme` الفارغان) |
| `808a82e` | `owner/` ← `bookings/`، `calendar/`، `chalet_form/`، `pricing/`؛ `owner_notifications_screen` ← `owner/`. اختبار `chalet_edit_screen_test` يقرأ مصدر شاشة الإضافة بمسارها — حُدّث المسار فقط |
| `0454708` | `favorites_screen` (1088) ← `favorites/` (228) + `bookings/my_bookings_screen.dart` (521) + `reviews/reviews_screen.dart` (375) |
| `dc35914` | `services.dart` (1204) ← 6 أجزاء (أكبرها booking_service 341)؛ `models.dart` (272) ← 3 أجزاء |

⚠️ حادثة وحيدة: أمر تقسيم models.dart نُفّذ مرتين (الأول بالرد الذي قاطعه "اكمل")، فالثاني كتب فوق ملفات الأجزاء بمحتوى فارغ. لم يُفقد شيء: models.dart لم يكن مُلتزماً، استُرجع من git وأُعيد التقسيم مرة واحدة؛ والسكربت صار يرفض الكتابة فوق ملف موجود أو نطاق خارج الملف.

كل commit: analyze نظيف + 369 نجاح.

### تقسيم الشاشات الكبيرة (تكملة المرحلة 9)
كل commit: analyze نظيف + 369 نجاح. الأرقام = أسطر الملف الرئيسي بعد التقسيم + الأجزاء.

| commit | الملف (قبل) | بعد |
|---|---|---|
| `2997448` | owner_calendar_widgets (1161)، owner_calendar_screen (1199) | widgets: 19 + calendar_day_cell 414، owner_day_panel 574، range_action_bar 155؛ screen: 833 + calendar_month_grid 291، calendar_chalet_selector 89 |
| `55c08bc` | admin_dashboard_screen (1025) | 245 + overview_tab 224، chalet_approvals_tab 244، users_tab 319 |
| `a43f187` | profile_screen (840) | 755 + edit_profile_sheet 88 |
| `032e97d` | manual_booking_sheet (1004) | 556 + manual_booking_models 97، manual_booking_sections 364 |
| `092deb4` | owner_dashboard_screen (986) | 568 + widgets/dashboard_upcoming_section 213، dashboard_actions_section 215 |
| `d29cb14` | chalet_pricing_screen (1587) | 916 + date_override_dialog 77، stay_type_card 275، weekday_prices_section 211، date_overrides_section 124 |
| `3d28a9d` | owner_edit_chalet_screen (1646) | 850 + edit_chalet_sections 398، edit_chalet_location_media 412 (جزءان بدل واحد بالجدول، حتى لا يقترب جزء من 800) |
| `ed0042e` | search_screen (1023) | 762 + search_filters_sheet 270 |
| `3881da8` | home_tab (1281) | 296 + widgets/city_picker_sheet 145، home_header 292، home_sections 566 |
| `ac20f7a` | chalet_detail_screen (1608) | 627 + widgets/chalet_detail_header 266 (إضافي على الجدول)، chalet_detail_sections 384، chalet_reviews_section 157، review_item 87، full_screen_gallery 108 |
| `d7e3d73` | booking_screen (1853) | 638 + widgets/booking_success_dialog 157، booking_header 189 (إضافي)، booking_calendar_section 367، booking_form_sections 313، booking_price_summary 214 |

**التعديلات النصية الوحيدة داخل المنقول** (كلها بلا أثر سلوكي): `setState(` ← `_setState(` بالأجزاء (عددها = عدد تحذيرات analyzer بالضبط، وفُحص أن لا `StatefulBuilder` يُظلّل اسم `setState` بأي جزء — ورقة فلاتر البحث تستخدم `setSheetState` فلم تُلمس)؛ والثوابت `static` المستخدمة بالأجزاء صارت مؤهَّلة باسم الكلاس (`_BookingScreenState._darkGreen` …).

**⛔ لم يُقسَّم (تراجع حسب القاعدة):** `owner_add_chalet_screen.dart` (1332). بعد تقسيمه فشل اختبار واحد: `chalet_edit_screen_test` ← "تسمية location موحّدة على المنطقة/الحي"، لأن الاختبار **يقرأ نص الملف الرئيسي** ويبحث عن `label: 'المنطقة/الحي'` الذي انتقل لجزء الخطوات. لا تغيير سلوك، لكن حسب القاعدة استُرجع الملف كما هو. الحل المقترح (بانتظار موافقتك): يقرأ الاختبار الملف الرئيسي + أجزاءه، ثم يُعاد التقسيم (727 + add_chalet_steps 436 + add_chalet_widgets 180).

**النتيجة:** 138 ملف dart بـ lib/؛ لا ملف > 916 سطراً عدا شاشة الإضافة (1332)؛ ثلاثة بين 800 و916 (pricing 916، edit 850، calendar 833 — منطقها المتشابك يبقى بالـ State).

## الأدمن داخل لوحة الإدارة فقط — ✅ `6390781`
(يعدّل تجربة `bb793c0`: الأدمن لم يعد يتصفح التطبيق إطلاقاً. تحقق بقراءة فقط من RLS: `chalets_select_unified` و`profiles_select_unified` تسمحان للأدمن بقراءة الشاليه غير المعتمد وبروفايل مالكه، و`chalet_stay_types_select_all` مفتوحة.)
- **الراوتر:** منطق التوجيه صار دالة واحدة قابلة للاختبار `AppRouter.resolveRedirect`. الأدمن المسجَّل: كل مسار غير `/admin-dashboard` (home، search، map، تفاصيل الشاليه، booking، payment، reviews، notifications، كل `owner-*`) يعيده للوحة، بما فيها الروابط المباشرة، و`/onboarding` (فتح التطبيق بجلسة محفوظة) و`/auth/*` بعد الدخول. يستخدم كاش الصلاحيات `currentUserProfile`؛ الضيف لا يُستعلم عن بروفايله. `isAdminBlockedRoute` ← `isAdminRoute` (قائمة سماح).
- **الدخول:** الأدمن ← `/admin-dashboard` مباشرة، ويُهمل أي إجراء زبون معلّق.
- **حُذف:** شريط `AdminModeBanner` (والملف) وزر "تصفّح التطبيق".
- **ترويسة اللوحة** (`AdminDashboardHeader`، الكحلي والذهبي كما هما): زر الإعدادات ← `SettingsScreen(languageAndThemeOnly: true)` (اللغة والوضع المظلم فقط)، وزر "تسجيل الخروج": تأكيد ← `signOut` ← `/home` كضيف (main.dart يحدّث البروفايل/المفضلة عند signedOut).
- **مراجعة الشاليه** (`AdminChaletReviewScreen`): الضغط على بطاقة شاليه معلّق يفتحها. تعرض الصور (معرض بعدّاد)، الوصف، المدينة/الحي/العنوان/الإحداثيات + فتح بالخريطة، المرافق والسعة، السعر الأساسي والعربون، الفترات المفعّلة بأوقاتها وأسعارها (سعر الفترة أو السعر الأساسي؛ بلا فترات = "يوم كامل")، المالك: الاسم والهاتف والبريد + اتصال، والفيديو إن وُجد. بلا قلب ولا زر حجز. أسفلها "اعتماد" (حوار تأكيد جديد) و"رفض" (حوار "رفض وحذف" الموجود)؛ بعد القرار تُغلق وتُزال البطاقة من القائمة؛ الفشل يعرض رسالة الدالة ويبقى. (أزرار الموافقة/الرفض السريعة على البطاقة حُذفت لاحقاً — انظر أدناه.)
- `AdminService.getChaletForReview` + `AdminChaletReview`.
- **باقٍ من `bb793c0`:** الهوية الكحلية/الذهبية، إخفاء المفضلة/الحجوزات/القلب/"احجز الآن"/وضع المالك للأدمن (صار احتياطياً لأن الأدمن لا يصل لهذه الشاشات).
- اختبارات (`admin_mode_test.dart`، 16): التوجيه بعد الدخول وعند فتح التطبيق، كل مسارات الزبون/المالك، رابط مباشر عبر GoRouter، الزبون/المالك/الضيف بلا تغيير، الترويسة بلا "تصفّح التطبيق"، الخروج (تأكيد/إلغاء) ← الرئيسية كضيف، إعدادات اللغة والثيم فقط، شاشة المراجعة (كل التفاصيل، بلا حجز ولا قلب، اعتماد، رفض، فشل).

**البوابة:** analyze: No issues found. test: 397 نجاح.

## تصغير الصور — ✅ `789c128`
- `onboarding_bg.jpg` (2.19 MB — كان PNG فعلياً باسم jpg، 853×1844) ← `onboarding_bg.webp` جودة 80 (166 KB). عرضه أصلاً أقل من 1080 فلم يُصغَّر.
- `logo.png` (1302×1253، 469 KB) ← 512×493 (112 KB) مع الشفافية. أكبر عرض له 150dp (450px على 3×).
- حُدّثت المراجع (onboarding، ترويسة الدخول، pubspec). المقارنة بالحجم الحقيقي بلا فرق مرئي. الأدوات: sharp في مجلد مؤقت خارج المشروع (لا تبعيات جديدة).
- `assets_test.dart`: الصورتان تُفكّان بمحرّك Flutter وضمن الحدود.

**البوابة:** analyze: No issues found. test: 399 نجاح.

## شاشة المراجعة الطريق الوحيد للقرار — ✅
- حُذف زرا "موافقة" و"رفض" السريعان من بطاقة الشاليه المعلّق (ومعهما `_approve`/`_reject`/`_actionLoading` بالتبويب). الاعتماد والرفض من شاشة المراجعة فقط؛ الضغط على البطاقة يفتحها (مع منع فتح شاشتين بضغطتين سريعتين)، وعليها سهم وتلميح "اضغط لمراجعة التفاصيل والاعتماد أو الرفض".
- البطاقة صارت ودجة عامة `PendingChaletCard` لتُختبر بلا Supabase. اختبار جديد: لا أزرار عليها، والضغط يستدعي فتح المراجعة.

**البوابة:** analyze: No issues found. test: 400 نجاح.
