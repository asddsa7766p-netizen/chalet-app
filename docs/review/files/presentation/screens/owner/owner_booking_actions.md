### lib/presentation/screens/owner/owner_booking_actions.dart

- **الوظيفة:** منطق تأكيد/رفض حجز معلّق، مُستخرَج كدوال مستقلة قابلة لإعادة الاستخدام من أكثر من شاشة (قائمة الحجوزات والتقويم معاً، حسب تعليق الكود).

- **الشرح التفصيلي:**
  - `confirmBookingFlow(context, bookingId, {confirm})`: يستدعي `BookingService.confirmIncomingBooking` (أو دالة بديلة `confirm` للاختبار — نمط حقن اعتماديات مألوف من ملفات owner/ الأخرى)، يعرض رسالة نجاح/فشل.
  - `rejectBookingFlow(context, bookingId, {reject})`: **بتأكيد Dialog صريح أولاً** ("هل أنت متأكد؟ لا يمكن التراجع") قبل استدعاء `BookingService.rejectIncomingBooking`.
  - كلتا الدالتين تلتقط `ScaffoldMessenger.of(context)` **قبل** أي `await` (`final messenger = ScaffoldMessenger.of(context);`) — نمط آمن صحيح: يتفادى استخدام `context` مباشرة بعد فجوة async (يستخدم `messenger` الملتقَط مسبقاً بدلاً من ذلك)، فيتجنب مشكلة "`context` بعد `await`" بشكل بنيوي دون الحاجة لفحص `mounted` صريح بهذا الموضع تحديداً.

- **الاعتماديات:** `app_colors.dart`, `services.dart`. **من يستخدمه:** على الأرجح [owner_bookings_screen.dart](owner_bookings_screen.md) و[owner_calendar_screen.dart](owner_calendar_screen.md)/[owner_calendar_widgets.dart](owner_calendar_widgets.md) (يُؤكَّد عند مراجعتها).

- **التعامل مع Supabase:** عبر `BookingService.confirmIncomingBooking`/`rejectIncomingBooking` (تحديثات مباشرة على `bookings`، بلا فحص عدد صفوف — راجع أدناه).

- **نقاط القوة:**
  - حقن اعتماديات اختياري (`confirm`/`reject` params) يسمح باختبار المنطق بدون Supabase حقيقي — نفس نمط الجودة بوحدة تعديل/تسعير الشاليه (دفعة سابقة).
  - التقاط `ScaffoldMessenger` قبل `await` — حل أنيق وبسيط لمشكلة "context بعد await" بدل نسيان فحص `mounted`.
  - تأكيد صريح قبل الرفض (إجراء لا رجعة فيه من منظور المستخدم).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 20-34، 38-80) — رسالة نجاح كاذبة محتملة، تجسيد مباشر لفجوة مُوثَّقة بـ[services.dart](../../../data/services/services.md):** كلتا الدالتين تعرضان **"تم تأكيد/رفض الحجز بنجاح"** لمجرد أن `confirmIncomingBooking`/`rejectIncomingBooking` لم تَرمِ استثناءً — لكن تلك الدالتان (تحديث مباشر لجدول `bookings` بلا `.select()`/فحص عدد صفوف، راجع مراجعة services.dart) **لا ترمي استثناءً أصلاً حتى لو رفضت RLS الصف بصمت** (مثال واقعي: مالك يضغط "تأكيد" على حجز غيّر المستأجر حالته للتو، أو ضغط مزدوج سريع). النتيجة: **المالك يرى "تم التأكيد بنجاح" بينما لم يتغيّر شيء فعلياً بقاعدة البيانات** — أثر مباشر وملموس لمشكلة كانت نظرية بمراجعة الخدمة، مؤكَّدة هنا بوضوح.

- **اقتراح الإصلاح:**
  - الحل الجذري بـ[services.dart](../../../data/services/services.md): إضافة `.select()` وفحص عدد الصفوف بـ`confirmIncomingBooking`/`rejectIncomingBooking`، بحيث تعكس هاتان الدالتان (`confirmBookingFlow`/`rejectBookingFlow`) نتيجة حقيقية بدل افتراض النجاح من غياب استثناء فقط.
