part of '../booking_screen.dart';

extension _BookingPriceSummary on _BookingScreenState {
  // ===================== PRICE DETAILS =====================
  Widget _priceRow(String label, String value, {bool total = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: total ? 15 : 13,
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
                color: total ? AppColors.charcoal : AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: total ? 18 : 14,
                fontWeight: FontWeight.w900,
                color: total ? _BookingScreenState._darkGreen : AppColors.charcoal)),
      ],
    );
  }

  Widget _buildPriceSummary() {
    if (_priceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_total == null) {
      if (_availabilityError != null) {
        return Text(_availabilityError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error));
      }
      return const SizedBox.shrink();
    }

    // ✅ إصلاح (قرار عمل): كانت هذه البطاقة تضيف "ضريبة الخدمة 3%" و"رسوم
    // المنصة 3%" (قيمة placeholder غير مرتبطة بأي ثابت حقيقي أصلاً) فوق
    // السعر الأساسي، فيظهر للعميل "مجموع كلي" أكبر بـ6% مما يُحفظ ويُحجز
    // فعلياً بقاعدة البيانات (bookings.total_price = السعر الأساسي فقط،
    // تحقق من ذلك فعلياً عبر RPC calculate_chalet_stay_price وقراءة صف
    // الحجز بعد إنشائه). بقرار صريح: العمولة/الرسوم لا تُعرض للعميل
    // إطلاقاً، والمجموع المعروض هنا يطابق بالضبط ما سيُحفظ وما يظهر على
    // زر التأكيد بالأسفل — رقم واحد فقط، مصدر واحد (_serverTotalPrice).
    final total = _total!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تفاصيل السعر',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            children: [
              _priceRow(
                  'سعر ${_selectedPeriod?.label ?? 'الفترة'}',
                  AppCurrency.formatPrice(total)),
              const SizedBox(height: 6),
              _priceRow(
                  arabicDayLabel(_date!, withYear: false),
                  _selectedPeriod?.timeLabel ?? 'طوال اليوم'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              _priceRow('المجموع الكلي', AppCurrency.formatPrice(total),
                  total: true),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ إضافة: قبل التأكيد، كان المستخدم لا يعرف أبداً ما ستكون عليه حالة
  // حجزه بعد الضغط على "تأكيد الحجز" — createBooking ينشئ الحجز دائماً
  // بحالة 'pending' بانتظار موافقة المالك (services.dart)، لكن لا شيء
  // بالشاشة كان يوضّح ذلك قبل الإرسال. ملاحظة صغيرة صادقة بدل تفاجؤ
  // المستخدم لاحقاً.
  Widget _buildBookingStatusNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryPale.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'بعد التأكيد، سيُرسل طلبك للمالك للموافقة عليه. يمكنك متابعة حالة الحجز في أي وقت من صفحة حجوزاتي.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== BOTTOM BAR =====================
  Widget _buildBottomBar() {
    final totalText = _total == null ? '—' : AppCurrency.formatPrice(_total!);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Column(children: [
                  Text(
                    _paymentMethod == 'cash'
                        ? 'الدفع في الشاليه'
                        : AppStrings.onlinePayment,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    _paymentMethod == 'cash'
                        ? Icons.money_rounded
                        : Icons.credit_card_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _canConfirm && !_loading ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _BookingScreenState._darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_outline, size: 16),
                            const SizedBox(width: 8),
                            Text('تأكيد الحجز  $totalText',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
