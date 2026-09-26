# تحقق مستقل من إصلاحات الإطلاق

- **الجولة 1 (تحقق):** 2026-09-26، commit `d510540`. قراءة فقط، بلا أي تعديل في `lib/` أو `test/`، وبلا اعتماد على سجلات الإصلاح. كل حكم مبني على الكود نفسه، ومعه الملف والسطر أو نتيجة grep/سكربت.
- **الجولة 2 (إصلاح):** 2026-09-26، من `6491484` إلى `15df1ce` (10 commits). كل commit مرّ بالبوابة: `flutter analyze` بلا ملاحظات، وكل الاختبارات تنجح. الحالات أدناه هي **الحالية** بعد الجولة 2، والبند الذي تغيّرت حالته مكتوب بجانبه "(كان …)".
- قاعدة البيانات الحية (`jugnkxeqqgtoerlknadm`): استعلامات `SELECT` فقط على `pg_policies` و`pg_proc` و`pg_trigger` و`pg_constraint` و`information_schema`.
- المسارات هي الحالية بعد نقل الملفات وتقسيمها بالمرحلة 9.

## 0) البوابة

| الفحص | الجولة 1 (`d510540`) | الجولة 2 (`15df1ce`) |
|---|---|---|
| `flutter analyze` | No issues found! | **No issues found!** |
| `flutter test` | 369 نجاح، 0 فشل | **377 نجاح، 0 فشل** (+4 `dashboard_range_test`، +3 `booking_action_error_test`، +1 رسالة الشاليه غير المتاح) |

> ملاحظة: تشغيل واحد بالجولة 2 أعطى 306 نجاح و2 فشل من 308. السبب أن `flutter clean`/`build` شُغِّلا بالتوازي معه. بعد `flutter pub get` وإعادة التشغيل وحده، نجحت الاختبارات الـ 373 كلها بنفس الكود.

---

## 1) بنود `99_summary.md`

### 🔴 الحرجة

| # | البند | الحالة | الدليل |
|---|---|---|---|
| C1 | منح/سحب `is_admin` بتحديث مباشر لـ profiles، والحظر بلا تأكيد | ✅ | `admin_service.dart`: `toggleUserAdmin` و`toggleUserActive` و`approveChalet` و`rejectChalet` تمر كلها عبر `_rpc('admin_*')`. grep `.update(`/`.delete(` في `screens/admin/` يرجع 0 نتيجة. حوار تأكيد قبل الحظر `users_tab.dart:84`، وقبل تغيير الصلاحية `:114`، وقبل الرفض/الحذف `chalet_approvals_tab.dart:76`. |
| C2 | قراءات لوحة الأدمن مباشرة من الجداول وتعتمد على RLS غير مؤكَّدة | ✅ | الإحصائيات تأتي من RPC `admin_get_overview_stats`. بقيت قراءتان مباشرتان مرقّمتان: الشاليهات المعلّقة `:89` والمستخدمون `:106`. **RLS الحية:** `profiles_select_unified` = `id = auth.uid() OR is_current_user_admin()`، و`bookings_select_unified` = أدمن أو مالك الشاليه أو صاحب الحجز. وtrigger `protect_profile_privilege_on_update` يعيد `is_admin/is_owner/role/is_active` لقيمها القديمة لغير الأدمن. |
| C3 | الريلز تهيّئ مشغّلاً لكل عنصر | ✅ | `reels_screen.dart`: `_windowRadius = 1`، و`_activeWindow()` تُرجع الحالي ±1 فقط، وكل ما يخرج من النافذة يُحرَّر بـ `_releaseControllerForIndex`. |

### 🟠 المتوسطة

