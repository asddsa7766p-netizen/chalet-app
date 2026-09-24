### lib/presentation/screens/favorites/favorites_screen.dart

- **⚠️ ملاحظة هيكلية جوهرية أولاً:** هذا الملف (1069 سطر) يحتوي فعلياً **ثلاث شاشات كاملة غير مترابطة منطقياً**: `FavoritesScreen` (المفضلة، سطر 18-223)، `MyBookingsScreen` (حجوزاتي، سطر 228-456، + `_BookingCard` سطر 458-708)، و`ReviewsScreen` (تقييمات شاليه، سطر 713-935، + `_ReviewTile` سطر 984-1069). التفصيل الكامل لهذه الملاحظة وأثرها بمراجعتي [my_bookings_screen.md](../bookings/my_bookings_screen.md) و[reviews_screen.md](../reviews/reviews_screen.md) (شيمات `export` تُشير هنا). سأراجع الثلاثة أدناه بنفس القالب المطلوب لكل واحدة على حدة ضمن هذا الملف الواحد فعلياً.

---

#### القسم 1: `FavoritesScreen` (سطر 18-223)

- **الوظيفة:** قائمة الشاليهات المفضّلة، مع سحب للحذف (`Dismissible`) وسحب للتحديث.
- **الشرح التفصيلي:** `build()` يجمع بين `ref.watch(favoritesProvider)` (القراءة التفاعلية) و`ref.listen(favoritesProvider, ...)` (استماع للتغييرات اللاحقة يستدعي `_loadChalets` عند تغيّر المعرّفات) **بالإضافة** لفحص يدوي داخل `build()` نفسه (سطر 107-110): لو لم يُحمَّل شيء بعد (`_lastIds == null`) لكن `favoritesProvider` **لديه بالفعل** قيمة جاهزة، يستدعي `_loadChalets` مباشرة. `_remove` محميّة ضد `StateError` من سحب مزدوج سريع (`matches.isEmpty` بدل `firstWhere` المباشر).
- **الاعتماديات:** `favorites_provider.dart`, `services.dart` (`FavoritesService`), `pricing_service.dart` (`ChaletStayType` — غير مستخدم فعلياً بهذا القسم تحديداً، يُستخدم بقسم الحجوزات أدناه بنفس الملف)، `common_widgets.dart` (`ChaletCard`). **من يستخدمه:** [main_screen.dart](../home/main_screen.md) (تبويب "المفضلة").
- **التعامل مع Supabase:** `FavoritesService.getFavorites()`، وعبر `favoritesProvider` (RPC `toggle_favorite`).
- **نقاط القوة:** تمييز صريح بين "لا توجد مفضلة" و"فشل التحميل" (كانا مدمجين برسالة مضلِّلة واحدة سابقاً حسب التعليق)، حماية من `StateError` بسحب مزدوج سريع، `RefreshIndicator` فعّال.
- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (سطر 107-110) — احتمال حقيقي لخطأ "setState() or markNeedsBuild() called during build":** الفحص `if (_lastIds == null && favState.valueOrNull != null) { ...; _loadChalets(_lastIds!); }` يُنفَّذ **مباشرة داخل `build()`**. بما أن `_loadChalets` دالة `async` تنفّذ **بشكل متزامن حتى أول `await`**، فإن أول سطر بداخلها — `setState(() { _loading = true; ... });` — يُنفَّذ **فعلياً وبشكل متزامن أثناء تنفيذ `build()` نفسها**. هذا نمط فلاتر محظور صراحة (استدعاء `setState` من داخل `build()` لنفس الـ widget) ويُطلق عادة استثناء تأكيد (assertion) حقيقياً بوضع Debug: *"setState() or markNeedsBuild() called during build"*. **السيناريو الذي يُفعِّله فعلياً**: بما أن [main_screen.dart](../home/main_screen.md) يبني كل التبويبات الستة دفعة واحدة عبر `IndexedStack` (`FavoritesScreen` تُبنى فوراً حتى لو غير معروضة)، فإن أول مرة يتحوّل فيها `favoritesProvider` من `loading` إلى `data` (يحدث مرة تقريباً بكل جلسة، بعد اكتمال تحميله الأولي) ستُطلق إعادة بناء لـ`FavoritesScreen` تقع فيها هذا الفحص بقيمة `favState.valueOrNull != null` صحيحة — فيُستدعى `_loadChalets` (و`setState` بداخلها) وسط تنفيذ نفس `build()` التي استدعتها. بوضع الإنتاج (Release) عادة لا تُرمى هذه التأكيدات (assertions تُزال)، فقد يمر الأمر بصمت كإعادة بناء إضافية غير ضارة عملياً غالباً — لكن بوضع Debug/Profile (المستخدَم أثناء التطوير والاختبار) هذا **قد يُنتج شاشة خطأ حمراء حقيقية**.
  - 🟡 **بسيطة:** `ref.listen` المُسجَّل بنفس `build()` (سطر 99-105) **لا يُغطي فعلياً** حالة "القيمة جاهزة أصلاً قبل أول بناء لهذه الشاشة" (لأن `ref.listen` يستجيب فقط للتغييرات *بعد* التسجيل، لا للقيمة الحالية وقت التسجيل) — وهذا بالضبط سبب وجود الفحص اليدوي المُشكِل بسطر 107-110. الحاجة الوظيفية لهذا الفحص حقيقية، لكن طريقة تنفيذه الحالية هي المشكلة.

