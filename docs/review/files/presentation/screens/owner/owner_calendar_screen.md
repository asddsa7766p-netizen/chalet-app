### lib/presentation/screens/owner/owner_calendar_screen.dart (1177 سطر)

- **الوظيفة:** شاشة تقويم المالك — تقويم شهري لشاليه واحد بالمرة (اختيار من رقائق أعلى الشاشة)، نقرة على يوم تفتح ورقة/لوحة جانبية (سعر اليوم، حجز يدوي، حجب/إلغاء حجب، تفاصيل حجز + قبول/رفض/إلغاء)، ووضع "تحديد أيام" لحجب/إلغاء حجب نطاق بنقرتين مع إمكانية التراجع.

- **الشرح التفصيلي:**
  - **بنية DI كاملة:** `OwnerCalendarDataSource` (من [owner_calendar_data_source.dart](owner_calendar_data_source.md)) + `ManualBookingOpener`/`PricingOpener` قابلان للحقن للاختبار — الشاشة بأكملها (1177 سطراً) قابلة للاختبار بلا Supabase حقيقي.
  - **تحميل نافذة الأشهر (`_loadWindow`):** يحمّل الشهر الحالي + السابق + التالي معاً بطلبين فقط (`loadBookings`+`loadBlocked` عبر `Future.wait`)، ويتجنّب إعادة تحميل أشهر محمَّلة مسبقاً (`_loadedMonths`). **حماية Race Condition عبر عداد جيل (`_gen`)**: كل تحميل "reset" يزيد `_gen`، وبعد كل `await` يتحقق الكود من `gen != _gen` **و** `chalet.id != _chalet?.id` معاً قبل تطبيق النتيجة — يمنع نتائج قديمة (شاليه سابق أو نافذة أشهر قديمة) من الكتابة فوق حالة أحدث. نفس مستوى الجودة الموجود بـ`manual_booking_sheet.dart` (`_priceToken`)، مطبَّق هنا بشكل أشمل (جيل + هوية الشاليه معاً).
  - **`_init()` (سطر 122-150): هذا هو الإصلاح الصحيح لعطل اقتران `Future.wait` الموثَّق بملفين آخرين.** بدل تجميع كل الطلبات بـ`Future.wait` واحد (كما بـ[owner_chalets_screen.dart](owner_chalets_screen.md) و[owner_bookings_screen.dart](owner_bookings_screen.md))، تُحمَّل الشاليهات أولاً، ثم `loadPendingCounts`/`loadUnreadCount` كل منهما بـ`.catchError` مستقل يُرجع قيمة افتراضية آمنة (`{}`/`0`) — فشل أيٍّ منهما **لا يمنع إطلاقاً** عرض قائمة الشاليهات نفسها. **هذا النمط موجود فعلاً بنفس المشروع ويجب نسخه حرفياً للملفين الآخرَين بدل إصلاح كل واحد بمعزل.**
  - **`_blockDays`/`_unblockDays` (سطر 421-479):** يضبطان `_busy = true` **قبل** استدعاء `_ds.blockDates`/`unblockDates` مباشرة، فتتعطّل كل الأزرار طوال تنفيذ الكتابة الفعلية — **هذا هو التطبيق الصحيح** لنفس نمط الحماية الذي وُجِد ناقصاً بـ`_onReject` في [owner_bookings_screen.dart](owner_bookings_screen.md) (يُنصَح استخدامه كمرجع للإصلاح هناك).
  - **شبكة تقويم مخصَّصة بدل `TableCalendar` (سطر 1006-1064)، بتعليق صريح يشرح السبب:** "TableCalendar يستبعد وصف Semantics لكل خلية ويمنع قراءة حالة اليوم بقارئ الشاشة" — كل خلية (`_cell`) تحمل `Semantics(label:, button:, selected:, onTap:, onLongPress:, excludeSemantics: true)` بنص عربي كامل يصف اليوم وحالته (محجوز/محجوب/بانتظار/اليوم/منتهٍ). **أول وأوضح اهتمام حقيقي بإمكانية الوصول (Accessibility) بكل الملفات المُراجَعة حتى الآن.**
  - حساب موضع أول يوم بالشبكة (`offset = month.weekday % 7`, الأحد=0) وربط "الأشرطة" المتصلة بصرياً بين أيام الحجز/الحجب المتجاورة (`_sameBand`) — تحقَّقتُ من صحة الصيغة الحسابية سطراً بسطر (لا خطأ إزاحة off-by-one).
  - **وضع "تحديد أيام" (`_rangeMode`)**: نقرة أولى تحدّد البداية وتقرّر تلقائياً الإجراء (حجب/إلغاء حجب) حسب حالة ذلك اليوم، نقرة ثانية تحدّد النهاية، ثم `_confirmRange` يستخدم `planBlock`/`planUnblock` (من [owner_calendar_logic.dart](owner_calendar_logic.md)) لتنفيذ الخطة الفعلية فقط على الأيام الصالحة.
  - **ميزة "تراجع" (Undo) بعد الحجب/إلغاء الحجب:** `SnackBarAction` يستدعي `_writeAndRefresh` لعكس العملية مباشرة على نفس القائمة الملتقَطة بالإغلاق (closure صحيح، لا يتأثر بتبديل الشاليه لاحقاً).

