// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:makan/data/services/pricing_service.dart';
import 'package:makan/presentation/screens/owner/pricing_preview.dart';

const _morning = ChaletStayType.morning;
const _evening = ChaletStayType.evening;

/// 0=أحد .. 4=خميس, 5=جمعة, 6=سبت
Map<int, double> _days(Iterable<int> days, double price) =>
    {for (final d in days) d: price};

void main() {
  group('effectiveWeekdayPrice — أولوية المصادر', () {
    test('سعر يوم النوع يتفوق على سعر اليوم العام والاحتياطي والافتراضي', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: {1: 1200},
        typeWeekday: {
          _morning: {1: 700}
        },
        basePrice: {_morning: 600},
      );
      expect(effectiveWeekdayPrice(s, _morning, 1),
          const EffectivePrice(700, PriceSource.typeWeekday));
    });

    test('سعر اليوم العام يتفوق على السعر الاحتياطي (أصل المشكلة)', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: {1: 1200},
        basePrice: {_morning: 600},
      );
      expect(effectiveWeekdayPrice(s, _morning, 1),
          const EffectivePrice(1200, PriceSource.defaultWeekday));
    });

    test('الاحتياطي يُطبَّق عند غياب أي سعر يوم، ويتفوق على الافتراضي', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        basePrice: {_morning: 600},
      );
      expect(effectiveWeekdayPrice(s, _morning, 3),
          const EffectivePrice(600, PriceSource.typeBase));
    });

    test('سعر الشاليه الافتراضي آخر ملجأ', () {
      const s = PricingSnapshot(chaletDefaultPrice: 1000);
      expect(effectiveWeekdayPrice(s, _morning, 3),
          const EffectivePrice(1000, PriceSource.chaletDefault));
    });

    test('أسعار نوع آخر لا تؤثر', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        typeWeekday: {
          _evening: {2: 900}
        },
        basePrice: {_evening: 800},
      );
      expect(effectiveWeekdayPrice(s, _morning, 2),
          const EffectivePrice(1000, PriceSource.chaletDefault));
    });

    test('نوع "عام" (null) يتجاهل الأسعار الاحتياطية وأسعار الأنواع', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: {5: 1500},
        typeWeekday: {
          _morning: {2: 700}
        },
        basePrice: {_morning: 600},
      );
      expect(effectiveWeekdayPrice(s, null, 5),
          const EffectivePrice(1500, PriceSource.defaultWeekday));
      expect(effectiveWeekdayPrice(s, null, 2),
          const EffectivePrice(1000, PriceSource.chaletDefault));
    });

    test('السعر صفر قيمة صالحة وليس "غير محدد"', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: {1: 0},
      );
      expect(effectiveWeekdayPrice(s, _morning, 1),
          const EffectivePrice(0, PriceSource.defaultWeekday));
    });
  });

  group('basePriceImpact — الحالات الثلاث', () {
    test('غير محدد: لا سعر احتياطي', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: _days(List.generate(7, (i) => i), 1200),
      );
      final r = basePriceImpact(s, _morning);
      expect(r.status, BasePriceStatus.notSet);
      expect(r.price, isNull);
    });

    test('متجاهَل بالكامل: كل الأيام السبعة لها سعر "عام"', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: _days(List.generate(7, (i) => i), 1200),
        basePrice: {_morning: 600},
      );
      final r = basePriceImpact(s, _morning);
      expect(r.status, BasePriceStatus.ignored);
      expect(r.price, 600);
      expect(r.appliedDays, isEmpty);
      expect(r.coveredByDefaultDays, [0, 1, 2, 3, 4, 5, 6]);
      expect(r.coveredByTypeDays, isEmpty);
    });

    test('جزئي: "عام" مضبوط للأحد–الخميس فيُطبَّق على الجمعة والسبت فقط', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: _days([0, 1, 2, 3, 4], 1200),
        basePrice: {_morning: 600},
      );
      final r = basePriceImpact(s, _morning);
      expect(r.status, BasePriceStatus.partial);
      expect(r.appliedDays, [5, 6]);
      expect(r.coveredByDefaultDays, [0, 1, 2, 3, 4]);
      expect(effectiveWeekdayPrice(s, _morning, 5).price, 600);
      expect(effectiveWeekdayPrice(s, _morning, 4).price, 1200);
    });

    test('مُطبَّق بالكامل: لا أسعار أيام إطلاقًا', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        basePrice: {_morning: 600},
      );
      final r = basePriceImpact(s, _morning);
      expect(r.status, BasePriceStatus.applied);
      expect(r.appliedDays, [0, 1, 2, 3, 4, 5, 6]);
    });

    test('التغطية مزيج: أيام النوع نفسه وأيام "عام" تُفصَل بقائمتين', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: _days([0, 1, 2], 1200),
        typeWeekday: {
          _morning: _days([2, 3, 4, 5, 6], 700)
        },
        basePrice: {_morning: 600},
      );
      final r = basePriceImpact(s, _morning);
      expect(r.status, BasePriceStatus.ignored);
      // الثلاثاء (2) له سعر للنوع نفسه وسعر عام: يُحسب للنوع (الأعلى أولوية)
      expect(r.coveredByTypeDays, [2, 3, 4, 5, 6]);
      expect(r.coveredByDefaultDays, [0, 1]);
    });

    test('سعر أيام نوع آخر لا يُغطّي احتياطي هذا النوع', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        typeWeekday: {
          _evening: _days(List.generate(7, (i) => i), 900)
        },
        basePrice: {_morning: 600},
      );
      expect(basePriceImpact(s, _morning).status, BasePriceStatus.applied);
    });

    test('السعر الاحتياطي صفر يُعامَل كمحدد', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        basePrice: {_morning: 0},
      );
      expect(basePriceImpact(s, _morning).status, BasePriceStatus.applied);
    });

    test('الحالة والحساب اليومي متسقان دائمًا', () {
      // كل توليفة من أيام "عام" (128 حالة): الأيام التي يُطبَّق عليها الاحتياطي
      // حسب basePriceImpact هي بالضبط الأيام التي مصدرها typeBase.
      for (var mask = 0; mask < 128; mask++) {
        final generalDays = [
          for (var d = 0; d < 7; d++)
            if (mask & (1 << d) != 0) d,
        ];
        final s = PricingSnapshot(
          chaletDefaultPrice: 1000,
          defaultWeekday: _days(generalDays, 1200),
          basePrice: {_morning: 600},
        );
        final viaSource = [
          for (var d = 0; d < 7; d++)
            if (effectiveWeekdayPrice(s, _morning, d).source ==
                PriceSource.typeBase)
              d,
        ];
        final r = basePriceImpact(s, _morning);
        expect(r.appliedDays, viaSource, reason: 'mask=$mask');
        expect(
          r.status,
          switch (viaSource.length) {
            0 => BasePriceStatus.ignored,
            7 => BasePriceStatus.applied,
            _ => BasePriceStatus.partial,
          },
          reason: 'mask=$mask',
        );
      }
    });
  });

  group('withoutWeekday — السعر البديل عند إفراغ الحقل', () {
    test('إزالة سعر يوم النوع يرجع لسعر "عام" ثم الاحتياطي', () {
      final s = PricingSnapshot(
        chaletDefaultPrice: 1000,
        defaultWeekday: {1: 1200},
        typeWeekday: {
          _morning: {1: 700, 2: 750}
        },
        basePrice: {_morning: 600},
      );
      final a = s.withoutWeekday(_morning, 1);
      expect(effectiveWeekdayPrice(a, _morning, 1),
          const EffectivePrice(1200, PriceSource.defaultWeekday));
      // أيام أخرى لا تتأثر، والأصل لا يتغير
      expect(effectiveWeekdayPrice(a, _morning, 2).price, 750);
      expect(effectiveWeekdayPrice(s, _morning, 1).price, 700);

      final b = a.withoutWeekday(null, 1);
      expect(effectiveWeekdayPrice(b, _morning, 1),
          const EffectivePrice(600, PriceSource.typeBase));
    });
  });

  group('describeWeekdays', () {
    test('فارغ وكل الأيام', () {
      expect(describeWeekdays([]), '');
      expect(describeWeekdays([0, 1, 2, 3, 4, 5, 6]), 'كل الأيام');
    });
    test('يومان أو غير متتاليين بالاسم', () {
      expect(describeWeekdays([5, 6]), 'الجمعة والسبت');
      expect(describeWeekdays([0, 2]), 'الأحد والثلاثاء');
    });
    test('ثلاثة متتالية فأكثر تُختصر', () {
      expect(describeWeekdays([0, 1, 2, 3, 4]), 'من الأحد إلى الخميس');
      expect(describeWeekdays([4, 5, 6]), 'من الخميس إلى السبت');
    });
    test('مزيج، وترتيب الإدخال لا يهم', () {
      expect(describeWeekdays([6, 0, 1, 2, 4]),
          'من الأحد إلى الثلاثاء والخميس والسبت');
    });
  });

  test('formatPriceNumber لا يقرّب الكسور', () {
    expect(formatPriceNumber(600), '600');
    expect(formatPriceNumber(600.5), '600.50');
  });
}
