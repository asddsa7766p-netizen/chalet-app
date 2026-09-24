### lib/presentation/screens/owner/chalet_edit_data_source.dart

- **الوظيفة:** طبقة وصول بيانات رفيعة (Data Source abstraction) بين شاشة تعديل/إضافة الشاليه وSupabase — واجهة مجرّدة `ChaletEditDataSource` + تنفيذ فعلي `SupabaseChaletEditDataSource`.

- **الشرح التفصيلي:**
  - **`ChaletEditDataSource`** (abstract class، سطر 12-37): 4 عمليات (`fetchChalet`, `uploadImages`, `updateChalet`, `deleteImageUrls`)، موثّقة الغرض صراحة بالتعليق: "لتمكين اختبارها بلا Supabase" — نمط Dependency Inversion حقيقي (نادر بهذا المشروع، معظم الملفات الأخرى تستدعي `Supabase.instance.client` مباشرة).
  - **`SupabaseChaletEditDataSource.updateChalet`** (سطر 70-86) — **أهم دالة بالملف من ناحية الأمان والصحة**:
    ```dart
    final illegal = changes.keys.where((k) => !chaletEditableColumns.contains(k));
    if (illegal.isNotEmpty) {
      throw ArgumentError('Column not editable from this screen: $illegal');
    }
    final rows = await _client.from('chalets').update(changes).eq('id', chaletId).select();
    return rows.isEmpty ? null : rows.first;
    ```
    (أ) **يرفض محلياً وقبل أي نداء شبكة** أي عمود خارج [`chaletEditableColumns`](chalet_edit_model.md) — حماية عميل إضافية فوق أي حماية سيرفر (RLS/trigger). (ب) **يستخدم `.select()` بعد `.update()` ويتحقق من عدد الصفوف المُعادة صراحة** — تعليق يوثّق بدقة تامة سلوك PostgREST الصحيح: "رفض الـRLS لا يرمي خطأ بل يحدّث صفر صفوف"، ويتعامل معه بشكل صحيح (`null` عند صفر صفوف) بدل افتراض النجاح.
  - `deleteImageUrls`: يفلتر الروابط عبر `chaletImageStoragePath` (من [chalet_edit_model.dart](chalet_edit_model.md)) قبل الحذف الفعلي من bucket `chalet-images`.

- **الاعتماديات:** `image_picker`, `supabase_flutter`, `services.dart` (فقط `ChaletService.uploadChaletImages`)، `chalet_edit_model.dart`. **من يستخدمه:** على الأرجح [owner_add_chalet_screen.dart](owner_add_chalet_screen.md)/[owner_edit_chalet_screen.dart](owner_edit_chalet_screen.md).

- **التعامل مع Supabase:** `chalets` (select واحد، update مع `.select()` للتحقق)، Storage `chalet-images` (حذف).

- **نقاط القوة:**
  - **هذا الملف تحديداً هو أفضل مثال بكل المشروع على التعامل الصحيح مع سلوك "RLS ترفض بصمت" الذي طلب المستخدم الانتباه له** — يتحقق فعلياً من عدد الصفوف المتأثرة بدل افتراض النجاح، بخلاف عدة دوال أخرى بـ[services.dart](../../../data/services/services.md) (`confirmIncomingBooking`, `rejectIncomingBooking`, `cancelBooking`) التي تحديث بدون `.select()` أو فحص لاحق. **يستحق أن يكون النمط المرجعي (reference pattern) لبقية عمليات التحديث الحساسة بالمشروع.**
  - نمط Dependency Inversion حقيقي يسهّل الاختبار (interface + تنفيذ)، غير مستخدَم بأي مكان آخر بالمشروع تقريباً.
  - حماية عميل استباقية (قائمة بيضاء) قبل الشبكة — تقليل فرص خطأ برمجي يرسل عموداً محمياً بالخطأ.

- **الأخطاء والمخاطر المحتملة:** لا مخاطر تُذكر — جودة هندسية عالية جداً ومتّسقة مع بقية وحدة تعديل الشاليه.

- **اقتراح الإصلاح:** لا شيء مطلوب لهذا الملف. **توصية أشمل للمشروع:** تعميم نمط `updateChalet` هنا (فحص عدد الصفوف بعد `.update().select()`) على كل عمليات التحديث الحساسة الأخرى بالمشروع — راجع التوصية المقترحة بـ[services.md](../../../data/services/services.md).
