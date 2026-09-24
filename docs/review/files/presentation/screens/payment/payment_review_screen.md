### lib/presentation/screens/payment/payment_review_screen.dart

- **الوظيفة:** شاشة (1) بتدفق الدفع — مراجعة تفاصيل الحجز وملخّص السعر (سعر الليلة، عدد الليالي، الإضافات، الضريبة/الرسوم، الإجمالي) قبل اختيار طريقة الدفع. (راجع [ملاحظة السياق العامة](payment_flow_entry.md) — المسار بأكمله معطَّل حالياً).

- **الشرح التفصيلي:** `StatelessWidget` بحت، يعرض حقول `BookingPaymentDetails` المُمرَّرة جاهزة (لا حساب هنا، الحساب تم بـ[payment_flow_entry.dart](payment_flow_entry.md)). `_formatCurrency`/`_formatDatesRange` دوال تنسيق محلية (تستخدم `intl` بلوكيل `'ar'` لأسماء الأشهر، و`'en_US'` للأرقام — نفس نمط عرض أرقام غربية داخل سياق عربي المستخدم بـ[currency_formatter.dart](../../../core/utils/currency_formatter.md) المركزي، لكن **مُعاد تطبيقه هنا محلياً ومستقلاً** بدل استخدام `AppCurrency.formatPrice` الموجودة أصلاً).

- **الاعتماديات:** `booking_payment_details.dart`, `payment_theme.dart`, `payment_widgets.dart`, `payment_method_screen.dart`. **من يستخدمه:** `payment_flow_entry.dart` (الشاشة الأولى بالتدفق).

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:** عرض واضح ومنظّم لتفصيل السعر، مع طمأنة صريحة ("لن يتم خصم أي مبلغ قبل تأكيد الدفع") وتوضيح سياسة خصوصية بيانات الدفع.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 8، 30) — استيراد مزدوج غريب لنفس الحزمة:** `import 'package:flutter/material.dart' as flutter_material;` **بالإضافة** للاستيراد العادي غير المُسمّى بسطر 1 (`import 'package:flutter/material.dart';`) — يُستخدم فقط لكتابة `flutter_material.TextDirection.rtl` بدل `TextDirection.rtl` المتاحة مباشرة أصلاً من الاستيراد الأول. لا يسبب أي خطأ (يعمل بشكل صحيح) لكنه تكرار غير مبرَّر — يظهر بنفس النمط أيضاً بـ[card_details_screen.dart](card_details_screen.md) و[payment_success_screen.dart](payment_success_screen.md) (3 ملفات من أصل 7، بلا تفسير واضح لماذا هذه الثلاثة تحديداً).
  - 🟡 **بسيطة:** يعرض تفصيل "الضريبة والرسوم" المحسوب محلياً بـ`payment_flow_entry.dart` — راجع الملاحظة الأشمل بمراجعة ذلك الملف عن تناقضها مع القرار الموثَّق بـ[booking_screen.dart](../booking/booking_screen.md).
  - 🟡 **بسيطة:** تنسيق العملة يُعاد تطبيقه محلياً (`NumberFormat('#,##0', 'en_US')`) بدل استخدام `AppCurrency.formatPrice` المركزية — تكرار منطق بسيط لكنه غير موحَّد.

- **اقتراح الإصلاح:**
  - إزالة الاستيراد المزدوج غير الضروري لـ`flutter/material.dart`.
  - استبدال `_formatCurrency` المحلية باستخدام `AppCurrency.formatPrice` من [currency_formatter.dart](../../../core/utils/currency_formatter.md) لتوحيد منطق تنسيق السعر بمكان واحد فقط بالمشروع.
