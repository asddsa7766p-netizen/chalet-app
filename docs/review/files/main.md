### lib/main.dart

- **الوظيفة:** نقطة دخول التطبيق: تحميل متغيرات البيئة، تهيئة Supabase (بتخزين جلسة آمن مخصّص)، تهيئة Sentry لمراقبة الأخطاء، تهيئة بيانات التاريخ العربية، قفل الاتجاه العمودي، ثم تشغيل `FriendsChaletsApp` (الـ widget الجذر) داخل `ProviderScope` (Riverpod).

- **الشرح التفصيلي:**
  - **`_loadEnv()`** (سطر 21-32): يحاول تحميل `.env` من جذر المشروع، ولو فشل يجرّب `assets/.env`، ولو فشل الاثنان يرمي `StateError` صريح ("Missing .env file..."). فشل واضح ومبكر بدل تشغيل التطبيق بحالة غير مكتملة — نمط جيد.
  - **`_SecureSupabaseStorage`** (سطر 36-66): تطبيق مخصّص لواجهة `LocalStorage` من `supabase_flutter`، يستخدم `FlutterSecureStorage` (مع `encryptedSharedPreferences: true` على أندرويد) بدل التخزين الافتراضي. يخزّن سلسلة الجلسة الكاملة (access/refresh token) تحت مفتاح ثابت واحد `sb-auth-token`. الدوال: `initialize()` (no-op)، `hasAccessToken()`، `accessToken()`، `persistSession(String)`، `removePersistedSession()` — تطابق تماماً توقيع الواجهة المطلوبة من supabase_flutter.
  - **`main()`** (سطر 68-138) بالترتيب:
    1. `WidgetsFlutterBinding.ensureInitialized()`.
    2. `await SharedPreferences.getInstance()` — تسخين مبكر (التعليق بالكود يوضّح أنه لم يعد ضرورياً لتخزين جلسة Supabase نفسها بعد التحول لـ `_SecureSupabaseStorage`، لكنه ما زال مفيداً لأن اللغة/الثيم/onboarding تُقرأ عبر `SharedPreferences.getInstance()` في أماكن أخرى من التطبيق).
    3. `initializeDateFormatting('ar')` — إصلاح موثّق بتعليق لمشكلة حقيقية (تقويم `TableCalendar` كان يعرض أسماء الأشهر/الأيام بالإنجليزية رغم أن التطبيق عربي بالكامل).
    4. `_loadEnv()`.
    5. قراءة `SUPABASE_URL`/`SUPABASE_ANON_KEY` من `dotenv.env`، مع `throw StateError` صريح لو أي منهما `null`.
    6. `Supabase.initialize(url:, anonKey:, authOptions: FlutterAuthClientOptions(localStorage: _SecureSupabaseStorage()))`.
    7. تهيئة Sentry **فقط لو** `_sentryDsn.isNotEmpty` (وهو `String.fromEnvironment('SENTRY_DSN', defaultValue: '')` — قيمة تُحدَّد وقت البناء عبر `--dart-define`، وليست من `.env`).
    8. تعيين `FlutterError.onError` ليرسل الاستثناء لـ Sentry (إن كان مفعّلاً) ثم يستدعي `FlutterError.presentError(details)` كالمعتاد.
    9. `SystemChrome.setSystemUIOverlayStyle` (status bar شفاف، أيقونات داكنة) و `setPreferredOrientations([portraitUp, portraitDown])` (قفل الاتجاه العمودي).
    10. `runApp(const ProviderScope(child: FriendsChaletsApp()))`.
  - **`FriendsChaletsApp`** (`ConsumerStatefulWidget`، سطر 140-218):
    - `initState`: (أ) يشترك بـ `AuthService.instance.authStateChanges` — عند `signedIn`/`signedOut`/`userUpdated` يستدعي `clearAdminCache()` ثم `ref.invalidate(favoritesProvider)` و`ref.invalidate(profileProvider)` (إصلاح موثّق بتعليق لمشكلة حالة ضيف قديمة تبقى ظاهرة بعد تسجيل الدخول). (ب) `WidgetsBinding.instance.addPostFrameCallback` يحمّل تفضيلات الثيم/اللغة من SharedPreferences مرة واحدة فقط (بحارس `_loadedPrefs`) **بعد** أول إطار.
    - `dispose`: يُلغي `_authSub?.cancel()` — تنظيف صحيح، لا تسريب.
    - `build`: يستخدم `ref.watch` (وليس `ref.read`) على `themeNotifierProvider`/`localeNotifierProvider` كي تُعاد بناء `MaterialApp` عند تغييرهما، ويعيد `MaterialApp.router` مع `AppRouter.router`، ودعم لغتين (`ar`/`en`) عبر `localizationsDelegates`، و`builder` يلف الشجرة بـ `Directionality` (rtl/ltr) حسب اللغة الحالية.

- **الاعتماديات:** يستورد `core/router/app_router.dart`, `core/theme/app_theme.dart`, `core/theme/app_state_providers.dart`, `data/providers/favorites_provider.dart`, `data/services/services.dart` (فقط `AuthService`), `presentation/screens/profile/profile_provider.dart`. **من يستخدمه:** لا أحد (نقطة الدخول)؛ يُشغَّل مباشرة عبر `flutter run`/متجر التطبيقات.

- **التعامل مع Supabase:** `Supabase.initialize(...)` (تهيئة العميل، بدون استعلام جداول)، والاشتراك بـ `auth.onAuthStateChange` عبر `AuthService.instance.authStateChanges`. لا يوجد استعلام `.from()`/`.rpc()` مباشر بهذا الملف.

