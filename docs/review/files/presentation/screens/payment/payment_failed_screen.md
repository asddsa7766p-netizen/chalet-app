### lib/presentation/screens/payment/payment_failed_screen.dart

- **الوظيفة:** شاشة (6) بتدفق الدفع — فشل معالجة الدفع، مع خيارين للتعافي (إعادة محاولة بنفس البيانات، أو تغيير طريقة الدفع) وزر مساعدة. (راجع [ملاحظة السياق العامة](payment_flow_entry.md)).

- **الشرح التفصيلي:** يعرض `reasonAr` (سبب الفشل، من `PaymentResult.failureReasonAr` أو رسالة افتراضية). زرّا التعافي يستخدمان `Navigator.pushReplacement` (يحافظان على نظافة سجل التنقّل، بنفس جودة [payment_processing_screen.dart](payment_processing_screen.md)) ويمرّران `card`/`walletType`/`gateway` الأصلية للمحاولة مجدداً بنفس البيانات دون طلبها من المستخدم مرة أخرى — تجربة مستخدم جيدة. زر "تحتاج مساعدة؟" بـ`onPressed` فارغ (`// TODO: اربطها بقناة الدعم الفعلية`).

- **الاعتماديات:** `booking_payment_details.dart`, `payment_gateway.dart`, `payment_theme.dart`, `payment_widgets.dart`, `payment_method_screen.dart`, `payment_processing_screen.dart`. **من يستخدمه:** `payment_processing_screen.dart` (عند فشل الدفع).

- **التعامل مع Supabase:** لا يوجد.

- **نقاط القوة:** إعادة المحاولة تحافظ على بيانات البطاقة/المحفظة الأصلية (لا تطلب من المستخدم إعادة إدخالها)، مسارا تعافٍ واضحان ومنطقيان لحالة فشل دفع حقيقية.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة (سطر 129-132) — زر "تحتاج مساعدة؟" بلا وظيفة:** يتّسق مع نمط أوسع بالمشروع (بطاقات تواصل [help_support_screen.dart](../settings/help_support_screen.md) أيضاً بلا `onTap`، رابط الشروط بـ[register_screen.dart](../auth/register_screen.md) أيضاً فارغ) — نقاط تواصل/مساعدة متعددة عبر التطبيق تبدو تفاعلية لكنها غير موصولة فعلياً بأي قناة دعم حقيقية. يستحق معالجة موحّدة (راجع التوصية المجمَّعة بـ[99_summary.md](../../../99_summary.md)).

- **اقتراح الإصلاح:** ربط زر "تحتاج مساعدة؟" بنفس قناة الدعم التي سيُتَّفق عليها لبقية نقاط التواصل بالتطبيق (راجع توصيات [help_support_screen.md](../settings/help_support_screen.md)).
