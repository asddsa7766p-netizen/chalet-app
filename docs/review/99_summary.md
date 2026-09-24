# الملخص النهائي — مراجعة تطبيق Makan (مكان)

مبني على مراجعة كل ملف تحت `lib/` (14 دفعة، أكثر من 90 ملفاً)، بمقارنة مستمرة مع سلوك الـ backend الموصوف من المستخدم (triggers لحساب السعر النهائي ومنع تعارض الحجوزات وحماية حقول الدفع/الحالة، ودوال RPC مثل `is_chalet_available`, `create_external_booking`, `cancel_external_booking`, `toggle_favorite`, `become_owner/customer`, `admin_*`). التفاصيل الكاملة لكل ملف موجودة تحت `docs/review/files/**`. هذا الملف يجمع النتائج فقط ولا يضيف ادعاءات جديدة لم تُشتق من تلك المراجعات.

**تذكير بحدود المراجعة:** لم تُفحَص سياسات RLS الفعلية بلوحة Supabase مباشرة — كل استنتاج يعتمد عليها مذكور صراحة كـ"يحتاج تحقق مباشر" في مكانه. ملفات `supabase/*.sql` المحلية قديمة/غير مطابقة للـ backend الموصوف، فلم تُستخدَم كمرجع.

---

## 1) جدول المشاكل مرتبة حسب الخطورة

### 🔴 حرجة

| الملف | السطر | المشكلة | الإصلاح المقترح |
|---|---|---|---|
| [admin/admin_dashboard_screen.dart](files/presentation/screens/admin/admin_dashboard_screen.md) | — | منح/سحب صلاحية `is_admin` عبر تحديث مباشر لجدول `profiles` من التطبيق (لا RPC)، يعتمد بالكامل على RLS غير مؤكَّدة؛ حظر مستخدم بضغطة واحدة بلا حوار تأكيد | نقل المنطق لدالة RPC خادمية (`admin_grant/revoke`) بصلاحيات SECURITY DEFINER محكومة، وإضافة حوار تأكيد قبل الحظر |
| [data/services/admin_service.dart](files/data/services/admin_service.md) | — | لا يُستخدَم أي من دوال `admin_*` الموصوفة من المستخدم؛ كل قراءات لوحة الإدارة (مستخدمين/حجوزات/شاليهات كل المنصة) مباشرة على الجداول، تعتمد كلياً على RLS غير مؤكَّدة من هذه المراجعة | **يحتاج تحقق مباشر وعاجل بلوحة Supabase**: هل RLS تمنع فعلياً غير الأدمن من قراءة بيانات كل المستخدمين؟ إن لم تكن مضبوطة، فهذه ثغرة تسريب بيانات حقيقية. الأصوب استبدال القراءات المباشرة بدوال `admin_*` RPC |
| [reels/reels_screen.dart](files/presentation/screens/reels/reels_screen.md) | — | `_togglePlaybackForVisibleIndex()` يهيّئ مشغّل فيديو لكل عنصر بالقائمة دفعة واحدة، وليس فقط العنصر المرئي حالياً | تهيئة/تخريب (`dispose`) المشغّلات حسب الظهور الفعلي فقط (نافذة صغيرة حول الفهرس الحالي)، بنفس فلسفة `PageView`/`ListView.builder` الكسول |

### 🟠 متوسطة

