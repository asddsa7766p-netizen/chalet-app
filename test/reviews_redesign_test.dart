import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:makan/core/utils/relative_time.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/presentation/screens/reviews/reviews_screen.dart';
import 'package:makan/presentation/widgets/reviews/review_widgets.dart';
import 'package:makan/presentation/widgets/reviews/write_review_sheet.dart';

final _now = DateTime(2030, 3, 20, 12);

ReviewModel _review(
  String id, {
  int rating = 5,
  String? comment,
  String? bookingId = 'b1',
  String? name = 'رنا حداد',
  DateTime? at,
}) =>
    ReviewModel(
      id: id,
      chaletId: 'c1',
      userId: 'u-$id',
      bookingId: bookingId,
      rating: rating,
      comment: comment,
      createdAt: at ?? _now.subtract(const Duration(days: 3)),
      userName: name,
    );

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

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ));

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('التاريخ النسبي والصيغ', () {
    String ago(Duration d) => relativeTimeAr(_now.subtract(d), now: _now);

    test('صيغ العدد العربية', () {
      expect(ago(const Duration(seconds: 20)), 'الآن');
      expect(ago(const Duration(minutes: 2)), 'منذ دقيقتين');
      expect(ago(const Duration(hours: 5)), 'منذ 5 ساعات');
      expect(ago(const Duration(days: 1)), 'أمس');
      expect(ago(const Duration(days: 3)), 'منذ 3 أيام');
      expect(ago(const Duration(days: 14)), 'منذ أسبوعين');
      expect(ago(const Duration(days: 90)), 'منذ 3 أشهر');
      expect(ago(const Duration(days: 400)), 'منذ سنة');
      expect(relativeTimeAr(_now.add(const Duration(hours: 1)), now: _now),
          'الآن');
    });

    test('عدد التقييمات وكلمة النجوم', () {
      expect(reviewsCountLabel(1), 'تقييم واحد');
      expect(reviewsCountLabel(2), 'تقييمان');
      expect(reviewsCountLabel(5), '5 تقييمات');
      expect(reviewsCountLabel(32), '32 تقييم');
      expect([for (var i = 1; i <= 5; i++) ratingWord(i)],
          ['سيء', 'مقبول', 'جيد', 'جيد جداً', 'ممتاز']);
    });
  });

  group('الملخص', () {
    test('المتوسط والتوزيع من كل التقييمات', () {
      final s = ReviewSummary.fromRatings([5, 5, 5, 4, 3]);
      expect(s.count, 5);
      expect(s.average, closeTo(4.4, 1e-9));
      expect(s.distribution, {5: 3, 4: 1, 3: 1, 2: 0, 1: 0});
      expect(s.share(5), 0.6);
      expect(ReviewSummary.fromRatings(const []).isEmpty, isTrue);
    });

    testWidgets('توزيع حقيقي: المتوسط والعدد ونسبة كل نجمة', (tester) async {
      await _pump(tester,
          ReviewSummaryView(summary: ReviewSummary.fromRatings([5, 5, 5, 4, 3])));
      await tester.pumpAndSettle();
      expect(find.text('4.4'), findsOneWidget);
      expect(find.text('5 تقييمات'), findsOneWidget);
      String share(int star) =>
          tester.widget<Text>(find.byKey(Key('review_share_$star'))).data!;
      expect([for (final s in [5, 4, 3, 2, 1]) share(s)],
          ['60%', '20%', '20%', '0%', '0%']);
    });

    testWidgets('الحالة الفارغة: لا "0.0" ولا أشرطة، بل دعوة للتقييم',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: ReviewsScreenSource(
            summary: (_) async => ReviewSummary.empty,
            page: (_, __, ___) async => const [],
            awaitingReview: (_) async => null,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد تقييمات بعد'), findsOneWidget);
      expect(find.text('كن أول من يقيّم بعد إقامتك'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.byType(ReviewSummaryView), findsNothing);
      expect(find.text('الأحدث'), findsNothing, reason: 'لا ترتيب بلا تقييمات');
    });
  });

  group('بطاقة التقييم', () {
    testWidgets('الاسم والحرف الأول والتاريخ النسبي وشارة الإقامة المؤكدة',
        (tester) async {
      await _pump(tester,
          ReviewCard(review: _review('r1', comment: 'مكان رائع'), now: _now));
      expect(find.text('رنا حداد'), findsOneWidget);
      expect(find.text('ر'), findsOneWidget);
      expect(find.text('منذ 3 أيام'), findsOneWidget);
      expect(find.text('إقامة مؤكدة'), findsOneWidget);
      expect(find.text('قراءة المزيد'), findsNothing, reason: 'نص قصير');
    });

    testWidgets('بلا حجز: لا شارة "إقامة مؤكدة"، وبلا اسم: "مستخدم"',
        (tester) async {
      await _pump(
          tester,
          ReviewCard(
              review: _review('r2', bookingId: null, name: '  '), now: _now));
      expect(find.text('إقامة مؤكدة'), findsNothing);
      expect(find.text('مستخدم'), findsOneWidget);
    });

    testWidgets('نص أطول من 3 أسطر يُطوى مع "قراءة المزيد" ثم "عرض أقل"',
        (tester) async {
      final long = List.filled(40, 'إقامة جميلة ومريحة جداً').join(' ');
      await _pump(tester,
          ReviewCard(review: _review('r3', comment: long), now: _now));
      final text = find.text(long);
      expect(tester.widget<Text>(text).maxLines, 3);
      await tester.tap(find.text('قراءة المزيد'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(text).maxLines, isNull);
      expect(find.text('عرض أقل'), findsOneWidget);
    });
  });

  group('ورقة كتابة التقييم', () {
    Future<List<(int, String?)>> pumpSheet(WidgetTester tester,
        {Future<void> Function()? result}) async {
      final calls = <(int, String?)>[];
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WriteReviewSheet(
              booking: _booking,
              submit: (rating, comment) async {
                calls.add((rating, comment));
                await (result ?? () async {})();
              },
            ),
          ),
        ),
      ));
      return calls;
    }

    ElevatedButton submit(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byKey(const Key('review_submit')));

    testWidgets('الشاليه وتاريخ الحجز، وزر الإرسال معطّل قبل النجوم',
        (tester) async {
      await pumpSheet(tester);
      expect(find.text('شاليه الزيتون'), findsOneWidget);
      expect(find.textContaining('إقامة صباحية'), findsOneWidget);
      expect(find.text('اختر عدد النجوم'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);
    });

    testWidgets('اختيار النجوم يغيّر الكلمة ويفعّل الإرسال', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('review_star_4')));
      await tester.pumpAndSettle();
      expect(find.text('جيد جداً'), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('review_star_1')));
      await tester.pumpAndSettle();
      expect(find.text('سيء'), findsOneWidget);
    });

    testWidgets('الإرسال يستدعي الخدمة بالنجوم والتعليق ثم رسالة شكر',
        (tester) async {
      final calls = await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('review_star_5')));
      await tester.enterText(
          find.byKey(const Key('review_comment')), '  نظيف وهادئ  ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_submit')));
      await tester.pumpAndSettle();
      expect(calls, [(5, 'نظيف وهادئ')]);
      expect(find.text('شكراً لتقييمك!'), findsOneWidget);
    });

    testWidgets('تعليق فارغ يُرسل null', (tester) async {
      final calls = await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('review_star_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_submit')));
      await tester.pumpAndSettle();
      expect(calls, [(3, null)]);
    });

    testWidgets('تقييم سابق لنفس الحجز: رسالة واضحة وتبقى الورقة',
        (tester) async {
      await pumpSheet(tester,
          result: () async => throw Exception('already_reviewed'));
      await tester.tap(find.byKey(const Key('review_star_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_submit')));
      await tester.pumpAndSettle();
      expect(find.text('لقد قيّمت هذه الإقامة من قبل'), findsOneWidget);
      expect(find.text('شكراً لتقييمك!'), findsNothing);
      expect(submit(tester).onPressed, isNotNull, reason: 'يمكن إعادة المحاولة');
    });

    testWidgets('showWriteReviewSheet يرجع true بعد الإرسال', (tester) async {
      late bool sent;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => sent = await showWriteReviewSheet(context,
                  booking: _booking, submit: (_, __) async {}),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_star_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_done')));
      await tester.pumpAndSettle();
      expect(sent, isTrue);
    });
  });

  group('شاشة كل التقييمات', () {
    testWidgets('الترتيب يعيد التحميل من الصفحة الأولى بالترتيب المختار',
        (tester) async {
      final requests = <(ReviewSort, int)>[];
      await tester.pumpWidget(MaterialApp(
        home: ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: ReviewsScreenSource(
            summary: (_) async => ReviewSummary.fromRatings([5, 2]),
            page: (_, sort, page) async {
              requests.add((sort, page));
              return [_review('r-${sort.name}', rating: 4)];
            },
            awaitingReview: (_) async => null,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2.0'), findsNothing);
      expect(find.text('3.5'), findsOneWidget);
      expect(requests, [(ReviewSort.newest, 0)]);

      await tester.tap(find.byKey(const Key('review_sort_lowest')));
      await tester.pumpAndSettle();
      expect(requests.last, (ReviewSort.lowest, 0));
      expect(find.byType(ReviewCard), findsOneWidget);
    });

    testWidgets('صفحات من 20: الوصول لنهاية القائمة يطلب الصفحة التالية',
        (tester) async {
      final pages = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: ReviewsScreen(
          chaletId: 'c1',
          chaletName: '',
          source: ReviewsScreenSource(
            summary: (_) async =>
                ReviewSummary.fromRatings(List.filled(25, 5)),
            page: (_, __, page) async {
              pages.add(page);
              final n = page == 0 ? 20 : 5;
              return [for (var i = 0; i < n; i++) _review('p$page-$i')];
            },
            awaitingReview: (_) async => null,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(pages, [0]);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(pages, [0, 1]);
    });

    testWidgets('إقامة بانتظار التقييم: زر "قيّم إقامتك"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ReviewsScreen(
          chaletId: 'c1',
          chaletName: 'شاليه الزيتون',
          source: ReviewsScreenSource(
            summary: (_) async => ReviewSummary.empty,
            page: (_, __, ___) async => const [],
            awaitingReview: (_) async => _booking,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reviews_write_cta')), findsOneWidget);
    });
  });
}
