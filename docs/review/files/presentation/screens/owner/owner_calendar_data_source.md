### lib/presentation/screens/owner/owner_calendar_data_source.dart (204 سطر)

- **الوظيفة:** طبقة Dependency Inversion لتقويم المالك — واجهة مجرّدة `OwnerCalendarDataSource` (8 عمليات) وتنفيذ حقيقي `SupabaseOwnerCalendarDataSource`، بنفس فلسفة `ChaletEditDataSource`/`PricingDataSource` (دفعة 9): الشاشة تعتمد على الواجهة فقط، فتُختبر ببيانات وهمية بلا اتصال حقيقي.

- **الشرح التفصيلي:**
  - `CalendarChalet`/`CalendarChalet.fromRow`: نموذج شاليه مبسَّط للتقويم (اسم، سعر افتراضي لليلة، حد ضيوف، حالة اعتماد).
  - `loadChalets`: شاليهات المالك عبر `ChaletService.getOwnerChalets`.
  - `loadPendingCounts`: عدد حجوزات `pending` مستقبلية (`check_out >= اليوم`) لكل شاليه دفعة واحدة (لعرض شارة رقمية بدل استعلام منفصل لكل شاليه — كفاءة جيدة).
  - `loadBookings(chaletId, from, toExclusive)`: يجلب حجوزات `pending`/`confirmed` التي **تتقاطع زمنياً** مع المدى المطلوب عبر الشرط الكلاسيكي لتقاطع المجالات: `check_in < toExclusive AND check_out > from` — نفس منطق exclusion constraint الذي وصفه المستخدم بجانب السيرفر، مطبَّق هنا للاستعلام أيضاً بشكل صحيح.
  - `loadBlocked`/`blockDates`/`unblockDates`: قراءة/كتابة جدول `availability` (الليالي المحجوبة يدوياً من المالك). `blockDates` يستخدم `upsert` بـ`onConflict: 'chalet_id,date'` (كتابة دفعة واحدة لعدة تواريخ). `unblockDates` يستخدم `update` مباشر — **لا يتحقق من عدد الصفوف المتأثرة** (انظر الخطر أدناه).
  - `loadMonthPricing`: يفوِّض لـ`ChaletPricingService.getMonthPricing` (خدمة تسعير مُراجَعة بدفعة سابقة).
  - `confirmBooking`/`rejectBooking`/`cancelManualBooking`: أغلفة رفيعة تستدعي `BookingService.confirmIncomingBooking`/`rejectIncomingBooking`/`cancelExternalBooking` مباشرة — **هذا استهلاك ثالث مؤكَّد** لنفس دوال `services.dart` المُوثَّق افتقارها للتحقق من عدد صفوف RLS (بعد [owner_booking_actions.dart](owner_booking_actions.md) و[manual_booking_actions.dart](manual_booking_actions.md))، هذه المرة عبر واجهة التقويم.
  - جميع مقارنات التواريخ (`_isoDate`) تُرسَل كنصوص `YYYY-MM-DD` مباشرة لأعمدة `date` بقاعدة البيانات — **يتفادى بذكاء كل مشاكل التوقيت الصيفي/المنطقة الزمنية** التي ظهرت بملفات أخرى تحسب فروق `DateTime` محلياً (`.difference().inDays`)، لأن المقارنة تتم على نص تاريخ صرف بدون مكوّن وقت أصلاً.

- **الاعتماديات:** `models.dart`, `pricing_service.dart`, `notification_service.dart`, `services.dart`, `owner_calendar_logic.dart` (`dateOnly`, `DayPriceInfo`). **من يستخدمه:** على الأرجح [owner_calendar_screen.dart](owner_calendar_screen.md) (يُؤكَّد عند مراجعته).

- **التعامل مع Supabase:**
  - قراءة: `bookings` (بأعمدة محدَّدة صراحة تتضمن `source`، متوافقة مع اعتماد `manual_booking.dart` عليه)، `availability`.
  - كتابة: `availability.upsert` (حجب)، `availability.update` (إلغاء حجب، بلا تحقق صفوف)، إضافة لدوال `BookingService` سالفة الذكر (RPC واحدة + تحديثين مباشرين بلا تحقق).

