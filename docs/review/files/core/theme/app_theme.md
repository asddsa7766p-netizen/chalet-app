### lib/core/theme/app_theme.dart

- **الوظيفة:** class ثابت `AppTheme` يبني كائنَي `ThemeData` كاملين (`lightTheme`, `darkTheme`) لكل التطبيق: `ColorScheme`, `AppBarTheme`, أزرار (Elevated/Outlined/Text)، `InputDecorationTheme`, `CardTheme`, `BottomNavigationBarTheme`, `ChipTheme`, `DividerTheme`, و`TextTheme` كامل (بخط Cairo عبر Google Fonts).

- **الشرح التفصيلي:**
  - **`lightTheme`** (سطر 9-225): `useMaterial3: true`، خط أساسي `GoogleFonts.cairo().fontFamily`، `ColorScheme` مبني يدوياً (وليس `fromSeed`) بكل الحقول الأساسية معرَّفة صراحة من [AppColors](../constants/app_colors.md). كل عناصر الـ theme الفرعية (أزرار/حقول إدخال/بطاقات/شريط تنقل سفلي/chips/فواصل/نصوص) معرَّفة صراحة بقيم `Cairo` وأحجام/أوزان ثابتة.
  - **`darkTheme`** (سطر 227-422): يستخدم `ColorScheme.fromSeed(seedColor: AppColors.primary, ...)` **ثم** يُمرَّر تقريباً كل حقل أساسي صراحة فوقه أيضاً (`primary`, `secondary`, `surface`, `background`, `error`) — أي أن `fromSeed` يبني لوحة كاملة يُعاد تجاهل معظمها فوراً بنفس السطر. يُعرَّف `darkBackground`/`darkSurface`/`darkCard` كلها بنفس القيمة الواحدة: `AppColors.charcoal`.
  - بقية بنية `darkTheme` تكرار شبه كامل لبنية `lightTheme` (نفس أسماء الحقول والأحجام) مع تبديل الألوان فقط.

