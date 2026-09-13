# Makan — Flutter Frontend Engineering Documentation

> الوثيقة مخصصة لشرح المشروع **كما هو موجود** لمهندس Flutter Senior جديد سينضم للفريق.
> 
> **ملاحظة**: بسبب تعطل أداة البحث عن نصوص/استدعاءات داخل المشروع (ripgrep غير متوفر في بيئة التشغيل)، تم بناء أجزاء “Complete inventory” استنادًا إلى الملفات التي تم قراءتها فعليًا + قائمة ملفات `lib/` المتاحة.

---

## 1) Flutter Architecture

### 1.1 Architecture Pattern
- التطبيق مبني حول:
  - **Service layer** داخل `lib/data/services/` (كل تواصل مع Supabase/Storage/RPC).
  - **Model layer** داخل `lib/data/models/` (DTOs/Parsers).
  - **Presentation layer** داخل `lib/presentation/` (Screens + Widgets).
  - **Router** موحد عبر `GoRouter`.
  - **State Management** عبر `flutter_riverpod` مع `ChangeNotifier` Notifiers.

### 1.2 State Management
- يستخدم التطبيق **Riverpod**.
- Providers الموجودة (حسب الملفات التي تم قراءتها):
  - `themeNotifierProvider` (ChangeNotifierProvider<ThemeNotifier>)
  - `localeNotifierProvider` (ChangeNotifierProvider<LocaleNotifier>)
- منطق تحميل الثيم واللغة:
  - `FriendsChaletsApp` في `main.dart` يقوم بقراءة Notifiers ثم يستدعي `loadFromPrefs()` مرة واحدة بعد أول render.

### 1.3 Navigation
- Navigation تتم عبر `GoRouter` (ملف: `lib/core/router/app_router.dart`).
- يتم تمرير بيانات عبر `state.extra` في بعض routes مثل:
  - `/payment`
  - `home/chalet/:id` (يستخدم chalet من extra إن توفر)

### 1.4 Dependency Injection
- لا يوجد DI framework خارجي.
- كل Services تستخدم نمط Singleton:
  - `static ...? _instance; static ... get instance => ...`
- يتم الوصول إليها مباشرة داخل Screens/Controllers.

---

## 2) Folder Structure

### 2.1 شجرة المشروع (حسب `lib/`)
```text
lib/
  main.dart
  core/
    constants/
      app_colors.dart
      app_strings.dart
    router/
      app_router.dart
    theme/
      app_state_providers.dart
      app_theme.dart
      locale_notifier.dart
      shared_preferences_keys.dart
      theme_notifier.dart
      theme_providers.dart
  data/
    models/
      chalet_model.dart
      models.dart
      reel_model.dart
    providers/
      favorites_provider.dart
    services/
      dashboard_service.dart
      host_service.dart
      pricing_service.dart
      reels_service.dart
      services.dart
  presentation/
    screens/
      splash/
        splash_screen.dart
      onboarding/
        onboarding_screen.dart
        app.code-workspace
      auth/
        login_screen.dart
        register_screen.dart
        forgot_password_screen.dart
      home/
        main_screen.dart
        home_tab.dart
      search/
        search_screen.dart
      chalet/
        chalet_detail_screen.dart
        chalet_detail_screen_ui_patch.txt
      booking/
        booking_screen.dart
      payment/
        payment_screen.dart
      reviews/
        reviews_screen.dart
      reels/
        reels_screen.dart
      favorites/
        favorites_screen.dart
        my_bookings_ui_only_notes.md
      map/
        palestine_chalets_map_screen.dart
      notifications/
        notifications_screen.dart
      profile/
        profile_screen.dart
        personal_data_screen.dart
        personal_data_placeholder.txt
      settings/
        settings_screen.dart
        about_app_screen.dart
        privacy_security_screen.dart
      host/
        host_dashboard_screen.dart
        host_bookings_screen.dart
        host_chalet_screen.dart
        host_reels_screen.dart
        host_statistics_screen.dart
      owner/
        owner_dashboard_screen.dart
        owner_add_chalet_screen.dart
        owner_chalets_screen.dart
        owner_bookings_screen.dart
        owner_external_screen.dart
        owner_profile_screen.dart
        owner_controllers.dart
      admin/
        admin_dashboard_screen.dart
  presentation/widgets/
    paginated_list_view.dart
    common/
      common_widgets.dart
      custom_button.dart
      custom_text_field.dart
      amenity_chip.dart
      app_logo.dart
      luxury_collapsing_app_bar.dart
      luxury_widgets.dart
      paginated_list_view.dart
      premium_scroll_app_bar.dart
```

