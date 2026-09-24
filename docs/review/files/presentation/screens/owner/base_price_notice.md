### lib/presentation/screens/owner/base_price_notice.dart

- **الوظيفة:** ويدجت إشعار داخل بطاقة "نوع الإقامة" بشاشة تسعير المالك، يشرح بوضوح **أثر السعر الاحتياطي الفعلي** (`base_price` لنوع إقامة معيّن) حسب هرم الأولوية الموصوف بـ[pricing_service.dart](../../../data/services/pricing_service.md): هل سيُطبَّق على كل الأيام، لن يُطبَّق إطلاقاً (تجاوزته أسعار أدق)، أم يُطبَّق جزئياً فقط.

- **الشرح التفصيلي:** `BasePriceNotice` (`StatelessWidget`) يقرأ `BasePriceImpact` (مُمرَّرة جاهزة، محسوبة على الأرجح بـ[pricing_preview.dart](pricing_preview.md) أو [pricing_data_source.dart](pricing_data_source.md)) ويعرض إحدى 4 حالات (`notSet`/`ignored`/`partial`/`applied`) بلون/أيقونة/نص مناسب، مع شرح **سبب** كل حالة تحديداً (`_ignoredReason`/`_partialRest` تبنيان جملة عربية دقيقة تذكر أي الأيام مغطّاة بأي مستوى أولوية). بحالتي `ignored`/`partial` يظهر زر "اضبط أسعار الأيام لهذا النوع" (`onOpenTypePrices`) ينقل المالك مباشرة لحل المشكلة بدل مجرد إخباره بها.

- **الاعتماديات:** `app_colors.dart`, `pricing_service.dart` (`ChaletStayType`)، `pricing_preview.dart` (`BasePriceImpact`, `BasePriceStatus`, `formatPriceNumber`, `describeWeekdays`). **من يستخدمه:** على الأرجح [chalet_pricing_screen.dart](chalet_pricing_screen.md).

- **التعامل مع Supabase:** لا يوجد — عرض بحت لبيانات محسوبة مسبقاً.

- **نقاط القوة:**
  - **شرح فعلي لمنطق أولوية تسعير معقّد بلغة مفهومة للمالك** (وليس مجرد "سعر افتراضي: 100₪") — يقلل احتمال أن يظن مالك أن سعره الاحتياطي يُطبَّق فعلاً بينما لا يُطبَّق أبداً بسبب أسعار أدق تسبقه بالأولوية (سوء فهم واقعي جداً بنظام تسعير هرمي كهذا).
  - يوجّه لحل فعلي (زر ينقل مباشرة لمكان الإصلاح) بدل إشعار جامد.
  - يستخدم `.withValues(alpha:)` (الـ API الحديث غير المهجور) بدل `.withOpacity()` المهجورة المنتشرة بعدة ملفات أخرى بالمشروع (راجع [app_theme.md](../../../core/theme/app_theme.md)) — إشارة لكتابة أحدث/أكثر عناية بهذا الجزء من الكود.
  - `Key`ات صريحة (`ValueKey('baseImpact_...')`) على كل حالة — تسهّل الاختبار الآلي (widget tests) لهذا المكوّن تحديداً.

- **الأخطاء والمخاطر المحتملة:** لا مخاطر تقنية تُذكر — ويدجت عرض بحت منطقه صحيح ومتّسق مع هرم الأولوية الموثَّق بملف الخدمة.

- **اقتراح الإصلاح:** لا شيء مطلوب.
