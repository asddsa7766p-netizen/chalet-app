import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/utils/currency_formatter.dart';

void main() {
  group('AppCurrency', () {
    test('formats prices with the shekel symbol', () {
      expect(AppCurrency.formatPrice(1250), '₪1,250');
      expect(AppCurrency.formatPrice(0), '₪0');
    });

    test('can omit the symbol for compact UI labels', () {
      expect(AppCurrency.formatPrice(1250, includeSymbol: false), '1,250');
    });
  });
}
