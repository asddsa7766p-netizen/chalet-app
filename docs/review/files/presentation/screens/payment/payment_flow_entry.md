### lib/presentation/screens/payment/payment_flow_entry.dart

- **⚠️ سياق مهم لكل ملفات الدفع (هذا الملف وبقية دفعة "payment"):** كامل مسار الدفع الإلكتروني **معطَّل فعلياً حالياً** — [app_router.dart](../../../core/router/app_router.md) (`onlinePaymentEnabled = false`) و[booking_screen.dart](../booking/booking_screen.md) (علم محلي مطابق) يمنعان الوصول لمسار `/payment` كلياً في الاستخدام العادي للتطبيق. المراجعة أدناه توثّق الكود كما هو (كما طُلب مراجعة كل ملف)، مع الإشارة الواضحة أن **خطورة أي مشكلة هنا مؤجَّلة عملياً** لحين تفعيل الدفع الإلكتروني فعلياً — باستثناء أي مشكلة **بنيوية** ستُعاد إنتاجها فور التفعيل دون تعديل، وهذه تحديداً تستحق الانتباه الآن قبل ذلك اليوم.

- **الوظيفة:** نقطة الدخول الوحيدة لمسار الدفع بالكامل — تبني `BookingPaymentDetails` من `ChaletModel` + تواريخ + عدد ضيوف، وتُعيد `PaymentReviewScreen` كأول شاشة بالتدفق.

- **الشرح التفصيلي:**
  ```dart
  final nights = checkOut.difference(checkIn).inDays;
  final subtotal = chalet.pricePerNight * nights;
  final taxAndFees = (subtotal + extrasTotal) * (taxAndFeesPercent / 100);
  final total = subtotal + extrasTotal + taxAndFees;
  ```
  يحسب **محلياً بالكامل** عدد الليالي والسعر الإجمالي من `chalet.pricePerNight` (السعر الأساسي الثابت فقط) — **بدون أي استدعاء لسعر السيرفر** (`calculate_chalet_stay_price` RPC، ولا حتى `chalet_weekday_prices`/`chalet_date_prices`). `taxAndFeesPercent` افتراضي = **5%** — نسبة **ثالثة** مستقلة تماماً عن `kServiceFeePercentage` (3%) و`kPlatformCommissionPercentage` (8%) بـ[pricing_constants.dart](../../../core/constants/pricing_constants.md).

- **الاعتماديات:** `chalet_model.dart`, `booking_payment_details.dart`, `payment_review_screen.dart`. **من يستخدمه:** [app_router.dart](../../../core/router/app_router.md) حصراً (مسار `/payment`، معطَّل حالياً).

- **التعامل مع Supabase:** لا يوجد إطلاقاً — حساب محلي بحت، لا RPC، لا قراءة/كتابة.

- **نقاط القوة:** دالة صغيرة وواضحة الغرض، توقيعها يسهّل فهم كل مدخلاتها.

- **الأخطاء والمخاطر المحتملة:**
  - 🟠 **متوسطة (رغم عدم الوصول الحالي) — إعادة إنتاج فعلية لمشكلة تسعير مُصلَحة عمداً بمكان آخر من نفس المشروع لو فُعِّل هذا المسار كما هو:** [booking_screen.dart](../booking/booking_screen.md) يحتوي قراراً موثّقاً بعناية فائقة (تحقُّق فعلي بتشغيل التطبيق ومقارنة بقاعدة البيانات) بإزالة أي عرض لعمولة/رسوم إضافية فوق السعر الأساسي، لأن ذلك كان يُظهر للعميل مجموعاً أكبر بـ6% مما يُحفظ فعلياً. **هذا الملف بالذات يطبّق بالضبط نفس النمط الذي أُزيل هناك**: يحسب `taxAndFees` بنسبة 5% إضافية محلياً، ويعرضها كجزء من "الإجمالي الكلي" بشاشات المراجعة/الدفع اللاحقة — رقم لا علاقة له بأي RPC سيرفر، ولا بأي من نسبتي `pricing_constants.dart`. لو أُعيد تفعيل مسار الدفع الإلكتروني يوماً بالاعتماد على هذا الكود كما هو، **سيُعرض للعميل سعر مختلف عن السعر الأساسي الفعلي**، بالضبط نوع الخلل الذي طلب المستخدم التحقق من غيابه، وبالضبط ما أثبت الفريق نفسه فعلياً أنه خطأ بملف آخر بنفس المشروع.
  - 🟡 **بسيطة (سطر 16) — نمط حساب ليالٍ محلي بدل الاستدعاء الآمن من `BookingModel.nightsCount` أو تحويل UTC:** `checkOut.difference(checkIn).inDays` — نفس نمط عطل التوقيت الصيفي الموثَّق والمُصلَح بـ[models.dart](../../../data/models/models.md) و[booking_screen.dart](../booking/booking_screen.md) (كلاهما لم يُصلَحا بهذا الملف أيضاً بحالة الأخير، وهذا ثالث موضع يستخدم نفس النمط غير الآمن).

- **اقتراح الإصلاح:**
  - قبل أي إعادة تفعيل مستقبلية لمسار الدفع: استبدال الحساب المحلي بالكامل باستدعاء `BookingService.calculateBookingPrice`/`ChaletPricingService.calculateStayPrice` (نفس المصدر المعتمد فعلياً بـbooking_screen.dart)، وإزالة `taxAndFeesPercent`/عرض أي رسوم إضافية غير مطابقة لما سيُحفظ فعلياً بقاعدة البيانات — بنفس القرار الموثَّق هناك بالضبط.
  - توحيد حساب الليالي مع النمط الآمن (UTC) المستخدم/المُصلَح بالملفين الآخرين.
