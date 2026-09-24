# نظرة عامة على تطبيق Makan (شاليهات الأصدقاء)

> هذا الملف جزء من مراجعة توثيقية شاملة (قراءة وتحليل فقط، بدون أي تعديل على `lib/`).
> باقي الملفات في `docs/review/files/...` (مراجعة كل ملف على حدة)، والخلاصة النهائية في `docs/review/99_summary.md`.

## 1. ما هو التطبيق

تطبيق Flutter لحجز الشاليهات في فلسطين، اسمه الداخلي `makan` (المعروض للمستخدم: "مكان"، والاسم القديم في التعليقات/الحزمة "شاليهات الأصدقاء" / Friends Chalets — كلا الاسمين موجود في الكود، راجع [main.dart](../../lib/main.dart) حيث اسم الـ widget الجذر ما زال `FriendsChaletsApp`). الباك إند بالكامل Supabase (Postgres + Auth + Storage + Realtime + Edge Functions).

فيه ثلاث شخصيات مستخدم واضحة من هيكل الشاشات والراوتر:
- **ضيف/زائر (Guest)**: تصفح بدون تسجيل دخول (`/home`, `/search`, `/map`, `/reels`, تفاصيل شاليه).
- **مستخدم مسجّل (Customer)**: حجز، مفضلة، تقييمات، إشعارات.
- **مالك شاليه (Owner/Host)**: مجموعة شاشات كاملة تحت `/owner-*` لإدارة الشاليهات، التسعير، التقويم، الحجوزات، الحجز اليدوي (خارج التطبيق)، والتقارير.
- **أدمن (Admin)**: شاشة واحدة `/admin-dashboard` محمية بفحص `AuthService.isAdmin()`.

## 2. هيكل مجلد lib/ (شجرة الملفات)

