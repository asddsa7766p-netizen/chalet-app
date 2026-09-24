import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/utils/date_utils.dart';

void main() {
  group('nightsBetween', () {
    test('عدد الأيام التقويمية ويتجاهل الوقت', () {
      expect(nightsBetween(DateTime(2030, 3, 12), DateTime(2030, 3, 14)), 2);
      expect(
          nightsBetween(DateTime(2030, 3, 12, 23, 59), DateTime(2030, 3, 13, 0, 1)),
          1);
      expect(nightsBetween(DateTime(2030, 3, 12), DateTime(2030, 3, 12)), 0);
    });

    test('عبر تغيير التوقيت الصيفي لا تنقص ليلة (25→27 مارس 2027)', () {
      expect(nightsBetween(DateTime(2027, 3, 25), DateTime(2027, 3, 27)), 2);
      expect(nightsBetween(DateTime(2027, 10, 29), DateTime(2027, 11, 1)), 3);
    });

    test('عبر حدود الشهر والسنة، وسالب إن كانت المغادرة قبل الوصول', () {
      expect(nightsBetween(DateTime(2030, 12, 30), DateTime(2031, 1, 2)), 3);
      expect(nightsBetween(DateTime(2030, 3, 14), DateTime(2030, 3, 12)), -2);
    });
  });
}