- **نقاط القوة:**
  - تخزين جلسة مشفّر فعلياً (`FlutterSecureStorage`) بدل الافتراضي غير المشفّر — قرار أمني واضح وموثّق.
  - فشل صريح ومبكر (`StateError`) عند غياب إعدادات أساسية (`.env`, Supabase URL/Key) بدل تشغيل بحالة غير معرّفة.
  - معالجة تزامن الحالة بعد تسجيل الدخول/الخروج (`ref.invalidate` على favorites/profile) — يحل مشكلة حقيقية موثّقة بالكود، ويُلغى الاشتراك بشكل صحيح في `dispose`.
  - لا يوجد أي استخدام لـ service_role key؛ فقط anon key من `.env` (وهو الاستخدام الصحيح للعميل).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 68-137، `main()`):** لا يوجد أي `try/catch` أو `runZonedGuarded` يلف خطوات الإقلاع (`_loadEnv`, `Supabase.initialize`, قراءة متغيرات البيئة). لو فشلت أي خطوة (مثلاً `.env` مفقود من حزمة الإنتاج، أو JSON تالف) يُرمى استثناء غير ملتقَط **قبل** تهيئة Sentry أصلاً (خطوة تهيئة Sentry تأتي *بعد* هذه الخطوات) — أي أن أعطال الإقلاع بالذات (أكثر مرحلة حساسية) **لا تُرفَع لـ Sentry إطلاقاً** ولا تظهر للمستخدم كرسالة مفهومة، بل شاشة سوداء/تعطّل صامت من منظور المستخدم النهائي.
  - 🟡 **بسيطة (سطر 102-121):** `SentryFlutter.init(...)` يُستدعى بدون معامل `appRunner`، ثم `runApp(...)` يُستدعى منفصلاً بعدها. التوثيق الشائع لـ Sentry Flutter يوصي بـ `SentryFlutter.init((options) {...}, appRunner: () => runApp(MyApp()))` لضمان التقاط أخطاء async خارج شجرة الـ widgets ضمن Zone خاص بـ Sentry. **يحتاج تحقق:** هل نسخة `sentry_flutter: ^8.14.0` المستخدمة تُعوّض هذا تلقائياً عبر `PlatformDispatcher.instance.onError` حتى بدون `appRunner`؟ لم أتحقق من توثيق النسخة بالتحديد، أذكرها كنقطة يستحق التأكد منها بدل افتراض حل/مشكلة قاطعة.
  - 🟡 **بسيطة (سطر 112-121):** `FlutterError.onError` يُكتب فوقه يدوياً بعد `SentryFlutter.init()` (الذي يُفترض أنه يضبط handler خاص به). هذا لا يكسر شيئاً (المعالج اليدوي يستدعي `Sentry.captureException` بنفسه) لكنه قد يتجاوز أي تخصيب تلقائي إضافي كان Sentry سيضيفه لمعالج الأخطاء الافتراضي الخاص به (مثل mechanism metadata لتجميع الأخطاء بشكل أفضل بلوحة Sentry).
  - 🟡 **بسيطة (سطر 171-180):** تحميل تفضيلات الثيم/اللغة يحدث في `addPostFrameCallback` (**بعد** أول إطار)، فأول إطار يُرسم بالقيم الافتراضية (`ThemeMode.light`, `Locale('ar')`) دائماً، حتى لو كانت تفضيلات المستخدم الفعلية مختلفة (وضع داكن/إنجليزي) — قد يظهر "ومضة" قصيرة بالثيم/اللغة الافتراضيين قبل التبديل للتفضيل الفعلي. أثر بصري بسيط فقط لأن الإطار الأول عادة لا يُرى بوضوح (splash/انتقال)، لكنه يستحق الذكر.
  - 🟡 **بسيطة — تناقض سطوع أيقونات status bar:** `SystemChrome.setSystemUIOverlayStyle` هنا (سطر 124-129) يضبط `statusBarIconBrightness: Brightness.dark` عالمياً مرة واحدة عند الإقلاع (مناسب لخلفية فاتحة). لكن أي شاشة تستخدم `Scaffold`+`AppBar` بالثيم الفاتح الافتراضي ستُطبَّق عليها لاحقاً `AppBarTheme.systemOverlayStyle` من [app_theme.dart](files/core/theme/app_theme.md) الذي يضبط `Brightness.light` (أيقونات فاتحة) على خلفية AppBar فاتحة أيضاً — تناقض فعلي موثّق بالتفصيل في مراجعة app_theme.dart. الإعداد هنا بـ main.dart هو الأصح فعلياً؛ المشكلة تحديداً في app_theme.dart.

- **اقتراح الإصلاح:**
  - لف خطوات الإقلاع الحساسة بـ `try { ... } catch (e, st) { ... }`، وفي حالة الفشل: تسجيل الخطأ لو أمكن (حتى log محلي/`debugPrint` كحد أدنى قبل تهيئة Sentry)، وعرض شاشة خطأ بسيطة للمستخدم (`runApp(ErrorApp(message: ...))`) بدل تعطّل صامت. مثال مختصر:
    ```dart
    Future<void> main() async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        // ...كل خطوات الإقلاع الحالية...
        runApp(const ProviderScope(child: FriendsChaletsApp()));
      } catch (e, st) {
        debugPrint('Startup failure: $e\n$st');
        runApp(MaterialApp(home: Scaffold(body: Center(child: Text('تعذّر تشغيل التطبيق، حاول لاحقاً')))));
      }
    }
    ```
  - عند تفعيل Sentry، الأفضل الانتقال لأسلوب `appRunner` الموصى به رسمياً، والتحقق من توثيق sentry_flutter 8.x لتأكيد ما إذا كان لا يزال هناك فرق عملي بدونه.