```
lib/
├── main.dart                                  # نقطة الدخول: تهيئة Supabase/env/secure storage/Sentry + MaterialApp.router
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart                    # لوحة الألوان (فاتح/داكن)
│   │   ├── app_strings.dart                   # نصوص عربية ثابتة (بعضها بديل لعدم وجود l10n كامل)
│   │   └── pricing_constants.dart             # ثوابت نسب العمولة/رسوم الخدمة (نسخة عرض فقط)
│   ├── router/
│   │   └── app_router.dart                    # GoRouter: كل المسارات + حراسة الدخول (auth/host/admin)
│   ├── theme/
│   │   ├── app_state_providers.dart           # Riverpod providers لـ theme/locale notifiers
│   │   ├── app_theme.dart                     # ThemeData الفاتح/الداكن (Material)
│   │   ├── locale_notifier.dart               # ChangeNotifier للغة (ar/en) + حفظها بـ SharedPreferences
│   │   ├── shared_preferences_keys.dart        # مفاتيح SharedPreferences الموحّدة
│   │   └── theme_notifier.dart                # ChangeNotifier للثيم (فاتح/داكن/نظام) + حفظه
│   └── utils/
│       └── currency_formatter.dart            # تنسيق عرض الأسعار (شيكل)
│
├── data/
│   ├── models/
│   │   ├── booking_payment_details.dart       # نموذج تفاصيل دفع الحجز (عرض فقط)
│   │   ├── chalet_model.dart                  # نموذج الشاليه (تحويل من/إلى JSON صف Supabase)
│   │   ├── manual_booking.dart                # نموذج الحجز اليدوي (يُنشئه المالك خارج التطبيق)
│   │   ├── models.dart                        # نماذج متعددة (Booking, Review, أنواع مشتركة) — راجع الملف لتفاصيل كل class
│   │   ├── notification_model.dart            # نموذج الإشعار
│   │   └── reel_model.dart                    # نموذج الفيديو القصير (Reel)
│   ├── providers/
│   │   └── favorites_provider.dart            # Riverpod StateNotifier لقائمة المفضلة (متزامن مع Supabase)
│   └── services/
│       ├── admin_service.dart                 # عمليات الأدمن (استدعاءات RPC/جداول admin_*)
│       ├── dashboard_service.dart              # بيانات لوحة تحكم المالك (إحصائيات/رسوم بيانية)
│       ├── host_service.dart                   # فحص/تفعيل صلاحية "مالك" (become_owner إلخ)
│       ├── location_service.dart               # صلاحيات الموقع الجغرافي (geolocator)
│       ├── notification_service.dart           # قراءة/تحديث إشعارات Supabase
│       ├── payment_gateway.dart                # MockPaymentGateway (بوابة دفع وهمية — الدفع الإلكتروني معطّل حالياً)
│       ├── pricing_service.dart                # حساب/عرض التسعير (يومي/أسبوعي، مواسم، إلخ) وتفاعله مع جداول التسعير
│       ├── reels_service.dart                  # جلب فيديوهات Reels
│       ├── services.dart                       # المدخل الرئيسي: AuthService + خدمات الشاليهات/الحجوزات/المفضلة/التقييمات + ترجمة أخطاء Postgres للعربية
│       └── unavailable_nights.dart             # حساب/جلب الليالي غير المتاحة لشاليه معيّن
│
└── presentation/
    ├── screens/
    │   ├── admin/            admin_dashboard_screen.dart
    │   ├── auth/              auth_shared.dart, login_screen.dart, register_screen.dart, forgot_password_screen.dart
    │   ├── booking/            booking_screen.dart                (1880 سطر — أكبر ملف بالتطبيق)
    │   ├── bookings/           my_bookings_screen.dart             (ملف سطر واحد فقط — راجع الملاحظة أدناه)
    │   ├── chalet/             chalet_detail_screen.dart
    │   ├── favorites/          favorites_screen.dart
    │   ├── home/               home_tab.dart, main_screen.dart
    │   ├── map/                palestine_chalets_map_screen.dart   (flutter_map + OpenStreetMap)
    │   ├── notifications/      notifications_screen.dart, owner_notifications_screen.dart
    │   ├── onboarding/         onboarding_screen.dart
    │   ├── owner/               25 ملفاً — أكبر مجلد بالتطبيق (تسعير، تعديل شاليه، تقويم، حجز يدوي، تقارير...)
    │   ├── payment/             card_details, payment_failed, payment_flow_entry, payment_method, payment_processing, payment_review, payment_success
    │   ├── profile/             profile_provider.dart, profile_screen.dart
    │   ├── reels/               reels_screen.dart
    │   ├── reviews/             reviews_screen.dart                 (ملف سطر واحد فقط)
    │   ├── search/              search_screen.dart
    │   ├── settings/            about_app, help_support, privacy_security, settings_screen
    │   ├── splash/              مجلد **فارغ** (لا يحتوي أي ملف .dart حالياً)
    │   ├── theme/               payment_theme.dart                  (ثيم خاص بشاشات الدفع فقط)
    │   └── widgets/             payment_widgets.dart                (ويدجت مشتركة لشاشات الدفع، بمكان غريب نوعاً ما تحت screens/)
    └── widgets/
        └── common/             common_widgets.dart, language_bottom_sheet.dart, login_prompt.dart, luxury_widgets.dart
```

