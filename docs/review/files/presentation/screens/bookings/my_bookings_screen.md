### lib/presentation/screens/bookings/my_bookings_screen.dart

- **الوظيفة:** ملف "سطر واحد" بالكامل — ليس شاشة فعلية، بل إعادة تصدير (`export`):
  ```dart
  export '../favorites/favorites_screen.dart' show MyBookingsScreen, ReviewsScreen;
  ```

- **الشرح التفصيلي:** لا يوجد أي تعريف class هنا. الغرض الوحيد: السماح لأي ملف يستورد `screens/bookings/my_bookings_screen.dart` (مسار "منطقي" يوحي أن هذا مكان تعريف شاشة الحجوزات) بالوصول لـ `MyBookingsScreen` **و** `ReviewsScreen` — كلاهما **معرَّفان فعلياً** داخل [favorites_screen.dart](../favorites/favorites_screen.md) (سطر 228 و713 على التوالي)، وليس بهذا الملف أو حتى بهذا المجلد.

- **الاعتماديات:** يعيد تصدير من `../favorites/favorites_screen.dart`. **من يستخدمه:** لم أجد أي ملف يستورد `bookings/my_bookings_screen.dart` تحديداً بالبحث الفعلي — [main_screen.dart](../home/main_screen.md) (المستهلك الفعلي الوحيد المؤكَّد لـ `MyBookingsScreen`) يستورد `favorites_screen.dart` **مباشرة**، متجاوزاً هذا الملف بالكامل. **قد يكون هذا الملف كود ميت حالياً من ناحية الاستيراد الفعلي** (موجود "للاستخدام المستقبلي" أو كبقايا إعادة هيكلة)، يحتاج تأكيد نهائي ببحث شامل إضافي لو أُريد الجزم بذلك 100%.

- **التعامل مع Supabase:** لا يوجد — ملف تصدير بحت.

- **نقاط القوة:** لا شيء يُذكر (ملف بنيوي بحت).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة — مؤشر هيكلي واضح على مشكلة تنظيم حقيقية:** وجود هذا الملف (ومثيله [reviews_screen.dart](../reviews/reviews_screen.md)) يكشف أن **ثلاث شاشات غير مترابطة منطقياً** (`FavoritesScreen`, `MyBookingsScreen`, `ReviewsScreen`) مُعرَّفة كلها فعلياً داخل ملف واحد اسمه `favorites_screen.dart` (1069 سطر)، بينما المجلدات "الصحيحة" ظاهرياً (`screens/bookings/`, `screens/reviews/`) لا تحتوي سوى شيمات تصدير سطر واحد. أي مطوّر جديد يبحث عن "أين شاشة حجوزاتي؟" أو يحاول تعديل منطق الحجوزات سيُفاجَأ بإيجاده داخل ملف "المفضلة". هذا لا يسبب عطلاً وظيفياً (الكود يعمل بشكل صحيح)، لكنه يزيد تكلفة الصيانة والفهم بشكل ملموس، وقد يسبب تعارضات Git غير ضرورية (تعديلات على شاشتين منطقياً منفصلتين تتصادم بنفس الملف).
  - 🟡 **بسيطة:** لا استخدام مؤكَّد لهذا الملف تحديداً بالاستيراد الفعلي — إن كان كذلك بالفعل، فهو وزن صيانة زائد بلا فائدة حالية (مشابه لملاحظة [shared_preferences_keys.dart](../../../core/theme/shared_preferences_keys.md)).

- **اقتراح الإصلاح:**
  - **الحل الجذري (يُنصَح به):** نقل تعريف `MyBookingsScreen` فعلياً إلى `lib/presentation/screens/bookings/my_bookings_screen.dart` (وليس مجرد تصدير)، ونقل `ReviewsScreen` إلى `lib/presentation/screens/reviews/reviews_screen.dart`، وتحديث `favorites_screen.dart` ليحتوي `FavoritesScreen` فقط كما يوحي اسمه، مع تحديث الاستيرادات بكل الملفات المستهلكة (`main_screen.dart`, `app_router.dart`, إلخ) لتشير للمسار الصحيح الجديد مباشرة.
  - لو التوحيد الجذري غير ممكن حالياً لضيق وقت/أولوية، الإبقاء على شيمات التصدير هذه مقبول كحل مؤقت، لكن يُفضَّل توثيق هذا القرار بتعليق واضح أعلى `favorites_screen.dart` نفسه يشرح "لماذا 3 شاشات بملف واحد" حتى لا يبدو خطأً غير مقصود لأي قارئ لاحق.
