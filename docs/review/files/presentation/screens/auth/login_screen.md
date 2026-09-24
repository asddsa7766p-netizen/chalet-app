### lib/presentation/screens/auth/login_screen.dart

- **الوظيفة:** شاشة تسجيل الدخول (بريد/كلمة مرور)، مع استئناف أي "إجراء معلّق" كان الضيف يحاول تنفيذه قبل تحويله لتسجيل الدخول (حجز/تقييم/مفضلة/تبويب معيّن)، وزر Google (غير مفعَّل بعد، يعرض ذلك بصراحة).

- **الشرح التفصيلي:**
  - `_login()`: يتحقق النموذج، `signIn(email, password)`، وعند النجاح يستهلك `AuthRedirectService.consumePendingAction()` ويتصرف حسب نوعه (`open_booking`, `open_reviews`, `toggle_favorite`, `open_tab`, أو افتراضياً `/home`). عند الفشل: `friendlyAuthError(e)` من [auth_shared.dart](auth_shared.md) بدل رسالة عامة ثابتة (تعليق يوثّق هذا كإصلاح متعمَّد).
  - `_loginWithGoogle()`: **صراحة وبصدق غير مُفعَّل** — يرمي `UnimplementedError` عمداً بدل تزييف نجاح الدخول (تعليق: "We do not fake a successful login")، ويعرض رسالة واضحة "غير متاح حالياً. سيتم تفعيله لاحقاً".
  - `_showError`: `ScaffoldMessenger.of(context).showSnackBar(...)`.
  - الزر الأساسي (`AuthGradientButton`) يُعطَّل تلقائياً أثناء `_loading` (`onTap: loading ? null : onTap` داخل الويدجت المشترك) — يمنع إرسال مزدوج بضغط متكرر.

- **الاعتماديات:** يستورد [auth_shared.dart](auth_shared.md) (كل عناصر الواجهة/التحقق/ترجمة الأخطاء)، `app_colors.dart`, `app_strings.dart`, `services.dart` (`AuthService`, `AuthRedirectService`, `FavoritesService`)، و`main_screen.dart` (فقط `goToMainTab`). **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/auth/login`).

- **التعامل مع Supabase:** `AuthService.instance.signIn` (Auth)، وبشكل غير مباشر `FavoritesService.instance.toggleFavorite` (لو كان الإجراء المعلّق تبديل مفضّلة).

- **نقاط القوة:**
  - استئناف نية الضيف بعد تسجيل الدخول (`PendingAuthAction`) بدل إعادته لصفحة عامة بعد نجاح الدخول — تجربة مستخدم جيدة ومدروسة.
  - صدق واضح بخصوص Google OAuth غير المفعّل بدل تزييف نجاح أو زر معطَّل بلا تفسير.
  - فحص `mounted` صحيح بعد أول `await` رئيسي (`signIn`، سطر 36) قبل استخدام `context`.
  - الزر معطَّل أثناء التحميل — يمنع Race Condition من ضغط مزدوج على تسجيل الدخول نفسه.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 63-76، حالة `'toggle_favorite'` داخل `_login`) — استخدام `context` بعد `await` جديد دون فحص `mounted` ثانية:** الفحص الوحيد لـ`mounted` بالدالة كله عند سطر 36 (بعد `signIn` مباشرة). لكن حالة `toggle_favorite` بالـ`switch` تحتوي `await FavoritesService.instance.toggleFavorite(chaletId)` (سطر 67 — نداء شبكة حقيقي جديد، منفصل تماماً عن `signIn`) ثم تستخدم `context.go('/home/chalet/$chaletId')` (سطر 72) **مباشرة بعده بدون أي فحص `mounted` إضافي**. لو أُغلقت/تخلَّصت الشاشة أثناء انتظار هذا النداء تحديداً (نادر لكن ممكن: تنقّل آخر يحدث بالتوازي، أو إغلاق سريع)، سيُستخدَم `context` على widget مُتخلَّص منه. **هذا يطابق تماماً فئة "استخدام context بعد await بدون فحص mounted" التي طلب المستخدم فحصها بدقة**، وهو تحديداً نوع الخطأ الذي رصده محلل Flutter الثابت (`use_build_context_synchronously`) بنسخة سابقة من هذا الملف (بأسطر مختلفة، قبل إضافة فحص `mounted` بسطر 36 — أي أن الفحص أُضيف لموضع واحد لكن ليس لكل الفروع).
  - 🟡 **بسيطة (سطر 69-70):** تعليق الكود نفسه يعترف صراحة بفشل صامت مقصود لخطأ تبديل المفضلة هنا (`catch (_) {}` بتعليق "⚠️ فشل صامت مقصود... يفضّل تسجيله عبر أداة Logging/Crashlytics بدل تجاهله كلياً") — اعتراف صادق بالفريق نفسه بثغرة تسجيل (logging) لم تُستكمل بعد.
  - 🟡 **بسيطة — مؤكَّدة بفحص مباشر لمجلد assets:** الأيقونة `assets/images/google_logo.png` المستخدمة بزر Google (مع `errorBuilder` احتياطي لأيقونة عامة) **غير موجودة فعلياً** بمجلد `assets/images/` (يحتوي فقط `logo.png` و`onboarding_bg.jpg`). النتيجة: زر Google **يعرض دائماً أيقونة `Icons.g_mobiledata` العامة** بدل شعار Google الفعلي، بالإضافة لكون الزر أصلاً غير وظيفي (`_loginWithGoogle` يرمي `UnimplementedError` دائماً) — الزر بأكمله حالياً عنصر نائب مؤقت لميزة غير مكتملة.
  - 🟡 **بسيطة (سطر 31):** `_formKey.currentState!.validate()` — استخدام `!` مباشر بدل فحص آمن. خطورة منخفضة جداً عملياً (الـ `Form` دائماً موجود بالشجرة وقت الضغط على الزر)، لكنه يخالف نمط أكثر أماناً مستخدَم بملف آخر بنفس المجموعة ([forgot_password_screen.dart](forgot_password_screen.md) يستخدم `?.validate() ?? false`).

- **اقتراح الإصلاح:**
  - إضافة فحص `mounted` قبل استخدام `context` بعد `await` الجديد داخل حالة `toggle_favorite`:
    ```dart
    try {
      await FavoritesService.instance.toggleFavorite(chaletId);
    } catch (e) {
      // سجّل الخطأ الحقيقي بدل تجاهله كلياً، مثال: Sentry.captureException(e);
    }
    if (!mounted) return;
    context.go('/home/chalet/$chaletId');
    ```
  - إضافة `Sentry.captureException(e)` بمكان تعليق "فشل صامت مقصود" (سطر 68-71) بدل ترك التجاهل كاملاً كما يوصي التعليق نفسه.
  - إما إضافة الصورة الفعلية `assets/images/google_logo.png`، أو (أبسط) استبدال `Image.asset` بأيقونة Google رسمية من حزمة أيقونات مثبتة أصلاً (لو متوفرة)، أو حذف محاولة تحميل صورة غير موجودة والاكتفاء بالأيقونة العامة صراحة حتى تفعيل الميزة فعلياً.