**ملاحظات على الهيكل نفسه (ستُفصَّل لاحقاً عند مراجعة كل ملف):**
- `lib/presentation/screens/bookings/my_bookings_screen.dart` و `lib/presentation/screens/reviews/reviews_screen.dart` كل واحد منهما **سطر واحد فقط**. يحتاج تأكيد أثناء دفعة المراجعة الخاصة بهما: هل هما ملفا `export` بسيطان يعيدان تصدير شاشة من مكان آخر، أم ملفان فارغان/متبقّيان من إعادة هيكلة يجب حذفهما؟ (لن أخمّن — سأقرأ محتواهما وأوثّق بدقة).
- مجلد `owner/` وحده فيه 25 ملفاً بأكثر من 11,000 سطر إجمالي — وهو فعلياً "تطبيق داخل التطبيق" لإدارة الشاليهات، ويستحق عناية خاصة في المراجعة الأمنية/منطق العمل لأنه المكان الذي يُفترض أن يعرض معلومات مالية حسّاسة (حجوزات، إيرادات) لمالك واحد فقط.
- إجمالي كود Dart بالتطبيق: **89 ملفاً، حوالي 32,500 سطر**.
- توجد أيضاً ملفات SQL محلية في `supabase/` (`schema.sql`, `owner_dashboard_schema.sql`, `owner_dashboard_split_schema.sql`) و Edge Function واحدة (`calculate-booking-price`). **هذه الملفات قديمة ولا تطابق وصف الباك إند الحالي** الذي زوّدني به المستخدم (لا تحتوي على `chalet_stay_types`, `chalet_weekday_prices`, `chalet_date_prices`, `availability`, `payments`, `conversations`, `messages`, `subscriptions`, ولا على الدوال `is_chalet_available` / `get_booked_dates` / `create_external_booking` / `cancel_external_booking` / `toggle_favorite` / `become_owner` / `become_customer` / `admin_*`). إذاً هذه الملفات المحلية توثّق نسخة قديمة من قاعدة البيانات فقط، والقاعدة الفعلية الحالية أكبر وتغيّرت عبر migrations غير موجودة في هذا الريبو. **لا يوجد اتصال مباشر بقاعدة البيانات الحية في هذه المراجعة** — كل الاستنتاجات عن التوافق مع الباك إند تعتمد على (أ) وصف المستخدم و(ب) ما يستدعيه كود Dart فعلياً من أسماء جداول/أعمدة/RPC، وسأنص صراحة كل مرة أشك فيها بدل التخمين.

## 3. المكتبات المستخدمة (من pubspec.yaml) ولماذا

| المكتبة | الفئة | لماذا موجودة |
|---|---|---|
| `supabase_flutter` | Backend | العميل الرسمي للاتصال بـ Supabase (Auth, Postgrest, Storage, Realtime) — هذا هو الباك إند الوحيد للتطبيق. |
| `flutter_secure_storage` | أمان | تخزين جلسة Supabase (access/refresh token) في Android Keystore / iOS Keychain بدل SharedPreferences غير المشفّرة — مستخدم فعلياً في [main.dart](../../lib/main.dart) عبر `_SecureSupabaseStorage`. نقطة قوة أمنية واضحة. |
| `flutter_dotenv` | إعداد | تحميل `SUPABASE_URL`/`SUPABASE_ANON_KEY` من ملف `.env` بدل كتابتها بالكود مباشرة. |
| `sentry_flutter` | مراقبة أخطاء | تتبّع الأعطال في بيئة production (مفعّل فقط لو `SENTRY_DSN` موجود عبر `--dart-define`). |
| `flutter_riverpod` + `riverpod_annotation` | إدارة الحالة | Riverpod هو نمط إدارة الحالة الأساسي. **ملاحظة:** `riverpod_annotation` و`riverpod_generator` (في dev_dependencies) موجودتان بالـ pubspec لكن لا يوجد أي استخدام فعلي لـ `@riverpod` ولا أي ملف `*.g.dart` مولَّد بكامل `lib/` — أي أن التطبيق يستخدم فقط الأسلوب اليدوي التقليدي (`ChangeNotifierProvider`, `StateNotifierProvider`, `FutureProvider`, `Provider`) وليس Riverpod codegen. هذا يعني أن حزمتين من الاعتماديات غير مستخدمتين فعلياً (وزن إضافي على وقت البناء بدون فائدة) — تفصيل في الملف الملخّص. |
| `go_router` | تنقّل (Routing) | كل التنقل عبر `GoRouter` مع نظام `redirect` مركزي للحراسة (auth/host/admin). |
| `cached_network_image` | UI | عرض صور الشاليهات القادمة من Supabase Storage/الإنترنت مع كاش وتحميل تدريجي. |
| `flutter_svg`, `shimmer`, `lottie`, `smooth_page_indicator`, `flutter_rating_bar`, `photo_view`, `google_fonts` | UI | عناصر واجهة متنوعة (أيقونات SVG، تحميل هيكلي Skeleton، أنيميشن، مؤشرات صفحات، تقييم نجوم، تكبير صور، خطوط Google). |
| `table_calendar` | UI | تقويم المالك (حجب تواريخ/عرض حجوزات) وربما تقويم الحجز للعميل. |
| `video_player`, `chewie`, `youtube_player_iframe` | فيديو | تشغيل الفيديوهات في قسم Reels. |
| `intl` | تنسيق | تنسيق التواريخ/الأرقام حسب اللغة (عربي/إنجليزي)، ومطلوب فعلياً بعد `initializeDateFormatting('ar')` في main.dart. |
| `shared_preferences` | تخزين محلي | حفظ تفضيلات غير حسّاسة: اللغة، الثيم، هل onboarding اكتمل. |
| `geolocator` | موقع | الموقع الجغرافي للمستخدم (خرائط/فرز حسب القرب على الأرجح). |
| `image_picker` | وسائط | اختيار صور من المعرض/الكاميرا (رفع صور الشاليه من شاشات المالك). |
| `url_launcher` | تكامل خارجي | فتح روابط خارجية (اتصال هاتفي، واتساب، مشاركة، إلخ حسب الاستخدام). |
| `connectivity_plus` | شبكة | فحص الاتصال بالإنترنت. |
| `flutter_map` + `latlong2` | خرائط | خريطة شاليهات فلسطين (بديل مجاني لـ Google Maps، يعتمد OpenStreetMap على الأغلب). |
| `patrol` | اختبار | اختبارات end-to-end (ضمن dependencies الرئيسية وليس dev_dependencies فقط — غريب بعض الشيء، الطبيعي أن تكون Patrol فقط في dev_dependencies إلا لو فيه استخدام runtime متعمّد). |

