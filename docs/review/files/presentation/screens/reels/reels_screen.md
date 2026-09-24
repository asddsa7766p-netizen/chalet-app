### lib/presentation/screens/reels/reels_screen.dart

- **الوظيفة:** شاشة "Reels" — مقاطع فيديو قصيرة عمودية (نمط TikTok/Instagram Reels) بالتمرير الرأسي، تعرض كل واحد اسم/وصف/عدد إعجابات الشاليه المرتبط، وتنتقل لتفاصيله عند الضغط.

- **الشرح التفصيلي:**
  - `_load()`: يجلب `ReelsService.instance.fetchReels()`، ثم بعد أول إطار (`addPostFrameCallback`) يُهيّئ متحكم الفيديو الأول (`_ensureControllerForIndex(0)`) ويستدعي `_togglePlaybackForVisibleIndex()`.
  - `_ensureControllerForIndex(index)`: ينشئ `VideoPlayerController`+`ChewieController` لفهرس معيّن (لو لم يوجدا مسبقاً)، ويبدأ `unawaited(videoController.initialize())` (تحميل الفيديو بالخلفية دون انتظار).
  - **`_togglePlaybackForVisibleIndex()` (سطر 117-134):**
    ```dart
    void _togglePlaybackForVisibleIndex() {
      for (var i = 0; i < _reels.length; i++) {
        _ensureControllerForIndex(i);   // ⚠️ لكل الفهارس، وليس فقط القريبة من الحالي
      }
      final visible = _currentIndex;
      for (final entry in _videoControllers.entries) {
        if (entry.key == visible) { if (initialized) controller.play(); }
        else { controller.pause(); }
      }
    }
    ```
    يُستدعى مرة عند التحميل الأول، **ومرة أخرى مع كل تغيير صفحة** (`_onPageChanged`).
  - `dispose()`: يتخلّص من **كل** الـcontrollers المُخزَّنة بالخريطتين (`_chewieControllers`, `_videoControllers`) + `_pageController` — شامل وصحيح عند إغلاق الشاشة.
  - زر الإعجاب: عرض ثابت لـ`reel.likesCount` بأيقونة قلب **بدون أي `onTap`** — معلَّق بوضوح بالكود كـ"UI only for now; wiring requires userId + like mutation" (غير موصول بعد عمداً، وليس عطلاً مخفياً).

- **الاعتماديات:** `chewie`, `video_player`, `reel_model.dart`, `reels_service.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) (مسار `/reels`، عام/متاح للضيف) و[main_screen.dart](../home/main_screen.md) (تبويب Reels).

- **التعامل مع Supabase:** عبر `ReelsService.fetchReels()` فقط بهذا الملف (لا استدعاء مباشر لـ`toggleLike`/`isLiked` هنا رغم وجودهما بالخدمة — متّسق مع كون زر الإعجاب غير موصول بعد).

- **نقاط القوة:**
  - تنظيف موارد شامل وصحيح بـ`dispose()` لكل الـcontrollers المُنشأة، بغض النظر عن عددها.
  - صدق واضح بترك زر الإعجاب "عرضاً فقط" مع تعليق يشرح بالضبط ما ينقصه (userId + mutation) بدل زر يبدو فعّالاً ولا يعمل.
  - إيقاف تشغيل الفيديوهات غير المرئية تلقائياً (`controller.pause()` لكل ما ليس الفهرس الحالي) — منطق صحيح لتوفير موارد أثناء التصفح (رغم المشكلة الأعمق أدناه بمرحلة الإنشاء نفسها).

- **الأخطاء والمخاطر المحتملة:**
  - 🔴 **حرجة (سطر 117-120) — تهيئة كل مشغّلات الفيديو دفعة واحدة بدل الفهرس المرئي فقط (خطر استنزاف موارد/تعطّل حقيقي):** الحلقة الأولى بداخل `_togglePlaybackForVisibleIndex` تستدعي `_ensureControllerForIndex(i)` **لكل فهرس من 0 حتى `_reels.length - 1`**، وليس فقط الفهرس الحالي (أو نافذة صغيرة حوله كما يوحي تعليق سطر 72 "Initialize first reel controllers" الذي يهيّئ الفهرس 0 فقط ثم يُستدعى هذا التابع مباشرة بعده ليُهيّئ الباقي كلهم فعلياً). **الأثر العملي**: أول مرة تُفتح فيها شاشة Reels (وبكل تغيير صفحة بعدها)، يُنشأ ويبدأ تحميل شبكي فعلي (`videoController.initialize()`) لكل فيديو بالقائمة **بشكل متزامن**، بغض النظر عن كونه ظاهراً للمستخدم أم لا. بما أن [reels_service.dart](../../../data/services/reels_service.md) يسمح برفع فيديوهات حتى 100MB ولا يوجد pagination على `fetchReels()` (مُفصَّل بمراجعة تلك الخدمة)، فإن قائمة بعشرات الفيديوهات تعني عشرات مشغلات فيديو نشطة بالذاكرة ومحاولات تحميل شبكي متزامنة فعلية — استهلاك بيانات جوال ضخم غير مبرَّر، استهلاك بطارية/ذاكرة مرتفع، واحتمال حقيقي لتعطّل التطبيق (نفاد ذاكرة) على أجهزة متوسطة/ضعيفة الإمكانيات مع عدد فيديوهات لا بأس به. هذا يخالف تماماً النمط المتوقّع لواجهات "Reels" (تحميل الحالي + ربما التالي فقط، بتحميل كسول أثناء التمرير).
  - 🟡 **بسيطة:** لا يوجد أي حد أقصى/نافذة تحميل (مثل: هيّئ فقط `currentIndex-1` إلى `currentIndex+1`) — حتى الحل الأبسط لتضييق نطاق المشكلة أعلاه غير مطبَّق حالياً.

- **اقتراح الإصلاح:**
  - تعديل `_togglePlaybackForVisibleIndex` لتهيئ فقط نافذة صغيرة حول الفهرس الحالي بدل كل القائمة:
    ```dart
    void _togglePlaybackForVisibleIndex() {
      final visible = _currentIndex;
      // هيّئ الحالي + المجاور مباشرة فقط (تحميل مسبق خفيف لتجربة أسلس).
      for (final i in [visible - 1, visible, visible + 1]) {
        _ensureControllerForIndex(i);
      }
      for (final entry in _videoControllers.entries) {
        if (entry.key == visible) {
          if (entry.value.value.isInitialized) entry.value.play();
        } else {
          entry.value.pause();
        }
      }
      // اختياري: تخلّص من أي controller بعيد جداً عن الفهرس الحالي لتحرير الذاكرة
      // فور مغادرة المستخدم له (وليس فقط عند إغلاق الشاشة بأكملها).
    }
    ```
  - إضافة `.dispose()` لأي controller يخرج عن نافذة العرض (وليس فقط عند `dispose()` الشاشة كلها) لتحرير الذاكرة تدريجياً أثناء التمرير الطويل.
