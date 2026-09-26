import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/core/router/app_router.dart';
import 'package:makan/data/models/chalet_model.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/data/services/admin_service.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:makan/presentation/screens/home/main_screen.dart';
import 'package:makan/presentation/screens/profile/profile_provider.dart';
import 'package:makan/presentation/widgets/common/common_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

const _admin = UserProfile(id: 'a1', fullName: 'مدير', isAdmin: true);
const _customer = UserProfile(id: 'c1', fullName: 'زبون');
const _owner = UserProfile(id: 'o1', fullName: 'مالك', isOwner: true);

Override _profile(UserProfile p) =>
    profileProvider.overrideWith((ref) async => p);

/// مسارات الزبون والمالك التي يجب أن تعيد الأدمن للوحة.
const _customerAndOwnerRoutes = [
  '/home',
  '/search',
  '/map',
  '/home/chalet/x',
  '/home/booking',
  '/home/reviews/x',
  '/payment',
  '/notifications',
  '/owner-dashboard',
  '/owner-add-chalet',
  '/owner-calendar',
  '/owner-bookings',
];

Future<String?> _redirect(String location, UserProfile? profile,
    {List<int>? loads}) {
  return AppRouter.resolveRedirect(
    location,
    isLoggedIn: profile != null,
    loadProfile: () async {
      loads?.add(1);
      return profile;
    },
  );
}

AdminChaletReview _review() => AdminChaletReview(
      chalet: ChaletModel.fromJson(const {
        'id': 'ch1',
        'owner_id': 'o1',
        'name': 'شاليه الياسمين',
        'description': 'شاليه عائلي هادئ مع حديقة',
        'city': 'نابلس',
        'location': 'رفيديا',
        'address': 'شارع الجامعة',
        'latitude': 32.22,
        'longitude': 35.25,
        'price_per_night': 400,
        'deposit_amount': 100,
        'max_guests': 12,
        'bedrooms': 3,
        'bathrooms': 2,
        'has_pool': true,
        'has_wifi': true,
        'images': <String>[],
      }),
      periods: const [
        ChaletStayTypeConfig(
          type: ChaletStayType.morning,
          checkinTime: TimeOfDay(hour: 10, minute: 0),
          checkoutTime: TimeOfDay(hour: 21, minute: 0),
          basePrice: 350,
        ),
        ChaletStayTypeConfig(
          type: ChaletStayType.evening,
          checkinTime: TimeOfDay(hour: 22, minute: 0),
          checkoutTime: TimeOfDay(hour: 9, minute: 0),
        ),
      ],
      ownerName: 'أبو أحمد',
      ownerPhone: '0599123456',
    );

