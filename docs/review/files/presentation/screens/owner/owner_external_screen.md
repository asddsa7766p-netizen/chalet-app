### lib/presentation/screens/owner/owner_external_screen.dart (298 سطر)

- **الوظيفة:** شاشة مخصَّصة لعرض **الحجوزات اليدوية فقط** (لكل شاليهات المالك معاً) — القادمة أولاً بالأقرب فالأبعد، ثم المنتهية بالأحدث فالأقدم، مع إمكانية إضافة حجز يدوي جديد أو إلغاء حجز قائم.

- **الشرح التفصيلي:**
  - `_load()`: يجلب كل الحجوزات (`BookingService.getIncomingBookings`) ثم يُصفِّي محلياً على `b.isManual` فقط (عبر [manual_booking.dart](../../../data/models/manual_booking.md))، ويقسمها لقادمة/منتهية بترتيبين متعاكسين منطقيين (قادمة: الأقرب أولاً؛ منتهية: الأحدث أولاً) — تجربة استخدام مدروسة.
  - `_addManualBooking`/`_cancelBooking`: يفوِّضان لـ[manual_booking_sheet.dart](manual_booking_sheet.md)/[manual_booking_actions.dart](manual_booking_actions.md) مباشرة، ثم `_load()` عند النجاح.
  - `_bookingTile`: يعرض بيانات الضيف (`b.manualGuest`)، الشاليه، مدى التاريخ الكامل (يوم/شهر/سنة لكلا الطرفين معاً، بلا غموض عبور شهر)، عدد الليالي/الضيوف، السعر، ملاحظة المالك إن وُجدت، وزر إلغاء مشروط بـ`canCancelManualBooking`.

- **الاعتماديات:** `app_colors.dart`, `manual_booking.dart`, `models.dart`, `services.dart`, `manual_booking_actions.dart`, `manual_booking_sheet.dart`. **من يستخدمه:** [owner_bookings_screen.dart](owner_bookings_screen.md) (زر "الحجوزات اليدوية" بالـ AppBar، عبر `context.push('/owner-external')`).

- **التعامل مع Supabase:** `BookingService.getIncomingBookings()` (**نفس الاستعلام بلا `.limit()` الموثَّق سابقاً بـ[owner_bookings_screen.md](owner_bookings_screen.md) — استهلاك رابع مؤكَّد لنفس نقطة القراءة غير المحدودة**)، `confirmAndCancelManualBooking` → RPC `cancel_external_booking`، `openManualBookingSheet` → RPC `create_external_booking`.

- **نقاط القوة:**
  - شاشة مركَّزة بغرض واحد واضح، منطق فرز/تصفية نظيف ومقروء.
  - إعادة استخدام كاملة لوحدات الحجز اليدوي بدل تكرار منطقها.
  - null-safety صحيح لبيانات الضيف الاختيارية (`guest.phone`/`guest.note`) — كل `!` محمي بفحص `!= null` مباشرة قبله.
  - `.withValues(alpha: 0.08)` (سطر 202) بدل `.withOpacity()` المهجورة — **أول وحيد استخدام لـ API الحديث الصحيح بكل الملفات المُراجَعة حتى الآن**، مؤشر أن هذا الملف من أحدث/أنظف ملفات المشروع، ومرجع جيد عند تحديث بقية الملفات لاحقاً.
  - ترتيب زمني ثنائي الاتجاه (قادمة تصاعدياً، منتهية تنازلياً) مدروس فعلياً لتجربة المستخدم لا اعتباطي.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 252-269) — زر "إلغاء الحجز" بلا حماية ضغط مزدوج أثناء طلب الشبكة الفعلي:** نفس الفجوة الهيكلية الموثَّقة بـ`_onReject` في [owner_bookings_screen.dart](owner_bookings_screen.md) (لا علم "مشغول" يُعطِّل الزر أثناء تنفيذ `cancelExternalBooking` فعلياً بعد إغلاق حوار التأكيد) — لكن الخطورة هنا **أقل** لأن الإلغاء يمر عبر RPC (`cancel_external_booking`) بدل تحديث جدول مباشر، وإلغاء حجز مُلغى مسبقاً على الأرجح عملية لا تُحدث ضرراً فعلياً (idempotent) من جهة السيرفر — **يحتاج تأكيداً مباشراً من سلوك الدالة الفعلي بدل افتراضه**.
  - 🟡 **(مُكرَّر، تُرقيته فقط) — نفس ملاحظة `getIncomingBookings()` بلا `.limit()`** الموثَّقة بالكامل بـ[owner_bookings_screen.md](owner_bookings_screen.md)، مستهلَكة هنا للمرة الرابعة بالتطبيق.

- **اقتراح الإصلاح:**
  - إضافة علم "مشغول" محلي (`bool _cancelling`) يُعطِّل زر "إلغاء الحجز" لتلك البطاقة تحديداً أثناء تنفيذ `_cancelBooking`، بنفس فلسفة `_busy` بـ[owner_calendar_screen.dart](owner_calendar_screen.md).
