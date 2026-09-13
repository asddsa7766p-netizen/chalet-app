/// يمثل بيانات الحجز المطلوب دفعها، وهو الكائن يلي بيتنقل بين شاشات الدفع.
/// عبّي هالكائن من شاشة "مراجعة الحجز" الموجودة عندك بالتطبيق قبل ما توصل
/// لأول شاشة بهالفلو (PaymentReviewScreen).
class BookingPaymentDetails {
  final String bookingId;
  final String chaletName;
  final String chaletLocation;
  final String chaletImageUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nightsCount;
  final int guestsCount;
  final double pricePerNight;
  final double subtotal; // سعر الليالي مجتمعة قبل الإضافات والضريبة
  final double extrasTotal; // الإضافات
  final double taxAndFeesPercent; // مثال: 5 تعني 5%
  final double totalAmount; // الإجمالي الكلي شامل الضريبة والرسوم
  final String? userEmail; // لإرسال تأكيد الحجز

  const BookingPaymentDetails({
    required this.bookingId,
    required this.chaletName,
    required this.chaletLocation,
    required this.chaletImageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.nightsCount,
    required this.guestsCount,
    required this.pricePerNight,
    required this.subtotal,
    required this.extrasTotal,
    required this.taxAndFeesPercent,
    required this.totalAmount,
    this.userEmail,
  });

  double get taxAndFeesAmount => totalAmount - subtotal - extrasTotal;
}

/// بيانات بطاقة الدفع المُدخلة من المستخدم بشاشة إدخال البطاقة.
class CardPaymentInput {
  final String cardNumber;
  final String cardHolderName;
  final String expiryMonthYear; // MM/YY
  final String cvv;
  final bool saveCardForLater;

  const CardPaymentInput({
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryMonthYear,
    required this.cvv,
    this.saveCardForLater = false,
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