### 2.2 شرح وظيفة كل مجلد وملف مهم
- `lib/main.dart`
  - تهيئة Supabase + loading .env.
  - تهيئة ProviderScope.
  - بناء `MaterialApp.router` مع `AppRouter.router`.
- `lib/core/`
  - `router/`: تعريف routes وredirect.
  - `theme/`: Notifiers + AppTheme.
  - `constants/`: ألوان ونصوص.
- `lib/data/`
  - `models/`: تمثيل البيانات من Supabase.
  - `services/`: كافة عمليات Supabase + Storage.
  - `providers/`: (مثل favorites_provider إن كان مستخدمًا UI side).
- `lib/presentation/`
  - `screens/`: UI flows.
  - `widgets/`: مكونات UI مشتركة.

---

## 3) Screens

> القائمة أدناه “كما هو موجود” حسب `list_files` في `lib/presentation/screens/`.
> 
> ملاحظة: لم يتم قراءة كل Screen كاملًا في هذه الجلسة؛ لذلك الوصف التفصيلي للخدمات يتم بشكل مؤكد فقط حيث تم الاطلاع على الكود.

### 3.1 SplashScreen
- الهدف: شاشة بدء (تهيئة/انتقال).
- من يستدعيها: `AppRouter` path `/splash`.
- الخدمات: غير محدد في جلسة القراءة الحالية.

### 3.2 OnboardingScreen
- الهدف: Onboarding.
- route: `/onboarding`.

### 3.3 Auth Screens
- `/auth/login` → `LoginScreen`
- `/auth/register` → `RegisterScreen`
- `/auth/forgot-password` → `ForgotPasswordScreen`

### 3.4 Home
- `/home` → `MainScreen(initialIndex: state.extra)`
- داخل home:
  - `home/chalet/:id` → `ChaletDetailScreen`
  - `home/booking` → `BookingScreen`
  - `home/reviews/:chaletId` → `ReviewsScreen`

### 3.5 SearchScreen
- route: `/search`
- الهدف: البحث عن شاليهات.
- الخدمات: غالبًا يستخدم `ChaletService.getChalets`.

### 3.6 ChaletDetailScreen
- route: `/home/chalet/:id`
- الهدف: تفاصيل شاليه + دخول صفحة الحجز.

### 3.7 BookingScreen
- route: `/home/booking`
- الهدف: إنشاء booking مع التقويم، اختيار نوع الإقامة (stay type) (إن متاح)، حساب السعر عبر backend RPC، ثم تأكيد الحجز.
- Services المستخدمة (مؤكد):
  - `ChaletService.instance.isAvailable`
  - `BookingService.instance.calculateBookingPrice`
  - `BookingService.instance.createBooking`
  - `ChaletPricingService.instance.getEnabledStayTypes`
  - `ChaletPricingService.instance.getMonthPricing`
  - `BookingService.instance.getBookedDates`

### 3.8 PaymentScreen
- route: `/payment`
- builder يتوقع `state.extra`:
  - `chalet`, `checkIn`, `checkOut`, `guestsCount`
- الهدف: تجهيز/دفع (تفاصيل غير مذكورة في جلسة القراءة الحالية).

### 3.9 ReviewsScreen
- route: `/home/reviews/:chaletId`
- الهدف: عرض تقييمات شاليه.
- Services: غالبًا `ReviewsService`.

### 3.10 ReelsScreen
- route: `/reels`
- الهدف: مشاهدة Reels عموديًا مع فيديو/Thumbnail.
- Services المستخدمة (مؤكد):
  - `ReelsService.instance.fetchReels()`

### 3.11 FavoritesScreen
- route غير مباشر (قد يكون داخل tabs داخل MainScreen).
- يستخدم غالبًا `FavoritesService`.

### 3.12 NotificationsScreen
- route غير مباشر.

### 3.13 Profile/Settings Screens
- routes غير مفصلة هنا (داخل home/settings flow).

### 3.14 Host Screens
- hosts routes هي `/owner-*` بحسب redirect logic.
- `host` screens: `HostDashboardScreen`, `HostBookingsScreen`, ...

### 3.15 Owner Screens
- `owner-dashboard` → `OwnerDashboardScreen`
- `owner-chalets` → `OwnerChaletsScreen`
- `owner-bookings` → `OwnerBookingsScreen`
- `owner-external` → `OwnerExternalScreen`
- `owner-profile` → `OwnerProfileScreen`
- `owner-add-chalet` → `OwnerAddChaletScreen`

