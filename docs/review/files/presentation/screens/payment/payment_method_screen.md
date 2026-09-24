### lib/presentation/screens/payment/payment_method_screen.dart

- **الوظيفة:** شاشة (2) بتدفق الدفع — اختيار طريقة الدفع (بطاقة ائتمانية/مدى أو محفظة إلكترونية)، ثم الانتقال للشاشة المناسبة. (راجع [ملاحظة السياق العامة](payment_flow_entry.md)).

- **الشرح التفصيلي:** `_continue()`: لو بطاقة → `CardDetailsScreen`؛ لو محفظة → مباشرة `PaymentProcessingScreen` (بدون شاشة إدخال بيانات إضافية، منطقي لمحفظة إلكترونية). يعرض أيضاً قسم "مزايا الحجز مع مكان" (3 نقاط: حجز آمن، إلغاء مجاني، دعم متواصل).

- **الاعتماديات:** `booking_payment_details.dart`, `payment_theme.dart`, `payment_widgets.dart`, `card_details_screen.dart`, `payment_processing_screen.dart`. **من يستخدمه:** `payment_review_screen.dart`، و[payment_failed_screen.dart](payment_failed_screen.md) (زر "تغيير طريقة الدفع").

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:** استخدام بدائل نصية بسيطة لشعارات Visa/Mastercard/mada بدل الشعارات الرسمية (تعليق يوضّح أن السبب تفادي مشاكل حقوق الملكية) — وعي قانوني جيد بدل استخدام شعارات رسمية بلا ترخيص.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 109-124) — تكرار نسخ-لصق واضح: قسم "مزايا الحجز مع مكان" مكرَّر حرفياً مرتين متتاليتين:**
    ```dart
    const _BenefitRow(icon: Icons.verified_user_outlined, text: 'حجز آمن 100%'),
    const _BenefitRow(icon: Icons.event_available_outlined, text: 'إلغاء مجاني وفق سياسة المكان'),
    const _BenefitRow(icon: Icons.headset_mic_outlined, text: 'دعم متواصل على مدار الساعة'),
    const _BenefitRow(icon: Icons.verified_user_outlined, text: 'حجز آمن 100%'),          // ← نفس الثلاثة مكرَّرة
    const _BenefitRow(icon: Icons.event_available_outlined, text: 'إلغاء مجاني وفق سياسة المكان'),
    const _BenefitRow(icon: Icons.headset_mic_outlined, text: 'دعم متواصل على مدار الساعة'),
    ```
    يعرض المستخدم نفس الثلاث نقاط مرتين متتاليتين (6 أسطر بدل 3) — خطأ نسخ-لصق واضح وليس مقصوداً بالتصميم.

- **اقتراح الإصلاح:** حذف مجموعة `_BenefitRow` المكرَّرة (الإبقاء على نسخة واحدة فقط من الثلاث نقاط).