| الملف | السطر | المشكلة | الإصلاح المقترح |
|---|---|---|---|
| [data/services/services.dart](files/data/services/services.md) + 3 مستهلِكين | — | **جذر مشترك:** `confirmIncomingBooking`/`rejectIncomingBooking` (وتحديثات مشابهة) تحديثات مباشرة على `bookings` بلا `.select()`/فحص عدد صفوف. رفض RLS صامت (0 صف) لا يرمي استثناءً → رسالة "نجاح" كاذبة للمالك. مؤكَّد بأثر فعلي عبر [owner_booking_actions.dart](files/presentation/screens/owner/owner_booking_actions.md) (لا حوار تأكيد بالقبول أيضاً) ومكرَّر بـ[owner_calendar_data_source.dart](files/presentation/screens/owner/owner_calendar_data_source.md) (`unblockDates`) | إضافة `.select()` وفحص عدد الصفوف بكل دوال UPDATE/DELETE على `bookings`/`availability`، بنفس نمط [chalet_edit_data_source.dart](files/presentation/screens/owner/chalet_edit_data_source.md) (المرجع الإيجابي الموجود فعلاً بالمشروع) |
| [owner_dashboard_screen.dart](files/presentation/screens/owner/owner_dashboard_screen.md) | 61-67 | **أخطر تكرار** لعطل اقتران `Future.wait`: 5 طلبات (ملف شخصي/إحصائيات/إشعارات/حجوزات/شاليهات) مجمَّعة بطلب واحد؛ فشل أيٍّ منها يُسقط الشاشة الرئيسية للمالك بالكامل | نسخ نمط `_init()` من [owner_calendar_screen.dart](files/presentation/screens/owner/owner_calendar_screen.md) (تحميل تسلسلي + `.catchError` مستقل لكل طلب ثانوي) — إصلاح جاهز بنفس المشروع |
| [owner_bookings_screen.dart](files/presentation/screens/owner/owner_bookings_screen.md) | 57-60 | نفس عطل اقتران `Future.wait` (تكرار ثانٍ)، عدّاد إشعارات هش يُخفي قائمة الحجوزات | نفس الإصلاح أعلاه |
| [owner_chalets_screen.dart](files/presentation/screens/owner/owner_chalets_screen.md) | 64-68 | نفس عطل اقتران `Future.wait` (تكرار أول تاريخياً) | نفس الإصلاح أعلاه |
| [owner_bookings_screen.dart](files/presentation/screens/owner/owner_bookings_screen.md) | 88-98 | عدم تناظر حماية الضغط المزدوج: `_onConfirm` يضبط "مشغول" قبل الطلب، `_onReject` بعده — الزر يبقى مفعَّلاً أثناء طلب الرفض الفعلي | نقل ضبط "مشغول" لقبل الاستدعاء، بنفس نمط `_blockDays`/`_unblockDays` بـ[owner_calendar_screen.dart](files/presentation/screens/owner/owner_calendar_screen.md) |
| [admin/admin_dashboard_screen.dart](files/presentation/screens/admin/admin_dashboard_screen.md) + [dashboard_service.dart](files/data/services/dashboard_service.md) | — | حساب إيرادات بجلب كل الصفوف وجمعها محلياً بـ Dart بدل `SUM` على السيرفر؛ admin_service.dart الأخطر لأنه يجلب حجوزات المنصة كلها بلا حدود | استبدال بدالة/`view` تجمع بالسيرفر (`SUM`/`RPC`)، مع حد أقصى (`.limit()`) على أي قراءة خام |
| [settings/settings_screen.dart](files/presentation/screens/settings/settings_screen.md) | — | عرض اللغة الحالية غير تفاعلي (يصبح قديماً فوراً بعد التغيير)؛ ميزة العملة بالكامل بلا أي أثر فعلي على بقية التطبيق | استخدام `ref.watch` بدل قراءة لمرة واحدة لعرض اللغة؛ حذف ميزة العملة أو ربطها فعلياً بكل عرض سعر بالتطبيق |
| [profile/profile_screen.dart](files/presentation/screens/profile/profile_screen.md) | — | نسخة ثانية كاملة من `NotificationsScreen` مضمَّنة هنا (مستخدَمة فعلياً) بينما النسخة الأكمل بمجلد `notifications/` كود ميت؛ عطل `.characters.first` على نص فارغ (مُصلَح بملفين آخرين) غير مُصلَح هنا؛ فجوة `mounted` بزر الحفظ | توحيد لنسخة واحدة من `NotificationsScreen`؛ تطبيق نفس حارس النص الفارغ المستخدَم بالملفات الأخرى؛ إضافة فحص `mounted` |
| [search/search_screen.dart](files/presentation/screens/search/search_screen.md) | — | `minGuests=2` يُرسَل دائماً بصمت حتى بلا تدخل المستخدم (وحتى بعد "مسح الكل")، يستبعد شاليهات سعة ضيف واحد من كل نتائج البحث؛ لا يحدث بـ`home_tab.dart` | إزالة القيمة الافتراضية المضمَّنة أو ضبطها لـ1، ومطابقة سلوك `home_tab.dart` |
| [payment/payment_flow_entry.dart](files/presentation/screens/payment/payment_flow_entry.md) | — | يعيد إنتاج عمولة وهمية 5% أُزيلت عمداً بـ`booking_screen.dart` — لو فُعِّل الدفع الإلكتروني لاحقاً ستعود مشكلة سعر مضلِّل | إزالة الحساب المحلي، الاعتماد على السعر القادم من السيرفر فقط، بنفس منطق `booking_screen.dart` |
| [payment/payment_success_screen.dart](files/presentation/screens/payment/payment_success_screen.md) | — | 3 أزرار رئيسية (عرض التفاصيل/مشاركة/إضافة للتقويم) بلا أي وظيفة فعلية على شاشة نجاح الدفع نفسها | ربط الأزرار بوظائفها الفعلية أو إخفاؤها لحين التنفيذ |
| [owner/owner_add_chalet_screen.dart](files/presentation/screens/owner/owner_add_chalet_screen.md) | — | `_uploadNewImages` دالة ميتة ومعطوبة بالكامل (لا تُستدعى، لا ترفع شيئاً فعلياً)؛ لا زر "رجوع" بالمعالج رغم وجود `_handleStepCancel` جاهزة | حذف الدالة الميتة أو إصلاحها إن كانت مقصودة؛ ربط `_handleStepCancel` بزر رجوع فعلي |
| [owner/chalet_pricing_screen.dart](files/presentation/screens/owner/chalet_pricing_screen.md) | — | حقول السعر لا تقبل أرقاماً عربية-هندية (بخلاف `chalet_edit_validation.dart`)؛ تسريب `Controller` بـ`_addDateOverride`؛ فجوة `mounted` وحيدة بـ`_deleteDateOverride` | تطبيق `normalizeDigits` الموجودة فعلاً بالمشروع على هذه الحقول؛ `dispose()` صريح للـ Controllers الديناميكية؛ فحص `mounted` |
| [data/services/pricing_service.dart](files/data/services/pricing_service.md) | — | كل دوال كتابة الأسعار/أنواع الإقامة بلا `try/catch` إطلاقاً — خطر خاص لأنها تتحكم ببيانات مالية حقيقية | لف كل دالة كتابة بـ`try/catch` وترجمة خطأ واضحة للمستخدم |
| [widgets/common/common_widgets.dart](files/presentation/widgets/common/common_widgets.md) | 234 | صورة بديلة ثابتة من Unsplash (خدمة خارجية) لأي شاليه بلا صورة غلاف — قد تُفهَم كصورة حقيقية للعقار، وتعتمد على استمرارية رابط خارجي | استبدالها بأصل محلي (placeholder) مُرفَق بالتطبيق |

