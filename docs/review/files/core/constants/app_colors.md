### lib/core/constants/app_colors.dart

- **الوظيفة:** يعرّف class ثابت `AppColors` (constructor خاص `AppColors._()` لمنع الإنشاء) يجمّع كل ألوان هوية التطبيق (الأساسي/الثانوي/النصوص/الحدود/الحالات) في مكان واحد، بدل تكرار قيم Hex بكل شاشة.

- **الشرح التفصيلي:**
  - كل الأعضاء `static const Color`، أي ثوابت زمن التصريف (compile-time constants) بدون أي منطق تنفيذي — لا توجد دوال أو async code بالملف.
  - مجموعات منطقية: خلفيات (`background`, `scaffold`, `card`)، اللون الأساسي وتدرجاته (`primary`, `primaryDark`, `primaryMedium`, `primaryLight`, `primaryPale`)، الذهبي/accent (`accent`, `accentLight`, `accentDark`, `accentMuted`)، نصوص (`textPrimary`, `textSecondary`, `textMuted`, `textHint`)، عناصر UI محايدة (`white`, `surface`, `cream`, `charcoal`)، حدود/ظلال (`sand`, `border`, `divider`, `shadow`, `overlay`)، ألوان دلالية (`success`, `error`, `warning`, `info`)، وألوان حالة الحجز (`pending`, `confirmed`, `cancelled`, `completed`) وهي فعلياً alias لأربعة من الألوان الدلالية أعلاه (`pending = warning`, `confirmed = success`, `cancelled = error`, `completed = info`).
  - تعليقات الكود توثّق تاريخ تعديلات واعية: تصحيح `primaryLight` (كان يساوي `accentLight` بالغلط)، وتوحيد `accentMuted` بدل تكراره بملفات AuthColors/PaymentColors منفصلة.

- **الاعتماديات:**
  - يستورد `package:flutter/material.dart` فقط (لتعريف `Color`).
  - **من يستخدمه:** عملياً كل شاشة/ويدجت تقريباً في `presentation/` (سيُؤكَّد تراكمياً أثناء بقية المراجعة)، بالإضافة إلى [app_theme.dart](../theme/app_theme.md) الذي يبني `ThemeData` كاملة اعتماداً عليه.

- **التعامل مع Supabase:** لا يوجد إطلاقاً — ملف عرض/تصميم بحت بدون أي وصول لبيانات.

- **نقاط القوة:**
  - مصدر حقيقة واحد (single source of truth) لكل ألوان التطبيق، يمنع الانحراف اللوني بين الشاشات.
  - تعليقات عربية تشرح *لماذا* تغيّرت بعض القيم (خصوصاً إصلاح `primaryLight`) بدل تركها بدون سياق — نمط جيد للصيانة المستقبلية.
  - استخدام `const` بكل مكان يقلل إعادة البناء (rebuilds) غير الضرورية لأن قيم الألوان ثابتة حقيقة عند التصريف.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة — لا يوجد نظام ألوان مخصص للوضع الداكن هنا:** كل القيم مصمَّمة لوضع فاتح (خلفية كريمية فاتحة، نص غامق). لا يوجد أي `AppColors.darkX` مكافئ. الوضع الداكن الفعلي (`app_theme.dart`) يعيد استخدام `AppColors.charcoal` لعدة أدوار مختلفة (خلفية/سطح/بطاقة) بدل تدرّج ألوان مخصص — التفصيل والأثر موثّق في مراجعة [app_theme.dart](../theme/app_theme.md).
  - 🟡 **بسيطة — لا اختبار تباين (contrast) موثّق:** مثلاً `textMuted (#A6A092)` على `background (#FBF8F3)` قد يعطي نسبة تباين منخفضة نسبياً لنص صغير (WCAG AA يتطلب 4.5:1 للنص العادي). لم أقس النسبة فعلياً بأداة — هذه ملاحظة تحتاج تحقق بصري/أداة تباين حقيقية بدل افتراض، أذكرها فقط كنقطة يجدر التحقق منها بصرياً على الشاشات الفعلية.

- **اقتراح الإصلاح:**
  - لا حاجة لتعديل بنيوي؛ إن أراد الفريق دعم وضع داكن حقيقي لاحقاً، الأنسب إضافة class موازٍ (`AppColorsDark`) أو تحويل القيم المستخدمة بالثيم إلى دوال تختار حسب `Brightness` بدل إعادة استخدام `charcoal` لعدة أدوار — تفاصيل مقترحة في ملف [app_theme.dart](../theme/app_theme.md).
