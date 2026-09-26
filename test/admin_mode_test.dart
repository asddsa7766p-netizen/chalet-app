import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/core/router/app_router.dart';
import 'package:makan/data/models/chalet_model.dart';
import 'package:makan/data/models/models.dart';
import 'package:makan/presentation/screens/home/main_screen.dart';
import 'package:makan/presentation/screens/profile/profile_provider.dart';
import 'package:makan/presentation/widgets/common/admin_mode_banner.dart';
import 'package:makan/presentation/widgets/common/common_widgets.dart';

import 'helpers/pricing_test_harness.dart' show loadArabicTestFont;

const _admin = UserProfile(id: 'a1', fullName: 'مدير', isAdmin: true);
const _customer = UserProfile(id: 'c1', fullName: 'زبون');

Override _profile(UserProfile p) =>
    profileProvider.overrideWith((ref) async => p);

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

  test('مسارات الحجز والدفع والمالك ممنوعة على الأدمن، والباقي مسموح', () {
    for (final r in [
      '/home/booking',
      '/payment',
      '/owner-add-chalet',
      '/owner-dashboard',
      '/owner-calendar',
    ]) {
      expect(AppRouter.isAdminBlockedRoute(r), isTrue, reason: r);
    }
    for (final r in [
      '/home',
      '/home/chalet/x',
      '/search',
      '/map',
      '/notifications',
      '/admin-dashboard',
    ]) {
      expect(AppRouter.isAdminBlockedRoute(r), isFalse, reason: r);
    }
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

  testWidgets('شريط وضع الإدارة يفتح لوحة الإدارة', (tester) async {
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: AdminModeBanner())),
      GoRoute(
          path: '/admin-dashboard',
          builder: (_, __) => const Text('ADMIN_DASHBOARD')),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('وضع الإدارة'), findsOneWidget);
    await tester.tap(find.text('لوحة الإدارة'));
    await tester.pumpAndSettle();
    expect(find.text('ADMIN_DASHBOARD'), findsOneWidget);
  });

  test('تبويبات الشريط السفلي: الأدمن بلا المفضلة (2) والحجوزات (3)', () {
    expect(mainTabsFor(isAdmin: true), [0, 1, 4, 5]);
    expect(mainTabsFor(isAdmin: false), [0, 1, 2, 3, 4, 5]);
  });
}
