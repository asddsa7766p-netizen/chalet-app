### lib/presentation/screens/owner/pricing_data_source.dart

- **الوظيفة:** طبقة وصول بيانات رفيعة بين شاشة تسعير المالك و[`ChaletPricingService`](../../../data/services/pricing_service.md) — نفس نمط [chalet_edit_data_source.dart](chalet_edit_data_source.md) بالضبط، مطبَّق هنا على عمليات التسعير (أنواع إقامة، أسعار أيام الأسبوع، أسعار تواريخ خاصة).

- **الشرح التفصيلي:** `PricingDataSource` (abstract) بـ7 عمليات، و`ServicePricingDataSource` تفوّض **حرفياً وبدون أي منطق إضافي** لـ`ChaletPricingService.instance` — تعليق الترويسة يوضّح الغرض الوحيد: "تمكين اختبار الشاشة (widget tests) دون Supabase حقيقي".

- **الاعتماديات:** `pricing_service.dart` فقط. **من يستخدمه:** على الأرجح [chalet_pricing_screen.dart](chalet_pricing_screen.md).

- **التعامل مع Supabase:** لا اتصال مباشر (تفويض كامل لـ`ChaletPricingService`).

- **نقاط القوة:** نمط Dependency Inversion متّسق مع [chalet_edit_data_source.dart](chalet_edit_data_source.md) — يؤكد أن وحدة "تعديل/تسعير الشاليه" بأكملها صُمِّمت بعناية معمارية واعية للاختبار، بخلاف معظم بقية المشروع.

- **الأخطاء والمخاطر المحتملة:** لا مخاطر تُذكر — ملف تفويض بسيط بلا منطق خاص به يمكن أن يُخطئ.

- **اقتراح الإصلاح:** لا شيء مطلوب.
