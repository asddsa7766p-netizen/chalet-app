### lib/presentation/screens/home/main_screen.dart

- **الوظيفة:** الحاوية الرئيسية للتنقل السفلي (Bottom Navigation) بعد تسجيل الدخول/كضيف: 6 تبويبات (الرئيسية، الخريطة، المفضلة، الحجوزات، Reels، حسابي) بنمط `IndexedStack` (كل الشاشات تُبنى مرة وتبقى حيّة بالذاكرة)، مع حراسة دخول لتبويبات معيّنة، ودالة مساعدة عامة `goToMainTab` للتنقل لتبويب محدد من أي مكان بالتطبيق.

- **الشرح التفصيلي:**
  - **`goToMainTab(context, index)`** (دالة على مستوى الملف، سطر 17-20): تعليق يوثّق إصلاحاً حقيقياً — `context.go('/home', extra: N)` وحده كان يعمل **مرة واحدة فقط** لأن GoRouter/`MainScreen` لا يكتشفان "تغيّراً" في `initialIndex` لو نفس القيمة تُطلَب مرتين متتاليتين (مثلاً "عرض حجوزاتي" مرتين). الحل: `ValueNotifier<int?> tabRequest` ثابت على مستوى الـ class، يُستمَع إليه بمعزل عن قيمة `initialIndex` نفسها، فيضمن التقاط الطلب حتى لو القيمة "لم تتغيّر" منطقياً.
  - **`_MainScreenState`**:
    - `initState`: يقرأ `initialIndex` من الـ widget، أو طلب تبويب معلّق (`tabRequest.value`) إن وُجد فيتجاوزه، ثم يشترك بـ `tabRequest.addListener(_onTabRequest)`.
    - `dispose`: يُلغي الاشتراك (`removeListener`) — نظيف، لا تسريب.
    - `_onTabRequest`: يستهلك القيمة (يصفّرها فوراً `tabRequest.value = null`) ثم يبدّل التبويب فقط لو ما زال `mounted`.
    - `_selectTab(i)`: لو التبويب هو "الحجوزات" (index 3)، يُنشئ `Key` جديد (`UniqueKey()`) لإجبار `MyBookingsScreen` على إعادة البناء الكامل — تعليق يوثّق سبباً حقيقياً: `IndexedStack` يبني كل الشاشات **مرة واحدة فقط** فتبقى شاشة الحجوزات "مجمّدة" على أول حالة (غالباً فارغة، قبل تسجيل الدخول أو قبل إنشاء أي حجز) رغم إنشاء حجوزات جديدة لاحقاً بدون أي `RefreshIndicator` بحالة "لا حجوزات" لإعادة الجلب يدوياً.
    - `didUpdateWidget`: يعيد اختيار التبويب لو `initialIndex` الخاص بالـ widget تغيّر من الخارج (مثال: الأب أعاد بناء `MainScreen` بقيمة مختلفة).
    - `build`: يبني `screens` (قائمة الشاشات الستة، بينها `MyBookingsScreen(key: _bookingsKey)`)، ويعرضها بـ `IndexedStack`. `BottomNavigationBar.onTap`: يتحقق قبل تبديل التبويبات 2 (مفضلة)، 3 (حجوزات)، 5 (حسابي) — لو ضيف غير مسجّل، يستدعي `requireAuth(context, PendingAuthAction('open_tab', {'index': i}))` بدل تبديل التبويب مباشرة (يحفظ نية المستخدم ليُستأنف تلقائياً بعد تسجيل الدخول، عبر `AuthRedirectService` بـ[services.dart](../../../data/services/services.md)).

