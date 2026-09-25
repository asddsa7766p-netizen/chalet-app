import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/models/manual_booking.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/presentation/screens/settings/privacy_security_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bookingsMsg = 'لديك حجوزات قادمة. ألغِها أولاً ثم احذف الحساب.';
const _chaletsMsg = 'لديك شاليهات مسجلة. تواصل مع الدعم لحذف حساب المالك.';

void main() {
  group('accountDeletionErrorMessage', () {
    test('رفض الخادم (P0001) يُعرض حرفياً', () {
      expect(
          accountDeletionErrorMessage(
              const PostgrestException(message: _bookingsMsg, code: 'P0001')),
          _bookingsMsg);
      expect(
          accountDeletionErrorMessage(
              const PostgrestException(message: _chaletsMsg, code: 'P0001')),
          _chaletsMsg);
    });

    test('خطأ غير مقصود لا يُعرض خاماً', () {
      final msg = accountDeletionErrorMessage(const PostgrestException(
          message: 'relation "x" does not exist', code: '42P01'));
      expect(msg, isNot(contains('relation')));
    });
  });

  group('زر حذف الحساب بشاشة الخصوصية', () {
    Future<({List<int> calls, List<bool> deleted})> pump(
      WidgetTester tester, {
      required Future<void> Function() delete,
    }) async {
      final calls = <int>[];
      final deleted = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: PrivacySecurityScreen(
          isLoggedIn: true,
          deleteAccount: () {
            calls.add(1);
            return delete();
          },
          onAccountDeleted: () => deleted.add(true),
        ),
      ));
      return (calls: calls, deleted: deleted);
    }

    Future<void> confirmDeletion(WidgetTester tester) async {
      final button = find.byKey(const Key('delete_account_button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      final confirm = find.byKey(const Key('delete_account_confirm_button'));
      expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull,
          reason: 'معطّل قبل كتابة كلمة "حذف"');
      await tester.enterText(
          find.byKey(const Key('delete_account_confirm_field')), 'حذف');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }

    testWidgets('نجاح: يحذف ثم يعود للرئيسية كضيف', (tester) async {
      final r = await pump(tester, delete: () async {});
      await confirmDeletion(tester);

      expect(r.calls, hasLength(1));
      expect(r.deleted, [true]);
      expect(find.text('تم حذف حسابك'), findsOneWidget);
    });

    testWidgets('رفض بحجوزات قادمة: رسالة الخادم كما هي ولا خروج',
        (tester) async {
      final r = await pump(tester,
          delete: () async => throw const PostgrestException(
              message: _bookingsMsg, code: 'P0001'));
      await confirmDeletion(tester);

      expect(r.calls, hasLength(1));
      expect(r.deleted, isEmpty);
      expect(find.text(_bookingsMsg), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('delete_account_button')));
      expect(button.onPressed, isNotNull, reason: 'الزر يعود قابلاً للضغط');
    });

    testWidgets('رفض بشاليهات مسجلة: رسالة الخادم كما هي ولا خروج',
        (tester) async {
      final r = await pump(tester,
          delete: () async =>
              throw const AccountDeletionException(_chaletsMsg));
      await confirmDeletion(tester);

      expect(r.calls, hasLength(1));
      expect(r.deleted, isEmpty);
      expect(find.text(_chaletsMsg), findsOneWidget);
    });

    testWidgets('إلغاء الحوار لا يحذف شيئاً', (tester) async {
      final r = await pump(tester, delete: () async {});
      final button = find.byKey(const Key('delete_account_button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(r.calls, isEmpty);
    });

    testWidgets('الضيف لا يرى زر الحذف', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: PrivacySecurityScreen(isLoggedIn: false)));
      expect(find.byKey(const Key('delete_account_button')), findsNothing);
    });
  });

  group('حجز حساب محذوف (user_id = null)', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 'b1',
          'chalet_id': 'c1',
          'check_in': '2026-10-01',
          'check_out': '2026-10-02',
          'status': 'completed',
          'created_at': '2026-09-01T10:00:00Z',
          ...extra,
        };

    test('يُقرأ بلا خطأ ويُعرض guest_name بلا هاتف', () {
      final b = BookingModel.fromJson(row({
        'user_id': null,
        'guest_name': 'مستخدم محذوف',
        'guest_phone': null,
        'profiles': null,
        'source': 'app',
      }));
      expect(b.userId, isNull);
      expect(b.isFromDeletedAccount, isTrue);
      expect(b.displayGuestName, 'مستخدم محذوف');
      expect(b.displayGuestPhone, isNull);
    });

    test('حجز حساب قائم يعرض اسم البروفايل كما كان', () {
      final b = BookingModel.fromJson(row({
        'user_id': 'u1',
        'profiles': {'full_name': 'أحمد', 'phone': '0599000000'},
      }));
      expect(b.isFromDeletedAccount, isFalse);
      expect(b.displayGuestName, 'أحمد');
      expect(b.displayGuestPhone, '0599000000');
    });

    test('الحجز اليدوي يبقى على أعمدة الحجز', () {
      final b = BookingModel.fromJson(row({
        'user_id': 'owner-1',
        'source': 'external',
        'guest_name': 'زبون هاتفي',
        'guest_phone': '0598111111',
        'profiles': {'full_name': 'المالك'},
      }));
      expect(b.isFromDeletedAccount, isFalse);
      expect(b.displayGuestName, 'زبون هاتفي');
      expect(b.displayGuestPhone, '0598111111');
    });
  });
}
