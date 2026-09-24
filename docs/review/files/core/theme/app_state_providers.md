### lib/core/theme/app_state_providers.dart

- **الوظيفة:** يعرّف provider اثنين بـ Riverpod: `themeNotifierProvider` و`localeNotifierProvider`، يكشفان [ThemeNotifier](theme_notifier.md) و[LocaleNotifier](locale_notifier.md) لبقية التطبيق كـ `ChangeNotifierProvider`.

- **الشرح التفصيلي:** ملف من سطرين فعليين:
  ```dart
  final themeNotifierProvider = ChangeNotifierProvider<ThemeNotifier>((ref) => ThemeNotifier());
  final localeNotifierProvider = ChangeNotifierProvider<LocaleNotifier>((ref) => LocaleNotifier());
  ```
  كلاهما `ChangeNotifierProvider` عادي (ليس `StateNotifierProvider` ولا Riverpod codegen) — التعليق أعلى الملف يوضّح أنهما يُحمَّلان من SharedPreferences لاحقاً عند إقلاع التطبيق (عبر `loadFromPrefs()` المستدعاة من [main.dart](../../main.md)).

- **الاعتماديات:** يستورد `locale_notifier.dart` و`theme_notifier.dart`. **من يستخدمه:** [main.dart](../../main.md) (`ref.watch`/`ref.read` على كلا الـ provider)، وأي شاشة إعدادات تبدّل الثيم/اللغة (`settings_screen.dart`, `language_bottom_sheet.dart` — يُؤكَّد لاحقاً).

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:** بساطة مقصودة — لا داعي لتعقيد إضافي لحالة بهذا الحجم (ثيم/لغة). الفصل بين تعريف الـ provider وتنفيذ الـ notifier نفسه (بملفين منفصلين) يحافظ على وضوح المسؤوليات.

- **الأخطاء والمخاطر المحتملة:** لا يوجد أي مخاطرة تُذكر بهذا الملف تحديداً؛ فحص null-safety/Supabase/dispose غير منطبق (لا يوجد أي منها هنا).

- **اقتراح الإصلاح:** لا شيء مطلوب.