### 3.16 AdminDashboardScreen
- route: `/admin-dashboard`
- الهدف: لوحة تحكم الأدمن.

---

## 4) Services

> سيتم شرح Services “كما هي موجودة” من خلال ملف `lib/data/services/services.dart` + ملفات الخدمات الأخرى التي تم قراءتها.

### 4.1 AuthService (داخل services.dart)
- `signUp`:
  - يستخدم `supabase.auth.signUp` ثم upsert لـ `profiles`
- `signIn`:
  - `signInWithPassword`
- `signOut`
- `resetPassword`
- `updatePassword`
- `getCurrentProfile`
- `updateProfile`
- `becomeOwner`:
  - `supabase.rpc('become_owner')`
- `becomeCustomer`:
  - `supabase.rpc('become_customer')`

### 4.2 ChaletService (داخل services.dart)
- `getChalets(filters...)`
  - query على `chalets`:
    - is_available=true, is_approved=true
    - filters: city, price range, pool/wifi, minGuests
    - searchQuery: split كلمات ثم `.or()` عبر ilike للحقل name/location/city
- `getChaletById`
- `getFeaturedChalets`
- `isAvailable(chaletId, checkIn, checkOut)`
  - يتحقق بعدم وجود bookings متداخلة لـ status pending/confirmed

### 4.3 BookingService (داخل services.dart)
- `calculateBookingPrice(...)`
  - يستدعي RPC:
    - `calculate_chalet_stay_price` مع params:
      - `p_chalet_id`, `p_check_in`, `p_check_out`, `p_stay_type`
- `createBooking(...)`
  - insert في جدول `bookings` بحقول:
    - chalet_id, user_id, check_in, check_out, guests_count, total_price, status=pending,
      payment_method, notes, stay_type
- `getBookedDates(chaletId)`
  - select `check_in, check_out` ل pending/confirmed ثم expands أيام داخل الفترة
- `getIncomingBookings()` (Owner)
  - select bookings + inner chalets(owner_id)
- `confirmIncomingBooking(bookingId)`
- `rejectIncomingBooking(bookingId)`
- `getMyBookings()`
- `cancelBooking(bookingId)`

### 4.4 FavoritesService
- `getFavorites()`
- `getFavoriteIds()`
- `toggleFavorite(chaletId)`

### 4.5 ReviewsService
- `getChaletReviews(chaletId)`
- `addReview(...)`
  - يشترط booking status completed إما عبر booking_id أو عبر lookup عبر user_id + chalet_id

### 4.6 NotificationsService
- `getNotifications()`
- `markAsRead(notificationId)`
- `markAllAsRead()`

### 4.7 DashboardService (dashboard_service.dart)
- `getOwnerDashboardStats(range)`
  - لا يعتمد على views بل يجلب bookings ثم يحسب aggregation داخل Dart

### 4.8 HostService (host_service.dart)
- `isHost()`
  - يقرأ `profiles.role` ويقارن مع 'owner'

### 4.9 ReelsService (reels_service.dart)
- `fetchReels()`
- `uploadReel(videoFile, thumbnailFile, chaletId, description)`
  - يرفع إلى buckets:
    - bucket `reels`
    - bucket `thumbnails`
  - ثم insert في جدول `reels` بـ `chalet_id`, `video_url`, `thumbnail_url`, `description`

### 4.10 ChaletPricingService (pricing_service.dart)
- يوفر طبقة التسعير لأوقات الوصول/المغادرة + أسعار weekday + overrides.
- RPC-equivalent via SQL functions:
  - `getPriceForDate` عبر supabase rpc `get_chalet_night_price`
  - `calculateStayPrice` عبر rpc `calculate_chalet_stay_price`
- ويقوم ببناء month pricing عبر جلب جداول:
  - chalet_weekday_prices
  - chalet_date_prices
  - chalet_stay_types

---

## 5) Models

> تم الاطلاع على `ChaletModel`, و `ReelModel` ضمن list_files (لكن الوصف التفصيلي لـ ReelModel لم يُقرأ هنا).

### 5.1 ChaletModel (chalet_model.dart)
- يمثل جدول `chalets`.
- حقوله الأهم:
  - id, name, description, location, city
  - pricePerNight
  - maxGuests
  - images (List<String>)
  - coverImage getter لتوافق كود قديم (images.first)
  - bookingType, minNights, depositAmount
  - videoUrl

### 5.2 BookingModel / ReviewModel / NotificationModel (models.dart)
- موجودة داخل `lib/data/models/models.dart`.
- (الوصف التفصيلي غير موجود في هذه الجلسة لعدم قراءة الملف كاملًا).