- **⚠️ ملاحظة هيكلية مهمة (اكتُشفت أثناء المراجعة، ليست خطأ بهذا الملف نفسه):** السطر `MyBookingsScreen(key: _bookingsKey)` يعمل رغم **عدم استيراد** أي ملف باسم `my_bookings_screen.dart` هنا — لأن `MainScreen` يستورد [favorites_screen.dart](../favorites/favorites_screen.md) (سطر 5)، وهذا الملف الأخير **يحتوي فعلياً** تعريف class `MyBookingsScreen` (وأيضاً `ReviewsScreen`) بجانب `FavoritesScreen` نفسها — ثلاث شاشات غير مترابطة منطقياً بملف واحد اسمه `favorites_screen.dart` فقط. التفصيل الكامل بمراجعة [my_bookings_screen.md](../bookings/my_bookings_screen.md) و[favorites_screen.md](../favorites/favorites_screen.md).

- **الاعتماديات:** يستورد `home_tab.dart`, `favorites_screen.dart` (لـ `FavoritesScreen` **و** `MyBookingsScreen` معاً)، `profile_screen.dart`, `reels_screen.dart`, `palestine_chalets_map_screen.dart`, `login_prompt.dart`, `services.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/home`)، ودالة `goToMainTab` تُستدعى من شاشات أخرى (`login_screen.dart` مؤكَّد، وربما أخرى).

- **التعامل مع Supabase:** لا اتصال مباشر — فقط `AuthService.instance.isLoggedIn` (قراءة محلية من الجلسة، لا شبكة) لحراسة التبويبات.

- **نقاط القوة:**
  - حل ذكي وموثَّق جيداً لقيد `IndexedStack` (عدم إعادة بناء الشاشات المخفية) عبر `Key` جديد مستهدَف فقط لتبويب الحجوزات بدل حل جذري أثقل (كسر مزايا `IndexedStack` بالكامل لكل التبويبات).
  - `ValueNotifier` ثابت (`tabRequest`) بديل بسيط وفعّال لمشكلة "نفس القيمة لا تُعتبر تغييراً" بدل حلول أثقل (مثل إضافة عداد تسلسلي لكل طلب).
  - حراسة دخول التبويبات الحساسة (مفضلة/حجوزات/حسابي) مع الحفاظ على نية المستخدم لاستئنافها بعد تسجيل الدخول (`PendingAuthAction`) — تجربة مستخدم جيدة للضيف بدل رسالة خطأ جافة.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة — منظّمة الملفات مضلِّلة (تفصيل كامل بمراجعات `my_bookings_screen.md`/`favorites_screen.md`):** الاستيراد هنا لشاشتين (`MyBookingsScreen`, `FavoritesScreen`) من نفس مسار ملف واحد قد يربك أي مطوّر يحاول تتبّع "أين تُعرَّف شاشة حجوزاتي؟" لأول مرة، خصوصاً أن مجلد `screens/bookings/` موجود فعلاً لكن يحتوي ملف تصدير سطر واحد فقط.
  - 🟡 **بسيطة (موثّقة سابقاً بـ[flutter_analyze_after_fix.log](../../../../../flutter_analyze_after_fix.log)، يحتاج تأكيد بأنها لا تزال قائمة):** كان مُسجَّلاً استيراد غير مستخدم لـ`app_strings.dart` واستيراد مكرر (`duplicate_import`) بهذا الملف — **لم أتحقق بشكل مباشر من هذين التحذيرين بالذات هنا لأن قراءتي الحالية للملف لا تُظهر استيراد `app_strings.dart` إطلاقاً** (ربما أُزيل فعلاً ضمن التعديلات اللاحقة الظاهرة بـ git status)؛ يُفضَّل تأكيد نهائي بتشغيل `flutter analyze` فعلياً بدل الاعتماد على اللوج القديم وحده.

- **اقتراح الإصلاح:**
  - لا تعديل وظيفي مطلوب بهذا الملف تحديداً. التوصية الهيكلية (نقل `MyBookingsScreen`/`ReviewsScreen` لملفاتهما الفعلية `bookings/my_bookings_screen.dart`/`reviews/reviews_screen.dart` بدل شيمات تصدير) مفصّلة بمراجعتي تينك الملفين.
