### lib/data/models/chalet_model.dart

- **الوظيفة:** نموذج `ChaletModel` — التمثيل الأساسي لصف جدول `chalets` بالتطبيق بأكمله (تحويل من/إلى JSON، نسخ معدَّل `copyWith`، مساواة بالمعرّف).

- **الشرح التفصيلي:**
  - حقول شاملة تطابق (حسب تعليق الترويسة) بنية `chalets` الحالية: `id, name, description, location, city, address, pricePerNight, maxGuests, bedrooms, bathrooms, hasPool/Wifi/Bbq/Parking, ownerId, rating, reviewsCount, isAvailable, isApproved, isFeatured, latitude/longitude, bookingType, minNights, depositAmount, images (List<String>), videoUrl, createdAt/updatedAt`.
  - تعليق الترويسة (سطر 1-9) يوثّق تاريخ تطوّر النموذج بوضوح: إضافة حقول جديدة، تحويل `coverImage` (نص واحد) إلى `images` (قائمة) ليطابق العمود الفعلي `images text[]` بقاعدة البيانات، مع إبقاء getter `coverImage` للتوافق العكسي مع كود قديم.
  - `fromJson`: **كل حقل تقريباً** يُقرأ بنمط آمن `json['x'] as Type? ?? default` — بما فيها `parseImages` الداخلية (تتحمّل `null`/نوع غير `List`/عناصر غير نصية بتحويلها لـ `.toString()`). **الاستثناء الوحيد:** `id: json['id'] as String` — cast مباشر بلا `?`/fallback.
  - getters محسوبة: `coverImage` (أول صورة أو نص فارغ)، `isPublic` (`isAvailable && isApproved` — يطابق بالضبط الشرط المزدوج المستخدم فعلياً بـ`ChaletService.getChalets`/`getFeaturedChalets` بـ[services.dart](../services/services.md))، `hasLocation` (كلا الإحداثيتين غير null).
  - `toJson`/`copyWith`: شاملان لكل الحقول (باستثناء `createdAt`/`updatedAt` من `toJson`، منطقي لأنهما يُدارا بالسيرفر).
  - `operator ==`/`hashCode`: مساواة بالمعرّف (`id`) فقط — نمط قياسي مناسب لعناصر تُقارَن/تُجمَّع بـ `Set`/قوائم (كما بمنطق المفضلة).

- **الاعتماديات:** لا يستورد شيئاً (نموذج بيانات نقي، بدون اعتماديات خارجية). **من يستخدمه:** عملياً كل شاشة/خدمة تتعامل مع شاليهات (`services.dart`, `pricing_service.dart`, `booking_screen.dart`, `chalet_detail_screen.dart`, `search_screen.dart`, `favorites_screen.dart`, شاشات owner/*...) — الأكثر استخداماً من كل نماذج البيانات.

- **التعامل مع Supabase:** لا اتصال مباشر (نموذج بيانات بحت) — لكنه القالب الذي يُحوَّل إليه/منه كل صف من جدول `chalets`.

- **نقاط القوة:**
  - **من أفضل أمثلة null-safety بالمشروع بأكمله**: كل حقل اختياري محمي بـ `?? default` مناسب، ومعالجة خاصة وذكية لتحويل `images` (يتحمّل عناصر بأنواع غير متوقعة بدل `as List<String>` مباشر الذي كان سيفشل لو عنصر واحد بالقائمة ليس نصاً).
  - توثيق تاريخي واضح بالترويسة لتطور بنية النموذج — يسهّل فهم "لماذا" لأي مطوّر لاحق.
  - `isPublic` getter يُطابق تماماً الشرط الفعلي المستخدم باستعلامات السيرفر — نقطة اتساق جيدة تقلل احتمال ظهور شاليه غير معتمد بمكان لم يُطبَّق فيه نفس الشرط بالخطأ.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 91، `fromJson`):** `id: json['id'] as String` بدون حماية — لو وصل `json` بدون `id` (نظرياً غير متوقع لعمود مفتاح أساسي NOT NULL، لكن ممكن لو استُخدم النموذج مستقبلاً مع مصدر بيانات جزئي/اختبار) سيرمي `TypeError` غير مُترجَم، بخلاف باقي الحقول جميعها المحمية بعناية بنفس الدالة.

- **اقتراح الإصلاح:**
  - لا حاجة لتغيير جوهري؛ لو أُريد اتساق كامل مع بقية الدالة (دفاعية 100%)، يمكن إضافة فحص صريح:
    ```dart
    final id = json['id'] as String?;
    if (id == null) throw const FormatException('ChaletModel.fromJson: missing id');
    ```
    (يحوّل نفس النوع من الفشل لرسالة أوضح بدل `TypeError` عام، دون تغيير السلوك الفعلي في الحالة الطبيعية).
