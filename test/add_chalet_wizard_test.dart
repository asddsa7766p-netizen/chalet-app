import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:makan/presentation/screens/owner/chalet_form/add_chalet_data_source.dart';
import 'package:makan/presentation/screens/owner/chalet_form/owner_add_chalet_screen.dart';

import 'helpers/chalet_edit_test_harness.dart' show testXFile;
import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

class _FakeAddChaletDataSource implements AddChaletDataSource {
  final saved = <Map<String, dynamic>>[];
  int savedImages = 0;

  @override
  String? get currentUserId => 'owner-1';

  @override
  Future<List<XFile>> pickImages() async => [testXFile('cover.png')];

  @override
  Future<String> saveChalet({
    required bool isEditing,
    String? editingChaletId,
    required String ownerId,
    required Map<String, dynamic> chaletData,
    required List<XFile> newImages,
    required List<Uint8List> newImageBytes,
    required List<String> existingImageUrls,
  }) async {
    saved.add({...chaletData, 'owner_id_arg': ownerId});
    savedImages = newImages.length;
    return 'new-chalet';
  }

  @override
  Future<bool> becomeOwner() async => false;
}

/// نفس minimumSize لأزرار AppTheme (عرض لا نهائي) بلا GoogleFonts: هذا ما
/// جعل زر "السابق" بلا عرض محدد يكسر تخطيط الشريط السفلي بنسخة الإصدار.
final _appButtonTheme = ThemeData(
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52))),
  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52))),
);

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Finder _button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

/// الزر موجود، ظاهر فعلاً (قابل للضغط، بعرض معقول) ومفعّل.
void _expectUsable(WidgetTester tester, String label) {
  final f = _button(label);
  expect(f, findsOneWidget, reason: '"$label" غير موجود');
  expect(f.hitTestable(), findsOneWidget, reason: '"$label" غير قابل للضغط');
  expect(tester.getSize(f).width, greaterThan(56),
      reason: '"$label" مضغوط لعرض لا يُرى');
  expect((tester.widget(f) as ButtonStyleButton).onPressed, isNotNull,
      reason: '"$label" معطّل');
}

Future<_FakeAddChaletDataSource> _pumpWizard(
    WidgetTester tester, double textScale) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final ds = _FakeAddChaletDataSource();
  final router = GoRouter(
    initialLocation: '/add',
    routes: [
      GoRoute(
          path: '/add',
          builder: (_, __) => OwnerAddChaletScreen(dataSource: ds)),
      GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
      GoRoute(path: '/owner-dashboard', builder: (_, __) => const Text('DASH')),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(
      theme: _appButtonTheme,
      routerConfig: router,
      builder: (c, child) => MediaQuery(
        data:
            MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return ds;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(_button(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadArabicTestFont);

  for (final scale in [1.0, 1.3]) {
    testWidgets(
        'المعالج كاملاً على 360dp (نص ×$scale): السابق/التالي بكل خطوة، '
        'و"إرسال للمراجعة" بالأخيرة يحفظ', (tester) async {
      final ds = await _pumpWizard(tester, scale);

      // الخطوة 1: معلومات أساسية (لا سابق قبلها).
      expect(_button('السابق'), findsNothing);
      _expectUsable(tester, 'التالي');
      _expectUsable(tester, 'حفظ كمسودة');
      await tester.enterText(_field('اسم الشاليه'), 'شاليه الاختبار');
      await tester.enterText(_field('وصف مختصر'), 'وصف قصير');
      await _tap(tester, 'التالي');

      // الخطوة 2: الصور والفيديو (هنا كان الزر يختفي).
      _expectUsable(tester, 'السابق');
      _expectUsable(tester, 'التالي');
      _expectUsable(tester, 'حفظ كمسودة');
      await tester.tap(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_CoverImageBox'));
      await tester.pumpAndSettle();
      await _tap(tester, 'التالي');

      // الخطوة 3: المميزات.
      _expectUsable(tester, 'السابق');
      _expectUsable(tester, 'التالي');
      // "السابق" يرجع خطوة فعلاً، ثم نعود.
      await _tap(tester, 'السابق');
      expect(
          find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_CoverImageBox'),
          findsOneWidget);
      await _tap(tester, 'التالي');
      await _tap(tester, 'التالي');

      // الخطوة 4 (الأخيرة): السابق + إرسال للمراجعة، بلا "التالي".
      _expectUsable(tester, 'السابق');
      _expectUsable(tester, 'إرسال للمراجعة');
      _expectUsable(tester, 'حفظ كمسودة');
      expect(find.text('التالي'), findsNothing);
      await tester.enterText(_field('السعر الأساسي (يبدأ من)'), '350');
      await tester.pump();

      expect(ds.saved, isEmpty);
      await tester.tap(_button('إرسال للمراجعة'));
      await tester.pump();
      expect(ds.saved, hasLength(1), reason: 'الإرسال لم يستدعِ الحفظ');
      expect(ds.saved.single['name'], 'شاليه الاختبار');
      expect(ds.saved.single['price_per_night'], 350);
      expect(ds.saved.single['owner_id_arg'], 'owner-1');
      expect(ds.savedImages, 1);

      // becomeOwner = false ← رسالة الانتظار ثم الرئيسية.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  }
}
