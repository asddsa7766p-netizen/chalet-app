### lib/data/models/booking_payment_details.dart

- **الوظيفة:** ثلاثة نماذج بيانات لتدفق الدفع (المعطَّل حالياً — راجع [app_router.dart](../../core/router/app_router.md)): `BookingPaymentDetails` (تفاصيل الحجز المطلوب دفعه، تنتقل بين شاشات الدفع الستة)، `CardPaymentInput` (بيانات بطاقة مُدخَلة من المستخدم)، و`PaymentResult` (نتيجة عملية دفع).

- **الشرح التفصيلي:**
  - `BookingPaymentDetails`: حقول عرض بحتة (bookingId, chaletName/Location/ImageUrl, checkIn/checkOut, nightsCount, guestsCount, pricePerNight, subtotal, extrasTotal, taxAndFeesPercent, totalAmount, userEmail?) — **كلها قيم تُمرَّر جاهزة من المستدعي**، لا حساب داخلي سوى getter واحد: `taxAndFeesAmount = totalAmount - subtotal - extrasTotal`. تعليق الترويسة يوضّح أنه يجب تعبئته من "شاشة مراجعة الحجز" قبل الوصول لأول شاشة بمسار الدفع.
  - `CardPaymentInput`: `cardNumber, cardHolderName, expiryMonthYear (MM/YY), cvv, saveCardForLater` — تخزين نصي خام بالذاكرة فقط (كائن Dart عادي، لا تشفير/تعتيم بهذا النموذج نفسه).
  - `PaymentMethodType` (enum): `cardVisaMastercardMada, paypal`.
  - `PaymentResult`: نتيجة بنمط named constructors (`.success(transactionId)` / `.failure(failureReasonAr)`) — تصميم واضح يمنع حالة غير منطقية (نجاح بدون معرّف عملية، أو فشل بدون سبب).

- **الاعتماديات:** لا يستورد شيئاً. **من يستخدمه:** [payment_gateway.dart](../services/payment_gateway.md) (توقيع `PaymentGateway.payWithCard`/`payWithWallet`)، وعلى الأرجح كل شاشات `presentation/screens/payment/*` — يُؤكَّد عند مراجعتها بالدفعة القادمة.

- **التعامل مع Supabase:** لا اتصال مباشر — نماذج عرض/نقل بيانات بحتة، غير مرتبطة بأي جدول Supabase مباشرة (لا `fromJson`/`toJson` هنا أصلاً، فقط بناء يدوي بالذاكرة).

- **نقاط القوة:**
  - `PaymentResult` بنمط named-constructor يمنع حالات بيانات متناقضة (success+failureReason معاً، أو failure بدون سبب) على مستوى النوع نفسه — تصميم دفاعي جيد.
  - فصل واضح بين "تفاصيل الحجز المطلوب دفعه" و"بيانات البطاقة المُدخَلة" و"نتيجة الدفع" — ثلاث مسؤوليات منفصلة بوضوح.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (ملاحظة استباقية لمستقبل الميزة، وليست مشكلة نشطة الآن):** `CardPaymentInput` يخزّن `cardNumber`/`cvv` كنص خام بالذاكرة بلا أي تعتيم/تشفير. **لا خطر فعلي حالياً** لأن `AppRouter.onlinePaymentEnabled = false` يمنع الوصول الكامل لمسار الدفع، والتنفيذ الوحيد المتوفر (`MockPaymentGateway`) لا يرسل هذه البيانات لأي مكان فعلي. **يستحق الانتباه عند ربط بوابة دفع حقيقية مستقبلاً:** التأكد أن هذا الكائن لا يُسجَّل (log) بالخطأ (مثلاً ضمن Sentry breadcrumbs أو `debugPrint`) في أي نقطة بمسار الدفع الحقيقي القادم، وأن بيانات البطاقة تُرسَل فقط مباشرة لـ SDK بوابة الدفع (PCI-compliant) لا لأي طبقة وسيطة بالتطبيق نفسه أو Supabase.
  - لا مشاكل null-safety/Supabase/dispose تُذكر بهذا الملف تحديداً (نماذج بيانات بسيطة بلا منطق معقّد).

- **اقتراح الإصلاح:** لا شيء عاجل الآن. عند تفعيل بوابة دفع حقيقية مستقبلاً: التأكد من عدم تسجيل `CardPaymentInput` بأي log/تقرير أعطال، وربما إضافة `toString()` مخصص يُخفي `cardNumber`/`cvv` احتياطاً (دفاع إضافي ضد تسريب عرضي لو طُبع الكائن بالخطأ أثناء تصحيح الأخطاء).
