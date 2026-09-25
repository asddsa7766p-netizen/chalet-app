import 'package:flutter/material.dart';
import 'package:makan/data/models/booking_payment_details.dart';
import 'package:makan/data/services/payment_gateway.dart';
import 'package:makan/presentation/screens/payment/widgets/payment_widgets.dart';

import 'payment_theme.dart';
import 'payment_failed_screen.dart';
import 'payment_success_screen.dart';

/// شاشة (5): "جارٍ معالجة الدفع..." — تستدعي بوابة الدفع فعلياً ثم توجّه
/// المستخدم تلقائياً لشاشة النجاح أو الفشل حسب النتيجة.
///
/// مرّر إما [card] (للدفع بالبطاقة) أو [walletType] (للدفع بمحفظة إلكترونية).
class PaymentProcessingScreen extends StatefulWidget {
  final BookingPaymentDetails booking;
  final CardPaymentInput? card;
  final PaymentMethodType? walletType;

  /// بوابة الدفع المستخدمة. اتركها فاضية لتستخدم MockPaymentGateway تلقائياً
  /// (مفيدة الآن لتجربة الشاشات قبل ربط بوابة حقيقية). لما تحدد البوابة
  /// النهائية، مرر implementation حقيقي من مكان استدعاء هالشاشة، أو
  /// عدّل القيمة الافتراضية بالأسفل مرة وحدة.
  final PaymentGateway? gateway;

  const PaymentProcessingScreen({
    super.key,
    required this.booking,
    this.card,
    this.walletType,
    this.gateway,
  }) : assert(card != null || walletType != null,
            'لازم تمرر إما بيانات بطاقة أو نوع محفظة إلكترونية');

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  late final PaymentGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? MockPaymentGateway();
    _processPayment();
  }

  Future<void> _processPayment() async {
    late final PaymentResult result;
    try {
      if (widget.card != null) {
        result = await _gateway.payWithCard(
          booking: widget.booking,
          card: widget.card!,
        );
      } else {
        result = await _gateway.payWithWallet(
          booking: widget.booking,
          walletType: widget.walletType!,
        );
      }
    } catch (e) {
      result = const PaymentResult.failure(
          'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى');
    }

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            booking: widget.booking,
            transactionId: result.transactionId,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentFailedScreen(
            booking: widget.booking,
            reasonAr: result.failureReasonAr ??
                'لم يتم إتمام العملية، يرجى المحاولة مرة أخرى',
            card: widget.card,
            walletType: widget.walletType,
            gateway: widget.gateway,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        // ما بنسمح بالرجوع أثناء معالجة الدفع لتفادي تكرار العملية
        canPop: false,
        child: Scaffold(
          backgroundColor: PaymentColors.background,
          appBar: AppBar(
            backgroundColor: PaymentColors.background,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title:
                const Text('جارٍ معالجة الدفع', style: PaymentTextStyles.screenTitle),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(PaymentSpacing.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(logoSize: 72, showName: true),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: PaymentColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('جاري معالجة الدفع...',
                      style: PaymentTextStyles.sectionTitle),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(PaymentSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: PaymentColors.cardBackground,
                      borderRadius:
                          BorderRadius.circular(PaymentSpacing.radiusMd),
                      border: Border.all(color: PaymentColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('معلومات مهمة',
                            style: PaymentTextStyles.sectionTitle),
                        const SizedBox(height: 8),
                        const Text(
                          'قد تستغرق عملية الدفع بضع ثوانٍ. لا تغلق، لم يتم خصم أي مبلغ حتى الآن.',
                          style: PaymentTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'يرجى عدم إغلاق التطبيق',
                          style: PaymentTextStyles.bodySecondary.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
