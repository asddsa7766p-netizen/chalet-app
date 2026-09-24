### lib/data/services/host_service.dart

- **الوظيفة:** خدمة صغيرة (25 سطر) بدالة واحدة `isHost()` تتحقق هل المستخدم الحالي له دور "مالك" (`profiles.role == 'owner'`).

- **الشرح التفصيلي:** `HostService` (singleton بنمط `instance`) بدالة `Future<bool> isHost()`: تُرجع `false` مباشرة لو لا يوجد مستخدم حالي، وإلا تستعلم `profiles.role` بـ `.eq('id', userId).maybeSingle()` وتقارن (بعد `toLowerCase()`) بالنص `'owner'`.

- **الاعتماديات:** يستورد `supabase_flutter` فقط. **من يستخدمه:** [app_router.dart](../../core/router/app_router.md) (حراسة كل مسارات `/owner-*` عدا `owner-add-chalet`) — مستهلك واحد مؤكَّد حالياً، وربما شاشات أخرى تُكتشف لاحقاً.

- **التعامل مع Supabase:** قراءة عمود واحد (`role`) من جدول `profiles` مفلترة بـ `id`.

- **نقاط القوة:** دالة صغيرة، واضحة الغرض، ومقاومة لاختلاف حالة الأحرف (`toLowerCase()` قبل المقارنة) — تحسّب لسيناريو تخزين القيمة بصيغة غير متوقعة (`Owner` بدل `owner`).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 12-24):** **لا يوجد أي `try/catch`** حول الاستعلام. بما أن المستهلك الوحيد المؤكَّد هو `redirect` بـ[app_router.dart](../../core/router/app_router.md) (الذي أيضاً لا يلتقط الاستثناء)، فأي خطأ شبكة يكسر تنقّل المالك بالكامل بدل التعامل معه بأمان. **تفصيل كامل وحل مقترح بمراجعة app_router.dart** (المكان الذي يظهر فيه الأثر الفعلي).
  - 🟡 **بسيطة:** لا يوجد أي كاش هنا (بخلاف `AuthService.isAdmin()` بـ[services.dart](services.md) المكاش صراحة بمتغيّر ثابت وتُمسَح عند تغيّر الجلسة). كل نداء لـ `isHost()` = استعلام Supabase جديد، رغم أن دور المستخدم لا يتغيّر عادة أثناء الجلسة نفسها. بما أن `redirect` بالراوتر يُعاد تنفيذه مع كل تنقّل، هذا يعني استعلام متكرر بكل تبديل تبويب بين شاشات owner.

- **اقتراح الإصلاح:**
  - إضافة try/catch يُرجع `false` بأمان (fail-closed) عند أي خطأ، تماماً كأسلوب `isAdmin()`:
    ```dart
    Future<bool> isHost() async {
      final userId = _supabaseHost.auth.currentUser?.id;
      if (userId == null) return false;
      try {
        final data = await _supabaseHost
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .maybeSingle();
        return (data?['role'] as String?)?.toLowerCase() == 'owner';
      } catch (_) {
        return false; // أو رمي استثناء مخصص ليعرض الراوتر رسالة "تعذّر التحقق"
      }
    }
    ```
  - إضافة كاش بسيط مشابه لـ `AuthService._isAdminCache`، يُمسَح بنفس نقطة مسح `clearAdminCache()` (تسجيل دخول/خروج/تحديث مستخدم) لتفادي استعلام متكرر عديم الفائدة عند كل تنقّل بين شاشات owner.
