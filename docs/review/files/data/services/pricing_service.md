### lib/data/services/pricing_service.dart

- **الوظيفة:** الملف الأكبر والأهم لمنطق التسعير المتقدم (574 سطر): إدارة "أنواع الإقامة" (صباحية/مسائية/يوم كامل صباحي/يوم كامل مسائي)، سعر أسبوعي متكرر لكل نوع، أسعار خاصة بتواريخ محددة، وحساب السعر النهائي (محلياً للعرض بالتقويم، وعبر RPC للمصدر الموثوق).

- **الشرح التفصيلي:**
  - **`ChaletStayType`** (enum): 4 قيم (`morning`, `evening`, `fullDayMorning`, `fullDayEvening`) مع `dbValue` (تطابق قيم CHECK constraint بجدول `chalet_stay_types` حسب التعليق)، `fromDb` (تحويل عكسي، مع fallback آمن لـ`morning` لو القيمة غير معروفة)، `label`/`shortLabel` (نصوص عربية للعرض)، `icon`، و`defaultCheckin`/`defaultCheckout` (أوقات افتراضية معقولة لكل نوع عند إضافته أول مرة).
  - **`ChaletStayTypeConfig`**: يمثّل صفاً من `chalet_stay_types`. `_parseTime`/`_formatTime` يحوّلان بين `TimeOfDay` ونص وقت Postgres (`"HH:MM:SS"`) — **بدون أي معالجة استثناء** حول `int.parse`.
  - **`ChaletDatePrice`**: يمثّل صفاً من `chalet_date_prices` (تاريخ + سعر + ملاحظة + نوع إقامة).
  - **`DayPriceInfo`**: `originalPrice` (سعر يوم الأسبوع الأساسي) و`finalPrice` (بعد أي خصم/سعر خاص)، مع `isSpecialOffer` محسوبة (`finalPrice < originalPrice`) — جاهزة لعرض باج "عرض خاص" بالتقويم.
  - **`ChaletPricingService`**: تعليق توثيقي دقيق جداً أعلى الكلاس (سطر 206-215) يشرح **هرم أولوية حساب سعر أي ليلة** (6 مستويات، من الأخص للأعم)، ويذكر صراحة أن هذا **"يطابق دالة SQL `get_chalet_night_price` بالسيرفر بالضبط"**.
    - دوال CRUD لأنواع الإقامة (`getStayTypes`, `getEnabledStayTypes`, `upsertStayType`, `setStayTypeEnabled`, `deleteStayType`) وللسعر الأسبوعي (`getWeekdayPrices`, `setWeekdayPrice`, `clearWeekdayPrice`) وللأسعار الخاصة بالتواريخ (`getDateOverrides`, `setDateOverride`, `deleteDateOverride`) — **كلها بدون استثناء تقريباً بلا أي `try/catch`**.
    - **`getPriceForDate`**: RPC **`get_chalet_night_price`** لسعر ليلة واحدة.
    - **`calculateStayPrice`**: RPC **`calculate_chalet_stay_price`** لإجمالي فترة كاملة — موثّق صراحة: **"هذا هو المصدر الموثوق لحساب مبلغ أي حجز"**.
    - **`getMonthPricing`**: يبني خريطة (تاريخ → `DayPriceInfo`) لشهر كامل **محلياً بـ Dart** (بإعادة تطبيق نفس هرم الأولوية الست مستويات يدوياً)، بدل RPC لكل يوم على حدة (30+ نداء شبكة لكل شهر). موثّق إصلاحان حقيقيان مهمان بتعليقات دقيقة:
      1. (سطر 494-498) الاستعلامات الخمسة (weekday-for-type/default، date-overrides-for-type/default، stay-types) كانت تُنفَّذ **بالتتابع** (كل واحد ينتظر السابق)؛ أُصلِحت لتُطلَق كلها كـ`Future`ات متوازية أولاً ثم تُنتظَر معاً — تقليل زمن الاستجابة من مجموع 5 رحلات شبكة إلى أطول رحلة واحدة فقط.
      2. (سطر 547-551) **إصلاح فعلي لعطل توقيت صيفي حقيقي تم التحقق منه بالتشغيل الفعلي**: بناء المفتاح اليومي بـ `d.add(Duration(days: 1))` (إضافة 24 ساعة بالضبط) كان يُنتج تاريخاً خاطئاً (23:00 لليوم السابق بدل منتصف الليل) بعد نهاية التوقيت الصيفي بفلسطين (أواخر أكتوبر) — مؤكَّد بالتجربة: "6 مفاتيح خاطئة بأكتوبر 2026 ويوم 31 مفقود". أُصلِح ببناء التاريخ بمكوّناته (`DateTime(d.year, d.month, d.day + 1)`) الذي يتجاوز مشكلة التوقيت الصيفي تلقائياً.

- **الاعتماديات:** يستورد `flutter/material.dart` (لـ `TimeOfDay`/`IconData`) و`supabase_flutter`. **من يستخدمه:** على الأرجح [chalet_pricing_screen.dart](../../presentation/screens/owner/chalet_pricing_screen.md) و[pricing_preview.dart](../../presentation/screens/owner/pricing_preview.md) و[effective_price_panel.dart](../../presentation/screens/owner/effective_price_panel.md) وربما [booking_screen.dart](../../presentation/screens/booking/booking_screen.md) — يُؤكَّد عند مراجعتها.

- **التعامل مع Supabase:** جداول `chalet_stay_types` (select/upsert/update/delete)، `chalet_weekday_prices` (select/upsert/delete)، `chalet_date_prices` (select/upsert/delete) — **الثلاثة مطابقة تماماً** لأسماء الجداول بوصف المستخدم للباك إند. RPC: `get_chalet_night_price`, `calculate_chalet_stay_price`.

