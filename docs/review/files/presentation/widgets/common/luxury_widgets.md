### lib/presentation/widgets/common/luxury_widgets.dart (165 سطر)

- **الوظيفة:** مجموعة ثانية من مكوّنات واجهة مشتركة بتصميم "فاخر" مختلف عن [common_widgets.dart](common_widgets.md): شريط بحث (`LuxurySearchBar`)، عنوان قسم (`LuxurySectionHeader`)، بطاقة تحميل وامضة (`LuxuryShimmerCard`)، وحالة فارغة (`LuxuryEmptyState`).

- **الشرح التفصيلي:**
  - `LuxurySearchBar`: `TextField` بتصميم مخصَّص، مع زر "X" لمسح النص يظهر فقط لو `controller!.text.isNotEmpty` **وقت البناء**. **مُستخدَمة فعلياً** بمكان واحد: [home_tab.dart](../../screens/home/home_tab.md) (`_buildSearchBar`) — راجع الخطر أدناه لمشكلة تفاعلية مؤكَّدة بهذا الاستخدام تحديداً.
  - `LuxurySectionHeader`: عنوان + إيموجي اختياري. **كود ميت مؤكَّد بالكامل** — لا يوجد أي استدعاء `LuxurySectionHeader(` بأي مكان بالكود خارج تعريفه هنا (تحقَّقتُ ببحث مباشر، وليس افتراضاً).
  - `LuxuryShimmerCard`: بطاقة هيكل تحميل وامضة بارتفاع قابل للتخصيص. **مُستخدَمة فعلياً** بـ[home_tab.dart](../../screens/home/home_tab.md) (مرّتين) — وهي **تطبيق مختلف تماماً** لنفس فكرة `ShimmerCard` بـ[common_widgets.dart](common_widgets.md) (المُستخدَمة بملف آخر، `search_screen.dart`) — راجع ملاحظة الازدواجية المُسجَّلة هناك.
  - `LuxuryEmptyState`: أيقونة + رسالة لحالة فارغة. **كود ميت مؤكَّد بالكامل** — لا يوجد أي استدعاء `LuxuryEmptyState(` بأي مكان بالكود خارج تعريفه هنا.

- **الاعتماديات:** `shimmer`, `app_colors.dart`. **من يستخدمه:** [home_tab.dart](../../screens/home/home_tab.md) فقط (`LuxurySearchBar`, `LuxuryShimmerCard`)؛ `LuxurySectionHeader`/`LuxuryEmptyState` بلا أي مستخدم.

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:**
  - تصميم بصري متماسك (حدود دائرية 18، ألوان AppColors، خط Cairo) متّسق مع باقي المشروع.
  - `LuxuryShimmerCard`/`LuxuryEmptyState` بسيطتان وواضحتا الغرض حيثما تُستخدَمان فعلياً.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة إلى متوسطة (سطر 41-47، مؤكَّدة بفحص الاستخدام الفعلي بـhome_tab.dart) — زر مسح البحث "X" لا يظهر/يختفي تفاعلياً أثناء الكتابة:** `LuxurySearchBar` هو `StatelessWidget` يقرر ظهور زر "X" من `controller!.text.isNotEmpty` **مرة واحدة وقت البناء فقط**، بلا أي استماع فعلي لتغيّرات `controller` (لا `ValueListenableBuilder`/`AnimatedBuilder` بداخله). **تحقَّقتُ مباشرة أن استخدامه الوحيد الفعلي (`home_tab.dart`) لا يمرِّر `onChanged` إطلاقاً ولا يُضيف أي `_searchCtrl.addListener` بذلك الملف** — فلا شيء يُعيد بناء `LuxurySearchBar` أثناء كتابة المستخدم. النتيجة العملية: زر "X" يبقى بحالته الأولى (مخفياً غالباً) طوال الكتابة، ولا يظهر/يتحدَّث إلا صدفةً عند إعادة بناء غير مرتبطة (مثل وصول نتائج بحث بعد الضغط على زر البحث بلوحة المفاتيح). هذا استنتاج **مؤكَّد بفحص مباشر لكود الاستدعاء الفعلي**، وليس افتراضاً نظرياً.
  - 🟡 **بسيطة (كود ميت مؤكَّد) — `LuxurySectionHeader` غير مُستخدَمة بأي مكان بالتطبيق** (تصحيح لملاحظة كانت مذكورة سابقاً بمراجعة common_widgets.dart بأنها البديل الفعلي لـ`SectionHeader` — غير صحيح، كلاهما ميت).
  - 🟡 **بسيطة (كود ميت مؤكَّد) — `LuxuryEmptyState` غير مُستخدَمة بأي مكان بالتطبيق.**
  - **(مُكرَّر، مُسجَّل بالفعل بـcommon_widgets.md)** — ازدواجية `LuxuryShimmerCard` مقابل `ShimmerCard`.

- **اقتراح الإصلاح:**
  - إما تمرير `onChanged: (_) => setState(() {})` (أو ما يعادله) من `home_tab.dart` عند استخدام `LuxurySearchBar`، أو (الأفضل بنيوياً) تحويل `LuxurySearchBar` نفسها لتستمع لـ`controller` داخلياً (`ValueListenableBuilder<TextEditingValue>` حول `suffixIcon` فقط) حتى تعمل بشكل تفاعلي صحيح بغض النظر عمّا يمرِّره المستدعي.
  - حذف `LuxurySectionHeader`/`LuxuryEmptyState` بعد التأكد من عدم استخدامهما (مؤكَّد فعلياً)، أو توحيدهما مع نظرائهما بـ[common_widgets.dart](common_widgets.md) إن كانت هناك نية لاستخدام أحد النمطين مستقبلاً.
