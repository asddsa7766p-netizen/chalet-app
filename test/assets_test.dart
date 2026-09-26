import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// الصور المضمّنة بالتطبيق: تُفك فعلاً بمحرّك Flutter، وأبعادها ضمن الحد
/// (خلفية الترحيب WebP بعرض ≤ 1080، والشعار ≤ 512).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> decode(WidgetTester tester, String asset) async {
    final data = await rootBundle.load(asset);
    final image = await tester.runAsync(() async {
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    });
    return image!;
  }

  testWidgets('خلفية الترحيب WebP بعرض ≤ 1080', (tester) async {
    final img = await decode(tester, 'assets/images/onboarding_bg.webp');
    expect(img.width, lessThanOrEqualTo(1080));
    expect(img.width, greaterThan(0));
  });

  testWidgets('الشعار ≤ 512 بكسل', (tester) async {
    final img = await decode(tester, 'assets/images/logo.png');
    expect(img.width, lessThanOrEqualTo(512));
    expect(img.height, lessThanOrEqualTo(512));
  });
}
