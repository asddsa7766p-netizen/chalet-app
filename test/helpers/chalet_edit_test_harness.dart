import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:makan/presentation/screens/owner/chalet_edit_data_source.dart';
import 'package:makan/presentation/screens/owner/owner_edit_chalet_screen.dart';

import 'pricing_test_harness.dart' show testTheme;

const kOwnerId = 'owner-1';
const kChaletId = 'chalet-1';

String chaletImageUrl(String name, {String chaletId = kChaletId}) =>
    'https://x.supabase.co/storage/v1/object/public/chalet-images/chalets/$chaletId/$name.jpg';

/// صف شاليه نموذجي (بيانات تجريبية داخل الاختبار فقط).
Map<String, dynamic> sampleChaletRow({
  String ownerId = kOwnerId,
  bool approved = true,
  Map<String, dynamic> overrides = const {},
}) =>
    {
      'id': kChaletId,
      'owner_id': ownerId,
      'name': 'شاليه الندى',
      'description': 'شاليه هادئ بإطلالة جميلة ومسبح خاص وجلسات خارجية.',
      'location': 'بيتا',
      'city': 'نابلس',
      'address': null,
      'price_per_night': 800,
      'max_guests': 10,
      'bedrooms': 3,
      'bathrooms': 2,
      'has_pool': true,
      'has_wifi': true,
      'has_bbq': false,
      'has_parking': true,
      'is_available': true,
      'is_approved': approved,
      'is_featured': false,
      'rating': 4.5,
      'reviews_count': 3,
      'latitude': 32.2211,
      'longitude': 35.2544,
      'booking_type': 'يومي',
      'min_nights': 2,
      'deposit_amount': 50,
      'images': [
        chaletImageUrl('a'),
        chaletImageUrl('b'),
        chaletImageUrl('c'),
      ],
      'video_url': null,
      'updated_at': '2026-01-01T00:00:00Z',
      ...overrides,
    };

class FakeChaletEditDataSource implements ChaletEditDataSource {
  FakeChaletEditDataSource({
    Map<String, dynamic>? row,
    this.userId = kOwnerId,
    this.failFetchTimes = 0,
  }) : row = row == null ? null : {...row};

  Map<String, dynamic>? row;
  String? userId;
  int failFetchTimes;

  /// null من updateChalet (محاكاة رفض RLS: صفر صفوف بلا خطأ).
  bool updateReturnsNull = false;
  bool throwOnUpdate = false;

  /// عدد الصور التي "تفشل" برفعها (تُحذف من نهاية القائمة الراجعة).
  int uploadFailCount = 0;

  final List<String> log = [];
  final List<Map<String, dynamic>> updates = [];
  final List<List<String>> deletedUrls = [];
  List<String> lastUploaded = [];
  int fetches = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, dynamic>?> fetchChalet(String chaletId) async {
    fetches++;
    if (failFetchTimes > 0) {
      failFetchTimes--;
      throw Exception('network');
    }
    return row == null ? null : {...row!};
  }

  @override
  Future<List<String>> uploadImages(
    String chaletId,
    List<XFile> files,
    List<Uint8List> bytes,
  ) async {
    log.add('upload ${files.length}');
    final urls = [
      for (var i = 0; i < files.length; i++) chaletImageUrl('new_$i'),
    ];
    final ok = urls.take(files.length - uploadFailCount).toList();
    lastUploaded = ok;
    return ok;
  }

  @override
  Future<Map<String, dynamic>?> updateChalet(
    String chaletId,
    Map<String, dynamic> changes,
  ) async {
    log.add('update');
    updates.add({...changes});
    if (throwOnUpdate) throw Exception('network');
    if (updateReturnsNull) return null;
    row = {...?row, ...changes};
    return {...row!};
  }

  @override
  Future<void> deleteImageUrls(String chaletId, List<String> urls) async {
    log.add('delete');
    deletedUrls.add([...urls]);
  }
}

/// PNG صغير ملوّن (لإظهار صور جديدة بلقطات الاختبار).
Future<Uint8List> makeTestPng(Color a, Color b, {int size = 96}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.toDouble(), size.toDouble()),
      [a, b],
    );
  canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
  final image =
      await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// PNG 1×1 صالح للفك (base64).
final Uint8List _tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// ملف صورة اختباري. بلا [bytes] يكون PNG صالحاً؛ مع [bytes] يكون ملء
/// بحجم محدد (لاختبار حد الحجم فقط، غير قابل للفك).
XFile testXFile(String name, {int? bytes, String? mime}) => XFile.fromData(
      bytes == null ? _tinyPng : (Uint8List(bytes)..fillRange(0, bytes, 7)),
      path: name,
      name: name,
      mimeType: mime ?? 'image/jpeg',
    );

class EditHarness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey boundaryKey = GlobalKey();
}

/// يشغّل شاشة التعديل داخل تطبيق (عربي/RTL) بالعرض المطلوب.
/// الارتفاع الكبير الافتراضي يُظهر كل الحقول بلا تمرير؛ باللقطات يُستخدم
/// ارتفاع الجهاز.
Future<EditHarness> pumpEditScreen(
  WidgetTester tester,
  ChaletEditDataSource ds, {
  double width = 390,
  double height = 4200,
  double textScale = 1.0,
  PickChaletImages? pickImages,
  LocateChalet? locate,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(width * 2, height * 2);
  addTearDown(tester.view.reset);

  final h = EditHarness();
  await tester.pumpWidget(
    RepaintBoundary(
      key: h.boundaryKey,
      child: MaterialApp(
        navigatorKey: h.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: testTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
              textDirection: TextDirection.rtl, child: child!),
        ),
        home: const SizedBox.shrink(),
      ),
    ),
  );

  h.navigatorKey.currentState!.push(MaterialPageRoute<void>(
    builder: (_) => OwnerEditChaletScreen(
      chaletId: kChaletId,
      dataSource: ds,
      pickImages: pickImages,
      locate: locate,
    ),
  ));
  await tester.pumpAndSettle();
  return h;
}
