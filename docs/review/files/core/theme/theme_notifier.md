### lib/core/theme/theme_notifier.dart

- **الوظيفة:** `ThemeNotifier extends ChangeNotifier` يدير وضع الثيم الحالي (فاتح/داكن) مع حفظ/تحميل التفضيل عبر `SharedPreferences`. **ملاحظة:** يدعم فعلياً فقط `ThemeMode.light`/`ThemeMode.dark` (لا يوجد خيار "اتباع النظام" `ThemeMode.system` بالكود رغم أن `ThemeMode` بحد ذاته يدعمه).

- **الشرح التفصيلي:**
  - `_themeMode` ابتدائياً `ThemeMode.light`.
  - `isDarkMode` getter مختصر (`_themeMode == ThemeMode.dark`).
  - `loadFromPrefs()`: يقرأ `bool` باسم `settings_dark_mode` (`kDarkModeKey`)، افتراضي `false`، يحدّث `_themeMode` تبعاً لذلك، `notifyListeners()`.
  - `setDarkMode(bool enabled)`: نفس نمط `setLanguage` بالملف الشقيق [locale_notifier.dart](locale_notifier.md) — تحديث محلي فوري، ثم حفظ `SharedPreferences`، ثم إشعار.

- **الاعتماديات:** يستورد `flutter/material.dart`, `shared_preferences`. **من يستخدمه:** [app_state_providers.dart](app_state_providers.md) (`themeNotifierProvider`)، [main.dart](../../main.md)، وشاشة الإعدادات (`settings_screen.dart` على الأرجح لتبديل الوضع الداكن).

- **التعامل مع Supabase:** لا يوجد — تخزين محلي بحت (نفس ملاحظة locale_notifier: تفضيل الثيم لا يُزامَن مع الحساب عبر الأجهزة).

- **نقاط القوة:** بساطة ووضوح، ومطابقة تامة لنمط `LocaleNotifier` — اتساق جيد بالكود.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة — لا خيار "اتباع النظام":** التصميم الحالي يفرض اختياراً ثنائياً فاتح/داكن يحفظه المستخدم يدوياً، بدل احترام إعداد نظام التشغيل تلقائياً (`ThemeMode.system`) كخيار افتراضي أو إضافي. قرار منتج وليس خطأ تقني، لكنه يستحق الذكر كفرصة تحسين تجربة مستخدم بسيطة.
  - 🟡 **بسيطة:** نفس ملاحظة الملف الشقيق: لا معالجة استثناء حول عمليات `SharedPreferences` (خطورة منخفضة عملياً).

- **اقتراح الإصلاح:** لإضافة دعم "اتباع النظام" مستقبلاً: تغيير `_themeMode` لتقبل القيم الثلاث، وإضافة زر/خيار ثالث بشاشة الإعدادات يمرّر `ThemeMode.system`.
