### lib/presentation/widgets/common/language_bottom_sheet.dart (115 سطر)

- **الوظيفة:** ورقة سفلية لاختيار لغة التطبيق (عربي/إنجليزي)، تعرض علامة صح على اللغة الحالية وتُطبِّق التغيير فوراً عند الاختيار.

- **الشرح التفصيلي:**
  - `LanguageBottomSheet` (`ConsumerWidget`): يقرأ `localeNotifierProvider` عبر `ref.watch` (تفاعلي، يعيد البناء عند تغيّر اللغة). `selectLanguage(code)`: `await ref.read(localeNotifierProvider).setLanguage(code)` ثم يتحقق من `context.mounted` **قبل** `Navigator.pop(context)` — نمط آمن صحيح.
  - `_LanguageOption`: خيار عرض بسيط (نص + حدود ملوَّنة + علامة صح إن كان مختاراً).

- **الاعتماديات:** `app_colors.dart`, `app_state_providers.dart` (`localeNotifierProvider`). **من يستخدمه:** مؤكَّد عبر بحث مباشر — [settings_screen.dart](../../screens/settings/settings_screen.md) و[profile_screen.dart](../../screens/profile/profile_screen.md) (كلاهما يفتحانها عبر `showModalBottomSheet`).

- **التعامل مع Supabase:** لا يوجد — تفضيل محلي فقط (`SharedPreferences` عبر `LocaleNotifier`، مُراجَع بدفعة 1).

- **نقاط القوة:**
  - استخدام `ref.watch` (لا `ref.read`) يجعل علامة الصح تتحدَّث فوراً وبشكل تفاعلي صحيح داخل الورقة نفسها.
  - `context.mounted` مُتحقَّق منه بشكل صريح وصحيح قبل `Navigator.pop` بعد الـ`await` — من الملفات القليلة جداً بالمشروع التي تلتزم بهذا الفحص (راجع الملاحظة العامة بـ`progress.md`).
  - مكوّن بسيط، مركَّز، معاد استخدامه فعلياً من مكانين مختلفين بدل تكراره.

- **الأخطاء والمخاطر المحتملة:**
  - لا مخاطر حقيقية بهذا الملف تحديداً. **توضيح مهم:** العطل المُوثَّق سابقاً بمراجعة [settings_screen.dart](../../screens/settings/settings_screen.md) (دفعة 7: "عرض اللغة غير تفاعلي يصبح قديماً فوراً") **مصدره شاشة الإعدادات نفسها** (على الأرجح تقرأ اللغة الحالية مرة واحدة بدل `ref.watch`)، **وليس هذا الملف** — هذه الورقة تتفاعل بشكل صحيح فور فتحها، لكن نص "اللغة الحالية" بشاشة الإعدادات (الأب) لا ينعكس عليه التغيير فور الإغلاق.

- **اقتراح الإصلاح:** لا إصلاح مطلوب لهذا الملف. الإصلاح الفعلي مطلوب بـ`settings_screen.dart` (راجع مراجعته لتفاصيل الاقتراح هناك).
