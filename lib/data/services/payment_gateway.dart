import 'dart:async';
import 'dart:math';

import '../models/booking_payment_details.dart';

/// واجهة موحّدة لأي بوابة دفع. لما تقرر البوابة الفعلية (Jawwal Pay،
/// Ooredoo Money، Stripe، PayTabs...) اعمل implementation جديد لهاي
/// الواجهة (زي JawwalPayGateway مثلاً) بدون ما تلمس أي شاشة UI.
abstract class PaymentGateway {
  /// دفع عبر بطاقة (Visa/Mastercard/mada)
  Future<PaymentResult> payWithCard({
    required BookingPaymentDetails booking,
    required CardPaymentInput card,
  });

  /// دفع عبر محفظة إلكترونية (PayPal أو غيرها)
  Future<PaymentResult> payWithWallet({
    required BookingPaymentDetails booking,
    required PaymentMethodType walletType,
  });
}

/// تنفيذ وهمي (Mock) يسمح بتجربة الشاشات الستة كاملة الآن —
/// بينجح تلقائياً، أو ممكن تستخدم MockPaymentGateway.alwaysFail
/// لتجربة شاشة "فشل الدفع".
///
/// ⚠️ لا تستخدم هذا التنفيذ بالإنتاج — استبدله بتنفيذ حقيقي لما تحدد البوابة.
class MockPaymentGateway implements PaymentGateway {
  final bool forceFailure;
  final Duration simulatedDelay;

  MockPaymentGateway({
    this.forceFailure = false,
    this.simulatedDelay = const Duration(seconds: 2),
  });

  @override
  Future<PaymentResult> payWithCard({
    required BookingPaymentDetails booking,
    required CardPaymentInput card,
  }) async {
    await Future.delayed(simulatedDelay);
    if (forceFailure) {
      return const PaymentResult.failure(
        'بيانات البطاقة غير صحيحة أو الرصيد غير كافٍ',
      );
    }
    final txId = 'MOCK-${Random().nextInt(999999)}';
    return PaymentResult.success(txId);
  }

  @override
  Future<PaymentResult> payWithWallet({
    required BookingPaymentDetails booking,
    required PaymentMethodType walletType,
  }) async {
    await Future.delayed(simulatedDelay);
    if (forceFailure) {
      return const PaymentResult.failure(
        'تعذر إتمام الدفع عبر المحفظة الإلكترونية، يرجى المحاولة مرة أخرى',
      );
    }
    final txId = 'MOCK-${Random().nextInt(999999)}';
    return PaymentResult.success(txId);
  }
}