### 🟡 بسيطة (مُجمَّعة حسب الموضوع)

| الموضوع | أين | ملاحظة |
|---|---|---|
| **خلل DST متكرر** (فرق `DateTime` محلي بدل `.utc()`) | ثابت ومُصلَح بـ [pricing_service.dart](files/data/services/pricing_service.md)، [models.dart](files/data/models/models.md) (`nightsCount`)، [owner_calendar_logic.dart](files/presentation/screens/owner/owner_calendar_logic.md) (`nightNumber`) — **لكن غير مُصلَح** بـ [booking_screen.dart](files/presentation/screens/booking/booking_screen.md) (`_nights`, يؤثر على العرض) و[manual_booking_sheet.dart](files/presentation/screens/owner/manual_booking_sheet.md) (سطر 750، عرض فقط) | توحيد كل حسابات فرق الليالي عبر دالة واحدة مشتركة (`DateTime.utc(...).difference(...)`) بدل تكرارها في كل ملف |
| **تطبيع الأرقام العربية-الهندية غير مُعمَّم** | منفَّذ 3 مرات منفصلة: `ChaletEditValidation.normalizeDigits`، `manual_booking_sheet.dart` (`parseManualPrice`)، وغير مُطبَّق إطلاقاً بـ`chalet_pricing_screen.dart` (🟠 أعلاه) | استخراج دالة واحدة مشتركة بملف utils عام |
| **ازدواجية كود** | `NotificationService` مفرد مقابل `NotificationsService` جمع ([services.md](files/data/services/services.md))؛ `NotificationModel` بملفين ([notification_model.md](files/data/models/notification_model.md))؛ `isHost()/isAdmin()` بـ3 تطبيقات مختلفة؛ `ShimmerCard` مقابل `LuxuryShimmerCard`؛ `ChaletCard` مقابل `_ChaletCard` (owner، مبرَّر) | توحيد كل زوج بتطبيق واحد يُستخدَم من الكل |
| **كود ميت مؤكَّد** | `SectionHeader`، `LuxurySectionHeader`، `LuxuryEmptyState` (كلها بلا أي استخدام)؛ `LoginPrompt` (كلاس حوار قديم)؛ `_uploadNewImages`؛ نسخة `NotificationsScreen` المستقلة بمجلد notifications/؛ `UserProfile.copyWith` (يُسقط role/isOwner/isAdmin بصمت، لكن بلا مستدعين حالياً) | حذف نظيف بعد تأكيد عدم الاستخدام (مؤكَّد بهذه المراجعة لكل ما ذُكر) |
| **race condition بلا عداد جيل** | [owner_reports_screen.dart](files/presentation/screens/owner/owner_reports_screen.md) (تبديل مدى زمني سريع يعرض بيانات مدى قديم) | إضافة عداد جيل بنفس نمط `_gen`/`_priceToken` المستخدَم بملفات أخرى بالمشروع |
| **استعلامات بلا `.limit()`** | `getIncomingBookings()` (بـ[owner_bookings_screen.md](files/presentation/screens/owner/owner_bookings_screen.md))، تُستهلَك بلا حد أيضاً بـ owner_dashboard_screen.dart وowner_external_screen.dart (4 استهلاكات مؤكَّدة)؛ `palestine_chalets_map_screen.dart` (حد ثابت 1000 بلا تحميل تدريجي) | إضافة ترقيم صفحات/حد أقصى معقول لكل استعلامات القوائم غير المحدودة |
| **أزرار/حقول بلا وظيفة فعلية موثَّقة** | `card_details_screen.dart` ("حفظ البطاقة")، `payment_failed_screen.dart` ("تحتاج مساعدة؟")، `help_support_screen.dart` (بطاقات تواصل)، رقم واتساب نائب حرفي "X"، بريد نائب مختلف بـ`privacy_security_screen.dart` (يتناقض مع help_support) | ربط فعلي أو إخفاء حتى التنفيذ؛ توحيد بيانات التواصل النائبة |
| **إمكانية الوصول (Accessibility)** | تناقض بين [owner_calendar_screen.dart](files/presentation/screens/owner/owner_calendar_screen.md) (شبكة مخصَّصة صديقة لقارئ الشاشة، موثَّقة بالكود) و[manual_booking_sheet.dart](files/presentation/screens/owner/manual_booking_sheet.md) (لا يزال `TableCalendar` غير الصديق لقارئ الشاشة حسب تعليق الكود نفسه) | تعميم شبكة `owner_calendar_screen.dart` أو استخلاصها كـ widget مشترك |
| **مشغِّل صامت لطلبات ثانوية/فرعية** | `catch (_) {}` فارغ بلا رسالة للمستخدم: زر اتصال الضيف بـ[owner_calendar_widgets.dart](files/presentation/screens/owner/owner_calendar_widgets.md)، وعدة مواضع أخرى مذكورة بالملاحظات الجانبية (`owner_calendar_screen.dart`, `booking_screen.dart`, `services.dart`, `profile_screen.dart`) | مراجعة كل حالة وإضافة تغذية راجعة بصرية (SnackBar) عند الفشل بدل الصمت الكامل |
| **تسمية بيانات تقديرية بلا توضيح كافٍ** | "حجوزات مؤكدة اليوم" بـ[owner_dashboard_screen.dart](files/presentation/screens/owner/owner_dashboard_screen.md) قد تشمل حجوزات `pending` (تقدير موثَّق جزئياً بتعليق TODO) | تسمية أدق ("غير ملغاة") أو طرح `pending` أيضاً من الحساب |
| **`.withOpacity()` مهجورة** | عشرات المواضع عبر معظم الملفات (باستثناء `owner_external_screen.dart` الذي يستخدم `.withValues()` الحديثة) | استبدال شامل بـ`.withValues(alpha:)` عبر بحث/استبدال بالمشروع كامل |
| **مدن/قوائم ناقصة غير متطابقة** | `AppStrings.cities` (8 مدن) بـ`search_screen.dart` تفتقد طوباس وسلفيت الموجودتين بقائمة `home_tab.dart` (10 مدن) | توحيد مصدر واحد لقائمة المدن |
| **تناقضات نصوص عرض التاريخ** | `owner_bookings_screen.dart` يعرض اسم شهر واحد فقط لمدى يعبر شهرين (بخلاف `owner_dashboard_screen.dart`/`owner_external_screen.dart` الصحيحين) | عرض شهر كل من تاريخي الوصول/المغادرة صراحة عند اختلافهما |
| **تكرار نسخ-لصق** | قسم "مزايا الحجز" مكرَّر حرفياً بـ`payment_method_screen.dart`؛ استيراد `flutter/material` مزدوج بـ3 ملفات دفع | إزالة التكرار، تنظيف الاستيرادات |
| **UI تفاعلية غير محدَّثة** | `LuxurySearchBar` (زر مسح "X") لا يظهر/يختفي أثناء الكتابة فعلياً — مؤكَّد بفحص استخدامه الحقيقي بـ`home_tab.dart` (لا `onChanged` ولا listener) | تمرير `onChanged` من المستدعي أو جعل الودجة تستمع للـ controller داخلياً |

