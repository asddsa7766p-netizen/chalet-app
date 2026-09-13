import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:makan/data/models/booking_payment_details.dart';

import '../theme/payment_theme.dart';
import '../widgets/payment_widgets.dart';
import 'package:flutter/material.dart' as flutter_material;

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
      textDirection: flutter_material.TextDirection.rtl,
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
                          Text('رقم الحجز',
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
                          Text('الإجمالي المدفوع',
                              style: PaymentTextStyles.bodySecondary),
                          Text(_formatCurrency(booking.totalAmount),
                              style: PaymentTextStyles.amountLarge),
                        ],
                      ),
                      if (booking.userEmail != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined,
                                size: 14, color: PaymentColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'تم إرسال تأكيد الحجز إلى بريدك الإلكتروني: ${booking.userEmail}',
                                style: PaymentTextStyles.bodySecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: وجّه لشاشة تفاصيل الحجز الفعلية بالمشروع
                    },
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: مشاركة تفاصيل الحجز
                        },
                        icon: const Icon(Icons.ios_share,
                            color: Colors.white, size: 18),
                        label: Text('مشاركة',
                            style: PaymentTextStyles.body
                                .copyWith(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PaymentSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: إضافة الحجز لتقويم الجهاز
                        },
                        icon: const Icon(Icons.calendar_today_outlined,
                            color: Colors.white, size: 16),
                        label: Text('إضافة للتقويم',
                            style: PaymentTextStyles.body
                                .copyWith(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(PaymentSpacing.radiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