- **الاعتماديات:** يستورد `core/constants/app_colors.dart` و`package:google_fonts/google_fonts.dart`. **من يستخدمه:** [main.dart](../../main.md) فقط (`theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`) — يُطبَّق عالمياً على كل `Scaffold`/widget بالتطبيق عبر `Theme.of(context)`.

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:**
  - `ThemeData` مركزية شاملة تغطي كل عناصر Material الأساسية — تقلل الحاجة لتنسيق يدوي متكرر بكل شاشة (لون خلفية، شكل الأزرار، نصف قطر الحواف...).
  - استخدام `useMaterial3: true` بشكل متّسق بين الثيمين.
  - تعليقات `// ✅` صغيرة موضعية تشرح قرارات لونية متعمّدة (مثل خلفية AppBar البيضاء).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 42-45، `lightTheme.appBarTheme.systemOverlayStyle`):** `statusBarIconBrightness: Brightness.light` (أيقونات status bar **فاتحة**) بينما خلفية AppBar بنفس الثيم هي `AppColors.background` (**فاتحة**، `#FBF8F3`) — تركيبة خاطئة فعلياً (المفروض أيقونات داكنة `Brightness.dark` على خلفية فاتحة، تماماً كما فعل [main.dart](../../main.md) سطر 127 بإعداده العالمي المبدئي `Brightness.dark`). النتيجة العملية: أيقونات شريط الحالة (الساعة/البطارية/الإشارة — **ليست** أيقونات AppBar نفسها كزر الرجوع، تلك منفصلة وتستخدم `foregroundColor: AppColors.primary` وتبدو صحيحة) تصبح فاتحة على خلفية فاتحة → تباين ضعيف يصعب قراءته، على أغلب شاشات التطبيق (أي شاشة بـ AppBar افتراضي من الثيم الفاتح). بالمقابل `darkTheme.appBarTheme.systemOverlayStyle` (سطر 257-260) صحيحة (أيقونات فاتحة على AppBar غامق `darkSurface`).
  - 🟡 **بسيطة (سطر 227-249، `darkTheme`):** `darkBackground = darkSurface = darkCard = AppColors.charcoal` — نفس اللون الغامق الواحد لخلفية الشاشة، السطح، والبطاقات. بما أن `elevation: 0` بكل مكان (لا ظل)، فالبطاقات (`cardTheme`) لن يكون لها أي فرق بصري محسوس عن الخلفية في الوضع الداكن سوى الحد الرفيع (`side: BorderSide(color: AppColors.sand, width: 1)`) — قد يجعل التسلسل الهرمي البصري (Visual hierarchy) بين "خلفية" و"بطاقة" ضعيفاً جداً بالوضع الداكن تحديداً. يحتاج تأكيد بصري فعلي على شاشة حقيقية بدل استنتاج من الكود فقط.
  - 🟡 **بسيطة (موثّقة فعلياً بـ `flutter analyze`، راجع [flutter_analyze_after_fix.log](../../../../../flutter_analyze_after_fix.log) بجذر المشروع — **تنويه: هذا اللوج قديم وقد لا يطابق أرقام الأسطر الحالية بالضبط بعد آخر تعديلات غير مُلتزَمة (git status يُظهر الملف `M`)، لكن نوع المشاكل نفسه لا يزال قائماً بالكود كما قرأته الآن**):**
    - سطر 19، 24، 242: استخدام `background`/`onBackground` بـ `ColorScheme` — كلاهما deprecated منذ Flutter 3.18 لصالح `surface`/`onSurface`.
    - سطر 359: `AppColors.cream.withOpacity(0.15)` — `withOpacity` deprecated لصالح `.withValues()` (قد يفقد دقة عشرية طفيفة، ليست مشكلة وظيفية حرجة).
    - سطر 14: منشئ `ColorScheme` بـ `lightTheme` يمكن أن يكون `const` (تحسين أداء بسيط جداً، `info` وليس تحذير).
  - 🟡 **بسيطة — اعتماد كامل على Google Fonts بلا خط مُجمَّع محلياً (bundled):** لا يوجد قسم `fonts:` بـ [pubspec.yaml](../../../../pubspec.yaml) (تأكدت بقراءته مباشرة) — فقط `GoogleFonts.cairo()` (حزمة `google_fonts`) وTextStyle مباشرة بسلسلة نصية حرفية `fontFamily: 'Cairo'` بكل مكان تقريباً (وليس عبر `GoogleFonts.cairo()` في كل موضع). حزمة `google_fonts` تنزّل ملف الخط وتخزّنه مؤقتاً (cache) عند أول استخدام لو لم يكن مرفقاً بالأصول (assets)؛ لو كان أول تشغيل للتطبيق بدون إنترنت قد يظهر خط النظام الافتراضي بدل Cairo لحظياً (يُدار عادة بأمان داخلياً من الحزمة نفسها بدون تعطّل، لكن يستحق التحقق الفعلي بجهاز حقيقي دون إنترنت عند أول تشغيل، بدل افتراض ذلك).

- **اقتراح الإصلاح:**
  - تصحيح سطوع أيقونات status bar بالثيم الفاتح:
    ```dart
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // بدل Brightness.light
    ),
    ```
  - استبدال `background`/`onBackground` بـ `surface`/`onSurface` في كل من `ColorScheme` (يزيل تحذيرات deprecation بدون أي تغيير وظيفي ملاحظ للمستخدم).
  - استبدال `.withOpacity(0.15)` بـ `.withValues(alpha: 0.15)`.
  - لتحسين التباين بالوضع الداكن: تعريف لون منفصل قليلاً لـ`darkCard` (أفتح بدرجة بسيطة من `darkBackground`) بدل استخدام `AppColors.charcoal` للثلاثة معاً.
  - (اختياري، لتقليل مخاطرة عدم توفر الخط دون إنترنت بأول تشغيل): تضمين ملفات خط Cairo كأصول محلية عبر قسم `fonts:` بـ pubspec.yaml بدل الاعتماد الكامل على تنزيل google_fonts وقت التشغيل.
