### lib/core/theme/locale_notifier.dart

- **الوظيفة:** `LocaleNotifier extends ChangeNotifier` يدير لغة التطبيق الحالية (`ar`/`en`)، مع حفظ/تحميل التفضيل عبر `SharedPreferences`.

- **الشرح التفصيلي:**
  - `_locale` ابتدائياً `Locale('ar')` (العربية افتراضياً قبل أي تحميل).
  - `loadFromPrefs()`: يقرأ `settings_language` (المفتاح الثابت `kLanguageKey`) من `SharedPreferences.getInstance()`، أو `'ar'` لو غير موجود، يحدّث `_locale`، ويستدعي `notifyListeners()`.
  - `setLanguage(String languageCode)`: يحدّث `_locale` فوراً، يحفظها بـ `SharedPreferences`، ثم `notifyListeners()`. **ملاحظة تسلسل:** يحدّث الحالة المحلية (`_locale`) *قبل* انتظار نجاح الحفظ (`await prefs.setString(...)` يأتي بعد تحديث `_locale` مباشرة) — أي أن الواجهة تعكس اللغة الجديدة فوراً حتى لو فشل الحفظ لاحقاً (نادر الحدوث مع SharedPreferences، لكنه يعني عدم تراجع (rollback) بصري لو فشل الحفظ فعلياً.

- **الاعتماديات:** يستورد `flutter/material.dart` و`shared_preferences`. **من يستخدمه:** [app_state_providers.dart](app_state_providers.md) (`localeNotifierProvider`)، ويُستهلك بـ[main.dart](../../main.md) و أي شاشة تبديل لغة (`language_bottom_sheet.dart` على الأرجح).

- **التعامل مع Supabase:** لا يوجد — تخزين محلي فقط (`SharedPreferences`)، لا علاقة له بجدول `profiles` أو أي تفضيل يُحفظ بقاعدة البيانات. **يحتاج تأكيد لاحقاً:** هل تفضيل اللغة يُزامَن أيضاً مع Supabase (مثلاً عمود بجدول `profiles`) ليبقى متّسقاً عبر أجهزة متعددة لنفس المستخدم، أم أنه محلي بحت لكل جهاز؟ الكود الحالي هنا يوحي بأنه محلي بحت فقط.

- **نقاط القوة:** نمط `ChangeNotifier` بسيط ومباشر، مطابق تماماً لبنية [ThemeNotifier](theme_notifier.md) الشقيق له — سهل الفهم والصيانة.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة:** لا يوجد أي تحقق أن `languageCode` الممرَّر لـ `setLanguage` هو فعلاً `'ar'` أو `'en'` (القيمتان الوحيدتان المدعومتان فعلياً بـ`supportedLocales` في main.dart) — تمرير أي نص آخر سيُقبل ويُحفَظ بصمت، وسينتج `Locale` غير مدعومة قد يتسبب بسلوك غير متوقع من Flutter (يعود عادة للغة افتراضية بأمان، لكن دون رسالة تشرح لماذا).
  - 🟡 **بسيطة:** لا معالجة خطأ حول `SharedPreferences.getInstance()`/`setString` (نادراً ما تفشل هذه الاستدعاءات، لذا الخطورة منخفضة عملياً).

- **اقتراح الإصلاح:**
  - إضافة تحقق بسيط: `assert(['ar', 'en'].contains(languageCode));` أو تحويل `languageCode` لِـ enum بدل `String` حر لمنع قيم غير متوقعة من الأساس.