## 4. نمط إدارة الحالة (State Management)

- الأساس: **Riverpod** (`flutter_riverpod`) بأسلوب يدوي (بدون codegen):
  - إشعارات ثيم/لغة: `ThemeNotifier` و`LocaleNotifier` (كلاهما `ChangeNotifier` عادي) مكشوفة عبر `ChangeNotifierProvider` في [app_state_providers.dart](../../lib/core/theme/app_state_providers.dart)، ويُستهلكان بـ `ref.watch(...)` في [main.dart](../../lib/main.dart) لإعادة بناء `MaterialApp` بالكامل (ثيم/لغة/اتجاه RTL-LTR) عند التغيير.
  - المفضلة: `favoritesProvider` في [favorites_provider.dart](../../lib/data/providers/favorites_provider.dart) — على الأرجح `StateNotifierProvider` يزامن مع جدول `favorites` بـ Supabase.
  - البروفايل: `profileProvider` في [profile_provider.dart](../../lib/presentation/screens/profile/profile_provider.dart).
  - `main.dart` يستمع لـ `AuthService.instance.authStateChanges` (Stream من Supabase Auth) ويستدعي `ref.invalidate(favoritesProvider)` و`ref.invalidate(profileProvider)` عند signIn/signOut/userUpdated — هذا **إصلاح متعمّد وموثّق بتعليق بالكود** لمشكلة كانت موجودة (بيانات الضيف القديمة تبقى ظاهرة بعد تسجيل الدخول). نقطة قوة: تصميم واعٍ لمشكلة تزامن حالة حقيقية.
  - كثير من الشاشات (خصوصاً شاشات owner/) تُدار كـ `StatefulWidget` عادي بحالة محلية (`setState`) بدل Riverpod — سأوثّق ذلك ملفاً ملفاً؛ يعني أن إدارة الحالة بالتطبيق **مختلطة** (Riverpod للحالة العابرة للشاشات + setState محلي داخل كل شاشة لحالتها الخاصة)، وهذا نمط شائع ومقبول لكنه يزيد احتمال تكرار منطق الجلب (fetch) بين الشاشات.

## 5. طريقة التنقل (Routing)

`GoRouter` واحد مركزي في [app_router.dart](../../lib/core/router/app_router.dart):

