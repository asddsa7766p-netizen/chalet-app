### lib/core/router/app_router.dart

- **الوظيفة:** يعرّف `AppRouter.router` — كائن `GoRouter` واحد مركزي لكل تنقل بالتطبيق، بما فيه شجرة كل المسارات (`GoRoute`) ومنطق الحراسة المركزي (`redirect`) الذي يقرر السماح بالدخول لمسار معيّن أو إعادة التوجيه حسب حالة تسجيل الدخول/الدور (owner/admin).

- **الشرح التفصيلي:**
  - **`isPublicRoute(String location)`** (سطر 41-49): دالة ثابتة تُرجع `true` لو المسار من: `/onboarding`, أي شيء يبدأ بـ `/auth/`, `/home`, أي شيء يبدأ بـ `/home/chalet/`, `/search`, `/map`, `/reels`. هذه فقط المسارات المسموحة للضيف بدون تسجيل دخول.
  - **`isProtectedRoute(String location)`** (سطر 52-58): `true` لـ `/home/booking`, `/payment`, أي شيء يبدأ بـ `/home/reviews/`, أي شيء يبدأ بـ `/owner-`, و`/admin-dashboard`.
  - **`redirect` (سطر 63-111)** يُنفَّذ (async) قبل كل تنقل، بالترتيب:
    1. لو `!Supabase.instance.isInitialized` → يسمح فقط بـ onboarding/auth، وإلا يعيد لـ `/onboarding` (حماية من الوصول المبكر جداً قبل اكتمال `main()`).
    2. `isLoggedIn = Supabase.instance.client.auth.currentUser != null` — **فحص محلي متزامن** من الجلسة المخزَّنة (لا نداء شبكة)، سريع وصحيح.
    3. `/onboarding`: لو مسجّل دخول يذهب لـ `/home` مباشرة، وإلا يبقى.
    4. مسجّل دخول + بصفحة `/auth/*` → يحوَّل لـ `/home` (يمنع رؤية شاشة تسجيل دخول وهو مسجّل أصلاً).
    5. مسار عام → يُسمح فوراً (`return null`).
    6. مسار محمي وغير مسجّل دخول → `/auth/login`.
    7. مسار `owner-*` (عدا `owner-add-chalet`) → `await HostService.instance.isHost()`؛ لو false يُحوَّل لـ `/home`.
    8. `/admin-dashboard` → لو غير مسجّل: `/auth/login`؛ وإلا `await AuthService.instance.isAdmin()`؛ لو false يُحوَّل لـ `/home`.
    9. غير ذلك: `return null` (يسمح).
  - **شجرة المسارات (سطر 112-272):** قائمة مسطّحة إلى حد كبير من `GoRoute`، مع تعشيش واحد فقط تحت `/home`: `chalet/:id`، `booking`، `reviews/:chaletId` (سطر 195-242). كل مسارات `/owner-*` والـ admin مسطّحة بالمستوى الجذري رغم كونها منطقياً "تحت" تدفق المالك — قرار تنظيم مقبول (GoRouter لا يفرض تعشيشاً حسب المنطق البصري).
  - **تمرير بيانات بين الشاشات عبر `state.extra`:**
    - `/payment` (سطر 160-190): `redirect` خاص بهذا المسار يتحقق أولاً من `AppRouter.onlinePaymentEnabled` (== `false` حالياً، ثابت مع تعليق صريح "الدفع الإلكتروني معطّل مؤقتاً... MockPaymentGateway الحالي لا ينشئ حجزاً فعلياً") فيُعاد لـ `/home` **دائماً** بغض النظر عن أي شيء آخر. ثم (لو فُعِّل مستقبلاً) يتحقق أن `state.extra` هو `Map<String, dynamic>` وأن كل مفتاح (`chalet`, `checkIn`, `checkOut`, `guestsCount`) من النوع الصحيح، وإلا `/home` أيضاً — فحص نوع صريح موثّق بتعليق أنه إصلاح لمشكلة `TypeError` حقيقية كانت تحدث عند deep link/تحديث صفحة ويب/Hot Restart (فقدان `extra` عبر إعادة تحميل الصفحة).
    - `/home/chalet/:id` (سطر 201-217) و`/home/booking` (سطر 218-232): نفس نمط فحص النوع الآمن (`extra is ChaletModel`) بدل cast مباشر (`as`)، مع fallback منطقي (تحميل البيانات ذاتياً بالشاشة، أو تمرير `null`).
    - `/home/reviews/:chaletId` (سطر 233-239): هنا **لا يوجد** نفس الفحص الآمن — `final chaletName = state.extra as String? ?? '';` يستخدم `as String?` (cast قابل للـ null، وليس فحص `is`) — لو `state.extra` من نوع مختلف تماماً عن `String` أو `null` (مثلاً `Map` أو `ChaletModel` بالخطأ) فسيرمي `TypeError` وقت التشغيل تماماً كما كانت المشكلة الأصلية الموثّقة أعلاه بمسارات أخرى، لأن `as String?` يتحقق فقط أن القيمة إمّا `String` أو `null`، ويفشل لأي نوع ثالث.
  - **`onlinePaymentEnabled = false`** (سطر 38): flag ثابت على مستوى الـ class، يُستخدم فقط داخل `redirect` لمسار `/payment`.

