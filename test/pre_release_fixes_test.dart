import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:makan/data/services/services.dart';
import 'package:makan/data/services/suspension_aware_http_client.dart';
import 'package:makan/presentation/screens/auth/auth_shared.dart';
import 'package:makan/presentation/screens/profile/profile_screen.dart';
import 'package:makan/presentation/widgets/common/osm_map_layers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, PostgrestException;

const _bannedBody = '{"code":400,"error_code":"user_banned","msg":"User is banned"}';

void main() {
  group('الحساب المحظور', () {
    test('خطأ GoTrue user_banned ← رسالة الإيقاف', () {
      final e = AuthApiException('User is banned',
          statusCode: '400', code: 'user_banned');
      expect(isAccountSuspendedError(e), isTrue);
      expect(translateSupabaseError(e), accountSuspendedMessage);
    });

    test('رسالة الخادم العربية تسبق "permission denied"', () {
      const e = PostgrestException(
          message: 'permission denied: $accountSuspendedMessage', code: 'P0001');
      expect(translateSupabaseError(e), accountSuspendedMessage);
    });

    test('تبقى مطابقة بعد تغليفها بـ Exception من طبقة الخدمات', () {
      final wrapped = Exception(translateSupabaseError(
          const PostgrestException(message: accountSuspendedMessage)));
      expect(isAccountSuspendedError(wrapped), isTrue);
    });

    test('شاشة الدخول تعرضها كما هي (لا "خطأ غير متوقع")', () {
      expect(friendlyAuthError(Exception(accountSuspendedMessage)),
          accountSuspendedMessage);
      expect(
          friendlyAuthError(AuthApiException('User is banned',
              statusCode: '400', code: 'user_banned')),
          accountSuspendedMessage);
    });

    test('أخطاء أخرى لا تُعدّ حظراً', () {
      expect(isAccountSuspendedError(AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials')), isFalse);
      expect(isAccountSuspendedError(Exception('network')), isFalse);
    });
  });

  group('SuspensionAwareHttpClient', () {
    Future<(int, String)> send(String path, int status, String body) async {
      var suspended = 0;
      final client = SuspensionAwareHttpClient(
        onSuspended: () => suspended++,
        inner: MockClient((_) async => http.Response(body, status)),
      );
      final res = await client
          .send(http.Request('POST', Uri.parse('https://x.supabase.co$path')));
      return (suspended, utf8.decode(await res.stream.toBytes()));
    }

    test('رفض تجديد الجلسة بسبب الحظر يبلّغ مرة، والرد يبقى مقروءاً', () async {
      final (n, body) = await send(
          '/auth/v1/token?grant_type=refresh_token', 400, _bannedBody);
      expect(n, 1);
      expect(body, _bannedBody, reason: 'GoTrue يقرأ نفس الرد بعدنا');
    });

    test('رفض الدخول بكلمة المرور لا يبلّغ (يعالجه signIn)', () async {
      final (n, _) =
          await send('/auth/v1/token?grant_type=password', 400, _bannedBody);
      expect(n, 0);
    });

    test('فشل تجديد لسبب آخر أو نجاحه لا يبلّغ', () async {
      final (a, _) = await send('/auth/v1/token?grant_type=refresh_token',
          400, '{"error_code":"refresh_token_not_found"}');
      final (b, body) = await send(
          '/auth/v1/token?grant_type=refresh_token', 200, '{"ok":true}');
      expect(a, 0);
      expect(b, 0);
      expect(body, '{"ok":true}');
    });
  });

  group('OpenStreetMap', () {
    test('User-Agent باسم الحزمة الحقيقي', () {
      expect(osmTileLayer().tileProvider.headers['User-Agent'],
          'flutter_map (com.makan.app)');
    });

    testWidgets('نص الإسناد ظاهر باتجاه ثابت', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(children: [OsmAttribution()]),
        ),
      ));
      final text = tester.widget<Text>(find.text('© OpenStreetMap contributors'));
      expect(text.textDirection, TextDirection.ltr);
    });
  });

  testWidgets('حسابي: فشل التحميل ← حالة خطأ مع إعادة المحاولة لا أصفار',
      (tester) async {
    // بلا Supabase مهيّأ يفشل جلب البروفايل والإحصائيات معاً.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_error')), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('حجز مكتمل'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_error')), findsOneWidget);
  });
}
