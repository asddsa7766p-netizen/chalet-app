import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/constants/app_strings.dart';
import 'package:makan/data/models/chalet_model.dart';
import 'package:makan/presentation/screens/home/widgets/city_sections.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

/// توزيع حقيقي (201 شاليه على 10 مدن، من القاعدة الحية).
const _counts = {
  'نابلس': 30,
  'رام الله': 30,
  'جنين': 28,
  'طولكرم': 24,
  'الخليل': 21,
  'أريحا': 18,
  'قلقيلية': 15,
  'بيت لحم': 13,
  'سلفيت': 12,
  'طوباس': 10,
};

ChaletModel _chalet(String city, int i) => ChaletModel.fromJson({
      'id': '$city-$i',
      'name': '$city $i',
      'city': city,
      'price_per_night': 100,
    });

void main() {
  setUpAll(loadArabicTestFont);

  group('ترتيب أقسام المدن', () {
    test('"الكل": كل المدن العشر، الأكثر شاليهات أولاً', () {
      final order = orderCitySections(_counts, AppStrings.allCities);
      expect(order, hasLength(10));
      // التعادل (نابلس = رام الله = 30) بترتيب AppStrings.cities.
      expect(order.take(5),
          ['رام الله', 'نابلس', 'جنين', 'طولكرم', 'الخليل']);
      expect(order.last, 'طوباس');
    });

    test('مدينة مختارة: قسمها أولاً ثم باقي المدن', () {
      final order = orderCitySections(_counts, 'جنين');
      expect(order.first, 'جنين');
      expect(order, hasLength(10), reason: 'باقي المدن تحتها');
      expect(order.skip(1).take(2), ['رام الله', 'نابلس']);
      expect(orderCitySections(_counts, 'طوباس').first, 'طوباس');
    });

    test('مدينة بلا شاليهات لا يظهر قسمها', () {
      final order =
          orderCitySections({'جنين': 3, 'أريحا': 0, 'نابلس': 5}, 'أريحا');
      expect(order, ['نابلس', 'جنين']);
    });
  });

  group('الأقسام الكسولة', () {
    Future<List<String>> pump(
      WidgetTester tester, {
      required List<String> cities,
      List<String>? viewAll,
      Future<List<ChaletModel>> Function(String city)? load,
    }) async {
      tester.view.physicalSize = const Size(390 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final requested = <String>[];
      final memo = <String, Future<List<ChaletModel>>>{};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              CitySectionsSliver(
                cities: cities,
                loadCity: (city) => memo.putIfAbsent(city, () {
                  requested.add(city);
                  return load?.call(city) ??
                      Future.value([
                        for (var i = 0; i < 12; i++) _chalet(city, i),
                      ]);
                }),
                onRetry: (city) {},
                onViewAll: (city) => viewAll?.add(city),
                cardBuilder: (c) => SizedBox(
                    width: 200, child: Text(c.name, key: Key(c.id))),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return requested;
    }

    testWidgets('تُجلب شاليهات القسم عند اقترابه من الشاشة فقط، ومرة واحدة',
        (tester) async {
      final order = orderCitySections(_counts, AppStrings.allCities);
      final requested = await pump(tester, cities: order);
      expect(requested.length, lessThan(order.length),
          reason: 'لا تُجلب كل المدن دفعة واحدة');
      expect(requested.first, 'رام الله');

      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(requested, order, reason: 'كلها بعد التمرير، بالترتيب');
      expect(requested.toSet(), hasLength(order.length),
          reason: 'بلا تكرار عند الرجوع');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 20000));
      await tester.pumpAndSettle();
      expect(requested, hasLength(order.length));
    });

    testWidgets('حتى 10 شاليهات بالقسم، و"عرض الكل" بمدينة القسم',
        (tester) async {
      final viewAll = <String>[];
      await pump(tester, cities: ['جنين'], viewAll: viewAll);
      expect(find.text('شاليهات جنين'), findsOneWidget);
      final list = find.byType(ListView);
      await tester.drag(list, const Offset(3000, 0));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(-3000, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('جنين-9')), findsOneWidget);
      expect(find.byKey(const Key('جنين-10')), findsNothing);
      await tester.tap(find.text('عرض الكل'));
      expect(viewAll, ['جنين']);
    });

    testWidgets('قسم بلا نتائج يختفي، وفشل الجلب يعرض إعادة المحاولة',
        (tester) async {
      await pump(tester,
          cities: ['جنين', 'أريحا'],
          load: (city) => city == 'جنين'
              ? Future.value(const <ChaletModel>[])
              : Future.error(Exception('network')));
      expect(find.text('شاليهات جنين'), findsNothing);
      expect(find.text('شاليهات أريحا'), findsOneWidget);
      expect(find.text('تعذر التحميل، إعادة المحاولة'), findsOneWidget);
    });
  });
}
