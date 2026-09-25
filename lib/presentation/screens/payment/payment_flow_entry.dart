import 'package:flutter/material.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/booking_payment_details.dart';
import 'payment_review_screen.dart';

/// نقطة الدخول الصحيحة لفلو الدفع، تُستدعى من app_router.dart.
///
/// [totalPrice] هو سعر الفترة كما حسبه السيرفر بشاشة الحجز — لا يُعاد حسابه
/// هنا ولا تُضاف له أي عمولة/رسوم (كانت تُضاف 5% وهمية تخالف السعر المحفوظ).
Widget buildPaymentFlow({
  required ChaletModel chalet,
  required DateTime checkIn,
  required DateTime checkOut,
  required int guestsCount,
  required double totalPrice,
  required String periodLabel,
}) {
  final booking = BookingPaymentDetails(
    bookingId: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
    chaletName: chalet.name,
    chaletLocation: chalet.location,
    chaletImageUrl: chalet.coverImage,
    checkIn: checkIn,
    checkOut: checkOut,
    guestsCount: guestsCount,
    periodLabel: periodLabel,
    subtotal: totalPrice,
  );

  return PaymentReviewScreen(booking: booking);
}
