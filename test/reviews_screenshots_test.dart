// لقطات شاشة لواجهة التقييمات بعرض 390 (منطقي، بكثافة 2×).
//
// تنبيه: كل البيانات تجريبية داخل هذا الاختبار وليست من قاعدة البيانات.
// الخط Segoe UI من نظام Windows بديلاً عن Cairo، والثيم مبسّط (AppTheme
// يجلب Cairo من الشبكة). تُحفظ في build/reviews_screenshots/.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/core/constants/app_colors.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/presentation/screens/reviews/reviews_screen.dart';
import 'package:makan/presentation/widgets/reviews/write_review_sheet.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

const _outDir = 'build/reviews_screenshots';
final _boundary = GlobalKey();

final _theme = ThemeData(
  fontFamily: 'Cairo',
  scaffoldBackgroundColor: AppColors.scaffold,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.scaffold,
    foregroundColor: AppColors.charcoal,
    centerTitle: true,
    titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.charcoal),
  ),
);

ReviewModel _r(String id, int rating, String name, int daysAgo,
        {String? comment, bool verified = true}) =>
    ReviewModel(
      id: id,
      chaletId: 'c1',
      userId: 'user-$name',
      bookingId: verified ? 'b-$id' : null,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 2)),
      userName: name,
    );

final _reviews = [
  _r('1', 5, 'رنا حداد', 3,
      comment: 'مكان هادئ ونظيف جداً، المسبح رائع والأطفال استمتعوا كثيراً. '
          'صاحب الشاليه متعاون وسريع الرد. الإطلالة على الجبال ساحرة وقت '
          'الغروب، وكل التفاصيل كانت كما في الصور تماماً. أنصح به للعائلات '
          'التي تبحث عن يوم هادئ بعيداً عن ضجيج المدينة.'),
  _r('2', 4, 'محمد خليل', 12, comment: 'تجربة جميلة، المطبخ يحتاج بعض الأدوات.'),
  _r('3', 5, 'سارة', 40, verified: false),
];

final _booking = BookingModel(
  id: 'bk1',
  chaletId: 'c1',
  userId: 'u1',
  checkIn: DateTime(2030, 3, 14),
  checkOut: DateTime(2030, 3, 15),
  guestsCount: 4,
  totalPrice: 400,
  status: BookingStatus.completed,
  createdAt: DateTime(2030, 3, 1),
  chaletName: 'شاليه الزيتون',
  stayType: 'morning',
);

Future<void> _app(WidgetTester tester, Widget home, {bool settle = true}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      locale: const Locale('ar'),
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: home,
    ),
  ));
  // الهياكل (shimmer) تتحرك بلا توقف فلا "تستقر".
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 800));
  final boundary =
      _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

ReviewsScreenSource _source(
        {required ReviewSummary summary,
        List<ReviewModel> page = const [],
        BookingModel? awaiting}) =>
    ReviewsScreenSource(
      summary: (_) async => summary,
      page: (_, __, ___) async => page,
      awaitingReview: (_) async => awaiting,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await loadArabicTestFont();
  });

  testWidgets('كل التقييمات', (tester) async {
    await _app(
        tester,
        ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: _source(
            summary: ReviewSummary.fromRatings(
                [...List.filled(21, 5), ...List.filled(7, 4), 3, 3, 2, 1]),
            page: _reviews,
          ),
        ));
    await _capture(tester, '1_all_reviews');
    await tester.tap(find.text('قراءة المزيد'));
    await tester.pumpAndSettle();
    await _capture(tester, '2_read_more_expanded');
  });

  testWidgets('فارغة مع دعوة للتقييم', (tester) async {
    await _app(
        tester,
        ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: _source(summary: ReviewSummary.empty, awaiting: _booking),
        ));
    await _capture(tester, '3_empty');
  });

  testWidgets('التحميل', (tester) async {
    await _app(
        tester,
        ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: ReviewsScreenSource(
            summary: (_) async => ReviewSummary.fromRatings([5, 4]),
            // لا تكتمل (بلا مؤقت): تبقى الهياكل ظاهرة.
            page: (_, __, ___) => Completer<List<ReviewModel>>().future,
            awaitingReview: (_) async => null,
          ),
        ),
        settle: false);
    await _capture(tester, '4_loading');
  });

  testWidgets('ورقة كتابة التقييم', (tester) async {
    await _app(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showWriteReviewSheet(context,
                    booking: _booking, submit: (_, __) async {}),
                child: const Text('open'),
              ),
            ),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _capture(tester, '5_sheet_empty');
    await tester.tap(find.byKey(const Key('review_star_4')));
    await tester.enterText(find.byKey(const Key('review_comment')),
        'المكان جميل ونظيف، والإطلالة رائعة.');
    await tester.pumpAndSettle();
    await _capture(tester, '6_sheet_filled');
    await tester.tap(find.byKey(const Key('review_submit')));
    await tester.pumpAndSettle();
    await _capture(tester, '7_sheet_thanks');
  });
}