| # | البند | الحالة | الدليل |
|---|---|---|---|
| M1 | UPDATE على bookings/availability بلا فحص عدد الصفوف | ✅ | `booking_service.dart` (`_setIncomingBookingStatus`، `cancelBooking`: `.select('id')` ثم رمي خطأ عند 0 صف)، و`owner_calendar_data_source.dart` (`unblockDates`). |
| M2 | `Future.wait` يُسقط لوحة المالك | ✅ | `owner_dashboard_screen.dart`: الطلبات متوازية، ولكل طلب ثانوي `catchError` مستقل. وفشل الإحصائيات نفسها يصل الآن لحالة الخطأ (N1). |
| M3 | `Future.wait` بإدارة الحجوزات | ✅ | `owner_bookings_screen.dart`: تحميل تسلسلي، والعدّاد بـ `catchError`. |
| M4 | `Future.wait` بشاليهاتي | ✅ | `owner_chalets_screen.dart`: نفس النمط. |
| M5 | عدم تناظر "مشغول" بين القبول والرفض | ✅ | `_decide` مشترك بـ `owner_bookings_screen.dart`؛ و`onStart` بعد الحوار وقبل الطلب في المسارين (`owner_booking_actions.dart:84`، `:119`). |
| M6 | الإيرادات تُحسب بجلب كل الصفوف وجمعها بـ Dart | ⚠️ | **الأدمن:** الحساب على السيرفر. **المالك:** ما زال يجمع في Dart، لكن القراءة الخام صارت بسقف `.limit(statsRowsLimit)` = 5000، وبلوغه يُسجَّل بـ Sentry (`dashboard_service.dart:156`، `:194-202`)، وأطول نطاق شهر. لا توجد دالة تجميع على السيرفر بعد. |
| M7 | الإعدادات: اللغة لا تتحدث، والعملة بلا أثر | ✅ | `settings_screen.dart:35` تستخدم `ref.watch(localeNotifierProvider)`، ولا يوجد إعداد عملة. |
| M8 | profile_screen: شاشة إشعارات مكررة، `characters.first`، `mounted` | ✅ | `NotificationsScreen` مرة واحدة فقط. الحارس في `profile_screen.dart:629-633`. و`edit_profile_sheet.dart:36`/`:39` فيهما `mounted`. |
| M9 | البحث يرسل `minGuests=2` بصمت | ✅ | `search_screen.dart:58` فيها `int? _guests` (null افتراضياً)، و"مسح الكل" وحذف الشريحة يعيدانها null. |
| M10 | عمولة وهمية 5% في `payment_flow_entry` | ✅ | `subtotal: totalPrice` (سعر السيرفر). |
| M11 | أزرار شاشة نجاح الدفع بلا وظيفة | ✅ | "عرض الحجز" ← `goToMainTab(context, 3)`، وزرا المشاركة والتقويم محذوفان. |
| M12 | `_uploadNewImages` ميتة، ولا زر رجوع بالمعالج | ✅ | grep `_uploadNewImages` = 0، و`_handleStepCancel` مربوطة بزر "السابق" وبالرجوع. |
| M13 | الأسعار: أرقام عربية، تسريب Controller، `mounted` | ✅ | `parseLocalizedDouble` بكل حقول الأسعار؛ `_DateOverrideDialogState` يتخلّص من متحكميه؛ فحص `mounted` بعد الحذف. |
| M14 | `pricing_service`: الكتابة بلا try/catch | ✅ | كل دوال الكتابة تمر عبر `_write`. |
| M15 | صورة Unsplash بديلة | ✅ | grep `unsplash\|picsum` = 0. |

### 🟡 البسيطة

