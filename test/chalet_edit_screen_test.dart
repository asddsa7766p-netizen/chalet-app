import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/presentation/screens/owner/chalet_form/chalet_edit_model.dart';
import 'package:makan/presentation/screens/owner/chalet_form/chalet_images_editor.dart';
import 'package:makan/presentation/screens/owner/chalet_form/owner_edit_chalet_screen.dart';

import 'helpers/chalet_edit_test_harness.dart';
import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

Finder _k(String k) => find.byKey(ValueKey(k));
String _text(WidgetTester t, String k) =>
    t.widget<TextField>(_k(k)).controller!.text;

Future<void> _type(WidgetTester t, String k, String v) async {
  await t.enterText(_k(k), v);
  await t.pump();
}

Future<void> _tap(WidgetTester t, String k) async {
  await t.tap(_k(k));
  await t.pumpAndSettle();
}

List<String> _imageSigs(WidgetTester t) => t
    .widget<ChaletImagesEditor>(find.byType(ChaletImagesEditor))
    .images
    .map((e) => e.signature)
    .toList();

int _tileCount(WidgetTester t) => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('imgTile_'))
    .evaluate()
    .length;

FakeChaletEditDataSource _fake({Map<String, dynamic>? overrides}) =>
    FakeChaletEditDataSource(
      row: sampleChaletRow(overrides: overrides ?? const {}),
    );