- **نقاط القوة:**
  - Dependency Inversion حقيقي (نفس معيار الجودة الأعلى بالمشروع، مُطبَّق هنا على وحدة التقويم أيضاً).
  - منطق تقاطع مجالات زمنية صحيح رياضياً بـ`loadBookings`، متّسق مع فلسفة الـ exclusion constraint بالسيرفر.
  - استخدام نصوص تاريخ ISO خام للمقارنة بدل حساب `DateTime` محلي — يتجنّب عائلة أخطاء DST الموثَّقة بملفات أخرى بالكامل.
  - `blockDates` يكتب دفعة واحدة (`upsert` بقائمة) بدل حلقة نداءات منفصلة — كفاءة وذرّية أفضل.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة إلى متوسطة (سطر 167-175) — `unblockDates` بلا تحقق من عدد الصفوف المتأثرة، نفس نمط RLS-silent-rejection الموثَّق بملفات أخرى:** `update({'is_available': true})` بلا `.select()`/فحص لاحق. لو رفضت RLS الصفوف بصمت (لأي سبب: تعارض ملكية، حالة بيانات غير متوقَّعة)، ستؤثر العملية على 0 صف دون رمي استثناء، ويظن المالك أن التاريخ صار متاحاً بينما يبقى محجوباً فعلياً بقاعدة البيانات — تناقض قد يُربك المالك (يرى التقويم "محدَّثاً" لكن الحجز الجديد على ذلك التاريخ يُرفَض من السيرفر لاحقاً بسبب تعارض تقويم لم يُحلّ فعلياً). أقل خطورة من حالات القبول/الرفض المالية لأن لا مال ولا حجز خاطئ يتغيّر، لكنه نفس الثغرة البرمجية بالضبط.
  - 🟡 **بسيطة (تحتاج تحقق) — `blockDates` عبر `upsert` بلا `.select()` أيضاً:** عادة يرمي Postgrest استثناءً صريحاً عند رفض RLS لعملية INSERT (بخلاف UPDATE التي تتجاهل الصفوف المفلترة بصمت)، فاحتمال الفشل الصامت هنا أضعف نظرياً — لكن هذا **غير مؤكَّد 100%** بدون اختبار فعلي لسياسات RLS الخاصة بجدول `availability` تحديداً، فيُذكَر هنا للتنويه فقط.
  - 🟡 **بسيطة جداً (سطر 30) — اتجاه القيمة الافتراضية بـ`isApproved`:** `row['is_approved'] as bool? ?? true` يفترض "معتمد" افتراضياً عند غياب القيمة، بدل الاتجاه الأكثر تحفظاً (`false`). أثر عملي شبه معدوم على الأرجح لأن العمود متوقَّع أن يكون NOT NULL بقاعدة البيانات، لكنه يستحق الذكر كاختيار افتراضي "متفائل" بدل "متحفظ".
  - **(مُكرَّر، غير مُعاد تصنيفه هنا):** استخدام `confirmBooking`/`rejectBooking`/`cancelManualBooking` لنفس دوال `services.dart` يُبقي هذا الملف عرضة لنفس خطر "رسالة نجاح كاذبة" المُوثَّق بالكامل بـ[services.md](../../../data/services/services.md) و[owner_booking_actions.md](owner_booking_actions.md) — يُذكَر هنا فقط كنقطة استهلاك ثالثة مؤكَّدة، والإصلاح الجذري موحَّد بمكان واحد (services.dart).

- **اقتراح الإصلاح:**
  - `unblockDates`: إضافة `.select()` والتحقق من أن عدد الصفوف المُعادة يطابق عدد التواريخ المطلوبة، وإلقاء استثناء واضح عند الاختلاف — بنفس نمط `chalet_edit_data_source.dart` (المرجع الإيجابي الموجود فعلاً بالمشروع لنفس المشكلة).
  - تغيير `?? true` إلى `?? false` بـ`isApproved` كإجراء تحفّظي وقائي بحت (لا أثر عملي متوقَّع إن كان العمود NOT NULL فعلاً بقاعدة البيانات).