| # | الموضوع | الحالة | الدليل |
|---|---|---|---|
| m1 | خلل DST في فرق التواريخ | ✅ (كان ⚠️) | `nightsBetween` بـ `DateTime.utc`، و`nextDay` بـ `DateTime(y,m,d+1)`. ونطاقات لوحة المالك صارت تقويمية: `dateRangeFor` (`dashboard_service.dart:36-51`: `DateTime(y, m, d - 1)`، `DateTime(y, m, d - 6)`، `DateTime(y, m, 0)`) و`endExclusive = nextDay(end)` (`:181`). grep `Duration(days: 1)` في lib لا يجد إلا تعليقاً (`pricing_service.dart:477`). اختبار `dashboard_range_test.dart`. |
| m2 | تطبيع الأرقام العربية مكرر | ✅ | تعريف واحد في `number_utils.dart`، و`parseManualPrice` يغلّف `parseLocalizedDouble`. |
| m3 | ازدواجيات (Notification*، isHost/isAdmin، Shimmer) | ✅ | كل منها تطبيق واحد: `user_profile.dart:31`، و`ShimmerCard`. |
| m4 | كود ميت | ✅ | grep لكل اسم = 0 تعريف. |
| m5 | سباق تبديل المدى بالتقارير | ✅ | `owner_reports_screen.dart` (`_gen`). |
| m6 | استعلامات بلا حد | ✅ | الحجوزات الواردة مرقّمة، و`getUpcomingIncomingBookings(limit: 3)`، والمفضلة والإشعارات والريلز محدودة، وإحصائيات المالك بسقف 5000. الخريطة 1000 سقف ثابت مقصود. |
| m7 | أزرار دعم بلا وظيفة وبيانات تواصل متضاربة | ✅ | `support_contact.dart` مصدر واحد، والواجهات مشروطة بـ `hasAny`. البيانات نفسها فارغة (N9). |
| m8 | إمكانية الوصول: ورقة الحجز اليدوي تستخدم `TableCalendar` | ❌ **مؤجَّل بقرار** | `manual_booking_sections.dart:118` و`booking_calendar_section.dart` ما زالتا `TableCalendar`، مع وصف `Semantics` للأيام الجزئية فقط. لم يُلمس حسب التعليمات. |
| m9 | `catch` فارغ صامت | ✅ | سكربت المسح = 0. `catchError` بتعليق فقط في `reels_screen.dart` مقصود (الخطأ يُعرض عبر `_LoadingOverlay`). |
| m10 | "حجوزات مؤكدة اليوم" تشمل pending | ✅ (كان ❌) | حقل جديد `OwnerDashboardStats.confirmedBookings` يعدّ `confirmed` و`completed` فقط، وهي نفس الحجوزات التي تُحسب بالإيرادات (`dashboard_service.dart:77`، `:248`)، ويستخدمه `owner_dashboard_screen.dart:447` بدل "الإجمالي ناقص الملغاة". |
| m11 | `.withOpacity()` | ✅ | 0 في كل الملفات. |
| m12 | قوائم مدن غير متطابقة | ✅ | `AppStrings.cities` مصدر وحيد. |
| m13 | اسم شهر واحد لحجز يمتد على شهرين | ✅ | `BookingModel.dateLabel` تعرض شهر كل تاريخ. |
| m14 | تكرار "مزايا الحجز" واستيراد material مزدوج | ✅ | قسم واحد، واستيراد واحد. |
| m15 | زر المسح في `LuxurySearchBar` لا يتحدّث | ✅ | `ValueListenableBuilder` على الـ controller. |

### أهم 10

| # | البند | الحالة | الدليل |
|---|---|---|---|
| T1 | تحقق RLS لجداول الأدمن | ✅ | C2. |
| T2 | صلاحية الأدمن عبر RPC + تأكيد الحظر | ✅ | C1. |
| T3 | مشغّلات الريلز | ✅ | C3. |
| T4 | فحص عدد الصفوف | ✅ | M1. |
| T5 | `Future.wait` بالشاشات الثلاث | ✅ | M2 إلى M4. |
| T6 | الحسابات المالية على السيرفر | ⚠️ | M6. |
| T7 | الأزرار بلا وظيفة | ✅ | M11، m7، L8. |
| T8 | `minGuests=2` | ✅ | M9. |
| T9 | توحيد isHost/isAdmin والإشعارات | ✅ | m3. |
| T10 | الضغط المزدوج + normalizeDigits + DST | ✅ (كان ⚠️) | M5، m2، m1. |

---

## 2) بنود ظهرت لاحقاً

