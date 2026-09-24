### lib/presentation/screens/owner/owner_calendar_widgets.dart (1080 سطر)

- **الوظيفة:** كل عناصر واجهة تقويم المالك المرئية (Widgets نقية بلا حالة/كتابة خاصة بها): رسم خلايا اليوم المخصَّص (`CustomPainter`)، مفتاح الألوان (`CalendarLegend`)، لوحة تفاصيل اليوم (`OwnerDayPanel`)، وشريط وضع تحديد الأيام (`RangeActionBar`).

- **الشرح التفصيلي:**
  - **`CalendarPalette`/`_CellPainter`:** نظام ألوان **لا يعتمد على اللون وحده** — تعليق صريح بالكود: كل حالة لها لون + نمط رسم مختلف (ممتلئ/متقطع/مخطَّط) + أيقونة معاً (ممتلئ+علامة صح = مؤكد، متقطع = معلّق، مخطَّط بخطوط = محجوب). تعليق إضافي يوثِّق ضبط `manualFill` يدوياً ليصل تباينه مع النص الأبيض لنسبة 4.5:1 (معيار WCAG AA) — **وعي حقيقي وموثَّق بإمكانية الوصول للألوان**، نادر جداً ببقية الملفات.
  - `_CellPainter.paint`: يرسم خلفية الخلية مع تراكب 0.6 بكسل عند الأطراف المتصلة (لتفادي خيوط رفيعة بين خلايا شريط حجز متجاور)، تخطيط قطري للمحجوب، حد متقطع للمعلّق، حد رملي رفيع للمتاح، وحلقة اختيار/اليوم فوق الكل.
  - **`CalendarDayCell`:** يستخدم `MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2)` (سطر 214) **— تحديد صريح لأقصى معامل تكبير نص داخل خلية اليوم**، يمنع بنيوياً مشكلة تجاوز المحتوى (Overflow) عند حجم خط كبير لإمكانية الوصول — **معالجة استباقية دقيقة بالضبط لفئة الخطر التي رُصدت كاحتمال بملفات أخرى** (مثل بطاقات [owner_bookings_screen.dart](owner_bookings_screen.md)).
  - **`OwnerDayPanel`:** لوحة "غبية" بالكامل (Dumb Component) — كل الأفعال عبر `VoidCallback`/`ValueChanged` تُمرَّر من [owner_calendar_screen.dart](owner_calendar_screen.md)، لا تنفّذ أي كتابة بنفسها (موثَّق بتعليق صريح). تُبنى حالتها (`_pastBody`/`_bookedBody`/`_blockedBody`/`_emptyBody`) حسب `day.kind`/`day.isPast`/`booking.status`/`booking.isManual`.
    - تُظهر زر "تأكيد/رفض" فقط لو `pending && !isManual` (صحيح: الحجز اليدوي لا يحتاج تأكيداً لأن المالك أدخله بنفسه).
    - **زر "حجز يدوي" بحالة "محجوب" معطَّل عمداً (`onTap: null`) مع ملاحظة نصية توضيحية صريحة "أزل الحجب أولاً..."** — نقيض مباشر وإيجابي لأزرار معطَّلة بلا تفسير وُجدت بملفات أخرى (`payment_success_screen.dart`، دفعة 8).
  - **`_bookingCard`:** يعرض اسم/هاتف الضيف (عبر `bookingGuestName`/`bookingGuestPhone` المُعرَّفتين بهذا الملف، تُفرِّقان بين ضيف يدوي/تطبيق باستخدام `manual_booking.dart`)، مدى التاريخ + عدد الليالي (`nightsLabel`)، رقم الليلة الحالية ضمن الإقامة (`day.nightNumber`، من [owner_calendar_logic.dart](owner_calendar_logic.md) — آمن من DST كما تحقَّقتُ سابقاً)، عدد الضيوف، السعر الإجمالي، والملاحظات. **زر اتصال مباشر (`launchUrl(Uri(scheme:'tel', path: phone))`)** لطلب رقم الضيف.
  - **`RangeActionBar`:** يبني نص العنوان/التفاصيل/زر التأكيد حسب حالة `start`/`end`/`action`/`blockPlan`/`unblockPlan` — يعرض بوضوح للمالك عدد الأيام التي ستُحجب فعلياً وعدد ما سيُتخطّى ولماذا (حجز موجود/محجوب أصلاً/غير محجوب) **قبل** الضغط على تأكيد — شفافية جيدة قبل إجراء يؤثر على عدة أيام دفعة واحدة.

