import '../../../../data/services/pricing_service.dart';

/// حساب "السعر الفعلي" لعرضه بشاشة تسعير المالك (عرض فقط).
///
/// لا يغيّر أي منطق تسعير ولا يتصل بالسيرفر: يكرّر محليًا الخطوات 3-6 من
/// هرم الأولوية الموثّق بـ [ChaletPricingService] (وتم التحقق من مطابقته
/// لدالة get_chalet_night_price بالقاعدة). أسعار التواريخ الخاصة (الخطوتان
/// 1-2) خارج هذا الحساب عمدًا: تتفوق على كل ما هنا، وتُعرض بشكل منفصل.
///
/// الأولوية لأي يوم أسبوع ونوع إقامة:
/// 1) سعر يوم الأسبوع لنفس النوع
/// 2) سعر يوم الأسبوع العام (default)
/// 3) السعر الاحتياطي للنوع (chalet_stay_types.base_price)
/// 4) سعر الشاليه الافتراضي (chalets.price_per_night)

/// من أين جاء السعر الفعلي.
enum PriceSource {
  typeWeekday,
  defaultWeekday,
  typeBase,
  chaletDefault,
}

/// لقطة أسعار الشاليه المطلوبة للحساب. تُبنى من الحقول (المسودة الحالية)
/// أو من القيم المحفوظة، والحساب نفسه لا يفرّق بينهما.
class PricingSnapshot {
  final double chaletDefaultPrice;

  /// أسعار الأيام العامة (stay_type = 'default'): 0=أحد .. 6=سبت.
  final Map<int, double> defaultWeekday;

  /// أسعار الأيام الخاصة بكل نوع.
  final Map<ChaletStayType, Map<int, double>> typeWeekday;

  /// السعر الاحتياطي لكل نوع (null = غير محدد).
  final Map<ChaletStayType, double?> basePrice;

  const PricingSnapshot({
    required this.chaletDefaultPrice,
    this.defaultWeekday = const {},
    this.typeWeekday = const {},
    this.basePrice = const {},
  });

  /// نسخة بدون سعر [day] للنوع [type] ([type] = null: سعر اليوم "العام").
  /// تُستخدم لمعرفة السعر الذي سيرجع له اليوم لو أُفرغ حقله.
  PricingSnapshot withoutWeekday(ChaletStayType? type, int day) {
    if (type == null) {
      return PricingSnapshot(
        chaletDefaultPrice: chaletDefaultPrice,
        defaultWeekday: {...defaultWeekday}..remove(day),
        typeWeekday: typeWeekday,
        basePrice: basePrice,
      );
    }
    return PricingSnapshot(
      chaletDefaultPrice: chaletDefaultPrice,
      defaultWeekday: defaultWeekday,
      typeWeekday: {
        ...typeWeekday,
        type: {...?typeWeekday[type]}..remove(day),
      },
      basePrice: basePrice,
    );
  }
}

class EffectivePrice {
  final double price;
  final PriceSource source;

  const EffectivePrice(this.price, this.source);

  @override
  bool operator ==(Object other) =>
      other is EffectivePrice &&
      other.price == price &&
      other.source == source;

  @override
  int get hashCode => Object.hash(price, source);

  @override
  String toString() => 'EffectivePrice($price, $source)';
}

/// السعر الذي سيُطبَّق فعلاً على [weekday] لنوع [type]
/// ([type] = null يعني "عام": بدون تصنيف نوع، ولا سعر احتياطي له).
EffectivePrice effectiveWeekdayPrice(
  PricingSnapshot s,
  ChaletStayType? type,
  int weekday,
) {
  if (type != null) {
    final own = s.typeWeekday[type]?[weekday];
    if (own != null) return EffectivePrice(own, PriceSource.typeWeekday);
  }
  final general = s.defaultWeekday[weekday];
  if (general != null) return EffectivePrice(general, PriceSource.defaultWeekday);

  if (type != null) {
    final base = s.basePrice[type];
    if (base != null) return EffectivePrice(base, PriceSource.typeBase);
  }
  return EffectivePrice(s.chaletDefaultPrice, PriceSource.chaletDefault);
}

/// حالة السعر الاحتياطي لنوع معيّن.
enum BasePriceStatus {
  /// لا يوجد سعر احتياطي مكتوب.
  notSet,

  /// كل الأيام السبعة لها سعر يوم يسبقه، فلن يُطبَّق على أي يوم.
  ignored,

  /// يُطبَّق على بعض الأيام فقط.
  partial,

  /// يُطبَّق على كل الأيام.
  applied,
}

class BasePriceImpact {
  final BasePriceStatus status;
  final double? price;

  /// الأيام التي سيُطبَّق عليها السعر الاحتياطي فعلاً.
  final List<int> appliedDays;

  /// أيام يسبقه فيها سعر يوم خاص بالنوع نفسه.
  final List<int> coveredByTypeDays;

  /// أيام يسبقه فيها سعر يوم "عام" (ولا سعر يوم خاص بالنوع).
  final List<int> coveredByDefaultDays;

  const BasePriceImpact({
    required this.status,
    required this.price,
    required this.appliedDays,
    required this.coveredByTypeDays,
    required this.coveredByDefaultDays,
  });
}

/// هل (وعلى أي أيام) سيُطبَّق السعر الاحتياطي لـ [type].
BasePriceImpact basePriceImpact(PricingSnapshot s, ChaletStayType type) {
  final base = s.basePrice[type];
  final applied = <int>[];
  final byType = <int>[];
  final byDefault = <int>[];

  for (var day = 0; day < 7; day++) {
    if (s.typeWeekday[type]?[day] != null) {
      byType.add(day);
    } else if (s.defaultWeekday[day] != null) {
      byDefault.add(day);
    } else {
      applied.add(day);
    }
  }

  final BasePriceStatus status;
  if (base == null) {
    status = BasePriceStatus.notSet;
  } else if (applied.isEmpty) {
    status = BasePriceStatus.ignored;
  } else if (applied.length == 7) {
    status = BasePriceStatus.applied;
  } else {
    status = BasePriceStatus.partial;
  }

  return BasePriceImpact(
    status: status,
    price: base,
    appliedDays: applied,
    coveredByTypeDays: byType,
    coveredByDefaultDays: byDefault,
  );
}

/// وصف أيام أسبوع بالأسماء لعرضه بالتحذيرات: أي 3 أيام متتالية فأكثر تُختصر
/// "من الأحد إلى الخميس"، والباقي يُذكر بالاسم ويُربط بـ"و".
/// الأيام: 0=أحد .. 6=سبت. القائمة الفارغة تعطي نصًا فارغًا.
String describeWeekdays(List<int> days) {
  final sorted = ({...days}.toList()..sort());
  if (sorted.isEmpty) return '';
  if (sorted.length == 7) return 'كل الأيام';

  const names = ChaletPricingService.weekdayLabels;
  final parts = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    if (j - i >= 2) {
      parts.add('من ${names[sorted[i]]} إلى ${names[sorted[j]]}');
    } else {
      for (var k = i; k <= j; k++) {
        parts.add(names[sorted[k]]);
      }
    }
    i = j + 1;
  }
  return parts.join(' و');
}

/// صيغة عرض السعر: بدون كسور للأرقام الصحيحة، وبكسرين لغير ذلك حتى لا
/// يُعرض 600.5 كأنه 601.
String formatPriceNumber(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
