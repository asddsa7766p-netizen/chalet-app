import '../../../../data/services/pricing_service.dart';

/// واجهة رفيعة بين شاشة تسعير المالك وخدمة التسعير.
///
/// هدفها الوحيد تمكين اختبار الشاشة (widget tests) دون Supabase حقيقي.
/// التنفيذ الافتراضي [ServicePricingDataSource] يفوّض حرفيًا إلى
/// [ChaletPricingService] بدون أي منطق إضافي.
abstract class PricingDataSource {
  Future<List<ChaletStayTypeConfig>> getStayTypes(String chaletId);

  Future<void> upsertStayType({
    required String chaletId,
    required ChaletStayTypeConfig config,
  });

  Future<Map<int, double>> getWeekdayPrices(
    String chaletId, {
    required String stayType,
  });

  Future<void> setWeekdayPrice({
    required String chaletId,
    required int weekday,
    required double price,
    required String stayType,
  });

  Future<void> clearWeekdayPrice({
    required String chaletId,
    required int weekday,
    required String stayType,
  });

  Future<List<ChaletDatePrice>> getDateOverrides(
    String chaletId, {
    required String stayType,
  });

  Future<void> setDateOverride({
    required String chaletId,
    required DateTime date,
    required double price,
    String? note,
    required String stayType,
  });

  Future<void> deleteDateOverride({
    required String chaletId,
    required DateTime date,
    required String stayType,
  });
}

class ServicePricingDataSource implements PricingDataSource {
  const ServicePricingDataSource();

  // الوصول للخدمة كسول عمدًا: لا يلمس Supabase إلا عند أول استدعاء فعلي.
  ChaletPricingService get _s => ChaletPricingService.instance;

  @override
  Future<List<ChaletStayTypeConfig>> getStayTypes(String chaletId) =>
      _s.getStayTypes(chaletId);

  @override
  Future<void> upsertStayType({
    required String chaletId,
    required ChaletStayTypeConfig config,
  }) =>
      _s.upsertStayType(chaletId: chaletId, config: config);

  @override
  Future<Map<int, double>> getWeekdayPrices(
    String chaletId, {
    required String stayType,
  }) =>
      _s.getWeekdayPrices(chaletId, stayType: stayType);

  @override
  Future<void> setWeekdayPrice({
    required String chaletId,
    required int weekday,
    required double price,
    required String stayType,
  }) =>
      _s.setWeekdayPrice(
        chaletId: chaletId,
        weekday: weekday,
        price: price,
        stayType: stayType,
      );

  @override
  Future<void> clearWeekdayPrice({
    required String chaletId,
    required int weekday,
    required String stayType,
  }) =>
      _s.clearWeekdayPrice(
        chaletId: chaletId,
        weekday: weekday,
        stayType: stayType,
      );

  @override
  Future<List<ChaletDatePrice>> getDateOverrides(
    String chaletId, {
    required String stayType,
  }) =>
      _s.getDateOverrides(chaletId, stayType: stayType);

  @override
  Future<void> setDateOverride({
    required String chaletId,
    required DateTime date,
    required double price,
    String? note,
    required String stayType,
  }) =>
      _s.setDateOverride(
        chaletId: chaletId,
        date: date,
        price: price,
        note: note,
        stayType: stayType,
      );

  @override
  Future<void> deleteDateOverride({
    required String chaletId,
    required DateTime date,
    required String stayType,
  }) =>
      _s.deleteDateOverride(
        chaletId: chaletId,
        date: date,
        stayType: stayType,
      );
}
