import 'package:intl/intl.dart';

class AppCurrency {
  static const String defaultSymbol = '₪';

  static String formatPrice(
    num value, {
    bool includeSymbol = true,
    String symbol = defaultSymbol,
    int decimalDigits = 0,
  }) {
    final formatted = NumberFormat.currency(
      locale: 'ar',
      symbol: includeSymbol ? symbol : '',
      decimalDigits: decimalDigits,
    ).format(value);

    return includeSymbol
        ? formatted.replaceAll('ر.س', symbol).replaceAll('SAR', symbol)
        : formatted.replaceAll('ر.س', '').replaceAll('SAR', '').trim();
  }
}
