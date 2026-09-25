// ============================================
// PRICING DISPLAY CONSTANTS (DISPLAY-ONLY)
// ============================================
// هذه النسب تُستخدم للعرض فقط في الواجهة — لا تدخل في حساب السعر المخزّن
// (bookings.total_price) ولا في منطق Supabase إطلاقًا.
//
// kPlatformCommissionPercentage: 8% عمولة منصة تُعرض للمالك في بطاقة الحجز
//                                (تُخصم من قيمة الحجز لحساب المبلغ المستحق).

/// مفتاح واحد لعرض نسبة العمولة بأي شاشة. مخفية قبل الإطلاق: النسبة هنا ثابتة
/// بالتطبيق، بينما المبلغ الفعلي يحسبه السيرفر لكل حجز
/// (bookings.platform_commission_amount)، فقد لا يتطابقان.
const bool kShowPlatformCommission = false;

/// 8% عمولة منصة مخصومة من المالك (DISPLAY-ONLY)
const double kPlatformCommissionPercentage = 0.08;