| # | البند | الحالة | الدليل |
|---|---|---|---|
| L1 | كل حجز = يوم واحد + فترة واحدة | ✅ | لا `rangeSelectionMode`/`DateTimeRange` في lib. `_checkOut = nextDay(_date)` في `booking_screen.dart:52` و`manual_booking_sheet.dart:152`. والقاعدة فيها trigger `enforce_single_day_booking`. |
| L2 | لا أثر لـ `min_nights` بمنطق الحجز | ✅ | لا يظهر في lib إلا في تعليقين. |
| L3 | الريلز: حالة فارغة، ولا تشغيل والتبويب مخفي | ✅ | حالة فارغة وحالة خطأ بإعادة المحاولة؛ `ReelsScreen(active: _currentIndex == 4)`، و`_activeWindow()` تُرجع `{}` حين `!widget.active`. وأُزيل المسار المستقل `/reels` غير المستخدم (N8). |
| L4 | الشاليهات المحذوفة لا تظهر في أي قائمة | ✅ | `isFilter('deleted_at', null)` في getChalets وfeatured وgetOwnerChalets والأدمن، و`chalets!inner` مع فلتر في المفضلة والريلز. والخادم يرفض الآن الحجز عليها (N3). |
| L5 | حذف الحساب يعمل، و`BookingModel.userId` يقبل null | ✅ | `auth_service.dart` (`delete_my_account` ثم خروج محلي)؛ الدالة الحية SECURITY DEFINER وبلا تنفيذ لـ anon؛ `bookings.user_id` nullable؛ `BookingModel.userId` هو `String?`، ولا يوجد استخدام لـ `.userId` خارج النموذج. |
| L6 | لا عرض لنسبة عمولة في أي شاشة | ✅ (كان ❌) | مفتاح واحد `kShowPlatformCommission = false` (`pricing_constants.dart:13`) يخفي تفاصيل العمولة (`owner_bookings_screen.dart:416`: `if (kShowPlatformCommission && !isManual)`). النسبة باقية ثابتاً واحداً `kPlatformCommissionPercentage` للاستخدام لاحقاً. لا توجد شاشة أخرى تعرض نسبة (شاشة الضيف بلا عمولة، و"إيرادات المنصة" عند الأدمن مبلغ). |
| L7 | لا `catch` فارغ في lib | ✅ | m9. |
| L8 | لا زر أو رابط بلا وظيفة | ✅ | سكربت المسح = 0 callback فارغ؛ كل وجهات `context.go/push` مسجّلة بالراوتر. |

---

## 3) ملخص

| القسم | ✅ | ⚠️ | ❌ |
|---|---|---|---|
| الحرجة (3) | 3 | 0 | 0 |
| المتوسطة (15) | 14 | 1 | 0 |
| البسيطة (15) | 14 | 0 | 1 |
| أهم 10 | 9 | 1 | 0 |
| البنود اللاحقة (8) | 8 | 0 | 0 |
| **المجموع (51)** | **48** (كان 44) | **2** (كان 4) | **1** (كان 3) |

- **❌ الوحيد:** m8 (`TableCalendar` في ورقة الحجز اليدوي). مؤجَّل بقرار.
- **⚠️:** M6/T6 (إحصائيات المالك تُجمع في Dart، لكنها محدودة بسقف وتُظهر الفشل).

---

## 4) المشاكل الجديدة من الجولة 1 ومآلها