- **اقتراح الإصلاح:** تأجيل النداء الأول لما بعد إطار البناء الحالي بدل تنفيذه أثناء `build()` مباشرة:
  ```dart
  if (_lastIds == null && favState.valueOrNull != null) {
    _lastIds = favState.valueOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadChalets(_lastIds!);
    });
  }
  ```

---

#### القسم 2: `MyBookingsScreen` (سطر 228-456) + `_BookingCard` (سطر 458-708)

- **الوظيفة:** حجوزات العميل موزّعة على 4 تبويبات (مؤكدة/قيد الانتظار/سابقة/ملغاة+مرفوضة)، مع إلغاء حجز (بتأكيد Dialog).
- **الشرح التفصيلي:** `_load()` يجلب كل الحجوزات مرة واحدة (`BookingService.getMyBookings`) ويوزّعها محلياً حسب `_statuses` (قائمة تصنيفات لكل تبويب). `_cancel`: Dialog تأكيد → `BookingService.cancelBooking` → إعادة تحميل. **تعليق يوثّق إصلاحاً دقيقاً حول الصدق بالتسمية**: تبويبا "الحالية"/"القادمة" سابقاً لم يطابقا فعلياً ما يُفلتَران عليه (كان "الحالية" يعرض أي حجز `confirmed` بغض النظر عن التاريخ حتى لو بعد 3 أشهر، و"القادمة" تعرض `pending` رغم أنه قد يُرفض) — أُعيدت التسمية لتصف الحالة الفعلية بدقة (مؤكدة/قيد الانتظار) **بدون** أي تغيير بمنطق الفلترة نفسه.
  - `_BookingCard.nightsCount`: يستخدم `booking.nightsCount` من [`BookingModel`](../../../data/models/models.md) — **وهي بالضبط النسخة المُصلَحة بمنطق UTC ضد عطل التوقيت الصيفي** (بخلاف [booking_screen.dart](../../booking/booking_screen.md) التي أعادت تعريف حساب مماثل محلياً **بدون** نفس الإصلاح) — استخدام صحيح ومتّسق هنا.
- **الاعتماديات:** `services.dart` (`BookingService`), `models.dart` (`BookingModel`, `BookingStatus`)، `pricing_service.dart` (`ChaletStayType` — لعرض تسمية نوع الإقامة). **من يستخدمه:** [main_screen.dart](../home/main_screen.md) (تبويب "الحجوزات").
- **التعامل مع Supabase:** `BookingService.getMyBookings()` (`bookings` بجوين `chalets`)، `BookingService.cancelBooking()`.
- **نقاط القوة:**
  - إصلاح صدق التسمية (أعلاه) — مثال جيد آخر على مراجعة دقيقة لمطابقة النص المعروض للسلوك الفعلي.
  - حماية `RangeError` لاختصار معرّف الحجز (نفس حماية `booking_screen.dart`، مطبَّقة هنا أيضاً بتعليق يوثّق أنها كانت غائبة).
  - بطاقة الحجز أصبحت قابلة للنقر (تنتقل لتفاصيل الشاليه) بعد أن كانت جامدة تماماً بلا أي تفاعل — إصلاح موثّق.
  - حالة "لا يوجد" الفارغة بكل تبويب أصبحت قابلة للسحب للتحديث (`RefreshIndicator`) بدل `Center` جامد بلا وسيلة تحديث.
  - عرض شارة نوع الإقامة الفعلي فقط عند وجود معنى حقيقي له (`!= 'default'`) بدل عرضها دائماً.
- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة:** `_load()` يجلب **كل** حجوزات المستخدم دفعة واحدة (بلا `.range()`/pagination) ثم يفلتر محلياً لـ4 تبويبات — مقبول لحجم حجوزات شخص واحد عادة (عكس القلق الأشمل بجداول عبر كل المنصة بملفات owner/admin)، لكنه يستحق نفس الملاحظة العامة لو تراكمت لمستخدم واحد سنوات من الحجوزات.
  - لا فجوات `mounted` أو مشاكل null-safety أخرى ملحوظة بهذا القسم.
