### lib/data/services/payment_gateway.dart

- **الوظيفة:** واجهة مجرّدة (`abstract class PaymentGateway`) لأي بوابة دفع مستقبلية، وتنفيذ وهمي حالي (`MockPaymentGateway`) يُستخدَم فقط لتجربة شاشات الدفع الستة أثناء التطوير.

- **الشرح التفصيلي:**
  - `PaymentGateway`: دالتان مجرّدتان `payWithCard`/`payWithWallet`، كلاهما تُرجع `Future<PaymentResult>`. تعليق أعلى الملف يشرح الغرض بوضوح: تنفيذ حقيقي لاحقاً (Jawwal Pay/Ooredoo Money/Stripe/PayTabs) يطبّق نفس الواجهة "بدون ما تلمس أي شاشة UI" — فصل جيد بين العقد (interface) والتنفيذ.
  - `MockPaymentGateway`: يقبل `forceFailure` (لتجربة مسار الفشل عمداً) و`simulatedDelay` (افتراضياً ثانيتان). كل من `payWithCard`/`payWithWallet` تنتظر التأخير المحاكى، ثم تُرجع إما `PaymentResult.failure('...')` (برسالة عربية جاهزة) أو `PaymentResult.success('MOCK-<رقم عشوائي>')`.
  - تحذير صريح جداً بالتعليق: "⚠️ لا تستخدم هذا التنفيذ بالإنتاج — استبدله بتنفيذ حقيقي لما تحدد البوابة".

- **الاعتماديات:** يستورد `data/models/booking_payment_details.dart` (`BookingPaymentDetails`, `CardPaymentInput`, `PaymentMethodType`, `PaymentResult`). **من يستخدمه:** على الأرجح [payment_flow_entry.dart](../../presentation/screens/payment/payment_flow_entry.md) و/أو شاشات الدفع الأخرى — يُؤكَّد عند مراجعتها (دفعة 8).

- **التعامل مع Supabase:** **لا يوجد إطلاقاً** — `MockPaymentGateway` لا يكتب أي شيء لقاعدة البيانات (لا ينشئ حجزاً، لا يسجّل دفعة) — يُحاكي فقط نتيجة الدفع بالذاكرة. هذا متّسق تماماً مع ما وثّقه [app_router.dart](../../core/router/app_router.md): "الدفع الإلكتروني معطّل مؤقتاً... MockPaymentGateway الحالي لا ينشئ حجزاً فعلياً بقاعدة البيانات" و`onlinePaymentEnabled = false` يمنع الوصول لمسار `/payment` كلياً حالياً.

- **نقاط القوة:**
  - تصميم بنمط Strategy/Interface نظيف يسمح بإضافة بوابة دفع حقيقية لاحقاً دون تعديل شاشات الواجهة.
  - تحذير صريح لا لبس فيه ضد استخدام هذا التنفيذ بالإنتاج، متّسق مع قرار تعطيل مسار الدفع بالراوتر — لا تناقض بين الملفين.
  - إمكانية محاكاة الفشل (`forceFailure`) مفيدة فعلياً لاختبار شاشة "فشل الدفع" دون الحاجة لبوابة حقيقية.

- **الأخطاء والمخاطر المحتملة:**
  - 🟡 **بسيطة — يحتاج تأكيد بدفعة الشاشات القادمة (لا خطأ مؤكَّد بهذا الملف نفسه):** بما أن أمان "عدم إتمام دفع وهمي كأنه حقيقي" يعتمد بالكامل على أن `AppRouter.onlinePaymentEnabled = false` يمنع الوصول لمسار `/payment` من أي مكان بالتطبيق — يستحق التأكد عند مراجعة شاشات الدفع (دفعة 8) أنه لا يوجد أي مسار وصول بديل (زر مباشر يفتح شاشة الدفع بدون المرور من `context.go('/payment')` عبر الراوتر، مثلاً `Navigator.push` مباشر لأحد شاشات `payment/*`) يتحايل على هذا القفل.
  - لا مخاطر أمنية/null-safety/dispose تُذكر بهذا الملف تحديداً (لا Supabase، لا Controllers، لا async معقّد).

- **اقتراح الإصلاح:** لا شيء مطلوب بهذا الملف حالياً؛ التأكيد المطلوب هو على مستوى الشاشات المستهلكة (دفعة 8) لضمان عدم وجود مسار وصول يتجاوز `onlinePaymentEnabled`.
