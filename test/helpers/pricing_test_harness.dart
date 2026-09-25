import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/core/constants/app_colors.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/owner/pricing/chalet_pricing_screen.dart';
import 'package:makan/presentation/screens/owner/pricing/pricing_data_source.dart';

/// بيانات تجريبية داخل الاختبار فقط — لا اتصال بقاعدة بيانات ولا بالتطبيق
/// الحقيقي.
class FakePricingDataSource implements PricingDataSource {
  FakePricingDataSource({
    List<ChaletStayTypeConfig> stayTypes = const [],
    Map<String, Map<int, double>> weekday = const {},
    Map<String, List<ChaletDatePrice>> overrides = const {},
  })  : stayTypes = [...stayTypes],
        weekday = {
          for (final e in weekday.entries) e.key: {...e.value},
        },
        overrides = {
          for (final e in overrides.entries) e.key: [...e.value],
        };

  final List<ChaletStayTypeConfig> stayTypes;
  final Map<String, Map<int, double>> weekday;
  final Map<String, List<ChaletDatePrice>> overrides;

  /// سجل الكتابات، مثل: "weekday default:0=1500.0" و"upsert morning".
  final List<String> log = [];
  int weekdayReads = 0;

  @override
  Future<List<ChaletStayTypeConfig>> getStayTypes(String chaletId) async =>
      [...stayTypes];

  @override
  Future<void> upsertStayType({
    required String chaletId,
    required ChaletStayTypeConfig config,
  }) async {
    log.add('upsert ${config.type.dbValue} enabled=${config.isEnabled} '
        'base=${config.basePrice}');
    stayTypes.removeWhere((c) => c.type == config.type);
    stayTypes.add(config);
  }

  @override
  Future<Map<int, double>> getWeekdayPrices(
    String chaletId, {
    required String stayType,
  }) async {
    weekdayReads++;
    return {...?weekday[stayType]};
  }

  @override
  Future<void> setWeekdayPrice({
    required String chaletId,
    required int weekday,
    required double price,
    required String stayType,
  }) async {
    log.add('weekday $stayType:$weekday=$price');
    this.weekday.putIfAbsent(stayType, () => {})[weekday] = price;
  }

  @override
  Future<void> clearWeekdayPrice({
    required String chaletId,
    required int weekday,
    required String stayType,
  }) async {
    log.add('clear $stayType:$weekday');
    this.weekday[stayType]?.remove(weekday);
  }

  @override
  Future<List<ChaletDatePrice>> getDateOverrides(
    String chaletId, {
    required String stayType,
  }) async =>
      [...?overrides[stayType]];

  @override
  Future<void> setDateOverride({
    required String chaletId,
    required DateTime date,
    required double price,
    String? note,
    required String stayType,
  }) async {}

  @override
  Future<void> deleteDateOverride({
    required String chaletId,
    required DateTime date,
    required String stayType,
  }) async {}
}

ChaletStayTypeConfig stayConfig(
  ChaletStayType type, {
  bool enabled = true,
  double? base,
}) =>
    ChaletStayTypeConfig(
      id: 'id-${type.dbValue}',
      type: type,
      isEnabled: enabled,
      checkinTime: type.defaultCheckin,
      checkoutTime: type.defaultCheckout,
      basePrice: base,
      sortOrder: type.index,
    );

Map<int, double> days(Iterable<int> ds, double price) =>
    {for (final d in ds) d: price};

/// يحمّل خطًا عربيًا من نظام Windows باسم 'Cairo' (الذي تستخدمه الشاشة)
/// حتى تظهر الحروف العربية بدل مربعات Ahem. لو لم يوجد الخط يتجاهل بصمت.
///
/// ويحمّل خط MaterialIcons من الـ SDK حتى لا تظهر الأيقونات مربعات باللقطات
/// (بيئة الاختبار لا تحمّله تلقائيًا).
Future<void> loadArabicTestFont() async {
  final files = [
    'C:/Windows/Fonts/segoeui.ttf',
    'C:/Windows/Fonts/segoeuib.ttf',
  ].map(File.new).where((f) => f.existsSync()).toList();
  if (files.isNotEmpty) {
    final loader = FontLoader('Cairo');
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  // جذر الـ SDK: من flutter_tester (…/bin/cache/artifacts/engine/<platform>/).
  final exe = Platform.resolvedExecutable.replaceAll('\\', '/');
  final cut = exe.indexOf('/bin/cache/');
  final root = Platform.environment['FLUTTER_ROOT'] ??
      (cut > 0 ? exe.substring(0, cut) : null);
  if (root == null) return;
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

ThemeData testTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      // نفس ColorScheme والفاصل بـ AppTheme.lightTheme (بدون GoogleFonts لأنه
      // يجلب الخط من الشبكة).
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.card,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.accent,
        ),
      ),
      // نفس إعداد التطبيق الحقيقي: زر مرتفع بعرض لا نهائي (لكشف أي تخطيط
      // يعتمد عليه بالخطأ).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );

class PricingHarness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey boundaryKey = GlobalKey();
}

/// يشغّل الشاشة داخل تطبيق (عربي/RTL) بعرض 390 منطقيًا.
/// ارتفاع [height] كبير بالسلوكيات لتظهر كل الحقول بلا تمرير، وبحجم الهاتف
/// (844) باللقطات.
Future<PricingHarness> pumpPricingScreen(
  WidgetTester tester,
  PricingDataSource ds, {
  double defaultPrice = 1000,
  double height = 3600,
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(390 * 2, height * 2);
  addTearDown(tester.view.reset);

  final h = PricingHarness();
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
    builder: (_) => ChaletPricingScreen(
      chaletId: 'chalet-1',
      chaletName: 'شاليه تجريبي',
      defaultPricePerNight: defaultPrice,
      dataSource: ds,
    ),
  ));
  await tester.pumpAndSettle();
  return h;
}
