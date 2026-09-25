/// بيانات الحجز المطلوب دفعها (يوم واحد + فترة)، تتنقل بين شاشات الدفع.
///
/// السعر من السيرفر فقط (calculate_chalet_stay_price عبر شاشة الحجز): لا
/// ضريبة ولا رسوم محسوبة بالتطبيق — الإجمالي = سعر الفترة + الإضافات.
class BookingPaymentDetails {
  final String bookingId;
  final String chaletName;
  final String chaletLocation;
  final String chaletImageUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestsCount;

  /// اسم الفترة المحجوزة ("إقامة صباحية"...).
  final String periodLabel;

  /// سعر الفترة كما حسبه السيرفر.
  final double subtotal;
  final double extrasTotal;

  const BookingPaymentDetails({
    required this.bookingId,
    required this.chaletName,
    required this.chaletLocation,
    required this.chaletImageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.guestsCount,
    required this.periodLabel,
    required this.subtotal,
    this.extrasTotal = 0,
  });

  double get totalAmount => subtotal + extrasTotal;
}

/// بيانات بطاقة الدفع المُدخلة من المستخدم بشاشة إدخال البطاقة.
class CardPaymentInput {
  final String cardNumber;
  final String cardHolderName;
  final String expiryMonthYear; // MM/YY
  final String cvv;

  const CardPaymentInput({
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryMonthYear,
    required this.cvv,
  });
}

enum PaymentMethodType { cardVisaMastercardMada, paypal }

/// نتيجة عملية الدفع النهائية، ترجع من PaymentGateway بعد المعالجة.
class PaymentResult {
  final bool success;
  final String? failureReasonAr; // نص عربي يُعرض للمستخدم عند الفشل
  final String? transactionId;

  const PaymentResult.success(this.transactionId)
      : success = true,
        failureReasonAr = null;

  const PaymentResult.failure(this.failureReasonAr)
      : success = false,
        transactionId = null;
}
