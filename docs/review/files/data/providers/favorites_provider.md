### lib/data/providers/favorites_provider.dart

- **الوظيفة:** حالة المفضلة العابرة لكل التطبيق عبر Riverpod: `FavoritesNotifier` (يدير مجموعة معرّفات الشاليهات المفضّلة كـ `AsyncValue<Set<String>>`، مع تحديث تفاؤلي عند التبديل)، و`isFavoriteProvider` (مساعد لكل شاليه على حدة).

- **الشرح التفصيلي:**
  - `FavoritesNotifier extends StateNotifier<AsyncValue<Set<String>>>`: يبدأ بـ `AsyncValue.loading()` ويستدعي `_load()` فوراً بالباني.
  - `_load()`: يجلب `FavoritesService.instance.getFavoriteIds()`، ملفوف بـ try/catch كامل: نجاح → `AsyncValue.data(ids)`، فشل → `AsyncValue.error(e, st)` (مع stack trace محفوظ — مفيد للتشخيص). **كلا الفرعين محروسان بفحص `mounted`** (خاصية `StateNotifier.mounted`، النظير الصحيح لفحص `context.mounted` بالـ widgets، لكن هنا لتفادي تحديث حالة notifier بعد التخلّص منه) — نمط سليم تماماً.
  - `reload()`: يعيد تشغيل `_load()` — واجهة عامة لإعادة الجلب من الخارج (مثلاً بعد سحب للتحديث).
  - `isFavorite(chaletId)`: قراءة متزامنة بسيطة من الحالة الحالية.
  - `toggleFavorite(ChaletModel chalet)`: **تحديث تفاؤلي (Optimistic Update)** — يحسب الحالة الجديدة محلياً فوراً (يعرضها للمستخدم قبل أي رد من السيرفر)، ثم يستدعي `FavoritesService.instance.toggleFavorite` (RPC الذرّية المُصلَحة، راجع [services.dart](../services/services.md))، ولو فشلت: **تراجع كامل** (`state = AsyncValue.data(current)` — القيمة الملتقَطة *قبل* التحديث التفاؤلي، وليست القيمة الحالية وقت الفشل، وهذا صحيح ويتفادى مشاكل تزامن لو تغيّرت الحالة أثناء الانتظار).
  - `favoritesProvider`: `StateNotifierProvider` يكشف `FavoritesNotifier`.
  - `isFavoriteProvider`: `Provider.family<bool, String>` يشتق حالة "هل هذا الشاليه مفضّل؟" لكل `chaletId` من نفس الحالة المشتركة — يتفادى كل بطاقة شاليه احتياجها جلب/فحص منفصل.

- **الاعتماديات:** يستورد `flutter_riverpod`, `../models/chalet_model.dart`, `../services/services.dart`. **من يستخدمه:** [main.dart](../../main.md) (`ref.invalidate(favoritesProvider)` عند signIn/signOut)، وعلى الأرجح كل مكان يعرض قلب/أيقونة مفضّلة (بطاقات الشاليه بالرئيسية/البحث، [favorites_screen.dart](../../presentation/screens/favorites/favorites_screen.md), [chalet_detail_screen.dart](../../presentation/screens/chalet/chalet_detail_screen.md)) — يُؤكَّد بدقة عند مراجعتها.

- **التعامل مع Supabase:** لا اتصال مباشر — كل الاتصال عبر `FavoritesService` (جدول `favorites`، RPC `toggle_favorite`).

- **نقاط القوة:**
  - استخدام `AsyncValue` بشكل نموذجي (loading/data/error) — يطابق تماماً نمط "حالة تحميل/خطأ" السليم الذي طلب المستخدم التحقق من وجوده.
  - فحص `mounted` على مستوى الـ `StateNotifier` قبل كل تحديث حالة — يمنع تحديث حالة notifier مُتخلَّص منه.
  - تحديث تفاؤلي مع تراجع صحيح عند الفشل (يستخدم القيمة المُلتقَطة قبل التغيير، لا القيمة الحالية وقت معالجة الخطأ) — استجابة فورية للمستخدم بدون المخاطرة بحالة غير متّسقة عند الفشل.
  - يعتمد على RPC الذرّية المُصلَحة من Race Condition بدل إعادة تطبيق النمط القديم — استفادة صحيحة من الإصلاح الموثّق بطبقة الخدمات.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 26-44، `toggleFavorite`) — تباعد تفاؤلي محتمل عند نقر مزدوج سريع:** كل استدعاء يقرأ `current = state.valueOrNull` **وقت النداء** (قد يكون فعلاً نتيجة تحديث تفاؤلي سابق لم يُؤكَّد بعد من السيرفر)، ويحسب التبديل بناءً عليه، **دون** مطابقة النتيجة النهائية بالقيمة المنطقية الفعلية التي تُعيدها `toggleFavorite` RPC (`result as bool`) في `services.dart`. لأن الـ RPC نفسها ذرّية وصحيحة دائماً من ناحية **قاعدة البيانات**، فلا خطر فعلي على البيانات المخزَّنة — لكن لو نقر المستخدم بسرعة عدة مرات متتالية (قبل اكتمال أول نداء)، قد تنتهي **الحالة المعروضة محلياً** (شكل القلب: مملوء/فارغ) مختلفة مؤقتاً عن الحالة الفعلية بقاعدة البيانات لحين إعادة تحميل كاملة (`reload()`) — عرض بصري خاطئ عابر فقط، وليس فساد بيانات فعلي.
  - 🟡 **بسيطة (سطر 40):** تعليق متبقٍ بالكود `// ← أضف هذا` (بجانب سطر `debugPrint`) — يبدو ملاحظة ذاتية للمطوّر لتذكيره بإضافة سطر التسجيل، لم تُحذف بعد إضافته فعلياً. لا يؤثر وظيفياً، لكنه بقايا صغيرة يُفضَّل تنظيفها.
  - 🟡 **بسيطة (سطر 40):** الخطأ يُسجَّل فقط بـ `debugPrint` (لا يظهر إلا بوضع التطوير)، دون إرساله لـ Sentry (المُفعَّل أصلاً بالمشروع) — فشل تبديل مفضّلة متكرر بالإنتاج (مثلاً مشكلة RLS) لن يُرصَد من لوحة مراقبة الأخطاء.

- **اقتراح الإصلاح:**
  - (اختياري، تحسين دقة العرض) مطابقة نتيجة الـ RPC الفعلية بعد النجاح بدل الاكتفاء بالتخمين التفاؤلي فقط:
    ```dart
    final added = await FavoritesService.instance.toggleFavorite(chalet.id);
    final latest = Set<String>.from(state.valueOrNull ?? current);
    added ? latest.add(chalet.id) : latest.remove(chalet.id);
    state = AsyncValue.data(latest);
    ```
  - حذف تعليق `// ← أضف هذا` المتبقي، وإضافة `Sentry.captureException(e)` بجانب `debugPrint` الحالي بمعالج الخطأ.