- **نقطة الدخول:** `/onboarding`.
- **حراسة مركزية عبر `redirect`** (تُنفَّذ قبل كل تنقل):
  1. لو Supabase لم تُهيَّأ بعد (اختبارات/hot reload/بداية مبكرة) → يسمح فقط بـ onboarding/auth، وإلا يرجّع لـ `/onboarding`.
  2. `isLoggedIn` = `Supabase.instance.client.auth.currentUser != null` (فحص محلي من الجلسة المخزَّنة، وليس نداء شبكة).
  3. مسارات عامة (`isPublicRoute`): onboarding, auth/*, home, home/chalet/:id, search, map, reels — يمكن للضيف الدخول إليها.
  4. مسارات محمية (`isProtectedRoute`): booking, payment, home/reviews/:id, أي شيء يبدأ بـ `owner-`, admin-dashboard — تتطلب تسجيل دخول، وإلا تحويل لـ `/auth/login`.
  5. مسارات `owner-*` (عدا `owner-add-chalet`) تتطلب أيضاً `await HostService.instance.isHost()` — **هذا نداء شبكة/DB داخل دالة `redirect`، يُنفَّذ عند كل تنقل لهذه المسارات** (تفصيل الأثر على الأداء وتكرار النداءات سيُراجَع في ملف app_router.dart نفسه).
  6. `/admin-dashboard` يتطلب `await AuthService.instance.isAdmin()` بنفس الأسلوب.
- **تعشيش المسارات:** `/home` هو المسار الأب لـ `chalet/:id`, `booking`, `reviews/:chaletId` (شجرة GoRoute متداخلة).
- **تمرير البيانات بين الشاشات:** عبر `state.extra` (كائنات Dart مباشرة مثل `ChaletModel`, `DateTime`, `int`) وليس فقط query params. الكود يحتوي على إصلاحات موثّقة بالتعليقات لمشاكل حقيقية حدثت: `state.extra` قد يكون `null` أو نوعاً خاطئاً عند deep link/تحديث صفحة الويب/Hot Restart، فتم إضافة فحوصات نوع (`is`/`is!`) بدل cast مباشر (`as`) الذي كان يرمي `TypeError` ويكسر التطبيق. هذا نمط جيد لكنه **هش بطبيعته** (type-unsafe بين الشاشات) — أي إضافة معامل جديد لاحقاً يحتاج تذكّر تكرار نفس الفحص، ولا يوجد فحص واحد مركزي.
- **الدفع الإلكتروني معطّل عمداً حالياً:** `AppRouter.onlinePaymentEnabled = false` بتعليق صريح: "MockPaymentGateway الحالي لا ينشئ حجزاً فعلياً بقاعدة البيانات" — أي وصول لمسار `/payment` يُعاد إلى `/home`. هذا قرار منتج متعمّد وليس خطأ، لكنه يعني أن كل شاشات `payment/*` حالياً **كود ميت من ناحية التدفق الفعلي للمستخدم** (تُراجَع لاحقاً هل ما زالت قابلة للوصول من أي مكان آخر بالتطبيق).

## 6. كيف يتصل التطبيق بـ Supabase

1. **التهيئة (main.dart):**
   - تحميل `.env` (أو `assets/.env` كبديل) عبر `flutter_dotenv` — لو الاثنان غائبان يرمي `StateError` (فشل صريح بدل تشغيل التطبيق بحالة غير معرّفة، جيد).
   - `Supabase.initialize(url:, anonKey:, authOptions: FlutterAuthClientOptions(localStorage: _SecureSupabaseStorage()))`.
   - `_SecureSupabaseStorage` (class خاص بـ main.dart) يطبّق واجهة `LocalStorage` من supabase_flutter، ويخزّن سلسلة الجلسة الكاملة تحت مفتاح واحد `sb-auth-token` في `FlutterSecureStorage` (مع `encryptedSharedPreferences: true` على أندرويد) — بدل التخزين الافتراضي غير المشفّر. **نقطة قوة أمنية موثّقة بوضوح في تعليق الكود.**
   - مفتاح `SUPABASE_ANON_KEY` هو المفتاح العام المخصص للعميل (anon/public key)، وهذا هو الاستخدام الصحيح؛ **لم أجد أي استخدام لـ service_role key داخل `lib/`** (فقط داخل Edge Function `calculate-booking-price` التي تعمل على سيرفر Deno — هذا هو المكان الصحيح الوحيد المسموح فيه باستخدام مفتاح بهذه الصلاحية).
2. **البوّابة الموحّدة للاستعلامات:** `final supabase = Supabase.instance.client;` مُعرَّف مرة واحدة أعلى [services.dart](../../lib/data/services/services.dart) ويُستورد من بقية ملفات `data/services/*`. بمعنى أن **كل استدعاءات `.from(...)`, `.rpc(...)`, `.storage`, إلخ تمر منطقياً عبر طبقة الخدمات** (`services.dart`, `pricing_service.dart`, `dashboard_service.dart`, `admin_service.dart`, `host_service.dart`, `notification_service.dart`, `reels_service.dart`, `unavailable_nights.dart`) بدل أن تستدعي الشاشات Supabase مباشرة — نمط معماري جيد (فصل طبقة البيانات عن العرض)، سأتحقق ملفاً ملفاً هل الشاشات فعلاً تلتزم بهذا أو تكسر الفصل أحياناً.
3. **ترجمة أخطاء الـ triggers:** `services.dart` يحتوي دالة `_translateSupabaseError` تفحص نص الخطأ القادم من PostgREST/trigger وتحوّله لرسالة عربية مفهومة — أمثلة موجودة فعلياً بالكود: تعارض حجز (`exclusion constraint`, كود `23P01`/`23505`) → "هذا التاريخ محجوز، جرب تواريخ تانية"؛ يوم محجوب (`availability unavailable`) → رسالة محايدة "بعض الأيام المختارة غير متاحة للحجز"؛ محاولة تعديل حقل محمي → "حدث خطأ، حاول مرة أخرى"؛ نقص صلاحيات أدمن → "حدث خطأ، غير مصرح بهذا الإجراء". **هذا يطابق بالضبط ما طلب المستخدم التحقق منه** (أن التطبيق يعالج رسائل الـ triggers ويعرضها بشكل مفهوم) — نقطة قوة حقيقية موثّقة بالكود نفسه بتعليقات تشرح الحادثة الأصلية. سأتحقق في ملف `services.dart` وملفات الحجز هل كل مسارات الخطأ فعلاً تمر من هذه الدالة أو أن بعضها يعرض `error.toString()` خام.
4. **Realtime/Storage:** لم أؤكد بعد أي استخدام فعلي لـ Realtime subscriptions أو Storage uploads — سيُوثَّق بدقة (مع اسم الجدول/bucket) عند مراجعة كل ملف خدمة على حدة، بدل الافتراض هنا.
5. **الحالة عند عدم التهيئة:** الراوتر يتحقق صراحة من `Supabase.instance.isInitialized` قبل قراءة `auth.currentUser` — يحمي من تعطّل مبكر في الاختبارات/hot reload.

## 7. سياق الباك إند المُعطى من المستخدم (للمقارنة أثناء المراجعة)

حسب وصف المستخدم، قاعدة البيانات الفعلية (غير الموجودة كـ migrations بهذا الريبو) فيها:
- **جداول:** `profiles, chalets, bookings, chalet_stay_types, chalet_weekday_prices, chalet_date_prices, availability, reviews, favorites, notifications, payments, conversations, messages, subscriptions`.
- **دوال RPC:** `is_chalet_available, get_booked_dates, create_external_booking, cancel_external_booking, toggle_favorite, become_owner, become_customer, admin_*`.
- **حماية على مستوى السيرفر:** triggers تفرض السعر الإجمالي، تمنع تعديل حقول الدفع/الحالة، ومنع تداخل الحجوزات بقيد exclusion.

سأتحقق عند كل ملف Dart يتعامل مع هذه الجداول/الدوال من:
- هل يعتمد على نتيجة السيرفر لحساب/عرض السعر النهائي أم يحسبه محلياً ويعرضه كـ"نهائي" (خطر: يختلف عمّا سيُحفظ فعلياً)،
- هل يمرّر أسماء أعمدة/قيم status/stay_type/booking_type صحيحة ومتوافقة مع القيم المسموحة،
- هل يحاول تحديث حقول محمية (دفع/حالة) مباشرة من التطبيق ثم يتوقع نجاحها،
- هل يعرض رسالة تعارض/عدم توفر واضحة للمستخدم عند رفض trigger للعملية.

## 8. خطة المراجعة والملفات

راجع [progress.md](progress.md) للتفصيل الكامل لكل دفعة وحالتها الحالية. الترتيب: `core` ← `services` ← `models` ← `providers/state` ← `screens` ← `widgets`، ثم `99_summary.md` في النهاية.
