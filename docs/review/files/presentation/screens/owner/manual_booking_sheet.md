### lib/presentation/screens/owner/manual_booking_sheet.dart (879 سطر)

- **الوظيفة:** ورقة سفلية (Bottom Sheet) تسمح للمالك بإدخال حجز يدوي (زبون تواصل هاتفياً/وجاهياً) — اختيار شاليه وتواريخ عبر تقويم، سعر متفق عليه (مقترَح من السيرفر وقابل للتعديل)، اسم/هاتف/عدد ضيوف/ملاحظة، ثم حفظ عبر RPC خادمي.

- **الشرح التفصيلي:**
  - `openManualBookingSheet(context, {chaletId, checkIn})`: دالة الدخول. تحمّل شاليهات المالك عبر `ChaletService.instance.getOwnerChalets`، وإن فشل أو كانت القائمة فارغة تعرض رسالة وتُرجع `false` مباشرة دون فتح الورقة. تتحقق من `context.mounted` بعد الـ`await` قبل `showModalBottomSheet` — **من الملفات القليلة جداً بالمشروع التي تستخدم `context.mounted` صراحة**. تُمرِّر 3 دوال حقن اعتماديات لـ`ManualBookingSheet`: `loadBookedNights` (يستخدم `BookingService.getUnavailableNights` — **الليالي المحجوزة + المحجوبة معاً عمداً**، موثَّق بالكود: "وإلا يقبل التقويم يوماً حجبه المالك ثم يرفضه الـ trigger" — تصميم دفاعي واعٍ)، `quotePrice` (`BookingService.calculateBookingPrice`)، `submit` (`BookingService.createExternalBooking`، أي RPC `create_external_booking` حسب وصف الـ backend).
  - `ManualBookingChalet`/`ManualBookingRequest`: نماذج بيانات بسيطة لنقل الحالة بين الدالة والورقة.
  - `validateManualGuestPhone`/`validateManualGuestName`/`parseManualPrice`/`validateManualPrice`: دوال تحقق مستقلة قابلة للاختبار بمعزل عن الواجهة. `parseManualPrice` **نسخة أخرى مستقلة من تطبيع الأرقام العربية-الهندية** (توازي `ChaletEditValidation.normalizeDigits` بوحدة تعديل/تسعير الشاليه) — تعالج أيضاً الفاصلة العربية "،" والفاصلة الإنجليزية "," كفاصل عشري. `validateManualPrice` يرفض سعراً ≤ صفر **بتعليق صريح يوثّق أن السيرفر يرفض ذلك أيضاً** — مثال جيد على مطابقة تحقق العميل لقيد السيرفر بدل تركه يكتشفه الزبون عبر رسالة خطأ لاحقة.
  - `_ManualBookingSheetState`: الحالة الرئيسية. تدير: تحميل الليالي المحجوزة/المحجوبة (`_loadBookedNights`)، اختيار التواريخ عبر `TableCalendar` مع قاعدة تعطيل موحَّدة `isDayDisabledForStay` (من [unavailable_nights.dart](../../../data/services/unavailable_nights.md) — **نفس القاعدة المستخدمة بشاشة حجز الزبون**، اتساق حقيقي بدل تكرار منطق)، جلب سعر مقترَح (`_fetchPrice`) مع **حماية Race Condition عبر `_priceToken`** (يزداد بكل طلب جديد، ويُتحقَّق من تطابقه بعد الـ`await` قبل تطبيق النتيجة — يمنع ظهور سعر قديم بعد تغيير التواريخ بسرعة)، ونفس نمط الحماية بـ`_loadBookedNights` (فحص `chaletId != _chalet.id` بعد الـ`await`).
  - `_save()`: يتحقق من `_formKey`، يستدعي `widget.submit`، وعند النجاح `Navigator.of(context).pop(true)` (بعد فحص `mounted`)؛ عند الفشل يعرض رسالة الخطأ الفعلية القادمة من السيرفر (`e.toString().replaceFirst('Exception: ', '')`) بدل رسالة عامة فقط — يسمح بعرض رسائل الـ trigger (مثل تعارض حجوزات) للمالك مباشرة، **مطابق تماماً لمتطلبات المستخدم بخصوص عرض أخطاء الـ trigger بوضوح**.
  - زر الحفظ (`_canSubmit ? _save : null`) يتعطّل أثناء `_saving` — يمنع الحفظ المزدوج (ضغط متكرر/race condition) بشكل صريح وصحيح.

- **الاعتماديات:** `table_calendar` (حزمة خارجية)، `app_colors.dart`، `services.dart` (`AuthService`, `ChaletService`, `BookingService`)، `unavailable_nights.dart` (`isDayDisabledForStay`). **من يستخدمه:** مؤكَّد عبر بحث فعلي بالكود: [owner_calendar_screen.dart](owner_calendar_screen.md)، [owner_dashboard_screen.dart](owner_dashboard_screen.md)، [owner_bookings_screen.dart](owner_bookings_screen.md)، [owner_external_screen.dart](owner_external_screen.md) — يُستدعى من 4 شاشات مختلفة.