| # | المشكلة | الحالة | ما تغيّر |
|---|---|---|---|
| N1 | `getOwnerDashboardStats` تبتلع الفشل وتُرجع أصفاراً | ✅ | لم يعد في الدالة try/catch: الفشل يُرمى للمستدعي، فتعرض اللوحة (`_error` + "إعادة المحاولة") والتقارير (`'تعذر تحميل التقارير'` + "إعادة المحاولة") حالة الخطأ. `empty()` صارت لغير المسجّل فقط (`dashboard_service.dart:176`). |
| N2 | DST في نطاقات لوحة المالك | ✅ | m1. |
| N3 | الشاليه المحذوف: `getChaletById` بلا فلتر، والخادم لا يفحص `deleted_at` | ✅ للحجز / ℹ️ للعرض | **الخادم:** trigger `trg_enforce_bookable_chalet` مفعّل، `BEFORE INSERT ON bookings` (تحقّقت منه على القاعدة الحية)، يرفض أي شاليه `deleted_at IS NOT NULL`، ويرفض حجوزات التطبيق على شاليه غير معتمد أو غير متاح، برسالة `'هذا الشاليه لم يعد متاحاً للحجز'` (P0001). **التطبيق:** `chaletNotBookableMessage` تُعرض كما هي (`supabase_errors.dart:19`، `:49-51`). أما فتح التفاصيل بالرابط فيبقى محمياً بـ RLS فقط (`getChaletById` بلا فلتر)، لكنه لم يعد يسمح بالحجز. |
| N4 | ورقة فلاتر البحث تحرّر المتحكمات أثناء حركة الإغلاق | ✅ | `_SheetPriceControllers` (StatefulWidget) يملك المتحكمين ويحرّرهما في `dispose()` الخاص به، أي بعد إزالة الورقة من الشجرة (`search_filters_sheet.dart:273-303`). لا توجد اختبارات لشاشة البحث لأنها تستدعي Supabase مباشرة. |
| N5 | `_setState` بعد await بلا `mounted` في منتقي المدن | ✅ | `city_picker_sheet.dart:132` (`if (!mounted) return;`). |
| N6 | `onStart` بعد الحوار بلا `mounted` | ✅ | `if (!context.mounted) return false;` قبل `onStart` في المسارين (`owner_booking_actions.dart:82`، `:117`). |
| N7 | فشل القبول/الرفض يُسقط رسالة الخادم | ✅ | `bookingActionErrorMessage` (`owner_booking_actions.dart:12`) تعرض الرسالة إن كانت فيها حروف عربية وليس فيها لاتينية (مثل `bookingNotUpdatedMessage` و`periodTakenMessage`)، وإلا الرسالة العامة. اختبار `booking_action_error_test.dart`. |
| N8 | المسار `/reels` غير مستخدم | ✅ | حُذف المسار، وحُذف من قائمة المسارات العامة، وحُذف استيراده من `app_router.dart`. الريلز تبقى تبويباً داخل `MainScreen`. |
| N9 | نص الشروط مؤقت، وبيانات الدعم فارغة | ℹ️ بانتظار المستخدم | `terms_screen.dart:37`؛ `app_strings.dart:13-14`. |
| N10 | `owner_add_chalet_screen.dart` = 1332 سطراً | ✅ | قُسّم إلى 727 + `add_chalet_steps` (436) + `add_chalet_widgets` (180). النقل حرفي: إعادة بناء الأصل من الملفات الثلاثة طابقت HEAD سطراً بسطر (0 فروق). والتعديلات الوحيدة `setState(` ← `_setState(` (8 مواضع) وتأهيل `_darkGreen`. اختبار `chalet_edit_screen_test` صار يقرأ المكتبة كاملة (الملف الرئيسي + أجزاؤه). أكبر ملف في lib الآن `chalet_pricing_screen.dart` (916). |

### إصلاح إضافي: بناء الإصدار (patrol)
- **المشكلة:** `GeneratedPluginRegistrant.java` كان يسجّل `pl.leancode.patrol.PatrolPlugin` رغم أن `patrol` في dev_dependencies.
- **الفحص:** لا يوجد أي ملف dart يستورد `package:patrol`، ولا مجلد `integration_test/` أو `patrol_test/` أو `test_driver/`، ولا ذكر له في أي ملف إعداد غير `pubspec.yaml`.
- **الإجراء (`15df1ce`):** حُذف من `pubspec.yaml`، ثم `flutter clean` و`flutter pub get`.
- **التحقق:**
  - `pubspec.lock` لم يعد يحتوي patrol ولا حزمه التابعة (`patrol_finders`، `patrol_log`، `dispose_scope`، `equatable`، `json_annotation`، `shelf`)، ولا شيء في lib/test يستوردها مباشرة.
  - grep `patrol` في `GeneratedPluginRegistrant.java` (أعيد توليده بـ 15 إضافة) وفي سجلّات iOS وmacOS وWindows وLinux = 0.