- **الاعتماديات:** يستورد كل شاشات `presentation/screens/*` التي لها مسار (auth, home, search, payment, reels, chalet, booking, reviews, owner/*, admin, map, notifications)، بالإضافة إلى `data/models/chalet_model.dart`, `data/services/host_service.dart`, `data/services/services.dart`. **من يستخدمه:** [main.dart](../../main.md) فقط (`routerConfig: AppRouter.router` داخل `MaterialApp.router`)، وكل مكان بالتطبيق يستخدم `context.go(...)`/`context.push(...)` (سيُلاحَظ بكل شاشة أثناء المراجعة).

- **التعامل مع Supabase:** لا يستعلم جداول مباشرة، لكن `redirect` يستدعي عبر الخدمات: `HostService.instance.isHost()` (يقرأ `profiles.role`) و`AuthService.instance.isAdmin()` (يقرأ `profiles.is_admin`، مع كاش داخلي) وأيضاً `Supabase.instance.client.auth.currentUser` (محلي بدون شبكة).

- **نقاط القوة:**
  - حراسة مركزية واحدة (`redirect`) بدل تكرار فحص "هل مسجّل دخول؟" بكل شاشة — تصميم نظيف يمنع نسيان الحراسة بشاشة جديدة تُضاف لاحقاً (طالما صُنِّف مسارها الجديد ضمن `isProtectedRoute`/`owner-`/`admin-`).
  - إصلاحات موثّقة بالكود لمشاكل حقيقية حدثت فعلاً (type-unsafe `extra`، تعليق صريح يشرح كل حالة) — يدل على تعلّم من حوادث فعلية بدل افتراضات نظرية.
  - تعطيل مسار الدفع الإلكتروني بشكل صريح وواضح السبب (بدل ترك شاشات دفع نصف مكتملة قابلة للوصول ومربكة) — قرار منتج جيد ومُبلَّغ بوضوح بالتعليق.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 98-101):** `await HostService.instance.isHost()` يُستدعى **بدون أي try/catch** داخل `redirect`. بمراجعة [host_service.dart](../../data/services/host_service.md) مباشرة: دالة `isHost()` هناك أيضاً **بدون try/catch** حول استعلام `profiles` — أي أن أي خطأ شبكة (لا إنترنت، timeout، خطأ Supabase) أثناء تنقّل المالك لأي شاشة `/owner-*` سيرمي استثناء غير ملتقَط داخل `redirect` نفسه. بخلاف `AuthService.isAdmin()` (المستخدم بنفس الملف لمسار `/admin-dashboard`، سطر 106) الذي **يلتقط** الخطأ صراحة ويُرجع `false` بأمان (`catch (_) { return false; }` — راجع [services.dart](../../data/services/services.md) سطر 271-281). **هذا تناقض واضح بين مساري الحماية بنفس الملف**: مسار الأدمن محمي من فشل الشبكة، ومسار المالك غير محمي إطلاقاً. الأثر العملي: مالك بلا إنترنت مستقر (أو Supabase بطيء/متعطل مؤقتاً) قد تفشل عليه شاشة owner بالكامل بدل رسالة خطأ مفهومة أو إعادة توجيه لطيفة.
  - 🟡 **بسيطة (سطر 98-101):** حتى في الحالة السعيدة (بدون خطأ شبكة)، `isHost()` **بدون أي كاش** (على عكس `isAdmin()` المكاش صراحة). بما أن `redirect` يُعاد تنفيذه من GoRouter مع كل عملية تنقل (`go`/`push`)، فكل تبديل تبويب بين شاشات المالك (`owner_bottom_nav.dart` على الأرجح يستخدم `context.go('/owner-...')` بين التبويبات) يُطلق استعلام Supabase جديد لقراءة `profiles.role` من جديد، رغم أن الدور لا يتغيّر عادة أثناء الجلسة نفسها. هذا يعني تأخير/وميض متكرر محتمل عند كل تنقل بين شاشات owner. تفصيل الحل المقترح في مراجعة [host_service.dart](../../data/services/host_service.md).
  - 🟡 **بسيطة (سطر 237):** `final chaletName = state.extra as String? ?? '';` بمسار `reviews/:chaletId` يستخدم cast مباشر (`as String?`) بدل فحص `is` الآمن المستخدم بمسارات أخرى بنفس الملف (`chalet/:id`, `booking`, `payment`) — نفس فئة الخطأ (`TypeError`) الذي أصلحه الكود عمداً بالمسارات الأخرى لم يُصلَح هنا. أي وصول لهذا المسار بـ `extra` من نوع غير `String`/`null` (مثلاً عبر خطأ برمجي مستقبلي بمكان استدعاء آخر) سيكسر التنقل.
  - 🟡 **بسيطة:** لا يوجد مسار "غير موجود" (`errorBuilder`/404) معرَّف على `GoRouter` — لو انتقل التطبيق (أو رابط خارجي/deep link) لمسار غير معرَّف بالشجرة، السلوك يعتمد على معالجة GoRouter الافتراضية للأخطاء (شاشة خطأ عامة) بدل تجربة متسقة مع تصميم التطبيق. يحتاج تأكيد بالتجربة الفعلية بدل افتراض.
  - 🟡 **بسيطة (سطر 38-39, 162-165):** `onlinePaymentEnabled = false` هو ثابت Dart عادي (`static const bool`)، أي تغييره يتطلب تعديل كود وإصدار تحديث تطبيق كامل، وليس remote config/feature flag قابل للتبديل من طرف السيرفر. مقبول لمرحلة حالية، لكن يستحق الإشارة كنقطة تحتاج قراراً هندسياً عند الاستعداد فعلياً لتفعيل الدفع الإلكتروني.

- **اقتراح الإصلاح:**
  - لف كل استدعاء غير آمن بحراسة `redirect` بـ try/catch يُرجع قيمة افتراضية آمنة (fail-closed، أي `/home` أو رسالة "تعذّر التحقق، حاول لاحقاً") بدل استثناء غير ملتقَط، مطابقةً لما فعلته الدالة `isAdmin()` تماماً:
    ```dart
    if (location.startsWith('/owner-') && location != '/owner-add-chalet') {
      try {
        final isHost = await HostService.instance.isHost();
        return isHost ? null : '/home';
      } catch (_) {
        return '/home'; // أو مسار/رسالة "تعذّر التحقق من صلاحياتك"
      }
    }
    ```
  - توحيد فحص `state.extra` بمسار `reviews/:chaletId` مع نفس أسلوب الفحص الآمن (`is`) المستخدم بباقي المسارات:
    ```dart
    final extra = state.extra;
    final chaletName = extra is String ? extra : '';
    ```
  - إضافة `errorBuilder` لـ `GoRouter` لعرض شاشة "الصفحة غير موجودة" متّسقة مع تصميم التطبيق بدل الاعتماد على السلوك الافتراضي.
