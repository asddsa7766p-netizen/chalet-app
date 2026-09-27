import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/chalet_approval.dart';
import 'package:makan/data/services/admin_service.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/presentation/screens/owner/rejected_chalet_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

Map<String, dynamic> _row({
  bool approved = false,
  String? reason,
  String? rejectedAt,
}) =>
    {
      'id': 'ch1',
      'name': 'شاليه الندى',
      'is_approved': approved,
      'rejection_reason': reason,
      'rejected_at': rejectedAt,
    };

void main() {
  setUpAll(loadArabicTestFont);

  group('حالة الاعتماد', () {
    test('معتمد / بانتظار / مرفوض', () {
      expect(_row(approved: true).approvalStatus,
          ChaletApprovalStatus.approved);
      expect(_row().approvalStatus, ChaletApprovalStatus.pending);
      expect(
          _row(reason: 'x', rejectedAt: '2026-09-20T10:00:00Z')
              .approvalStatus,
          ChaletApprovalStatus.rejected);
      // المعتمد لا يُعد مرفوضاً حتى لو بقي تاريخ رفض قديم.
      expect(
          _row(approved: true, rejectedAt: '2026-09-20T10:00:00Z')
              .approvalStatus,
          ChaletApprovalStatus.approved);
    });

    test('سبب الرفض: الفراغ = null', () {
      expect(_row(reason: '  ').rejectionReason, isNull);
      expect(_row(reason: ' الصور غير واضحة ').rejectionReason,
          'الصور غير واضحة');
    });

  });

  group('رسائل السيرفر بـ translateSupabaseError', () {
    for (final m in [
      rejectReasonRequiredMessage,
      nothingToResubmitMessage,
      chaletNotFoundMessage,
    ]) {
      test(m, () {
        expect(
            translateSupabaseError(PostgrestException(message: m, code: 'P0001')),
            m);
        expect(translateSupabaseError(Exception('PostgrestException: $m')), m);
      });
    }
  });

  test('صف get_nearby_chalets: الشاليه من jsonb والمسافة بالكيلومتر', () {
    final n = NearbyChalet.fromRow({
      'chalet': {
        'id': 'c9',
        'name': 'شاليه القمر',
        'city': 'نابلس',
        'price_per_night': 350,
        'latitude': 32.22,
        'longitude': 35.25,
        'images': ['https://x/a.jpg'],
        'created_at': '2026-09-01T10:00:00+00:00',
      },
      'distance_km': 2.5,
    });
    expect(n.chalet.id, 'c9');
    expect(n.chalet.name, 'شاليه القمر');
    expect(n.chalet.pricePerNight, 350);
    expect(n.chalet.coverImage, 'https://x/a.jpg');
    expect(n.distanceKm, 2.5);
    expect(
        NearbyChalet.fromRow({
          'chalet': {'id': 'c1'},
          'distance_km': 0,
        }).distanceKm,
        0.0,
        reason: 'عدد صحيح من jsonb');
  });

  test('إحصائيات الأدمن: rejectedChalets (وصفر إن غاب المفتاح)', () {
    final s = AdminOverviewStats.fromJson(
        const {'pendingChalets': 2, 'rejectedChalets': 3});
    expect(s.pendingChalets, 2);
    expect(s.rejectedChalets, 3);
    expect(AdminOverviewStats.fromJson(const {}).rejectedChalets, 0);
  });

  group('بطاقة الشاليه المرفوض (شاليهاتي)', () {
    Future<({List<int> edits, List<int> sends, List<int> done})> pump(
      WidgetTester tester, {
      Future<void> Function()? resubmit,
    }) async {
      final edits = <int>[];
      final sends = <int>[];
      final done = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RejectedChaletCard(
            chalet: _row(
                reason: 'الصور غير واضحة',
                rejectedAt: '2026-09-20T10:00:00Z'),
            onEdit: () => edits.add(1),
            onManagePrices: () {},
            resubmit: () async {
              sends.add(1);
              await resubmit?.call();
            },
            onResubmitted: () => done.add(1),
          ),
        ),
      ));
      return (edits: edits, sends: sends, done: done);
    }

    testWidgets(
        'شارة "مرفوض" حمراء والسبب ظاهر، وإعادة الإرسال ظاهرة دائماً بلا شرط تعديل',
        (tester) async {
      final r = await pump(tester);
      expect(find.byKey(const Key('rejected_badge')), findsOneWidget);
      expect(find.text('مرفوض'), findsOneWidget);
      expect(find.text('الصور غير واضحة'), findsOneWidget);
      expect(find.text('سبب الرفض · 20/9/2026'), findsOneWidget);
      // الصف بلا updated_at أصلاً: الزر لا يعتمد على وقت آخر تعديل.
      expect(find.byKey(const Key('rejected_resubmit')), findsOneWidget);
      expect(find.text('إعادة الإرسال للمراجعة'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rejected_edit')));
      expect(r.edits, [1]);
    });

    testWidgets('إعادة الإرسال تستدعي الدالة ثم تحدّث القائمة',
        (tester) async {
      final r = await pump(tester);
      await tester.tap(find.byKey(const Key('rejected_resubmit')));
      await tester.pumpAndSettle();
      expect(r.sends, [1]);
      expect(r.done, [1]);
      expect(find.text('أُعيد إرسال الشاليه للمراجعة ✅'), findsOneWidget);
    });

    testWidgets('فشل إعادة الإرسال: رسالة السيرفر ولا تحديث', (tester) async {
      final r = await pump(tester,
          resubmit: () async => throw Exception(nothingToResubmitMessage));
      await tester.tap(find.byKey(const Key('rejected_resubmit')));
      await tester.pumpAndSettle();
      expect(r.sends, [1]);
      expect(r.done, isEmpty);
      expect(find.text(nothingToResubmitMessage), findsOneWidget);
      expect(find.byKey(const Key('rejected_resubmit')), findsOneWidget);
    });
  });
}