---

## 2) أهم 10 أشياء يجب إصلاحها قبل الإطلاق

1. **التحقق الفوري من سياسات RLS بلوحة Supabase** لجداول `profiles`/`bookings`/`chalets` المستخدَمة من `admin_service.dart` — إن لم تكن مقيَّدة بـ`is_admin` فعلياً، فهذه ثغرة تسريب بيانات كل المستخدمين لأي حساب عادي يعرف كيف يستدعي الاستعلام مباشرة.
2. **نقل منح/سحب صلاحية `is_admin`** (admin_dashboard_screen.dart) من تحديث جدول مباشر إلى دالة RPC خادمية محكومة، وإضافة حوار تأكيد قبل حظر مستخدم.
3. **إصلاح تهيئة مشغّلات الفيديو بشاشة الريلز** (reels_screen.dart) — خطر تعطّل/استنزاف ذاكرة حقيقي مع أي عدد فيديوهات معقول، وهذا مسار مستخدَم فعلياً بالتطبيق.
4. **إضافة فحص عدد صفوف RLS** لكل تحديثات `bookings`/`availability` المباشرة (confirmIncomingBooking/rejectIncomingBooking/unblockDates) — لتفادي رسائل "نجاح" كاذبة تصل فعلياً للمالك عند رفض صامت من RLS.
5. **إصلاح عطل اقتران `Future.wait`** بثلاث شاشات (owner_dashboard_screen.dart الأخطر، owner_bookings_screen.dart، owner_chalets_screen.dart) — الحل جاهز وموجود بالفعل بنفس المشروع (owner_calendar_screen.dart).
6. **مراجعة كل الاستعلامات المالية المُجمَّعة محلياً** (admin_service.dart, dashboard_service.dart) — استبدالها بحساب خادمي (SUM/RPC) بدل جلب كل الصفوف، خصوصاً استعلام admin الذي يجلب حجوزات المنصة كاملة بلا حدود.
7. **مراجعة كل أزرار/ميزات بلا وظيفة فعلية** قبل الإطلاق (أزرار شاشة نجاح الدفع، "حفظ البطاقة"، "تحتاج مساعدة؟"، بطاقات دعم بلا onTap، بيانات تواصل نائبة متضاربة بين شاشتين) — إما ربطها أو إخفاؤها.
8. **إصلاح `minGuests=2` الصامت بشاشة البحث** — يستبعد فعلياً شاليهات سعة ضيف واحد من كل نتائج البحث بلا علم المستخدم، وهذا يؤثر مباشرة على اكتشاف المنتج.
9. **تفعيل تحقق ملكية/صلاحية موحَّد** وتوحيد الازدواجيات الأمنية-التشغيلية (isHost/isAdmin بـ3 تطبيقات مختلفة، NotificationService مفرد بلا حماية) قبل أن يعتمد عليها أي مسار جديد لاحقاً.
10. **إصلاح عدم تناظر حماية الضغط المزدوج** بأزرار القبول/الرفض بـowner_bookings_screen.dart، وتطبيق `normalizeDigits`/إصلاح DST المتاحَين فعلياً بالمشروع على الملفات المتبقية التي لا تستخدمهما بعد (خصوصاً chalet_pricing_screen.dart وbooking_screen.dart).

