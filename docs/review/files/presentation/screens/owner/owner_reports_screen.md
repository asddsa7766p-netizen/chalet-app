### lib/presentation/screens/owner/owner_reports_screen.dart (251 سطر)

- **الوظيفة:** شاشة تقارير مختصرة للمالك — اختيار مدى زمني (اليوم/آخر 7 أيام/الشهر الماضي...)، 4 كروت ملخَّصة (إيرادات، إجمالي حجوزات، ملغاة/مرفوضة، متوسط يومي)، وتفصيل الإيرادات حسب كل شاليه مع شريط نسبة مئوية.

- **الشرح التفصيلي:**
  - `_load()`: يجلب `OwnerDashboardStats` عبر `DashboardService.getOwnerDashboardStats(range: _range)` حسب المدى المختار حالياً.
  - `_onRangeChanged(r)`: يضبط `_range = r` ثم يستدعي `_load()` مجدداً — **بلا أي حماية من نتائج متزامنة متضاربة (راجع الخطر أدناه)**.
  - `_buildSummaryCards`/`_buildChaletBreakdown`: عرض بسيط ومباشر للإحصائيات المُجمَّعة، مع شريط `LinearProgressIndicator` لنسبة كل شاليه من الإيرادات الكلية (`ratioPercent`).

- **الاعتماديات:** `app_colors.dart`, `dashboard_service.dart` (`OwnerDashboardStats`, `OwnerDashboardRange`). **من يستخدمه:** [owner_dashboard_screen.dart](owner_dashboard_screen.md) (زر "عرض التقارير")، عبر `context.push('/owner-reports')`.

- **التعامل مع Supabase:** عبر `DashboardService.getOwnerDashboardStats` فقط — **يرث نفس الملاحظة المُسجَّلة سابقاً بمراجعة [dashboard_service.dart](../../../data/services/dashboard_service.md) (دفعة 2): الإحصائيات تُحسَب محلياً بجمع كل الصفوف بدل `SUM` على السيرفر** — لا مخاطرة جديدة هنا، فقط استهلاك إضافي لنفس النمط.

- **نقاط القوة:**
  - شاشة مركَّزة وبسيطة، حالات تحميل/خطأ/فارغة مغطاة بالكامل مع زر إعادة محاولة.
  - `RefreshIndicator` لإعادة تحميل يدوية.
  - عرض تفصيل الشاليهات مع شريط نسبي بصري واضح.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة إلى متوسطة (سطر 49-53) — Race Condition حقيقي عند تبديل المدى الزمني بسرعة:** `_onRangeChanged` لا يستخدم أي رمز/عداد جيل للتمييز بين الطلبات (بخلاف `_priceToken` بـ[manual_booking_sheet.dart](manual_booking_sheet.md) أو `_gen` بـ[owner_calendar_screen.dart](owner_calendar_screen.md)). سيناريو واقعي: المالك يضغط "اليوم" ثم فوراً "آخر 7 أيام" — لو استجاب طلب "اليوم" (الأقدم) بعد طلب "آخر 7 أيام" (الأحدث) بسبب تفاوت الشبكة، تُعرَض بيانات "اليوم" بينما الرقاقة المحدَّدة بصرياً تبقى "آخر 7 أيام" — تناقض حقيقي بين الفلتر الظاهر والبيانات المعروضة فعلياً. الأثر منخفض نسبياً (بيانات عرض فقط قابلة للتصحيح بإعادة الضغط/التحديث)، لكنه نفس فئة "طلبات متزامنة" التي طلب المستخدم فحصها صراحة، وموجود لها حل جاهز بنفس المشروع.
  - لا مخاطر أخرى ذات شأن: لا استخدام غير آمن لـ`!` فعلياً (محمي ببنية `build()`)، لا تسريب موارد، لا مشاكل توقيت/تاريخ (لا حسابات `DateTime.difference` هنا).

- **اقتراح الإصلاح:**
  - إضافة عداد جيل بسيط (نفس نمط `_gen`/`_priceToken`): كل استدعاء لـ`_load()` يلتقط رقماً تسلسلياً عند البدء، ويتجاهل نتيجته إن لم يعد يطابق آخر رقم عند اكتمال الطلب:
    ```dart
    int _gen = 0;
    Future<void> _load() async {
      final gen = ++_gen;
      setState(() { _loading = true; _error = null; });
      try {
        final stats = await DashboardService.instance.getOwnerDashboardStats(range: _range);
        if (!mounted || gen != _gen) return;
        setState(() { _stats = stats; _loading = false; });
      } catch (_) {
        if (!mounted || gen != _gen) return;
        setState(() { _loading = false; _error = 'تعذر تحميل التقارير'; });
      }
    }
    ```