- **الاعتماديات:** `app_colors.dart`, `currency_formatter.dart`, `manual_booking.dart`, `models.dart`, `pricing_service.dart`, `manual_booking_actions.dart` (`canCancelManualBooking`), `owner_calendar_data_source.dart`, `owner_calendar_logic.dart`, وحزمة `url_launcher`. **من يستخدمه:** [owner_calendar_screen.dart](owner_calendar_screen.md) (`CalendarDayCell`, `CalendarLegend`, `OwnerDayPanel`, `RangeActionBar`, `bookingGuestName`).

- **التعامل مع Supabase:** لا يوجد إطلاقاً — واجهة عرض نقية بالكامل، كل القراءة/الكتابة تمرّ عبر الشاشة الأب.

- **نقاط القوة:**
  - **ثاني أقوى دليل بالمشروع (بعد owner_calendar_screen.dart) على وعي حقيقي بإمكانية الوصول:** عدم الاعتماد على اللون وحده، فحص تباين WCAG موثَّق بالكود، وتحديد صريح لأقصى تكبير نص بخلية التقويم.
  - فصل تام بين العرض (Widgets غبية) والمنطق/الحالة (بالشاشة الأب) — بنية مثالية لإعادة الاستخدام والاختبار.
  - أزرار معطَّلة **مع تفسير نصي واضح** بدل تركها بلا سياق — نمط UX جيد يستحق التعميم.
  - `RangeActionBar` يعرض شفافية كاملة (عدد الأيام المتأثرة والمتخطاة وسببها) قبل تنفيذ إجراء جماعي.
  - استخدام `nightNumber`/`nightsLabel` الآمنين من DST والصحيحين نحوياً (موروثين من owner_calendar_logic.dart) بدل حسابات محلية جديدة.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 848-852) — `catch (_) {}` صامت تماماً عند فشل زر الاتصال بالضيف:**
    ```dart
    onPressed: () async {
      try {
        await launchUrl(Uri(scheme: 'tel', path: phone));
      } catch (_) {}
    },
    ```
    لا رسالة خطأ للمالك إن تعذّر فتح تطبيق الاتصال (جهاز بلا خدمة هاتف: تابلت/محاكي/نسخة ويب)، ولا حتى فحص القيمة المُرجَعة من `launchUrl` (وهي `bool` تُشير صراحة لنجاح/فشل الفتح، وتُتجاهَل هنا بالكامل حتى بدون استثناء). من منظور المالك: يضغط زر الاتصال ولا يحدث شيء ظاهرياً بلا أي تفسير — نفس فئة "try/catch يبتلع الخطأ بصمت" التي طلب المستخدم تتبعها صراحة، وإن كان أثرها هنا محدوداً (ميزة مساعدة فقط، لا بيانات حجز/مال تتأثر).
  - 🟡 **بسيطة:** `.withOpacity()` مهجورة بعدة مواضع (أسطر 256, 920, 1005) — نفس الملاحظة العامة المتكررة.
  - لا مخاطر منطقية أو null-safety حقيقية أخرى: تحقَّقتُ تحديداً من `_lo`/`_hi` وپ`blockPlan!`/`unblockPlan!` بـ`RangeActionBar` (يبدو للوهلة الأولى استخداماً خطراً لـ`!`) وهي **آمنة فعلياً** لأن بنية `build()` تضمن عدم الوصول لها إلا بعد التحقق من عدم إعدام `start`/`end`/الخطة المقابلة بنفس الشرط.

- **اقتراح الإصلاح:**
  - فحص القيمة المُرجَعة من `launchUrl` وعرض `SnackBar` قصير ("تعذر فتح تطبيق الاتصال") عند `false` أو عند التقاط استثناء، بدل الصمت الكامل. مثال:
    ```dart
    onPressed: () async {
      final ok = await launchUrl(Uri(scheme: 'tel', path: phone))
          .catchError((_) => false);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
      }
    },
    ```