void main() {
  setUpAll(loadArabicTestFont);

  // ==========================================================
  group('الوصول: المالك فقط', () {
    testWidgets('المالك يرى النموذج بقيمه الحالية', (tester) async {
      await pumpEditScreen(tester, _fake());

      expect(_text(tester, 'field_name'), 'شاليه الندى');
      expect(_text(tester, 'field_max_guests'), '10');
      expect(_text(tester, 'field_price_per_night'), '800');
      expect(_text(tester, 'field_location'), 'بيتا');
      expect(_text(tester, 'field_latitude'), '32.2211');
      expect(find.text('معتمد'), findsOneWidget);
      expect(_k('dirtyBarText'), findsNothing);
    });

    testWidgets('مستخدم آخر: رسالة بلا أي نموذج', (tester) async {
      final ds = FakeChaletEditDataSource(
          row: sampleChaletRow(), userId: 'someone-else');
      await pumpEditScreen(tester, ds);

      expect(find.text('الشاليه غير موجود أو لا تملك صلاحية تعديله'),
          findsOneWidget);
      expect(_k('field_name'), findsNothing);
      expect(_k('saveButton'), findsNothing);
      expect(ds.updates, isEmpty);
    });

    testWidgets('شاليه غير موجود، أو مستخدم غير مسجل: نفس الرسالة',
        (tester) async {
      await pumpEditScreen(tester, FakeChaletEditDataSource(row: null));
      expect(find.text('الشاليه غير موجود أو لا تملك صلاحية تعديله'),
          findsOneWidget);
      expect(_k('field_name'), findsNothing);
    });

    testWidgets('بلا تسجيل دخول: نفس الرسالة', (tester) async {
      final ds = FakeChaletEditDataSource(row: sampleChaletRow(), userId: null);
      await pumpEditScreen(tester, ds);
      expect(find.text('الشاليه غير موجود أو لا تملك صلاحية تعديله'),
          findsOneWidget);
      expect(_k('field_name'), findsNothing);
    });

    testWidgets('فشل التحميل: رسالة وزر إعادة المحاولة يعمل', (tester) async {
      final ds = FakeChaletEditDataSource(
          row: sampleChaletRow(), failFetchTimes: 1);
      await pumpEditScreen(tester, ds);
      expect(find.text('تعذر تحميل بيانات الشاليه، يرجى المحاولة لاحقاً'),
          findsOneWidget);

      await _tap(tester, 'retryLoad');
      expect(_k('field_name'), findsOneWidget);
      expect(ds.fetches, 2);
    });
  });

  // ==========================================================
  group('الحالة وما يُخفى أو يُقفل', () {
    testWidgets('قيد المراجعة: شارة للقراءة فقط بلا أي مفتاح اعتماد',
        (tester) async {
      await pumpEditScreen(tester, _fake(overrides: {'is_approved': false}));
      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(find.textContaining('تحددها الإدارة'), findsOneWidget);
      // المفتاح الوحيد بالصفحة هو "متاح للحجز"
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(_k('availableSwitch'), findsOneWidget);
    });

    testWidgets('min_nights وdeposit_amount مخفيان تماماً', (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(find.textContaining('الوديعة'), findsNothing);
      expect(find.textContaining('الحد الأدنى للليالي'), findsNothing);
      expect(_k('field_min_nights'), findsNothing);
      expect(_k('field_deposit_amount'), findsNothing);
    });

    testWidgets('booking_type للقراءة فقط مع سطر يشرح معناه', (tester) async {
      await pumpEditScreen(tester, _fake(overrides: {'booking_type': 'خارجي'}));
      expect(find.text('نوع الحجز: خارجي'), findsOneWidget);
      expect(find.textContaining('لا يمكن تغييره من هذه الصفحة'),
          findsOneWidget);
      expect(find.textContaining('إحصائيات لوحتك'), findsOneWidget);
      // القائمة المنسدلة الوحيدة هي المدينة
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('التسميات: المنطقة/الحي والسعر الأساسي (يبدأ من)',
        (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(find.text('المنطقة/الحي'), findsWidgets);
      expect(find.text('السعر الأساسي (يبدأ من)'), findsWidgets);
      expect(find.text('العنوان التفصيلي (اختياري)'), findsWidgets);
    });

    testWidgets('نص السعر المساعد ثابت ويشرح الأثر، مع رابط أسعار الأيام',
        (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(
        find.textContaining('في البحث وصفحة الشاليه'),
        findsOneWidget,
      );
      expect(find.textContaining('ليس له سعر يوم أو سعر خاص بالفترة'),
          findsOneWidget);
      expect(_k('openPricing'), findsOneWidget);
    });
  });

  // ==========================================================
  group('رسائل التحقق بالعربية (تظهر تحت الحقل فور التعديل)', () {
    final cases = <(String, String, String)>[
      ('field_name', '', 'اسم الشاليه مطلوب'),
      ('field_name', 'ا' * 101, 'الاسم طويل (الحد الأقصى 100 حرف)'),
      ('field_description', '', 'وصف الشاليه مطلوب'),
      ('field_description', 'ا' * 2001, 'الوصف طويل (الحد الأقصى 2000 حرف)'),
      ('field_max_guests', '', 'أدخل عدداً صحيحاً بين 1 و200'),
      ('field_max_guests', '0', 'أدخل عدداً صحيحاً بين 1 و200'),
      ('field_max_guests', '-3', 'أدخل عدداً صحيحاً بين 1 و200'),
      ('field_max_guests', '201', 'أدخل عدداً صحيحاً بين 1 و200'),
      ('field_max_guests', '3.5', 'أدخل عدداً صحيحاً بين 1 و200'),
      ('field_price_per_night', '', 'أدخل سعراً أكبر من صفر'),
      ('field_price_per_night', '0', 'أدخل سعراً أكبر من صفر'),
      ('field_price_per_night', '-50', 'أدخل سعراً أكبر من صفر'),
      ('field_price_per_night', 'abc', 'أدخل سعراً أكبر من صفر'),
      ('field_price_per_night', '100001', 'سعر غير منطقي'),
      ('field_location', 'ا' * 101, 'النص طويل (الحد الأقصى 100 حرف)'),
      ('field_address', 'ا' * 201, 'النص طويل (الحد الأقصى 200 حرف)'),
      ('field_video_url', 'https://example.com/v', 'يرجى إدخال رابط يوتيوب صحيح'),
      ('field_video_url', 'مش رابط', 'يرجى إدخال رابط يوتيوب صحيح'),
    ];

    for (final c in cases) {
      testWidgets('${c.$1} ← "${c.$2.length > 12 ? '${c.$2.substring(0, 12)}…' : c.$2}"',
          (tester) async {
        final ds = _fake();
        await pumpEditScreen(tester, ds);

        await _type(tester, c.$1, c.$2);
        expect(find.text(c.$3), findsOneWidget);

        // الحفظ ممنوع ولا يصل شيء للسيرفر
        await _tap(tester, 'saveButton');
        expect(find.text('راجع الحقول المعلَّمة (1)'), findsOneWidget);
        expect(ds.updates, isEmpty);
        expect(ds.log, isEmpty);
      });
    }

    testWidgets('إحداثيات: أحدهما فقط', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_latitude', '');
      expect(
          find.text('أدخل خط العرض وخط الطول معاً أو اتركهما فارغين'),
          findsOneWidget);
      await _tap(tester, 'saveButton');
      expect(ds.updates, isEmpty);
    });

    testWidgets('إحداثيات: غير صالحة (رقم، نطاق، صفر)', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);

      await _type(tester, 'field_latitude', 'abc');
      expect(find.text('إحداثيات غير صالحة'), findsOneWidget);

      await _type(tester, 'field_latitude', '91');
      expect(find.text('إحداثيات غير صالحة'), findsOneWidget);

      await _type(tester, 'field_latitude', '32.2');
      await _type(tester, 'field_longitude', '181');
      expect(find.text('إحداثيات غير صالحة'), findsOneWidget);

      await _type(tester, 'field_latitude', '0');
      await _type(tester, 'field_longitude', '0');
      expect(find.text('إحداثيات غير صالحة'), findsNWidgets(2));

      await _tap(tester, 'saveButton');
      expect(ds.updates, isEmpty);
    });

    testWidgets('إحداثيات خارج فلسطين: تحذير غير مانع والحفظ يمرّ',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_latitude', '10');
      await _type(tester, 'field_longitude', '10');

      expect(_k('coordsWarning'), findsOneWidget);
      expect(find.textContaining('لن يظهر الشاليه على خريطة فلسطين'),
          findsOneWidget);
      expect(find.text('إحداثيات غير صالحة'), findsNothing);

      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'latitude': 10.0, 'longitude': 10.0}
      ]);
    });

    testWidgets('حذف كل الصور: أضف صورة واحدة على الأقل', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      for (var i = 0; i < 3; i++) {
        await tester.tap(_k('imgDelete_0'));
        await tester.pump();
      }
      expect(find.text('أضف صورة واحدة على الأقل'), findsOneWidget);
      await _tap(tester, 'saveButton');
      expect(ds.updates, isEmpty);
      expect(ds.log, isEmpty);
    });

    testWidgets('الأرقام العربية مقبولة وتُحفظ لاتينية', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_max_guests', '٥');
      expect(find.text('أدخل عدداً صحيحاً بين 1 و200'), findsNothing);
      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'max_guests': 5}
      ]);
    });

    testWidgets('حقل لم يُلمس وبياناته القديمة ناقصة لا يمنع تعديلاً آخر',
        (tester) async {
      final ds = _fake(overrides: {'description': ''});
      await pumpEditScreen(tester, ds);
      // لا خطأ ظاهر على الوصف الفارغ القديم
      expect(find.text('وصف الشاليه مطلوب'), findsNothing);

      await _type(tester, 'field_name', 'اسم جديد');
      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'name': 'اسم جديد'}
      ]);
    });
  });

  // ==========================================================
  group('الحفظ بالفروقات والتحقق من التطبيق', () {
    testWidgets('تغيير الاسم فقط يرسل الاسم فقط', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'شاليه جديد');
      await _tap(tester, 'saveButton');

      expect(ds.updates, [
        {'name': 'شاليه جديد'}
      ]);
      expect(find.text('تم حفظ التعديلات'), findsOneWidget);
      expect(_k('dirtyBarText'), findsNothing);
      expect(find.text('تعديل: شاليه جديد'), findsOneWidget);
    });

    testWidgets('عدة تعديلات: كل مفتاح بقيمته، ولا يُرسل عمود غير مسموح',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);

      await _type(tester, 'field_price_per_night', '900.5');
      await _tap(tester, 'bedroomsPlus');
      await _tap(tester, 'amenity_has_bbq');
      await _tap(tester, 'amenity_has_wifi');
      await tester.tap(_k('availableSwitch'));
      await tester.pumpAndSettle();
      await _type(tester, 'field_address', 'شارع الجامعة');
      await _tap(tester, 'saveButton');

      expect(ds.updates, hasLength(1));
      final u = ds.updates.single;
      expect(u, {
        'price_per_night': 900.5,
        'bedrooms': 4,
        'has_bbq': true,
        'has_wifi': false,
        'is_available': false,
        'address': 'شارع الجامعة',
      });
      expect(chaletEditableColumns.containsAll(u.keys), isTrue);
      for (final banned in [
        'owner_id',
        'is_approved',
        'is_featured',
        'rating',
        'reviews_count',
        'updated_at',
        'booking_type',
        'min_nights',
        'deposit_amount',
      ]) {
        expect(u.containsKey(banned), isFalse, reason: banned);
      }
    });

    testWidgets('مسح المنطقة يعيدها لاسم المدينة (كما تفعل شاشة الإضافة)',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_location', '');
      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'location': 'نابلس'}
      ]);
    });

    testWidgets('حقل location لم يُلمس لا يُرسل حتى لو كان فارغاً بالقاعدة',
        (tester) async {
      final ds = _fake(overrides: {'location': null});
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'س');
      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'name': 'س'}
      ]);
    });

    testWidgets('مسح الإحداثيات كلياً يرسل null للاثنين', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_latitude', '');
      await _type(tester, 'field_longitude', '');
      expect(find.text('أدخل خط العرض وخط الطول معاً أو اتركهما فارغين'),
          findsNothing);
      await _tap(tester, 'saveButton');
      expect(ds.updates, [
        {'latitude': null, 'longitude': null}
      ]);
    });

    testWidgets('التحديث يرجع null (رفض RLS): فشل صريح والمسودة باقية',
        (tester) async {
      final ds = _fake()..updateReturnsNull = true;
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'اسم');
      await _tap(tester, 'saveButton');

      expect(
        find.text('لم تُحفظ التعديلات، ربما لا تملك صلاحية تعديل هذا الشاليه'),
        findsOneWidget,
      );
      expect(find.text('تم حفظ التعديلات'), findsNothing);
      expect(_k('dirtyBarText'), findsOneWidget); // المسودة لم تُمسح
      expect(_text(tester, 'field_name'), 'اسم');
    });

    testWidgets('خطأ شبكة: رسالة عربية والمسودة باقية', (tester) async {
      final ds = _fake()..throwOnUpdate = true;
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'اسم');
      await _tap(tester, 'saveButton');

      expect(find.text('تعذر الحفظ، تحقق من الاتصال وحاول مرة ثانية'),
          findsOneWidget);
      expect(_k('dirtyBarText'), findsOneWidget);
    });

    testWidgets('النقر المتكرر على حفظ لا يرسل مرتين', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'اسم');
      await tester.tap(_k('saveButton'));
      await tester.tap(_k('saveButton'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(ds.updates, hasLength(1));
    });

    testWidgets('سعر الشاليه: تنبيه ثابت النص عند تغييره فقط', (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(_k('priceChangeNotice'), findsNothing);

      await _type(tester, 'field_price_per_night', '900');
      expect(_k('priceChangeNotice'), findsOneWidget);
      expect(find.text('تغيير السعر سيؤثر على الأيام التي بلا سعر مضبوط.'),
          findsOneWidget);

      await _type(tester, 'field_price_per_night', 'abc'); // غير صالح
      expect(_k('priceChangeNotice'), findsNothing);

      await _type(tester, 'field_price_per_night', '800'); // رجوع للأصل
      expect(_k('priceChangeNotice'), findsNothing);
      expect(_k('dirtyBarText'), findsNothing);
    });

    testWidgets('مدينة خارج القائمة تبقى ولا تتغير بصمت', (tester) async {
      final ds = _fake(overrides: {'city': 'الناصرة'});
      await pumpEditScreen(tester, ds);
      expect(find.text('الناصرة'), findsWidgets);

      await _type(tester, 'field_name', 'اسم');
      await _tap(tester, 'saveButton');
      expect(ds.updates.single.containsKey('city'), isFalse);
    });

    testWidgets('تحديث الموقع: تأكيد ثم تعبئة الحقلين بلا حفظ تلقائي',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(
        tester,
        ds,
        locate: () async => (latitude: 32.5, longitude: 35.5),
      );
      await _tap(tester, 'useMyLocation');
      expect(find.text('تحديث الموقع'), findsOneWidget);
      expect(find.textContaining('هل أنت الآن عند الشاليه؟'), findsOneWidget);
      await _tap(tester, 'dialogConfirm');

      expect(_text(tester, 'field_latitude'), '32.500000');
      expect(_text(tester, 'field_longitude'), '35.500000');
      expect(ds.updates, isEmpty);
      expect(_k('dirtyBarText'), findsOneWidget);
    });

    testWidgets('تحديث الموقع: الإلغاء لا يغيّر شيئاً، وفشل GPS رسالة',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds, locate: () async => null);
      await _tap(tester, 'useMyLocation');
      await _tap(tester, 'dialogCancel');
      expect(_text(tester, 'field_latitude'), '32.2211');

      await _tap(tester, 'useMyLocation');
      await _tap(tester, 'dialogConfirm');
      expect(
        find.text('تعذر الوصول لموقعك، تأكد من تفعيل GPS ومنح صلاحية الموقع'),
        findsOneWidget,
      );
      expect(_text(tester, 'field_latitude'), '32.2211');
    });
  });

  // ==========================================================
  group('حماية التعديلات غير المحفوظة', () {
    testWidgets('لا شريط بلا تعديل، ويظهر مع العدّاد ونقطة القسم',
        (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(_k('dirtyBarText'), findsNothing);

      await _type(tester, 'field_name', 'جديد');
      expect(find.text('لديك 1 تعديل غير محفوظ'), findsOneWidget);
      expect(_k('sectionDot_basic'), findsOneWidget);
      expect(_k('sectionDot_capacity'), findsNothing);
      expect(find.text('لم يُحفظ'), findsWidgets);

      await _tap(tester, 'bathroomsPlus');
      expect(find.text('لديك 2 تعديل غير محفوظ'), findsOneWidget);
      expect(_k('sectionDot_capacity'), findsOneWidget);
    });

    testWidgets('إعادة الحقل لقيمته الأصلية تُلغي حالة التعديل',
        (tester) async {
      await pumpEditScreen(tester, _fake());
      await _type(tester, 'field_name', 'x');
      expect(_k('dirtyBarText'), findsOneWidget);
      await _type(tester, 'field_name', 'شاليه الندى');
      expect(_k('dirtyBarText'), findsNothing);

      // 800 مقابل 800.0 ليس تعديلاً
      await _type(tester, 'field_price_per_night', '800.0');
      expect(_k('dirtyBarText'), findsNothing);
    });

    testWidgets('تجاهل الكل: تأكيد ثم رجوع كل شيء للمحفوظ', (tester) async {
      await pumpEditScreen(tester, _fake());
      await _type(tester, 'field_name', 'x');
      await _tap(tester, 'bedroomsPlus');
      await tester.tap(_k('imgDelete_0'));
      await tester.pump();

      await _tap(tester, 'discardAllButton');
      expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
      await _tap(tester, 'dialogConfirm');

      expect(_text(tester, 'field_name'), 'شاليه الندى');
      expect(tester.widget<Text>(_k('bedroomsValue')).data, '3');
      expect(_tileCount(tester), 3);
      expect(_k('dirtyBarText'), findsNothing);
    });

    testWidgets('الخروج مع تعديلات: حوار، البقاء يُبقي الشاشة', (tester) async {
      final h = await pumpEditScreen(tester, _fake());
      await _type(tester, 'field_name', 'x');

      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('تعديلات غير محفوظة'), findsOneWidget);
      expect(find.textContaining('عندك 1 تعديل'), findsOneWidget);

      await _tap(tester, 'leaveStay');
      expect(find.byType(OwnerEditChaletScreen), findsOneWidget);
      expect(_text(tester, 'field_name'), 'x');
    });

    testWidgets('تجاهل وخروج: يغلق بدون حفظ', (tester) async {
      final ds = _fake();
      final h = await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'x');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _tap(tester, 'leaveDiscard');

      expect(find.byType(OwnerEditChaletScreen), findsNothing);
      expect(ds.updates, isEmpty);
    });

    testWidgets('حفظ وخروج: يحفظ ثم يغلق', (tester) async {
      final ds = _fake();
      final h = await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', 'x');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _tap(tester, 'leaveSave');

      expect(ds.updates, [
        {'name': 'x'}
      ]);
      expect(find.byType(OwnerEditChaletScreen), findsNothing);
    });

    testWidgets('حفظ وخروج مع خطأ تحقق: يبقى ولا يفقد شيئاً', (tester) async {
      final ds = _fake();
      final h = await pumpEditScreen(tester, ds);
      await _type(tester, 'field_name', '');
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      await _tap(tester, 'leaveSave');

      expect(find.byType(OwnerEditChaletScreen), findsOneWidget);
      expect(ds.updates, isEmpty);
      expect(find.text('اسم الشاليه مطلوب'), findsOneWidget);
    });

    testWidgets('بلا تعديلات: الخروج مباشر بلا حوار', (tester) async {
      final h = await pumpEditScreen(tester, _fake());
      h.navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(OwnerEditChaletScreen), findsNothing);
      expect(find.text('تعديلات غير محفوظة'), findsNothing);
    });
  });

  // ==========================================================
  group('مسودة الصور: إضافة وحذف وغلاف', () {
    final sigsOriginal = [
      chaletImageUrl('a'),
      chaletImageUrl('b'),
      chaletImageUrl('c'),
    ];

    testWidgets('الحالة الأولى: 3 صور، الأولى غلاف، ولا تعديل', (tester) async {
      await pumpEditScreen(tester, _fake());
      expect(_tileCount(tester), 3);
      expect(_imageSigs(tester), sigsOriginal);
      expect(find.text('الصور (3/8)'), findsOneWidget);
      expect(_k('coverBadge'), findsOneWidget);
      expect(_k('imgCover_0'), findsNothing);
      expect(_k('imgCover_1'), findsOneWidget);
      expect(_k('imagesDirty'), findsNothing);
    });

    testWidgets('إضافة صورتين: تظهران "جديدة" ويصير تعديلاً واحداً',
        (tester) async {
      await pumpEditScreen(
        tester,
        _fake(),
        pickImages: () async =>
            [testXFile('n1.jpg'), testXFile('n2.png', mime: 'image/png')],
      );
      await _tap(tester, 'imgAdd');

      expect(_tileCount(tester), 5);
      expect(find.text('الصور (5/8)'), findsOneWidget);
      expect(find.text('جديدة'), findsNWidgets(2));
      expect(_k('imagesDirty'), findsOneWidget);
      expect(find.text('لديك 1 تعديل غير محفوظ'), findsOneWidget);
      expect(_k('sectionDot_media'), findsOneWidget);
    });

    testWidgets('الحد الأقصى 8: تُضاف المتاحة فقط مع رسالة، ويختفي زر الإضافة',
        (tester) async {
      await pumpEditScreen(
        tester,
        _fake(),
        pickImages: () async => [
          for (var i = 0; i < 6; i++) testXFile('n$i.jpg'),
        ],
      );
      await _tap(tester, 'imgAdd');

      expect(_tileCount(tester), 8);
      expect(find.text('الصور (8/8)'), findsOneWidget);
      expect(_k('imgAdd'), findsNothing);
      expect(find.textContaining('الحد الأقصى 8 صور'), findsWidgets);
    });

    testWidgets('صورة أكبر من 10MB مرفوضة برسالة ولا تُضاف', (tester) async {
      await pumpEditScreen(
        tester,
        _fake(),
        pickImages: () async => [
          testXFile('big.jpg', bytes: 10 * 1024 * 1024 + 1),
          testXFile('ok.jpg'),
        ],
      );
      await _tap(tester, 'imgAdd');

      expect(_tileCount(tester), 4); // 3 + الصالحة فقط
      expect(find.text('الصورة "big.jpg" أكبر من 10 ميغابايت'),
          findsOneWidget);
    });

    testWidgets('صيغة غير مدعومة مرفوضة برسالة', (tester) async {
      await pumpEditScreen(
        tester,
        _fake(),
        pickImages: () async => [testXFile('x.gif', mime: 'image/gif')],
      );
      await _tap(tester, 'imgAdd');
      expect(_tileCount(tester), 3);
      expect(
        find.text(
            'صيغة الصورة "x.gif" غير مدعومة (المسموح: JPG وPNG وWEBP وHEIC)'),
        findsOneWidget,
      );
    });

    testWidgets('حذف صورة موجودة: تنقص وتصير تعديلاً، والغلاف كما هو',
        (tester) async {
      await pumpEditScreen(tester, _fake());
      await _tap(tester, 'imgDelete_1');

      expect(_tileCount(tester), 2);
      expect(_imageSigs(tester), [sigsOriginal[0], sigsOriginal[2]]);
      expect(find.text('الصور (2/8)'), findsOneWidget);
      expect(_k('imagesDirty'), findsOneWidget);
    });

    testWidgets('اجعلها الغلاف: تنتقل للأول والترتيب يتبدل', (tester) async {
      await pumpEditScreen(tester, _fake());
      await _tap(tester, 'imgCover_2');

      expect(_imageSigs(tester),
          [sigsOriginal[2], sigsOriginal[0], sigsOriginal[1]]);
      expect(_k('imagesDirty'), findsOneWidget);

      // وإعادتها للأصل تُلغي حالة التعديل
      await _tap(tester, 'imgCover_2');
      await _tap(tester, 'imgCover_2');
      expect(_imageSigs(tester), sigsOriginal);
      expect(_k('imagesDirty'), findsNothing);
    });

    testWidgets('حفظ تغيير الغلاف فقط: تحديث الترتيب بلا رفع ولا حذف',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _tap(tester, 'imgCover_2');
      await _tap(tester, 'saveButton');

      expect(ds.log, ['update']);
      expect(ds.updates.single['images'],
          [sigsOriginal[2], sigsOriginal[0], sigsOriginal[1]]);
      expect(ds.deletedUrls, isEmpty);
    });

    testWidgets('حذف صورة ثم حفظ: تحديث الصف أولاً ثم حذف الملف المزال',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds);
      await _tap(tester, 'imgDelete_1');
      await _tap(tester, 'saveButton');

      expect(ds.log, ['update', 'delete']); // التحديث قبل الحذف
      expect(ds.updates.single['images'], [sigsOriginal[0], sigsOriginal[2]]);
      expect(ds.deletedUrls, [
        [sigsOriginal[1]]
      ]);
      expect(_tileCount(tester), 2);
      expect(_k('dirtyBarText'), findsNothing);
    });

    testWidgets('حذف صورة جديدة غير مرفوعة لا يستدعي أي حذف من التخزين',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds,
          pickImages: () async => [testXFile('n1.jpg')]);
      await _tap(tester, 'imgAdd');
      expect(_tileCount(tester), 4);
      await _tap(tester, 'imgDelete_3');
      expect(_tileCount(tester), 3);
      expect(_k('dirtyBarText'), findsNothing);
      expect(ds.log, isEmpty);
    });

    testWidgets('إضافة ثم حفظ: رفع ← تحديث بالترتيب (الموجودة ثم الجديدة)',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(
        tester,
        ds,
        pickImages: () async => [testXFile('n1.jpg'), testXFile('n2.jpg')],
      );
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'saveButton');

      expect(ds.log, ['upload 2', 'update']);
      expect(ds.updates.single['images'], [
        ...sigsOriginal,
        chaletImageUrl('new_0'),
        chaletImageUrl('new_1'),
      ]);
      expect(ds.deletedUrls, isEmpty);
      // بعد الحفظ كلها صارت روابط محفوظة (لا "جديدة")
      expect(find.text('جديدة'), findsNothing);
      expect(_tileCount(tester), 5);
    });

    testWidgets('جديدة كغلاف + حذف موجودة: الترتيب النهائي والحذف صحيحان',
        (tester) async {
      final ds = _fake();
      await pumpEditScreen(
        tester,
        ds,
        pickImages: () async => [testXFile('n1.jpg')],
      );
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'imgCover_3'); // الجديدة صارت الأولى
      await _tap(tester, 'imgDelete_2'); // حذف b (كانت الثانية بعد التبديل)
      await _tap(tester, 'saveButton');

      expect(ds.log, ['upload 1', 'update', 'delete']);
      expect(ds.updates.single['images'],
          [chaletImageUrl('new_0'), sigsOriginal[0], sigsOriginal[2]]);
      expect(ds.deletedUrls, [
        [sigsOriginal[1]]
      ]);
    });

    testWidgets('فشل رفع صورة: لا تحديث، يُحذف ما رُفع، والمسودة كاملة',
        (tester) async {
      final ds = _fake()..uploadFailCount = 1;
      await pumpEditScreen(
        tester,
        ds,
        pickImages: () async => [testXFile('n1.jpg'), testXFile('n2.jpg')],
      );
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'saveButton');

      expect(ds.updates, isEmpty);
      expect(ds.log, ['upload 2', 'delete']);
      expect(ds.deletedUrls, [
        [chaletImageUrl('new_0')]
      ]);
      expect(find.text('تعذر رفع 1 من الصور، لم تُحفظ التعديلات'),
          findsOneWidget);
      expect(_tileCount(tester), 5); // لم تُسقط الصورة بصمت
      expect(_k('dirtyBarText'), findsOneWidget);
    });

    testWidgets('رفض الـRLS بعد الرفع: يُحذف الملف المرفوع ولا يُحذف الأصلي',
        (tester) async {
      final ds = _fake()..updateReturnsNull = true;
      await pumpEditScreen(tester, ds,
          pickImages: () async => [testXFile('n1.jpg')]);
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'imgDelete_0');
      await _tap(tester, 'saveButton');

      expect(ds.log, ['upload 1', 'update', 'delete']);
      // المحذوف هو المرفوع للتو فقط، لا الصورة الأصلية التي حذفها المالك
      expect(ds.deletedUrls, [
        [chaletImageUrl('new_0')]
      ]);
    });

    testWidgets('خطأ شبكة عند التحديث بعد الرفع: تنظيف المرفوع', (tester) async {
      final ds = _fake()..throwOnUpdate = true;
      await pumpEditScreen(tester, ds,
          pickImages: () async => [testXFile('n1.jpg')]);
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'saveButton');

      expect(ds.log, ['upload 1', 'update', 'delete']);
      expect(ds.deletedUrls, [
        [chaletImageUrl('new_0')]
      ]);
      expect(find.text('تعذر الحفظ، تحقق من الاتصال وحاول مرة ثانية'),
          findsOneWidget);
    });

    testWidgets('التجاهل يعيد الصور الأصلية بترتيبها', (tester) async {
      final ds = _fake();
      await pumpEditScreen(tester, ds,
          pickImages: () async => [testXFile('n1.jpg')]);
      await _tap(tester, 'imgAdd');
      await _tap(tester, 'imgCover_3');
      await _tap(tester, 'imgDelete_2');
      await _tap(tester, 'discardAllButton');
      await _tap(tester, 'dialogConfirm');

      expect(_imageSigs(tester), sigsOriginal);
      expect(_k('dirtyBarText'), findsNothing);
      expect(ds.log, isEmpty);
    });
  });

  // ==========================================================
  group('مقياس النص الكبير (لا قص ولا overflow)', () {
    // تمرير فعلي عبر كل الصفحة: ListView كسول فلا يُبنى إلا المرئي.
    Future<void> scrollThrough(WidgetTester t) async {
      final list = find.byType(ListView);
      for (var i = 0; i < 14; i++) {
        await t.drag(list, const Offset(0, -700));
        await t.pump();
      }
      for (var i = 0; i < 14; i++) {
        await t.drag(list, const Offset(0, 700));
        await t.pump();
      }
    }

    for (final scale in [1.5, 2.0]) {
      testWidgets('عرض 360 ومقياس $scale: كل الأقسام بلا استثناء تخطيط',
          (tester) async {
        final ds = _fake();
        await pumpEditScreen(tester, ds,
            width: 360, height: 2400, textScale: scale);

        // حالة أصعب: أخطاء وتعديلات وتحذيرات ظاهرة معاً
        await _type(tester, 'field_name', '');
        await tester.pumpAndSettle();
        expect(find.text('اسم الشاليه مطلوب'), findsOneWidget);
        await scrollThrough(tester);

        Future<void> reveal(String key) async {
          await tester.scrollUntilVisible(_k(key), 300,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
        }

        await reveal('field_latitude');
        await _type(tester, 'field_latitude', '10');
        await _type(tester, 'field_longitude', '10');
        expect(_k('coordsWarning'), findsOneWidget);

        await reveal('field_video_url');
        await _type(tester, 'field_video_url', 'x');
        expect(find.text('يرجى إدخال رابط يوتيوب صحيح'), findsOneWidget);

        await reveal('field_price_per_night');
        await _type(tester, 'field_price_per_night', '900');
        expect(_k('priceChangeNotice'), findsOneWidget);

        await scrollThrough(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_k('dirtyBarText'), findsOneWidget);
      });
    }

    testWidgets('لا ارتفاع ثابت يقصّ النص: بلاطات المرافق تكبر مع الخط',
        (tester) async {
      await pumpEditScreen(tester, _fake(), width: 390, height: 3000);
      final small = tester.getSize(_k('amenity_has_wifi')).height;

      await pumpEditScreen(tester, _fake(),
          width: 390, height: 3000, textScale: 2.0);
      // بلاطة "واي فاي" أقصر من ضعف الأصغر لو لم تكبر، فنشترط نمواً فعلياً
      final big = tester.getSize(_k('amenity_has_wifi')).height;
      expect(big, greaterThan(small));
    });
  });

  // ==========================================================
  group('شاشة الإضافة (فحص المصدر: تعديل نصي وإخفاء حقلين)', () {
    final src =
        File('lib/presentation/screens/owner/chalet_form/owner_add_chalet_screen.dart')
            .readAsStringSync();

    test('حقلا الوديعة والحد الأدنى للليالي غير موجودين', () {
      expect(src.contains('مبلغ الوديعة'), isFalse);
      expect(src.contains('الحد الأدنى للليالي'), isFalse);
      expect(src.contains('_depositCtrl'), isFalse);
      expect(src.contains('_minNightsCtrl'), isFalse);
    });

    test('الحمولة لا ترسل min_nights ولا deposit_amount', () {
      expect(src.contains("'min_nights'"), isFalse);
      expect(src.contains("'deposit_amount'"), isFalse);
    });

    test('تسمية location موحّدة على المنطقة/الحي', () {
      expect(src.contains("label: 'المنطقة/الحي'"), isTrue);
      expect(src.contains("label: 'العنوان'"), isFalse);
    });

    test('لم تُضف أي كتابة جديدة لـ updated_at (تبقى كما كانت)', () {
      final count = "'updated_at'".allMatches(src).length;
      expect(count, 1);
    });
  });
}
