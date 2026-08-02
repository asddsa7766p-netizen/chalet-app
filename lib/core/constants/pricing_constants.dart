// ============================================
// PRICING DISPLAY CONSTANTS (DISPLAY-ONLY)
// ============================================
// هذه النسب تُستخدم للعرض فقط في الواجهة — لا تدخل في حساب السعر المخزّن
// (bookings.total_price) ولا في منطق Supabase إطلاقًا.
//
// kServiceFeePercentage: 3% رسوم خدمة تُعرض للعميل كمعلومة قبل التأكيد.
// kPlatformCommissionPercentage: 8% عمولة منصة تُعرض للمالك في بطاقة الحجز
//                                (تُخصم من قيمة الحجز لحساب المبلغ المستحق).

/// 3% رسوم خدمة معروضة للعميل (DISPLAY-ONLY)
const double kServiceFeePercentage = 0.03;

/// 8% عمولة منصة مخصومة من المالك (DISPLAY-ONLY)
const double kPlatformCommissionPercentage = 0.08;
