part of '../booking_screen.dart';

extension _BookingSuccessDialog on _BookingScreenState {
  /// ✅ إصلاح: يبني رمز حجز آمن حتى لو الـ id أقصر من 8 أحرف (كان
  /// booking.id.substring(0, 8) يرمي RangeError ويكسر شاشة النجاح).
  String _bookingCode(BookingModel booking) {
    final raw =
        booking.id.length >= 8 ? booking.id.substring(0, 8) : booking.id;
    return '#CH-${raw.toUpperCase()}';
  }

  Future<void> _shareOnWhatsApp(BookingModel booking) async {
    final bookingCode = _bookingCode(booking);
    final text = Uri.encodeComponent(
      'حجزت في ${_chaletModel?.name ?? ''} 🎉\n'
      'رقم الحجز: $bookingCode\n'
      'التاريخ: ${booking.dateLabel}\n'
      'الفترة: ${_selectedPeriod?.label ?? booking.periodLabel}'
      '${_selectedPeriod?.timeLabel == null ? '' : ' (${_selectedPeriod!.timeLabel})'}',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack('تعذر فتح واتساب');
      }
    } catch (_) {
      if (mounted) _showSnack('تعذر فتح واتساب');
    }
  }

  void _showSuccessDialog(BookingModel booking) {
    final bookingCode = _bookingCode(booking);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.primaryPale.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 58, color: _BookingScreenState._darkGreen),
              ),
              const SizedBox(height: 16),
              // ✅ إصلاح: النص كان يقول "تم تأكيد طلبك" رغم أن كل حجز
              // يُنشأ دائماً بحالة 'pending' (createBooking بـservices.dart
              // يضع status:'pending' دون استثناء — التأكيد الفعلي إجراء
              // منفصل لاحق من المالك). كان يدّعي أيضاً "إرسال التفاصيل
              // لهاتفك" رغم عدم وجود أي إرسال SMS/إشعار فعلي بالكود. الآن
              // النص يعكس الحالة الحقيقية فقط ويوجّه لمصدر الحقيقة الفعلي
              // (صفحة حجوزاتي) بدل الادّعاء بتواصل غير موجود.
              const Text('تم إرسال طلب حجزك ✅',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _BookingScreenState._darkGreen),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                  'طلبك الآن قيد انتظار موافقة المالك. يمكنك متابعة حالة حجزك في أي وقت من صفحة حجوزاتي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                ),
                child: Column(children: [
                  const Text('رقم الحجز الخاص بك',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textHint)),
                  const SizedBox(height: 6),
                  Text(bookingCode,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.charcoal)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.pop();
                    goToMainTab(context, 3);
                  },
                  icon: const Icon(Icons.description_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _BookingScreenState._darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  // ✅ إصلاح: النص كان "عرض تفاصيل الحجز" لكنه فعلياً
                  // يفتح قائمة "حجوزاتي" الكاملة (لا توجد شاشة تفاصيل حجز
                  // منفصلة) — لم أُضِف مساراً جديداً، فقط صححت التسمية
                  // لتطابق الوجهة الفعلية.
                  label: const Text('عرض حجوزاتي',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareOnWhatsApp(booking),
                  icon: const Icon(Icons.share_rounded),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: _BookingScreenState._darkGreen,
                    side: const BorderSide(color: _BookingScreenState._darkGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  label: const Text('شارك على واتساب',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
