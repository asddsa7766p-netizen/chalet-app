import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/constants/app_strings.dart';
import 'package:makan/presentation/widgets/common/common_widgets.dart';
import 'package:makan/presentation/widgets/common/luxury_widgets.dart';

void main() {
  testWidgets('زر المسح يظهر ويختفي أثناء الكتابة ويمسح النص', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LuxurySearchBar(controller: ctrl)),
    ));

    final clear = find.byKey(const Key('luxury_search_clear'));
    expect(clear, findsNothing);

    await tester.enterText(find.byType(TextField), 'نابلس');
    await tester.pump();
    expect(clear, findsOneWidget);

    await tester.tap(clear);
    await tester.pump();
    expect(ctrl.text, isEmpty);
    expect(clear, findsNothing);
  });

  test('AppStrings.cities: عشر مدن بلا "الكل" ولا تكرار', () {
    expect(AppStrings.cities, hasLength(10));
    expect(AppStrings.cities.toSet(), hasLength(10));
    expect(AppStrings.cities, isNot(contains(AppStrings.allCities)));
    expect(AppStrings.cities, containsAll(['طوباس', 'سلفيت']));
  });

  testWidgets('شاليه بلا صورة غلاف: عنصر نائب محلي بلا شبكة', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChaletImagePlaceholder(width: 100, height: 100),
      ),
    ));
    expect(find.byIcon(Icons.home_work_rounded), findsOneWidget);
  });
}