### 5.3 ReelModel (reel_model.dart)
- يمثل `reels`.

---

## 6) Providers / Controllers

### 6.1 Riverpod Providers (app_state_providers.dart)
- `themeNotifierProvider`
- `localeNotifierProvider`

### 6.2 Owner controllers (owner_controllers.dart)
> يوجد `owner_controllers.dart` داخل owner folder (ظاهر في list_files وقد تم قراءته في جلسة سابقة جزئيًا).
- `OwnerBookingsController`:
  - wraps BookingService.getIncomingBookings/confirm/reject
- `OwnerChaletsController`:
  - wraps chalets load for owner

---

## 7) Booking Flow (End-to-End)

> هذا القسم يشرح رحلة الحجز من UI حتى نجاح العملية (مبني على قراءة BookingScreen + BookingService).

### 7.1 بدء الرحلة
- المستخدم يفتح شاشة الحجز من سياق الشاليه.
- Navigation:
  - route داخل home: `home/booking` مع `extra: chalet`.

### 7.2 اختيار التاريخ
- BookingScreen يستخدم `TableCalendar`.
- المستخدم يختار:
  - check-in
  - check-out
- يتم استدعاء `_fetchServerPrice()` عندما تصبح الفتره صحيحة.

### 7.3 اختيار عدد الضيوف
- `_guests` مع ± buttons.
- يوجد debounce 500ms:
  - `_fetchServerPrice()` لا يُستدعى بكل ضغط.

### 7.4 اختيار stay type (إن مفعل لهذا الشاليه)
- `_loadStayTypes()`:
  - `ChaletPricingService.getEnabledStayTypes(chaletId)`
- يتم حفظ `_selectedStayType`:
  - أول type dbValue.

### 7.5 حساب السعر & التحقق من التوفر
- `_fetchServerPrice()`:
  1) availability check:
     - `ChaletService.isAvailable(...)` عبر query bookings pending/confirmed overlap
  2) calculate price:
     - `BookingService.calculateBookingPrice(... stayType: _selectedStayType)`

### 7.6 تأكيد الحجز (Create)
- زر “تأكيد الحجز”:
  - `_confirm()`
- داخل `_confirm()`:
  - تحقق محلي من صلاحية المدخلات + `_canConfirm`
  - استدعاء:
    - `BookingService.createBooking(... totalPrice: _serverTotalPrice!, stayType: _selectedStayType)`
- النجاح:
  - `_showSuccessDialog(booking)`
  - يستخرج booking id الحقيقي: `booking.id`
- الفشل:
  - رسائل UX خصوصًا conflict.

---

## 8) Authentication Flow

### 8.1 Login
- route: `/auth/login`.
- `AuthService.signIn` عبر `supabase.auth.signInWithPassword`.

### 8.2 Register
- route: `/auth/register`.
- `AuthService.signUp`:
  - supabase auth signUp
  - ثم upsert profiles بـ full_name/phone/email.

### 8.3 Become Owner / Customer
- من داخل flows:
  - `AuthService.becomeOwner()` → RPC `become_owner`
  - `AuthService.becomeCustomer()` → RPC `become_customer`

### 8.4 Redirect / Route Guard
- في `AppRouter.redirect`:
  - لو غير logged in → `/auth/login`
  - لو logged in ودخل auth path → `/home`
  - owner routes (`/owner-*`): تحقق HostService.isHost()

---

## 9) Storage Upload

### 9.1 صور الشاليهات (Owner Add Chalet)
- يتم عبر `OwnerAddChaletScreen`:
  - `_uploadNewImages(chaletId)`
- Bucket: `chalet-images`
- Path: `chalets/<chalet_id>/<timestamp>_<index>.<ext>`

### 9.2 فيديوهات Reels
- يتم عبر `ReelsService.uploadReel()`
- Buckets:
  - `reels`: `reels/<timestamp>_video.<ext>`
  - `thumbnails`: `thumbnails/<timestamp>_thumb.<ext>`
- ثم insert في جدول `reels` بـ `chalet_id` و urls.

---

## 10) RPC Calls

> هذه القائمة مبنية على الملفات التي تم قراءتها مباشرة (خصوصًا services.dart + ChaletPricingService + Edge function file).
> 
> قد توجد RPC أخرى داخل screens لم يتم قراءتها بالكامل.

### 10.1 RPC: `calculate_chalet_stay_price`
- Location:
  - `BookingService.calculateBookingPrice`
  - `ChaletPricingService.calculateStayPrice`
- Params:
  - `p_chalet_id`, `p_check_in`, `p_check_out`, `p_stay_type`
