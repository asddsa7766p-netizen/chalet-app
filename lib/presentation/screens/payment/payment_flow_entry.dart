import 'package:flutter/material.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/models/booking_payment_details.dart';
import 'payment_review_screen.dart';

/// نقطة الدخول الصحيحة لفلو الدفع، تُستدعى من app_router.dart
Widget buildPaymentFlow({
  required ChaletModel chalet,
  required DateTime checkIn,
  required DateTime checkOut,
  required int guestsCount,
  double extrasTotal = 0,
  double taxAndFeesPercent = 5,
  String? userEmail,
}) {
  final nights = checkOut.difference(checkIn).inDays;
  final subtotal = chalet.pricePerNight * nights;
  final taxAndFees = (subtotal + extrasTotal) * (taxAndFeesPercent / 100);
  final total = subtotal + extrasTotal + taxAndFees;

  final booking = BookingPaymentDetails(
    bookingId: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
    chaletName: chalet.name,
    chaletLocation: chalet.location,
    chaletImageUrl: chalet.coverImage,
    checkIn: checkIn,
    checkOut: checkOut,
    nightsCount: nights,
    guestsCount: guestsCount,
    pricePerNight: chalet.pricePerNight,
    subtotal: subtotal,
    extrasTotal: extrasTotal,
    taxAndFeesPercent: taxAndFeesPercent,
    totalAmount: total,
    userEmail: userEmail,
  );

  return PaymentReviewScreen(booking: booking);
}