- **اقتراح الإصلاح:** لا شيء عاجل بخلاف ما ذُكر.

---

#### القسم 3: `ReviewsScreen` (سطر 713-935) + `_ReviewTile` (سطر 984-1069)

- **الوظيفة:** عرض كل تقييمات شاليه معيّن (بتوزيع نجوم) + نموذج إضافة تقييم جديد.
- **الشرح التفصيلي:** `_submit()` يستدعي `ReviewsService.addReview`، ويميّز 3 حالات خطأ بفحص نصي: `already_reviewed`, `not_eligible_review`, وعام — متّسق مع تصميم الاستثناءات بنصوص حرة الموثَّق بمراجعة [services.dart](../../../data/services/services.md).
- **الاعتماديات:** `services.dart` (`ReviewsService`), `models.dart` (`ReviewModel`), `common_widgets.dart`. **من يستخدمه:** [chalet_detail_screen.dart](../chalet/chalet_detail_screen.md) (زر "عرض الكل" بقسم التقييمات) عبر مسار `/home/reviews/:chaletId`.
- **التعامل مع Supabase:** `ReviewsService.getChaletReviews`، `ReviewsService.addReview`.
- **نقاط القوة:** حماية `_myRating == 0 || _submitting` ضد إرسال فارغ/مزدوج، حماية `characters.first` على اسم فارغ (نفس حماية `chalet_detail_screen.dart`، مطبَّقة هنا أيضاً بتعليق صريح).
- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 788) — استخدام `_` كمتغيّر فعلي مقروء، مربك جداً رغم صحته:**
    ```dart
    } catch (_) {
      ...
      final msg = _ is Exception ? _.toString() : 'error';
    ```
    بلغة Dart، `catch (_)` يُسمّي متغيّر الاستثناء المُلتقَط حرفياً `_`، ويمكن قراءته لاحقاً (كما يحدث هنا) — هذا **يعمل بشكل صحيح فعلياً** وليس خطأ وظيفياً، لكنه يخالف تماماً الاصطلاح الشائع لاستخدام `_` (يعني عادة عمداً "غير مُستخدَم") مما يجعل الكود مضلِّلاً لأي قارئ (أو حتى IDE) يفترض أن هذا الاستثناء يُتجاهَل، بينما هو فعلياً يُقرأ مرتين. الفحص `is Exception` أيضاً زائد عملياً: `.toString()` متاحة على أي `Object` بلغة Dart أصلاً (بما فيها أي شيء آخر غير `Exception` قد يُرمى)، فلا حاجة حقيقية لهذا الفحص الشرطي.
  - 🟡 **بسيطة (سطر 984-1069 مقابل [`_ReviewItem`](../chalet/chalet_detail_screen.md) بملف آخر):** كلاس `_ReviewTile` هنا يكاد يكون **نسخة مكرَّرة** من `_ReviewItem` بـ`chalet_detail_screen.dart` (نفس البنية: صورة رمزية بحرف أول، اسم، نجوم، تعليق، تاريخ) — بما فيها نفس إصلاح حماية `.characters.first` المُطبَّق بشكل منفصل ومستقل بكلا الملفين. فرصة إعادة استخدام (widget مشترك واحد بدل نسختين شبه متطابقتين تحتاجان نفس الإصلاح مرتين لو ظهرت مشكلة جديدة مستقبلاً).
  - 🟡 **بسيطة (سطر 1002-1008 مقابل 1030):** تناقض بسيط بمعالجة `userName`: حرف الصورة الرمزية يتحقق من `trim().isNotEmpty` (يعامل نصاً بمسافات فقط كأنه فارغ)، لكن نص الاسم المعروض بجانبه (سطر 1030) يستخدم `?? 'مستخدم'` البسيط (لا يلتقط نصاً بمسافات فقط، فقط `null` الفعلي) — حالة حدّية نادرة جداً (اسم بمسافات فقط بقاعدة البيانات) وتأثيرها بصري بحت.

- **اقتراح الإصلاح:**
  - تبسيط معالجة الخطأ بـ`_submit` لتفادي `_` المربكة:
    ```dart
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final msg = e.toString();
        ...
      }
    }
    ```
  - استخراج widget مشترك واحد لعرض "بطاقة تقييم" (صورة رمزية + اسم + نجوم + تعليق + تاريخ) تحت `presentation/widgets/common/`، يستخدمه كل من هذا القسم و`chalet_detail_screen.dart` بدل نسختين منفصلتين.