- Returns:
  - رقم (total price).

### 10.2 RPC: `get_chalet_night_price`
- Location:
  - `ChaletPricingService.getPriceForDate`
- Params:
  - `p_chalet_id`, `p_date`, `p_stay_type`

### 10.3 RPC: `become_owner`
- Location: `AuthService.becomeOwner`

### 10.4 RPC: `become_customer`
- Location: `AuthService.becomeCustomer`

### 10.5 Edge Function: `calculate-booking-price` (Legacy)
- موجود في `supabase/functions/calculate-booking-price/`.
- Flutter في الملفات التي تم قراءتها لا يظهر أنها تستدعيه مباشرة.

---

## 11) Supabase Integration

### 11.1 Auth
- supabase auth (signIn/signUp/reset/updatePassword/signOut)
- session storage: Secure storage wrapper داخل main.dart.

### 11.2 Database Queries
- يستخدم Supabase client `.from(<table>).select()/insert()/update()/delete()`
- استخدام inner joins مع syntax مثل:
  - `chalets!inner(...)`

### 11.3 Storage
- `supabase.storage.from(bucket).upload/uploadBinary`
- استخدام `getPublicUrl(path)` لتكوين روابط الصور/الفيديوهات.

---

## 12) UI Components

> يتمثل في widgets داخل `presentation/widgets/common/`.

### 12.1 Common Widgets (common_widgets.dart)
- يحتوي widgets عامة تستخدم في screens.

### 12.2 Custom Buttons
- `custom_button.dart`:
  - Buttons styling موحد.

### 12.3 Custom Text Field
- `custom_text_field.dart`:
  - TextField مع validation/labels.

### 12.4 AppBar/Scroll
- `luxury_collapsing_app_bar.dart`
- `premium_scroll_app_bar.dart`

### 12.5 paginated_list_view
- يوجد paginated_list_view.dart داخل `presentation/widgets/` وداخل `presentation/widgets/common/`.

---

## 13) Folder Dependency Map (High-Level)

- `core/router/app_router.dart`
  - يعتمد على Screens (presentation/screens/**)
- Screens:
  - يعتمدون على Services (data/services/**)
  - يعتمدون على Models (data/models/**)
  - يعتمدون على Widgets المشتركة (presentation/widgets/**)
- Services:
  - يعتمدون على `supabase_flutter`
  - يعتمدون على Models فقط عند parsing responses.

---

## 14) Backend Contracts (Flutter → Supabase)

> العقود أدناه “كما يفترضها” Flutter في الكود.
> 
> ⚠️ هذه ليست ضمانات schema 100% لأن schema.sql الذي تم قراءته سابقًا قد لا يعكس DB الحالي.

### 14.1 الجداول المستخدمة (حسب code)
- `profiles`
- `chalets`
- `bookings`
- `favorites`
- `reviews`
- `notifications`
- `reels`

### 14.2 Storage buckets
- `chalet-images`
- `reels`
- `thumbnails`

### 14.3 حقول booking المطلوبة من Flutter
- Flutter يكتب/يقرأ:
  - `chalet_id`, `user_id`, `check_in`, `check_out`, `guests_count`,
  - `total_price`, `status`, `payment_method`, `notes`,
  - `stay_type` (موجود/مفترض داخل Flutter createBooking)

### 14.4 RPC المطلوبة
- `calculate_chalet_stay_price`
- `get_chalet_night_price`
- `become_owner`
- `become_customer`

---

## 15) Final Frontend Documentation (Start Working Guide)

### 15.1 كيف يبدأ مهندس جديد العمل؟
1) ابدأ من `main.dart`:
   - Supabase initialize + Riverpod providers.
2) راجع `core/router/app_router.dart`:
   - كيف يتم redirect والـ routes.
3) راجع services في `lib/data/services/`:
   - ابدأ بـ `services.dart` لأنه يحتوي Auth/Chalet/Booking/Favorites/Reviews/Notifications.
4) راجع `BookingScreen`:
   - لتفهم الـ pricing + availability flow.
5) راجع `OwnerAddChaletScreen`:
   - لفهم storage buckets/path.
6) راجع `ReelsService`:
   - لتفهم فيديو/thumbnail storage.

### 15.2 نقاط مهمة عند التعديل
- عند تعديل التسعير/أنواع الإقامة:
  - راجع `BookingScreen` + `BookingService.calculateBookingPrice` + `ChaletPricingService`.
- عند تعديل Storage rules:
  - راجع owners upload + reels upload.
- عند تعديل auth roles:
  - راجع HostService + Router redirect + RPC become_owner/become_customer.

