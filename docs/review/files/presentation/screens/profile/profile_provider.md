### lib/presentation/screens/profile/profile_provider.dart

- **الوظيفة:** `profileProvider` — `FutureProvider<UserProfile?>` واحد يجلب بروفايل المستخدم الحالي (شامل `is_owner`/`role`/`is_admin`)، مُصمَّم عمداً ليكون قابلاً للإبطال (`invalidate`) من أي مكان بالتطبيق يغيّر دور المستخدم.

- **الشرح التفصيلي:**
  - الكود نفسه سطر واحد فعلياً: `FutureProvider<UserProfile?>((ref) async => AuthService.instance.getCurrentProfile());`.
  - **تعليق توثيقي ممتاز (سطر 5-16)** يشرح بدقة **سبب معماري حقيقي** لاختيار `FutureProvider` بدل تحميل محلي بـ `initState` داخل شاشة البروفايل: شاشات التنقّل السفلي بالتطبيق على الأرجح تُبقي كل تبويب حياً بالذاكرة (نمط `IndexedStack` أو ما يعادله) بدل إعادة بنائه من الصفر عند كل تبديل تبويب — أي أن `initState` **لا يُعاد استدعاؤه** عند العودة لتبويب "حسابي". فبدون provider مركزي، لو أصبح المستخدم "مالكاً" فعلياً (بعد `becomeOwner()`) أثناء وجوده بشاشة أخرى، شاشة حسابه كانت ستستمر بعرض الحالة القديمة لحين إعادة تشغيل التطبيق بالكامل. **الحل الموثَّق:** أي كود يغيّر دور المستخدم ينادي `ref.invalidate(profileProvider)`، فتتحدّث فوراً كل الشاشات المراقبة لهذا الـ provider حتى لو كانت بالخلفية.

- **الاعتماديات:** يستورد `flutter_riverpod`, `data/models/models.dart` (لـ `UserProfile`), `data/services/services.dart` (لـ `AuthService`). **من يستخدمه:** [main.dart](../../../main.md) (`ref.invalidate(profileProvider)` عند signIn/signOut/userUpdated — راجع تفصيل كامل بمراجعة main.dart)، وعلى الأرجح [profile_screen.dart](profile_screen.md) وأي شاشة تحتاج معرفة دور المستخدم الحالي بسرعة (مثل إظهار/إخفاء زر "لوحة المالك") — يُؤكَّد بدقة عند مراجعتها.

- **التعامل مع Supabase:** لا اتصال مباشر؛ يُفوِّض بالكامل لـ `AuthService.getCurrentProfile()` بـ[services.dart](../../../data/services/services.md) (قراءة صف كامل من `profiles` بـ `.single()`).

- **نقاط القوة:**
  - تعليق توثيقي نموذجي يشرح "لماذا" هذا التصميم بالتحديد (مشكلة `IndexedStack`/`initState`) بدل ترك القارئ يخمّن — من أفضل الأمثلة التوثيقية بالمشروع.
  - نمط `invalidate` بدل Polling/StreamSubscription لتحديث الحالة بعد تغيّر الدور — بسيط وكفؤ، ويتطابق تماماً مع نفس النمط المُطبَّق فعلياً بـ[main.dart](../../../main.md) لصفحة المفضلة والبروفايل معاً عند تغيّر حالة تسجيل الدخول — اتساق معماري جيد عبر الملفين.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (اعتماداً على `AuthService.getCurrentProfile()` — مُفصَّلة أصلاً بمراجعة [services.dart](../../../data/services/services.md)):** تلك الدالة تستخدم `.single()` بدل `.maybeSingle()` — أي أن حالة "لا يوجد صف بروفايل" (نظرياً نادرة، لكن ممكنة بلحظة مبكرة جداً بعد التسجيل لو تأخّر الـ trigger) تصل لهذا الـ `FutureProvider` كـ **حالة خطأ** (`AsyncError`) وليس كحالة بيانات فارغة (`AsyncData(null)`) رغم أن التوقيع `UserProfile?` يوحي بأن `null` مسار متوقع. أي شاشة تراقب `profileProvider` وتتعامل بعناية مع `.when(data:, error:, loading:)` **يجب أن تفرّق** بين "مستخدم ضيف حقيقي" (لا يُستدعى `getCurrentProfile` أصلاً هنا لأن الدالة تُرجع `null` مباشرة لو `currentUser == null` — هذا المسار سليم كـ`AsyncData(null)`) و"مستخدم مسجّل لكن صف البروفايل غائب لسبب ما" (يصل كـ`AsyncError` لا `AsyncData(null)`) — يحتاج تأكيد بمراجعة الشاشات المستهلكة الفعلية هل تعالج فرع الخطأ هنا بشكل مناسب أم تتجاهله.

- **اقتراح الإصلاح:** لا حاجة لتعديل هذا الملف نفسه؛ الإصلاح الجذري (لو لزم) في `AuthService.getCurrentProfile()` نفسها — راجع الاقتراح بمراجعة [services.dart](../../../data/services/services.md).
