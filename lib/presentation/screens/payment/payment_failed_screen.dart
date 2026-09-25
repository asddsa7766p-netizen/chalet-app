import 'package:flutter/material.dart';
import 'package:makan/data/models/booking_payment_details.dart';
import 'package:makan/data/services/payment_gateway.dart';

import '../../../core/utils/support_contact.dart';
import '../theme/payment_theme.dart';
import '../widgets/payment_widgets.dart';
import 'payment_method_screen.dart';
import 'payment_processing_screen.dart';

/// شاشة (6): فشل معالجة الدفع — تسمح بإعادة المحاولة أو تغيير طريقة الدفع
class PaymentFailedScreen extends StatelessWidget {
  final BookingPaymentDetails booking;
  final String reasonAr;
  final CardPaymentInput? card;
  final PaymentMethodType? walletType;
  final PaymentGateway? gateway;

  const PaymentFailedScreen({
    super.key,
    required this.booking,
    required this.reasonAr,
    this.card,
    this.walletType,
    this.gateway,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: PaymentColors.background,
        appBar: const PaymentAppBar(),
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
                    color: PaymentColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 20),
                Text(
                  'فشل في معالجة الدفع',
                  style: PaymentTextStyles.screenTitle.copyWith(
                    color: PaymentColors.error,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'لم يتم إتمام العملية، يرجى المحاولة مرة أخرى',
                  style: PaymentTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: PaymentColors.errorBackground,
                    borderRadius:
                        BorderRadius.circular(PaymentSpacing.radiusMd),
                    border:
                        Border.all(color: PaymentColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: PaymentColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سبب الرفض',
                              style: PaymentTextStyles.body.copyWith(
                                color: PaymentColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(reasonAr,
                                style: PaymentTextStyles.bodySecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'حاول مرة أخرى',
                  trailingIcon: Icons.refresh,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PaymentProcessingScreen(
                          booking: booking,
                          card: card,
                          walletType: walletType,
                          gateway: gateway,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'تغيير طريقة الدفع',
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PaymentMethodScreen(booking: booking),
                      ),
                    );
                  },
                ),
                // يظهر فقط إن عُرّفت بيانات الدعم (AppStrings.supportPhone/Email).
                if (SupportContact.hasAny) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: SupportContact.open,
                    icon: const Icon(Icons.headset_mic_outlined,
                        size: 18, color: PaymentColors.textSecondary),
                    label: const Text(
                      'تحتاج مساعدة؟',
                      style: PaymentTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