- **نقاط القوة:**
  - توثيق هرم الأولوية الست-مستويات بدقة متناهية مع تأكيد مطابقته لمنطق السيرفر — نادر الوضوح بهذا المستوى.
  - إصلاح موثّق وموثوق (بتحقق فعلي بالتشغيل) لعطل توقيت صيفي حقيقي بمنطقة القدس — تحديداً نوع المشاكل التي طلب المستخدم فحصها ("مشاكل التواريخ والمناطق الزمنية")، وهنا مُعالَجة بشكل استثنائي الجودة.
  - تحسين أداء موثّق (تفعيل التوازي بدل التسلسل) بتفسير واضح للأثر العملي (لماذا كان "تبديل نوع الإقامة يبين متأخر خطوة").
  - فصل واضح بين "تقدير للعرض" (`getMonthPricing`، محلي) و"مصدر الحقيقة" (`calculateStayPrice`، عبر RPC) — يطابق ما طلب المستخدم التحقق منه (الاعتماد على السيرفر للسعر الفعلي المحسوب على أي حجز).

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة — ازدواجية منطق هرم الأولوية بين السيرفر والتطبيق (سطر 206-215، 530-570):** `getMonthPricing` تعيد تطبيق نفس هرم الأولوية الست-مستويات **يدوياً بـ Dart** بدل استدعاء RPC. طالما بقي هذا المنطق **مطابقاً تماماً** لدالة `get_chalet_night_price` بالسيرفر (كما هو موثّق الآن)، فلا خطر فعلي — لكن **أي تعديل مستقبلي على منطق الأولوية بدالة SQL السيرفر** (مثلاً إضافة مستوى سابع، تغيير ترتيب الأولوية، تعديل حالة حدّية) **يجب تكراره يدوياً هنا أيضاً**، وإلا سيعرض تقويم الشهر سعراً مختلفاً عن السعر الفعلي الذي سيُحسب لحظة الحجز الفعلي عبر `calculateStayPrice`/RPC — بالضبط نوع "السعر المعروض يختلف عمّا سيُحفظ" الذي طلب المستخدم التحقق من غيابه. **لا يوجد اختبار آلي مذكور بهذا الملف يقارن نتيجة الحساب المحلي بنتيجة RPC** للتأكد من التطابق المستمر.
  - 🟠 **متوسطة (كل دوال الكتابة تقريباً: `upsertStayType`, `setStayTypeEnabled`, `deleteStayType`, `setWeekdayPrice`, `clearWeekdayPrice`, `setDateOverride`, `deleteDateOverride`):** **لا يوجد أي `try/catch`** على أي عملية كتابة تسعير — لا ترجمة أخطاء، لا رسالة عربية مفهومة. أي رفض RLS أو خطأ شبكة أثناء تعديل مالك لسعر شاليهه سيصل كاستثناء تقني خام (أو غير مُلتقَط إطلاقاً حسب الشاشة المستهلكة) — بخلاف [services.dart](services.md) المتّسق بتغليف كل عملية بـ `_translateSupabaseError`. يستحق أهمية خاصة كون هذا الملف يتحكم مباشرة بأسعار قد تخصم/تُحسَب من دخل المالك الفعلي.
  - 🟠 **متوسطة (سطر 288-308، `deleteStayType`):** 3 عمليات حذف متتالية (`chalet_weekday_prices` ← `chalet_date_prices` ← `chalet_stay_types`) **بدون transaction وبدون أي تنظيف تعويضي عند فشل جزئي** (بخلاف نمط "compensating transaction" المُطبَّق بـ`createOrUpdateChaletWithImages` بـ[services.dart](services.md)). لو فشلت الخطوة الثانية أو الثالثة (مثلاً انقطاع شبكة منتصف العملية)، تبقى البيانات بحالة غير متّسقة جزئياً (بعض الأسعار محذوفة، البعض الآخر والنوع نفسه لا يزالان موجودين) دون أي تنبيه أو محاولة استرجاع.
  - 🟡 **بسيطة (سطر 125-132، `_parseTime`):** `int.parse(parts[0])`/`int.parse(parts[1])` بدون أي `try/catch` أو تحقق من طول `parts`. احتمال حدوثه منخفض (التنسيق قادم من عمود Postgres `time` مستقر البنية)، لكن أي قيمة غير متوقعة (`null` تحوّل لنص فارغ بالخطأ، أو تنسيق مختلف) سيرمي `FormatException`/`RangeError` غير مُترجَم.

- **اقتراح الإصلاح:**
  - تغليف كل دوال الكتابة بـ try/catch + `_translateSupabaseError` (المستوردة من services.dart) بنفس أسلوب باقي طبقة الخدمات، مثال:
    ```dart
    Future<void> setWeekdayPrice({required String chaletId, required int weekday, required double price, String stayType = defaultStayType}) async {
      try {
        await _supabase.from('chalet_weekday_prices').upsert({...}, onConflict: 'chalet_id,weekday,stay_type');
      } catch (e) {
        throw Exception(_translateSupabaseError(e));
      }
    }
    ```
  - إضافة اختبار وحدة (unit test) بسيط يقارن نتيجة `getMonthPricing` لعينة تواريخ بنتيجة `getPriceForDate`/RPC الفعلية لنفس التواريخ، يُشغَّل دورياً (أو يدوياً بعد أي تعديل على منطق التسعير بالسيرفر) للتأكد من استمرار التطابق بين الحساب المحلي والسيرفر.
  - لـ `deleteStayType`: لو توفّرت إمكانية بالسيرفر، الأفضل نقلها لدالة RPC واحدة تنفّذ الحذوف الثلاثة داخل transaction حقيقية بقاعدة البيانات، بدل 3 نداءات client منفصلة.
