// ============================================
// PRICING DISPLAY CONSTANTS (DISPLAY-ONLY)
// ============================================
// هذه النسب تُستخدم للعرض فقط في الواجهة — لا تدخل في حساب السعر المخزّن
// (bookings.total_price) ولا في منطق Supabase إطلاقًا.
//
// kPlatformCommissionPercentage: 8% عمولة منصة تُعرض للمالك في بطاقة الحجز
//                                (تُخصم من قيمة الحجز لحساب المبلغ المستحق).

/// 8% عمولة منصة مخصومة من المالك (DISPLAY-ONLY)
const double kPlatformCommissionPercentage = 0.08;
