import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/utils/number_utils.dart';
import 'package:makan/presentation/screens/owner/manual_booking_sheet.dart'
    show parseManualPrice;

void main() {
  group('parseLocalizedInt / parseLocalizedDouble', () {
    test('أرقام عربية-هندية وفارسية ولاتينية، مع مسافات', () {
      expect(parseLocalizedInt(' ١٢ '), 12);
      expect(parseLocalizedInt('۴۰'), 40);
      expect(parseLocalizedDouble('١٥٠٠'), 1500);
      expect(parseLocalizedDouble('٣٢٫٥'), 32.5);
      expect(parseLocalizedDouble('١٬٢٠٠'), 1200);
    });

    test('نص غير رقمي أو فارغ أو null أو لانهائي: null', () {
      expect(parseLocalizedInt('abc'), isNull);
      expect(parseLocalizedInt('1.5'), isNull);
      expect(parseLocalizedInt(null), isNull);
      expect(parseLocalizedDouble(''), isNull);
      expect(parseLocalizedDouble('Infinity'), isNull);
      expect(parseLocalizedDouble('NaN'), isNull);
    });
  });

  test('parseManualPrice يبقى يقبل الفاصلة العشرية العربية والعادية', () {
    expect(parseManualPrice('١٢،٥'), 12.5);
    expect(parseManualPrice('1,5'), 1.5);
    expect(parseManualPrice('١ ٠٠٠'), 1000);
  });
}