---

## 3) نقاط القوة العامة بالمشروع

- **الالتزام الحقيقي بسعر السيرفر كمصدر وحيد للحقيقة**: أدلة متكررة وموثَّقة (إزالة عمولة وهمية 6% بـbooking_screen.dart، تحقق سعر > 0 يطابق قيد السيرفر بـmanual_booking_sheet.dart، عرض تفاصيل عمولة "للعرض فقط" موسوم صراحة بأنه لا يمسّ `total_price` الفعلي).
- **وحدة تعديل/تسعير الشاليه ووحدة تقويم المالك من أفضل ما يمكن توقّعه هندسياً**: Dependency Inversion حقيقي وقابل للاختبار (`ChaletEditDataSource`, `PricingDataSource`, `OwnerCalendarDataSource`)، تحقق فعلي من عدد صفوف RLS بخلاف بقية المشروع، حماية Race Condition متسقة (عدادات جيل/رموز طلب) في أكثر من ملف، وحماية شاملة من فقدان بيانات (تعديلات غير محفوظة).
- **أول اهتمام حقيقي وموثَّق بإمكانية الوصول (Accessibility)** بكل التطبيق تقريباً موجود بوحدة تقويم المالك: شبكة أيام مخصَّصة بـSemantics كاملة، ألوان لا تعتمد على اللون وحده مع فحص تباين WCAG موثَّق بالكود، وحدّ أقصى لتكبير النص داخل الخلايا.
- **توثيق ذاتي صادق ونادر لتاريخ إصلاحات حقيقية**: عشرات تعليقات "✅ إصلاح" عبر الملفات (خصوصاً home_tab.dart وowner_dashboard_screen.dart وowner_chalets_screen.dart وowner_bottom_nav.dart) تشرح عطلاً حقيقياً سابقاً وسبب/طريقة إصلاحه، أحياناً مع تأكيد اختبار فعلي على منصة معيّنة (الويب).
- **صدق بعرض البيانات غير المتوفرة** بدل اختلاق أرقام: owner_dashboard_screen.dart وowner_reports_screen.dart يعرضان "—" صراحة للمقاييس غير الجاهزة بعد (مشاهدات، إشغال، تقييمات) بدل قيم وهمية.
- **لا وجود لأي `service_role` key داخل `lib/`** — الاستخدام الوحيد بمكانه الصحيح (Edge Function).
- **تخزين جلسة Supabase مشفَّر فعلياً** عبر `flutter_secure_storage` بدل التخزين الافتراضي غير المشفَّر.
- **ميزة تصفّح الضيف (guest browsing) مكتملة التنفيذ فعلياً من طرف لطرف**: تحقَّقتُ مباشرة أن تدفّق "احفظ الإجراء المطلوب ← وجِّه لتسجيل الدخول ← استأنف الإجراء تلقائياً بعد النجاح" (requireAuth + AuthRedirectService + login_screen.dart) مكتمل التنفيذ فعلياً وليس نصف منجز.
- **RPC ذرّية صحيحة لبعض العمليات الحساسة** (toggleFavorite، create/cancel_external_booking) بدل أنماط SELECT-then-write غير الآمنة، مع وعي موثَّق بالفرق (نفس الإصلاح لم يُعمَّم بعد لـReelsService.toggleLike).