void main() {
  setUpAll(loadArabicTestFont);

  group('isAdminProvider', () {
    test('يتبع is_admin بالبروفايل، وfalse أثناء التحميل', () async {
      final admin = ProviderContainer(overrides: [_profile(_admin)]);
      addTearDown(admin.dispose);
      expect(admin.read(isAdminProvider), isFalse); // لم يكتمل التحميل بعد
      await admin.read(profileProvider.future);
      expect(admin.read(isAdminProvider), isTrue);

      final customer = ProviderContainer(overrides: [_profile(_customer)]);
      addTearDown(customer.dispose);
      await customer.read(profileProvider.future);
      expect(customer.read(isAdminProvider), isFalse);
    });
  });

  group('توجيه الأدمن', () {
    test('بعد تسجيل الدخول وعند فتح التطبيق بجلسة محفوظة: لوحة الإدارة',
        () async {
      // onboarding = نقطة البدء عند فتح التطبيق؛ صفحات /auth بعد الدخول.
      for (final r in ['/onboarding', '/auth/login', '/auth/register']) {
        expect(await _redirect(r, _admin), '/admin-dashboard', reason: r);
      }
    });

    test('كل مسار زبون أو مالك يعيده للوحة (والروابط المباشرة)', () async {
      for (final r in _customerAndOwnerRoutes) {
        expect(await _redirect(r, _admin), '/admin-dashboard', reason: r);
      }
    });

    test('لوحة الإدارة نفسها مسموحة', () async {
      expect(AppRouter.isAdminRoute('/admin-dashboard'), isTrue);
      expect(await _redirect('/admin-dashboard', _admin), isNull);
    });

    test('الزبون والمالك والضيف كما كانوا', () async {
      expect(await _redirect('/onboarding', _customer), '/home');
      expect(await _redirect('/auth/login', _customer), '/home');
      expect(await _redirect('/home', _customer), isNull);
      expect(await _redirect('/home/booking', _customer), isNull);
      expect(await _redirect('/admin-dashboard', _customer), '/home');
      expect(await _redirect('/owner-dashboard', _customer), '/home');
      expect(await _redirect('/owner-dashboard', _owner), isNull);

      final loads = <int>[];
      expect(await _redirect('/onboarding', null, loads: loads), isNull);
      expect(await _redirect('/home', null, loads: loads), isNull);
      expect(await _redirect('/home/booking', null, loads: loads),
          '/auth/login');
      expect(await _redirect('/admin-dashboard', null, loads: loads),
          '/auth/login');
      expect(loads, isEmpty, reason: 'لا استعلام بروفايل للضيف');
    });

    testWidgets('رابط مباشر لمسار زبون عبر GoRouter يفتح اللوحة',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home/chalet/x',
        redirect: (_, state) => AppRouter.resolveRedirect(
            state.matchedLocation,
            isLoggedIn: true,
            loadProfile: () async => _admin),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('HOME'), routes: [
            GoRoute(
                path: 'chalet/:id', builder: (_, __) => const Text('CHALET')),
          ]),
          GoRoute(
              path: '/admin-dashboard',
              builder: (_, __) => const Text('ADMIN_DASHBOARD')),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('ADMIN_DASHBOARD'), findsOneWidget);
      expect(find.text('CHALET'), findsNothing);

      router.go('/search');
      await tester.pumpAndSettle();
      expect(find.text('ADMIN_DASHBOARD'), findsOneWidget);
    });
  });

  group('ترويسة لوحة الإدارة', () {
    Future<List<int>> pumpHeader(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final signOuts = <int>[];
      final router = GoRouter(initialLocation: '/admin-dashboard', routes: [
        GoRoute(
            path: '/admin-dashboard',
            builder: (_, __) => Scaffold(
                  body: AdminDashboardHeader(signOut: () async {
                    signOuts.add(1);
                  }),
                )),
        GoRoute(path: '/home', builder: (_, __) => const Text('HOME_GUEST')),
      ]);
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      return signOuts;
    }

    testWidgets('لا زر "تصفّح التطبيق"، وفيها الإعدادات والخروج',
        (tester) async {
      await pumpHeader(tester);
      expect(find.text('تصفّح التطبيق'), findsNothing);
      expect(find.byKey(const Key('admin_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('admin_sign_out_button')), findsOneWidget);
    });

    testWidgets('تسجيل الخروج: تأكيد ثم signOut ثم الرئيسية كضيف',
        (tester) async {
      final signOuts = await pumpHeader(tester);
      await tester.tap(find.byKey(const Key('admin_sign_out_button')));
      await tester.pumpAndSettle();
      expect(signOuts, isEmpty, reason: 'لا خروج قبل التأكيد');
      await tester.tap(find.widgetWithText(TextButton, 'تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(signOuts, hasLength(1));
      expect(find.text('HOME_GUEST'), findsOneWidget);
    });

    testWidgets('إلغاء الخروج يبقيه باللوحة', (tester) async {
      final signOuts = await pumpHeader(tester);
      await tester.tap(find.byKey(const Key('admin_sign_out_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(signOuts, isEmpty);
      expect(find.text('HOME_GUEST'), findsNothing);
    });

    testWidgets('إعدادات الأدمن: اللغة والثيم فقط', (tester) async {
      await pumpHeader(tester);
      await tester.tap(find.byKey(const Key('admin_settings_button')));
      await tester.pumpAndSettle();
      expect(find.text('الوضع المظلم'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      expect(find.byIcon(Icons.article_outlined), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });
  });

  group('شاشة مراجعة الشاليه', () {
    Future<({List<String> approved, List<String> rejected, List<bool?> popped})>
        pumpReview(WidgetTester tester,
            {Future<void> Function()? approveResult,
            double height = 2400}) async {
      tester.view.physicalSize = Size(1080, height);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final approved = <String>[];
      final rejected = <String>[];
      final popped = <bool?>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped.add(await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => AdminChaletReviewScreen(
                              chaletId: 'ch1',
                              load: (_) async => _review(),
                              approve: (id) async {
                                approved.add(id);
                                await approveResult?.call();
                              },
                              reject: (id) async => rejected.add(id),
                            ))));
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      return (approved: approved, rejected: rejected, popped: popped);
    }

    testWidgets('تعرض كل التفاصيل بلا قلب ولا زر حجز', (tester) async {
      // شاشة طويلة حتى تُبنى كل الأقسام بلا تمرير.
      await pumpReview(tester, height: 9000);
      for (final t in [
        'شاليه الياسمين',
        'شاليه عائلي هادئ مع حديقة',
        'نابلس',
        'رفيديا',
        'شارع الجامعة',
        'مسبح خاص',
        'واي فاي',
        '₪400',
        '₪100',
        'إقامة صباحية',
        '10:00 ص - 9:00 م',
        '₪350',
        'إقامة مسائية',
        '10:00 م - 9:00 ص',
        'أبو أحمد',
        '0599123456',
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      // الفترة المسائية بلا سعر خاص تأخذ السعر الأساسي.
      expect(
          find.descendant(
              of: find.byKey(const Key('review_period_1')),
              matching: find.text('₪400')),
          findsOneWidget);
      expect(find.text('احجز الآن'), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byKey(const Key('review_approve')), findsOneWidget);
      expect(find.byKey(const Key('review_reject')), findsOneWidget);
    });

    testWidgets('الاعتماد: تأكيد ثم الدالة ثم الرجوع للقائمة', (tester) async {
      final r = await pumpReview(tester);
      await tester.tap(find.byKey(const Key('review_approve')));
      await tester.pumpAndSettle();
      expect(find.text('اعتماد الشاليه'), findsOneWidget);
      expect(r.approved, isEmpty, reason: 'لا اعتماد قبل التأكيد');
      await tester.tap(find.widgetWithText(TextButton, 'اعتماد'));
      await tester.pumpAndSettle();
      expect(r.approved, ['ch1']);
      expect(r.popped, [true]);
      expect(find.text('تمت الموافقة على الشاليه ✅'), findsOneWidget);
    });

    testWidgets('الرفض: حوار "رفض وحذف" ثم الدالة', (tester) async {
      final r = await pumpReview(tester);
      await tester.tap(find.byKey(const Key('review_reject')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفض وحذف'));
      await tester.pumpAndSettle();
      expect(r.rejected, ['ch1']);
      expect(r.approved, isEmpty);
      expect(r.popped, [true]);
    });

    testWidgets('فشل الاعتماد: رسالة الخادم ويبقى بالشاشة', (tester) async {
      final r = await pumpReview(tester,
          approveResult: () async =>
              throw const AdminActionException('الشاليه محذوف'));
      await tester.tap(find.byKey(const Key('review_approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'اعتماد'));
      await tester.pumpAndSettle();
      expect(find.text('الشاليه محذوف'), findsOneWidget);
      expect(r.popped, isEmpty);
      expect(find.byKey(const Key('review_approve')), findsOneWidget);
    });
  });

  testWidgets('ChaletCard: showFavorite=false يخفي القلب كلياً',
      (tester) async {
    final chalet = ChaletModel.fromJson(const {
      'id': 'c',
      'owner_id': 'o',
      'name': 'شاليه',
      'city': 'نابلس',
      'location': 'نابلس',
      'price_per_night': 300,
      'max_guests': 5,
      'images': <String>[],
    });
    for (final horizontal in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              ChaletCard(
                  chalet: chalet, horizontal: horizontal, onFavoriteTap: () {}),
              ChaletCard(
                  chalet: chalet,
                  horizontal: horizontal,
                  onFavoriteTap: () {},
                  showFavorite: false),
            ]),
          ),
        ),
      ));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget,
          reason: 'horizontal=$horizontal');
    }
  });

  test('تبويبات الشريط السفلي: الأدمن بلا المفضلة (2) والحجوزات (3)', () {
    expect(mainTabsFor(isAdmin: true), [0, 1, 4, 5]);
    expect(mainTabsFor(isAdmin: false), [0, 1, 2, 3, 4, 5]);
  });
}
