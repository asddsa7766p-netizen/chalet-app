import 'package:intl/intl.dart';

class AppCurrency {
  static const String defaultSymbol = '₪';

  static String formatPrice(
    num value, {
    bool includeSymbol = true,
    String symbol = defaultSymbol,
    int decimalDigits = 0,
  }) {
    final formatter = NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = decimalDigits
      ..maximumFractionDigits = decimalDigits;

    final formattedNumber = formatter.format(value);
    final normalized =
        formattedNumber.replaceAll(RegExp(r'[\u200F\u00A0]'), '');

    return includeSymbol ? '$symbol$normalized' : normalized;
  }
}