---

## 4) تقييم الجودة العام: **6.5 / 10**

**التبرير:**
- **لماذا ليس أعلى:** توجد ثلاث مشاكل 🔴 حرجة حقيقية (اثنتان أمنيتان تتعلقان بلوحة الإدارة، وواحدة استقرار/أداء بشاشة الريلز) لا يجب إطلاق التطبيق قبل حلّها أو التحقق منها. إضافة لذلك، نمط "اقتران Future.wait" يتكرر 3 مرات ويضرب أهم شاشة بالتطبيق للمالك (لوحة تحكمه)، ونمط "رفض RLS صامت يُنتج رسالة نجاح كاذبة" مؤكَّد بأثر فعلي وليس نظرياً فقط. كمية لا بأس بها من الكود الميت والازدواجيات المتراكمة (نماذج بيانات مكرَّرة، مكوّنات واجهة مكرَّرة، فحوصات صلاحية بـ3 تطبيقات مختلفة) تشير لتاريخ تطوير متقطّع بمعايير مراجعة غير متسقة عبر الزمن.
- **لماذا ليس أقل:** الأجزاء الأفضل بالمشروع (وحدة تعديل/تسعير الشاليه، وحدة تقويم المالك بالكامل) تنافس أفضل ما يمكن توقّعه من تطبيق Flutter/Supabase احترافي — Dependency Inversion حقيقي، اختبارات-جاهزية بالتصميم، تحقق فعلي من RLS، حماية Race Condition متسقة، ووعي حقيقي بإمكانية الوصول نادر حتى بمشاريع أكبر. الانضباط حول "السيرفر هو مصدر الحقيقة للسعر" مطبَّق ومُختبَر عملياً في أكثر من مكان، لا مجرد شعار. الأهم: كل هذه المشاكل (بما فيها الحرجة) **موضعية ومحدودة النطاق**، وليست عيباً معمارياً شاملاً يتطلب إعادة كتابة — إصلاح البنود العشرة أعلاه، بمعظمها بالاعتماد على أنماط جاهزة **موجودة فعلياً بنفس المشروع**، يرفع الجودة الفعلية بشكل كبي
ر خلال وقت معقول قبل الإطلاق.
