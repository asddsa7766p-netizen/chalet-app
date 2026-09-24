### lib/presentation/screens/owner/owner_bottom_nav.dart

- **الوظيفة:** شريط تنقّل سفلي مشترك لكل شاشات قسم المالك (شاليهاتي، الإشعارات، إضافة شاليه، التقويم، الرئيسية).

- **الشرح التفصيلي:** تعليق الترويسة يوثّق إصلاحين: (1) هذا الشريط كان محصوراً داخل `owner_dashboard_screen.dart` فقط، فأُخرِج ليكون متاحاً بكل شاشات القسم (كما هو مستخدَم فعلياً بـ[owner_chalets_screen.dart](owner_chalets_screen.md) مثلاً)؛ (2) زر "الرسائل" كان زراً ميتاً (`onTap` فارغ، لا شاشة رسائل فعلية) واستُبدل بـ"الإشعارات" (شاشة ووظيفة حقيقيتان). التنقّل بالكامل عبر `context.go`/`context.push` (GoRouter، متّسق).

- **الاعتماديات:** `app_colors.dart`. **من يستخدمه:** [owner_chalets_screen.dart](owner_chalets_screen.md) وعلى الأرجح `owner_dashboard_screen.dart`/`owner_bookings_screen.dart`/`owner_calendar_screen.dart` (تُؤكَّد لاحقاً).

- **التعامل مع Supabase:** لا يوجد — `unreadCount` يُمرَّر جاهزاً من الشاشة الأب.

- **نقاط القوة:** إصلاح صادق لزر ميت (نمط متكرر جيد بالمشروع: استبدال أزرار وهمية بوظائف حقيقية بدل تركها)، إعادة استخدام حقيقية عبر شاشات متعددة، تنقّل متّسق عبر GoRouter بالكامل (بخلاف كثير من الملفات الأخرى).

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة:** `.withOpacity()` مهجورة (سطر 36) — نفس الملاحظة العامة بمراجعة [app_theme.dart](../../../core/theme/app_theme.md).

- **اقتراح الإصلاح:** استبدال `.withOpacity(0.06)` بـ`.withValues(alpha: 0.06)`.
