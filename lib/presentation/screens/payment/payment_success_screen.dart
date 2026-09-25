import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:makan/data/models/booking_payment_details.dart';

import '../home/main_screen.dart' show goToMainTab;
import 'payment_theme.dart';

/// شاشة (4): تأكيد نجاح الحجز والدفع
class PaymentSuccessScreen extends StatelessWidget {
  final BookingPaymentDetails booking;
  final String? transactionId;

  const PaymentSuccessScreen({
    super.key,
    required this.booking,
    this.transactionId,
  });

  String _formatCurrency(double amount) {
    final f = NumberFormat('#,##0', 'en_US');
    return '${f.format(amount)} ₪';
  }

  String _formatDatesRange() {
    final fmt = DateFormat('d MMMM yyyy', 'ar');
    return '${fmt.format(booking.checkIn)} - ${fmt.format(booking.checkOut)}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: PaymentColors.primaryDarker,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PaymentSpacing.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: PaymentColors.primaryDarker, size: 44),
                ),
                const SizedBox(height: 20),
                Text(
                  'تم الحجز بنجاح!',
                  style: PaymentTextStyles.screenTitle.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'شكراً لحجزك مع مكان',
                  style: PaymentTextStyles.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: PaymentColors.cardBackground,
                    borderRadius:
                        BorderRadius.circular(PaymentSpacing.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('رقم الحجز',
                              style: PaymentTextStyles.bodySecondary),
                          Row(
                            children: [
                              Text(booking.bookingId,
                                  style: PaymentTextStyles.sectionTitle),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_outlined,
                                  size: 16, color: PaymentColors.textSecondary),
                            ],
                          ),
                        ],
                      ),
                      const Divider(
                          height: 24, color: PaymentColors.borderLight),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              booking.chaletImageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: PaymentColors.borderLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking.chaletName,
                                    style: PaymentTextStyles.sectionTitle),
                                const SizedBox(height: 4),
                                Text(booking.chaletLocation,
                                    style: PaymentTextStyles.bodySecondary),
                                const SizedBox(height: 6),
                                Text(_formatDatesRange(),
                                    style: PaymentTextStyles.bodySecondary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                          height: 24, color: PaymentColors.borderLight),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي المدفوع',
                              style: PaymentTextStyles.bodySecondary),
                          Text(_formatCurrency(booking.totalAmount),
                              style: PaymentTextStyles.amountLarge),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    // "حجوزاتي" هي شاشة تفاصيل حجوزات المستخدم بالتطبيق.
                    onPressed: () => goToMainTab(context, 3),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PaymentSpacing.radiusMd),
                      ),
                    ),
                    child: Text('عرض الحجز',
                        style: PaymentTextStyles.buttonText.copyWith(
                          color: PaymentColors.primaryDarker,
                        )),
                  ),
                ),
                // أُخفي زرّا "مشاركة" و"إضافة للتقويم": لم يكن لهما أي تنفيذ.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
