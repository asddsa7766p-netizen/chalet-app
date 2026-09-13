import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:makan/data/models/booking_payment_details.dart';

import '../theme/payment_theme.dart';
import '../widgets/payment_widgets.dart';
import 'payment_method_screen.dart';
import 'package:flutter/material.dart' as flutter_material;

/// شاشة (1): مراجعة الحجز وملخص الدفع قبل اختيار طريقة الدفع
class PaymentReviewScreen extends StatelessWidget {
  final BookingPaymentDetails booking;

  const PaymentReviewScreen({super.key, required this.booking});

  String _formatCurrency(double amount) {
    final f = NumberFormat('#,##0', 'en_US');
    return '${f.format(amount)} ₪';
  }

  String _formatDatesRange() {
    final inFmt = DateFormat('d MMMM', 'ar');
    final outFmt = DateFormat('d MMMM', 'ar');
    return '${inFmt.format(booking.checkIn)} - ${outFmt.format(booking.checkOut)}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: flutter_material.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: PaymentColors.background,
        appBar: const PaymentAppBar(),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PaymentSpacing.screenPadding,
              8,
              PaymentSpacing.screenPadding,
              16,
            ),
            child: PrimaryButton(
              label: 'متابعة للدفع',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PaymentMethodScreen(booking: booking),
                  ),
                );
              },
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(PaymentSpacing.screenPadding),
            children: [
              const PaymentStepIndicator(currentStep: 3),
              const SizedBox(height: PaymentSpacing.sectionGap),
              ChaletSummaryCard(
                imageUrl: booking.chaletImageUrl,
                name: booking.chaletName,
                location: booking.chaletLocation,
                datesLabel: _formatDatesRange(),
                guestsLabel:
                    '${booking.nightsCount} ليالي - ${booking.guestsCount} ضيف',
              ),
              const SizedBox(height: PaymentSpacing.sectionGap),
              Text('ملخص الدفع', style: PaymentTextStyles.sectionTitle),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: PaymentColors.cardBackground,
                  borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
                  border: Border.all(color: PaymentColors.borderLight),
                ),
                child: Column(
                  children: [
                    SummaryRow(
                      label: 'سعر الليلة الواحدة',
                      value: _formatCurrency(booking.pricePerNight),
                    ),
                    SummaryRow(
                      label: '${booking.nightsCount} ليالي',
                      value: _formatCurrency(booking.subtotal),
                    ),
                    SummaryRow(
                      label: 'الإضافات',
                      value: _formatCurrency(booking.extrasTotal),
                    ),
                    SummaryRow(
                      label:
                          'الضريبة والرسوم (${booking.taxAndFeesPercent.toStringAsFixed(0)}%)',
                      value: _formatCurrency(booking.taxAndFeesAmount),
                    ),
                    const Divider(height: 24, color: PaymentColors.borderLight),
                    SummaryRow(
                      label: 'الإجمالي الكلي',
                      value: _formatCurrency(booking.totalAmount),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: PaymentColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('لن يتم خصم أي مبلغ قبل تأكيد الدفع',
                      style: PaymentTextStyles.bodySecondary),
                ],
              ),
              const SizedBox(height: PaymentSpacing.sectionGap),
              Container(
                padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: PaymentColors.cardBackground,
                  borderRadius: BorderRadius.circular(PaymentSpacing.radiusMd),
                  border: Border.all(color: PaymentColors.borderLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PaymentColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: PaymentColors.primaryDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('لماذا نحمي بياناتك؟',
                              style: PaymentTextStyles.sectionTitle),
                          const SizedBox(height: 4),
                          Text(
                            'نتم جميع عمليات الدفع عبر بوابات دفع آمنة ومعتمدة ونضمن سرية بياناتك ولا نحتفظ بمعلومات بطاقتك.',
                            style: PaymentTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
