### lib/presentation/widgets/common/common_widgets.dart (377 سطر)

- **الوظيفة:** مكوّنات واجهة مشتركة عامة: حقل نص موحَّد (`CustomTextField`)، زر رئيسي بحالة تحميل (`AppButton`)، عنوان قسم (`SectionHeader`)، بطاقة تحميل وامضة (`ShimmerCard`)، وبطاقة عرض شاليه بتخطيطين (`ChaletCard`).

- **الشرح التفصيلي:**
  - `CustomTextField`: غلاف حول `TextFormField` بتصميم موحَّد (حدود، حشوة، خط Cairo). **مُستخدَم فعلياً وبكثافة** — تحقَّقتُ عبر بحث مباشر بالكود: `booking_screen.dart`, `search_screen.dart` (مرتين), `favorites_screen.dart`, `profile_screen.dart`, `forgot_password_screen.dart` (3 مرات), `owner_add_chalet_screen.dart` (6 مرات).
  - `AppButton`: زر رئيسي بحالة `loading` (تعطيل + مؤشر دوران بدل النص). **مُستخدَم فعلياً** بـ`search_screen.dart`, `favorites_screen.dart`, `profile_screen.dart`, `forgot_password_screen.dart` (مرتين).
  - `SectionHeader`: عنوان قسم + زر إجراء اختياري. **كود ميت مؤكَّد بالكامل** — بحث مباشر بكل الكود لا يجد أي استدعاء `SectionHeader(` خارج تعريفه هنا. **تصحيح لملاحظة كانت هنا سابقاً:** `LuxurySectionHeader` بـ[luxury_widgets.dart](luxury_widgets.md) **ليست البديل الفعلي المستخدَم** كما افتُرض ابتداءً — تحقَّقتُ لاحقاً عبر بحث مباشر أنها **هي أيضاً كود ميت غير مُستخدَم بأي مكان**؛ عناوين الأقسام الفعلية بالشاشات (home_tab.dart إلخ) تُبنى على الأرجح بنصوص `Text` مباشرة بلا مكوّن مشترك، بلا استخدام أي من الكلاسين.
  - `ShimmerCard`: بطاقة هيكل تحميل وامضة (`Shimmer.fromColors`). **مُستخدَمة فعلياً** بـ`search_screen.dart` فقط — بينما `home_tab.dart` يستخدم `LuxuryShimmerCard` (تعريف مختلف بـ[luxury_widgets.dart](luxury_widgets.md)) لنفس الغرض تماماً.
  - `ChaletCard`: بطاقة عرض شاليه بتخطيطين (أفقي/عمودي) — صورة (`CachedNetworkImage` مع `errorWidget` احتياطي)، اسم، موقع، سعر، وزر مفضَّلة. **مُستخدَمة فعلياً** بـ`search_screen.dart` و`favorites_screen.dart`. (ملاحظة: `owner_chalets_screen.dart` يستخدم بطاقة خاصة به `_ChaletCard` منفصلة تماماً — منطقي لأن محتوى بطاقة المالك مختلف جوهرياً: حالة اعتماد/توفر بدل زر مفضَّلة، فليس تكراراً غير مبرَّر).
  - عند غياب صورة غلاف الشاليه (`chalet.coverImage.isEmpty`)، يُستخدَم **رابط صورة خارجي ثابت من Unsplash** كبديل مؤقت (سطر 234).

- **الاعتماديات:** `cached_network_image`, `shimmer`, `app_colors.dart`, `chalet_model.dart`. **من يستخدمه:** راجع أعلاه لكل كلاس على حدة.

- **التعامل مع Supabase:** لا يوجد — كل البيانات تُمرَّر جاهزة من الشاشة الأب (`ChaletModel`، دوال تحقق، callbacks).

- **نقاط القوة:**
  - `CustomTextField`/`AppButton` يقلّلان تكرار كود التنسيق بشكل حقيقي وفعّال عبر 6+ شاشات مختلفة.
  - `ChaletCard` يدعم تخطيطين (قوائم أفقية وعمودية) من مكوّن واحد مشترك بدل تكرار بطاقتين منفصلتين.
  - `errorWidget` احتياطي على `CachedNetworkImage` — تدهور رشيق (Container رمادي بسيط) حتى لو فشل تحميل الصورة الفعلية (أو حتى صورة Unsplash البديلة).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 234) — صورة بديلة ثابتة من خدمة خارجية (Unsplash) لشاليه بلا صورة غلاف:**
    ```dart
    final image = chalet.coverImage.isNotEmpty
        ? chalet.coverImage
        : 'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80';
    ```
    أي شاليه (أو حجز) بلا صورة غلاف فعلية يعرض **نفس صورة كوخ/شاليه عشوائية من الإنترنت لا علاقة لها بالعقار الحقيقي** لكل مستخدمي التطبيق دون تمييز — قد يُفهَم خطأً على أنه صورة العقار الفعلية (مضلِّل تسويقياً)، ويعتمد على توفّر رابط خارجي واحد بلا ضمان استمراريته (Unsplash قد يُغيّر/يحذف الصورة أو يقيّد الوصول لاحقاً بلا إشعار).
  - 🟡 **بسيطة (كود ميت مؤكَّد) — `SectionHeader` غير مُستخدَم إطلاقاً بأي مكان بالتطبيق.**
  - 🟡 **بسيطة (تكرار غير ضروري) — يوجد تطبيقان منفصلان لنفس فكرة "بطاقة تحميل وامضة"** (`ShimmerCard` هنا و`LuxuryShimmerCard` بـ[luxury_widgets.dart](luxury_widgets.md))، كل منهما يُستخدَم فعلياً بملف مختلف — لا خطأ وظيفي، لكنه ازدواجية صيانة (تعديل مستقبلي على أحدهما قد يُنسى بالآخر).
  - 🟡 **بسيطة (سطر 280-287) — نص الموقع بتخطيط `ChaletCard.horizontal` بلا `maxLines`/`overflow`:** بخلاف اسم الشاليه (محمي بـ`maxLines: 2, overflow: ellipsis`)، نص `chalet.location` بلا أي حد لعدد الأسطر — لعنوان طويل بشكل غير معتاد قد يتمدد البطاقة رأسياً أكثر من المتوقَّع بقائمة أفقية ذات ارتفاع صف ثابت (لم أتحقق بصرياً من الأثر الفعلي بقوائم `search_screen.dart`/`favorites_screen.dart` الحالية).

- **اقتراح الإصلاح:**
  - استبدال رابط Unsplash الخارجي بأصل محلي مُرفَق بالتطبيق (`assets/images/chalet_placeholder.png`) — أسرع، لا يعتمد على خدمة خارجية، ولا يُري المستخدم صورة عقار وهمية قد تُفهَم كصورة حقيقية.
  - حذف `SectionHeader` بعد التأكد من عدم استخدامه (مؤكَّد فعلياً بهذه المراجعة)، أو توحيده مع `LuxurySectionHeader` كمكوّن واحد.
  - توحيد `ShimmerCard`/`LuxuryShimmerCard` بمكوّن واحد يُستخدَم من كل الشاشات.
  - إضافة `maxLines: 1, overflow: TextOverflow.ellipsis` لنص `chalet.location` بتخطيط `horizontal`.