- **الاعتماديات:** `app_colors.dart`, `models.dart`, `pricing_service.dart`, `chalet_pricing_screen.dart`, `manual_booking_actions.dart`, `manual_booking_sheet.dart`, `owner_booking_actions.dart`, `owner_bottom_nav.dart`, `owner_calendar_data_source.dart`, `owner_calendar_logic.dart`, `owner_calendar_widgets.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/owner-calendar`).

- **التعامل مع Supabase:** لا استدعاء مباشر — بالكامل عبر `OwnerCalendarDataSource` (راجع [owner_calendar_data_source.md](owner_calendar_data_source.md) للتفاصيل والمخاطر الموروثة، خصوصاً `confirmBooking`/`rejectBooking` التي ترث خطر "نجاح كاذب" الموثَّق بـ[services.md](../../../data/services/services.md)).

- **نقاط القوة:**
  - **من أفضل ملفين بكل المشروع** (مع owner_calendar_logic.dart) هندسياً: DI كامل، حماية Race Condition شاملة (جيل + هوية شاليه)، حماية ضغط مزدوج صحيحة (busy قبل الـawait مباشرة)، إعادة استخدام كل وحدات owner/ الأخرى (booking actions، manual booking، pricing) بدل تكرارها.
  - **الملف الوحيد بالمشروع بأكمله (حتى الآن) الذي يعالج إمكانية الوصول (screen reader) بجدية** — بديل مخصَّص عن TableCalendar موثَّق بسبب واضح.
  - `_init()` يحل عملياً (وليس نظرياً فقط) مشكلة اقتران `Future.wait` الموثَّقة بملفين آخرين — مرجع إصلاح جاهز بنفس الكودبيس.
  - ميزة تراجع (Undo) حقيقية بعد الحجب/إلغاء الحجب — تفصيل UX نادر بالمشروع.
  - جلب أسعار كسول (عند فتح ورقة يوم فقط، ومحفوظ بذاكرة مؤقتة لكل شهر) بدل تحميل كل الأسعار مقدَّماً.
  - حدود زمنية واضحة للتقويم (شهر-3 إلى شهر+13) تمنع تمرير المستخدم لمدى غير منطقي.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 481-488) — `_writeAndRefresh` (مسار "تراجع" فقط) يتجاوز حارس `_busy`:** بخلاف `_blockDays`/`_unblockDays` الأصليتين، دالة التراجع تستدعي `write()` (أي `_ds.unblockDates`/`blockDates` مباشرة) بلا فحص/ضبط `_busy` إطلاقاً. لو ضغط المالك "تراجع" على إشعار حجب سابق بينما عملية حجب/إلغاء حجب أخرى (على تاريخ مختلف) قيد التنفيذ فعلاً، يمكن لكتابتين متزامنتين أن تصلا لقاعدة البيانات معاً. الأثر العملي منخفض جداً لأنهما تُطبَّقان على تواريخ مختلفة عادة (لا تعارض بيانات فعلي)، لكنه يكسر مبدأ "عملية كتابة واحدة بالمرة" الذي يتبعه بقية الملف بدقة.
  - 🟡 **بسيطة (توثيقية، عبر مقارنة ملفات) — تناقض إمكانية وصول بين شاشتي تقويم المالك:** هذه الشاشة تستخدم شبكة مخصَّصة صديقة لقارئ الشاشة، بينما [manual_booking_sheet.dart](manual_booking_sheet.md) (المستخدَمة من نفس قسم المالك لإدخال حجز يدوي) لا تزال تستخدم `TableCalendar` **الذي يوثِّق هذا الملف نفسه أنه "يمنع قراءة حالة اليوم بقارئ الشاشة"** — فجوة اتساق حقيقية موثَّقة بتعليق الكود ذاته وليست تخميناً.
  - 🟡 **بسيطة:** `.withOpacity()` مهجورة (سطر 902 على الأقل) — نفس الملاحظة العامة المتكررة.
  - لا توجد مخاطر حرجة أو متوسطة إضافية حقيقية بهذا الملف تحديداً؛ المخاطر الأعمق (خطر "نجاح كاذب" عند القبول/الرفض) موروثة من `services.dart`/`owner_calendar_data_source.dart` ومُوثَّقة هناك، لا تنبع من منطق هذا الملف نفسه.

- **اقتراح الإصلاح:**
  - تطبيق نمط `_init()` (استدعاءات منفصلة بـ`.catchError` بدل `Future.wait` واحد يجمع كل شيء) حرفياً على [owner_chalets_screen.dart](owner_chalets_screen.md) و[owner_bookings_screen.dart](owner_bookings_screen.md).
  - تطبيق نمط `_blockDays`/`_unblockDays` (ضبط علم "مشغول" قبل الـ`await` مباشرة) على `_onReject` بـ[owner_bookings_screen.dart](owner_bookings_screen.md).
  - بـ`_writeAndRefresh`: إضافة نفس حارس `_busy` (تجاهل الضغط لو `_busy == true`، وضبطه أثناء تنفيذ التراجع) لتوحيد قاعدة "عملية واحدة بالمرة" على كل مسارات الكتابة.
  - استبدال `TableCalendar` بـ`manual_booking_sheet.dart` بنفس شبكة `Semantics` المخصَّصة المستخدمة هنا (أو استخلاصها كـ widget مشترك لتُستخدَم بالملفين معاً)، لإغلاق فجوة إمكانية الوصول.