- **التعامل مع Supabase:**
  - قراءة شاليهات المالك: `ChaletService.getOwnerChalets`.
  - قراءة الليالي غير المتاحة: `BookingService.getUnavailableNights` (محجوزة + محجوبة معاً).
  - عرض سعر مقترَح: `BookingService.calculateBookingPrice` (للعرض فقط، لا يُفرَض على السيرفر عند الحفظ — المالك يكتب السعر الفعلي المتفق عليه، والسيرفر يتحقق من صحته/رفضه عند `create_external_booking` وفق وصف الـ backend).
  - الحفظ: `BookingService.createExternalBooking` → RPC `create_external_booking` (خادمي، يتحقق من التعارض والسعر حسب وصف المستخدم للـ triggers).

- **نقاط القوة:**
  - حقن اعتماديات كامل (3 دوال + `today` اختياري للاختبار) — نمط الجودة نفسه الموجود بوحدة تعديل/تسعير الشاليه، مطبَّق هنا أيضاً بورقة الحجز اليدوي.
  - حماية Race Condition مزدوجة (`_priceToken` لجلب السعر، فحص `chaletId` لتحميل الليالي) — من أفضل الأمثلة بالمشروع على التعامل الصحيح مع طلبات async متتالية سريعة.
  - إعادة استخدام منطق تعطيل الأيام (`isDayDisabledForStay`) بدل تكراره — اتساق فعلي بين شاشتي المالك والزبون.
  - رسالة خطأ الحفظ تعرض نص استثناء السيرفر الفعلي (تلبية مباشرة لمتطلب "عرض رسائل الـ trigger بوضوح").
  - تحقق سعر > 0 على العميل موثَّق أنه يطابق قيد السيرفر — يقلل رسائل خطأ مفاجئة للمالك.
  - معالجة ذكية لحالة "تاريخ وصول محدَّد مسبقاً صار غير متاح بعد تحميل الليالي" (سطر 272-276).
  - زر حفظ يتعطّل أثناء الحفظ (حماية ضغط مزدوج).
  - استخدام `context.mounted`/`mounted` صحيح ومتّسق بكل نقاط الـ`await` (فتح الورقة، تحميل الليالي، جلب السعر، الحفظ).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 750، عرض فقط) — نفس نمط خلل التوقيت الصيفي (DST) المتكرر بالمشروع:** `_checkOut!.difference(_checkIn!).inDays` يستخدم فرق `DateTime` محلي (غير UTC) — نفس النمط المُصلَح بـ[models.dart](../../../data/models/models.md) (`BookingModel.nightsCount`) وموثَّق كعطل غير مُصلَح بـ[booking_screen.dart](../../booking/booking_screen.md). الأثر هنا محدود لأنه **نص عرض فقط** ("من ... إلى ... · N ليالٍ") ولا يُستخدَم لحساب السعر (السعر يأتي من `quotePrice`/يكتبه المالك يدوياً) — لكنه قد يُري المالك عدد ليالٍ خاطئاً بيوم واحد عند حجز يعبر تاريخ تغيّر التوقيت الصيفي بفلسطين.
  - 🟡 **بسيطة (سطر 78-88) — ازدواجية أخرى لتطبيع الأرقام العربية:** `parseManualPrice` منطق مطابق تقريباً لـ`ChaletEditValidation.normalizeDigits` (دفعة سابقة) لكنه مُعاد كتابته من الصفر هنا بدل إعادة الاستخدام — يؤكد الملاحظة العامة السابقة بعدم تعميم هذه الدالة بمكان مشترك؛ كما أن معالجة الفاصلة الإنجليزية "," كفاصل عشري (سطر 86) قد تُسيء تفسير رقم مكتوب بفاصلة كفاصل آلاف (مثال نظري: "1,234" ستُقرأ 1.234 بدل 1234) — احتمال عملي منخفض لأن حقل السعر رقمي بسيط ولا يُظهر عادة فواصل آلاف، لكنه يستحق الذكر.
  - 🟡 **بسيطة (سطر 260-286) — لا زر "إعادة محاولة" صريح عند فشل تحميل الليالي المحجوزة:** `_bookedLoadError` يُعرَض كنص فقط؛ لاستعادة المحاولة على المالك تبديل الشاليه ثم الرجوع، أو إغلاق الورقة وإعادة فتحها — نفس النمط المفقود المُلاحَظ بـ`palestine_chalets_map_screen.dart` (دفعة 6).
  - 🟡 **بسيطة/حافة نادرة (سطر 338-339):** إن كانت `maxGuests` للشاليه = 0 (حالة بيانات شاذة غير متوقعة عملياً)، يُحصَر `_guests` عند 0 دون إمكانية زيادته لاحقاً (`canAdd` يتطلب `_guests < max`) — تجميد الضيوف عند صفر بدل حد أدنى منطقي (1). يحتاج تأكيد فقط إن كان `max_guests` مضموناً ≥ 1 بقاعدة البيانات.

- **اقتراح الإصلاح:**
  - سطر 750: `final nights = DateTime.utc(_checkOut!.year, _checkOut!.month, _checkOut!.day).difference(DateTime.utc(_checkIn!.year, _checkIn!.month, _checkIn!.day)).inDays;` — نفس الإصلاح المطبَّق بالفعل بـ`models.dart`.
  - توحيد `parseManualPrice`/`normalizeDigits` بدالة مشتركة واحدة (مثلاً بملف utils عام) تُستخدَم من هنا ومن وحدة تعديل/تسعير الشاليه معاً، لتفادي انحراف السلوك بين النسختين مستقبلاً.
  - إضافة زر "إعادة المحاولة" صغير بجانب رسالة `_bookedLoadError` يستدعي `_loadBookedNights()` مباشرة.
