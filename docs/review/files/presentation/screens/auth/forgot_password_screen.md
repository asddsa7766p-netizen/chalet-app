### lib/presentation/screens/auth/forgot_password_screen.dart

- **الوظيفة:** شاشة "نسيت كلمة المرور" — تدفق كامل بمرحلتين: (1) إرسال بريد يحتوي رمز OTP مكوّن من 6 أرقام، (2) إدخال الرمز + كلمة مرور جديدة + تأكيدها لإتمام إعادة التعيين، مع تبريد (cooldown) لإعادة الإرسال.

- **الشرح التفصيلي:**
  - تعليق ترويسة الملف وتعليقات داخلية توثّق القرار المعماري: التطبيق **لا يملك deep link/app link مُعدّاً** (لا scheme، لا intent-filter)، فرابط "Reset Password" الافتراضي من Supabase (مصمّم لتطبيقات ويب) لن يفتح التطبيق أصلاً — لذلك اعتُمد تدفق OTP بدلاً منه بالكامل، **بشرط إعداد يدوي خارجي بلوحة Supabase** (قالب بريد "Reset Password" يجب أن يتضمن `{{ .Token }}` صراحة، القالب الافتراضي أحياناً يحتوي فقط `{{ .ConfirmationURL }}`) — تنويه واضح لخطوة تشغيلية خارج الكود لا يمكن فرضها من هنا.
  - `_startCooldown()`: `Timer.periodic` كل ثانية لعدّ تنازلي 30 ثانية (`_resendCooldownSeconds`)، مع **فحص `mounted` داخل كل تكة (tick)** ثم `timer.cancel()` فوراً لو غير مُثبَّت — نمط إدارة Timer نموذجي وصحيح تماماً.
  - `dispose()`: يُلغي `_cooldownTimer` صراحة (إضافة لكل الـ controllers) — لا تسريب.
  - `_submit()`: يتحقق النموذج، حارس `if (_loading) return;` **إضافي** قبل `setState` (إضافة لتعطيل الزر نفسه)، يستدعي `resetPassword(email)`، وعند النجاح يبدأ التبريد.
  - `_confirmReset()`: 3 عمليات متتالية بمحاولة واحدة (`verifyPasswordRecoveryOtp` → `updatePassword` → `signOut`)، كلها بـ `try` واحد. تعليق يوضّح سبب `signOut` المتعمَّد بعد نجاح التغيير: إنهاء جلسة الاسترداد المؤقتة كي "يدخل المستخدم بكلمة المرور الجديدة بشكل صريح وواضح" (وليس مجرد خطوة تقنية عشوائية).
  - الشاشة تفرض `Directionality(textDirection: TextDirection.rtl)` **صراحة وثابتة** (سطر 148-149) بغض النظر عن لغة التطبيق الفعلية المختارة.

- **الاعتماديات:** يستورد `dart:async` (لـ`Timer`)، [auth_shared.dart](auth_shared.md) (`Validators`, `friendlyAuthError`)، `app_colors.dart`, `services.dart` (`AuthService`)، `common_widgets.dart` (`CustomTextField`, `AppButton`). **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/auth/forgot-password`)، ورابط من [login_screen.dart](login_screen.md).

- **التعامل مع Supabase:** `AuthService.instance.resetPassword` (Auth email OTP)، `verifyPasswordRecoveryOtp` (Auth OTP verify)، `updatePassword` (Auth update user)، `signOut`.

- **نقاط القوة:**
  - **إدارة Timer نموذجية بالكامل**: فحص `mounted` صحيح داخل كل تكة + `cancel()` عند الإلغاء المبكر + `cancel()` بـ`dispose()` — من أفضل أمثلة إدارة موارد async بالمشروع كله، بدون أي تسريب أو استدعاء `setState` بعد التخلص.
  - حراسة مزدوجة ضد الإرسال المتكرر: تعطيل الزر **و** حارس `if (_loading) return;`/`if (_verifying) return;` صريح داخل الدالتين أنفسهما — أكثر الملفات حرصاً بمجموعة شاشات المصادقة ضد Race Conditions من ضغط متكرر.
  - تبريد إعادة الإرسال (30 ثانية) مع عدّاد مرئي — يحمي فعلياً من إرهاق Supabase Auth بطلبات متتالية (rate limiting)، ويشرح تعليق الكود هذا صراحة كسبب الإضافة.
  - شفافية كاملة حول قيد تشغيلي خارج نطاق الكود (إعداد قالب البريد بلوحة Supabase) بدل تركه غامضاً لو فشل الاسترداد بالإنتاج.
  - `_resetFormKey`/`_formKey` منفصلان لكل مرحلة من التدفق — منطقي وواضح، يمنع تحقق حقول المرحلة الأولى من التأثير على الثانية.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 93-125، `_confirmReset`):** ثلاث عمليات شبكة متتالية بمحاولة `try` واحدة — لو نجحت `verifyPasswordRecoveryOtp` و`updatePassword` (**التغيير الفعلي المهم نجح**) لكن فشلت `signOut` الأخيرة فقط (خطأ شبكة عابر، نادر)، يعرض الكود **رسالة خطأ عامة للمستخدم** رغم أن كلمة المرور تغيّرت فعلياً بنجاح — رسالة مضلِّلة في هذا السيناريو الحدّي تحديداً (أثر منخفض الاحتمال، لكنه حقيقي).
  - 🟡 **بسيطة (سطر 148-149):** `Directionality(textDirection: TextDirection.rtl)` مفروضة صراحة بالكود، بغض النظر عن `localeNotifier` الفعلي. لو بدّل المستخدم اللغة لإنجليزية (بافتراض أن التبديل يعمل فعلياً بمكان آخر، مع العلم أن دعم الإنجليزية نفسه غير مكتمل حسب مراجعة [app_strings.dart](../../../core/constants/app_strings.md))، هذه الشاشة **تحديداً** ستبقى RTL بينما باقي التطبيق LTR — تناقض بصري إضافي فوق فجوة الترجمة الأساسية الأشمل.

- **اقتراح الإصلاح:**
  - فصل معالجة الخطأ بـ`_confirmReset` لتمييز نجاح التغيير الفعلي عن فشل الخطوة الأخيرة الثانوية (`signOut`)، مثال:
    ```dart
    await AuthService.instance.verifyPasswordRecoveryOtp(...);
    await AuthService.instance.updatePassword(_newPasswordCtrl.text);
    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // فشل signOut لا يجب أن يُعرَض كخطأ لتغيير كلمة المرور الناجح فعلاً.
    }
    if (!mounted) return;
    // ... رسالة النجاح كما هي
    ```
  - إزالة `Directionality(rtl)` الصريحة والاعتماد على اتجاه التطبيق العام (المُدار مركزياً بـ[main.dart](../../../main.md)) بدل تثبيتها محلياً بهذه الشاشة فقط.
