# 🏡 شاليهات الأصدقاء - Friends Chalets

> تطبيق Flutter لحجز الشاليهات في فلسطين مع Supabase كـ Backend

---

## 📱 الشاشات المُنفَّذة (15 شاشة)

| # | الشاشة | الملف |
|---|--------|-------|
| 1 | شاشة البداية (Splash) | `splash/splash_screen.dart` |
| 2-4 | التهيئة (Onboarding) | `onboarding/onboarding_screen.dart` |
| 5 | إنشاء حساب | `auth/register_screen.dart` |
| 6 | تسجيل الدخول | `auth/login_screen.dart` |
| 7 | الرئيسية | `home/home_tab.dart` |
| 8 | تفاصيل الشاليه | `chalet/chalet_detail_screen.dart` |
| 9 | الحجز | `booking/booking_screen.dart` |
| 10 | المفضلة | `favorites/favorites_screen.dart` |
| 11 | حجوزاتي | `favorites/favorites_screen.dart` |
| 12 | حسابي | `profile/profile_screen.dart` |
| 13 | التقييمات | `favorites/favorites_screen.dart` |
| 14 | الإشعارات | `profile/profile_screen.dart` |
| 15 | نسيت كلمة المرور | `auth/register_screen.dart` |

---

## 🛠️ المتطلبات

- **Flutter**: >= 3.10.0
- **Dart**: >= 3.0.0
- **حساب Supabase**: [supabase.com](https://supabase.com)
- **Android Studio** أو **VS Code**

---

## 🚀 خطوات الإعداد

### 1️⃣ إعداد Supabase

1. انتقل إلى [supabase.com](https://supabase.com) وأنشئ مشروعاً جديداً
2. اذهب إلى **SQL Editor**
3. انسخ محتوى ملف `supabase/schema.sql` والصقه في المحرر
4. اضغط **Run** لتنفيذ الـ Schema

5. من **Settings → API** انسخ:
   - `Project URL`
   - `anon public key`

### 2️⃣ إعداد التطبيق

افتح `lib/main.dart` وعدّل هذين السطرين:

```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';     // ← ضع رابط مشروعك
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // ← ضع مفتاح anon
```

### 3️⃣ تثبيت الحزم

```bash
flutter pub get
```

### 4️⃣ تشغيل التطبيق

```bash
flutter run
```

---

## 📁 هيكل المشروع

```
lib/
├── main.dart                          # نقطة الدخول
├── core/
│   ├── constants/
│   │   ├── app_colors.dart           # ألوان التطبيق
│   │   └── app_strings.dart          # النصوص العربية
│   ├── theme/
│   │   └── app_theme.dart            # Theme الكامل
│   └── router/
│       └── app_router.dart           # التنقل (go_router)
├── data/
│   ├── models/
│   │   ├── chalet_model.dart         # موديل الشاليه
│   │   └── models.dart               # باقي الموديلات
│   └── services/
│       └── services.dart             # خدمات Supabase
└── presentation/
    ├── screens/
    │   ├── splash/                   # شاشة البداية
    │   ├── onboarding/               # التهيئة
    │   ├── auth/                     # المصادقة
    │   ├── home/                     # الرئيسية
    │   ├── chalet/                   # تفاصيل الشاليه
    │   ├── booking/                  # الحجز
    │   ├── favorites/                # المفضلة + حجوزاتي + تقييمات
    │   ├── profile/                  # الحساب + إعدادات + إشعارات
    │   └── ...
    └── widgets/
        └── common/                   # Widgets مشتركة
```

---

## 🗄️ قاعدة البيانات

### الجداول

| الجدول | الوصف |
|--------|-------|
| `profiles` | بيانات المستخدمين |
| `chalets` | الشاليهات وتفاصيلها |
| `bookings` | الحجوزات |
| `reviews` | التقييمات والتعليقات |
| `favorites` | المفضلة |
| `notifications` | الإشعارات |

### الميزات الأمنية
- ✅ **Row Level Security (RLS)** على جميع الجداول
- ✅ **كل مستخدم يرى بياناته فقط**
- ✅ **trigger تلقائي** لإنشاء profile عند التسجيل
- ✅ **trigger تلقائي** لتحديث تقييم الشاليه

---

## 📦 الحزم المستخدمة

| الحزمة | الاستخدام |
|--------|-----------|
| `supabase_flutter` | Backend كامل |
| `go_router` | التنقل بين الشاشات |
| `flutter_riverpod` | إدارة الحالة |
| `cached_network_image` | تحميل الصور |
| `table_calendar` | تقويم اختيار التواريخ |
| `smooth_page_indicator` | مؤشرات Onboarding |
| `shimmer` | تأثير التحميل |
| `shared_preferences` | حفظ بيانات محلية |

---

## 📲 بناء ملف APK للأندرويد

```bash
flutter build apk --release
```
الملف في: `build/app/outputs/flutter-apk/app-release.apk`

## 🍎 بناء للـ iOS

```bash
flutter build ios --release
```

---

## 🔧 إضافات مستقبلية

- [ ] دفع إلكتروني (Stripe / PayPal)
- [ ] خرائط Google للمواقع
- [ ] دردشة مباشرة مع المالك
- [ ] Push Notifications
- [ ] لوحة تحكم للملاك
- [ ] دعم اللغة الإنجليزية
- [ ] وضع مظلم (Dark Mode)

---

## 👨‍💻 تطوير

**شاليهات الأصدقاء** | Friends Chalets  
📧 info@friendschalets.com  
📱 +966 50 123 4567

---

*بُني بـ ❤️ لدعم السياحة الداخلية في فلسطين*
