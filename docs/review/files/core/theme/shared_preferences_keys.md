### lib/core/theme/shared_preferences_keys.dart

- **الوظيفة:** ملف من 7 أسطر فقط، يُعيد تصدير (re-export) مفتاحين ثابتين: `settingsDarkModeKey = ThemeNotifier.kDarkModeKey` و`settingsLanguageKey = LocaleNotifier.kLanguageKey`. التعليق بالكود صريح: "Kept for future use/centralization".

- **الشرح التفصيلي:** لا منطق، فقط تعريف ثابتين يعيدان تصدير قيمتين معرَّفتين أصلاً كـ `static const` داخل [ThemeNotifier](theme_notifier.md) و[LocaleNotifier](locale_notifier.md).

- **الاعتماديات:** يستورد `theme_notifier.dart` و`locale_notifier.dart`. **من يستخدمه:** **لا أحد حالياً** — تحقّقت بالبحث عن `settingsDarkModeKey`/`settingsLanguageKey` بكامل `lib/` ولا يوجد أي استخدام آخر غير تعريفهما بهذا الملف نفسه.

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:** لا شيء يُذكر تحديداً بهذا الملف (بخلاف النية الجيدة بتوحيد أسماء المفاتيح مستقبلاً المذكورة بالتعليق).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة — كود ميت (dead code) مؤكَّد:** الملف بأكمله غير مُستخدَم فعلياً بأي مكان آخر بالتطبيق (تحقّق فعلي بالبحث، وليس افتراضاً). التعليق نفسه يعترف أنه "لأجل الاستخدام المستقبلي" — أي أنه بالفعل غير مُفعَّل الآن. لا يشكّل خطورة (لا يُنفَّذ أي كود منه)، لكنه وزن صيانة زائد بدون فائدة حالية.

- **اقتراح الإصلاح:** إما حذف الملف حتى يُحتاج فعلاً (يمكن استرجاعه من Git لاحقاً بسهولة)، أو إن كانت النية استخدامه قريباً كمرجع موحّد لمفاتيح SharedPreferences بكل التطبيق، الأفضل فعلياً تحديث [locale_notifier.dart](locale_notifier.md) و[theme_notifier.dart](theme_notifier.md) ليستخدما هذين الثابتين المُصدَّرين هنا بدل تعريف `kLanguageKey`/`kDarkModeKey` داخل كل class على حدة — بحيث يصبح هذا الملف فعلاً "المصدر الموحّد" بدل مجرد إعادة تصدير لا يستخدمها أحد.
