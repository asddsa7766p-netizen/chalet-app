import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/pricing_service.dart';
import 'pricing_preview.dart';

/// اسم قصير للمصدر + لونه (يُستخدم بالجدول والمفتاح وتلميحات الحقول).
class PriceSourceStyle {
  final String label;
  final Color color;
  const PriceSourceStyle(this.label, this.color);

  static PriceSourceStyle of(PriceSource s) {
    switch (s) {
      case PriceSource.typeWeekday:
        return const PriceSourceStyle('يوم النوع', AppColors.primary);
      case PriceSource.defaultWeekday:
        return const PriceSourceStyle('يوم «عام»', AppColors.info);
      case PriceSource.typeBase:
        return const PriceSourceStyle('احتياطي', AppColors.accentDark);
      case PriceSource.chaletDefault:
        return const PriceSourceStyle('افتراضي', AppColors.textSecondary);
    }
  }
}

/// لوحة "السعر الفعلي": جدول الأيام السبعة × أنواع الإقامة المفعّلة، يعرض
/// السعر الذي سيُطبَّق فعلاً على كل يوم ومصدره.
///
/// يعكس المسودة ([draft]) لا المحفوظ فقط: أي خلية يختلف سعرها أو مصدرها عن
/// المحفوظ ([saved]) تُوسَم "بعد الحفظ". عرض فقط، لا يكتب شيئًا.
class EffectivePricePanel extends StatelessWidget {
  /// أعمدة الجدول: أنواع مفعّلة، أو [null] وحده ("عام") إن لم يُفعَّل نوع.
  final List<ChaletStayType?> columns;
  final PricingSnapshot saved;
  final PricingSnapshot draft;

  /// مفتاح نوع التعديل الحالي ('default' أو dbValue) لتمييز عموده.
  final String selectedKey;
  final double chaletDefaultPrice;

  /// يُستدعى بمفتاح النوع عند الضغط على رأس عمود أو خلية.
  final ValueChanged<String> onSelect;

  const EffectivePricePanel({
    super.key,
    required this.columns,
    required this.saved,
    required this.draft,
    required this.selectedKey,
    required this.chaletDefaultPrice,
    required this.onSelect,
  });

  static String keyOf(ChaletStayType? t) =>
      t?.dbValue ?? ChaletPricingService.defaultStayType;

  bool get _hasChanges {
    for (final t in columns) {
      for (var d = 0; d < 7; d++) {
        if (effectiveWeekdayPrice(saved, t, d) !=
            effectiveWeekdayPrice(draft, t, d)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'السعر الفعلي لكل يوم',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'هاد هو السعر اللي رح يُطبَّق فعلاً على كل يوم. أي يوم بلا أي سعر '
            'يأخذ ₪${formatPriceNumber(chaletDefaultPrice)} (السعر الافتراضي للشاليه).',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildHeaderRow(),
          const SizedBox(height: 4),
          for (var day = 0; day < 7; day++) _buildDayRow(day),
          const SizedBox(height: 10),
          _buildLegend(),
          if (_hasChanges) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 16, color: AppColors.accentDark),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'الخلايا الموسومة "بعد الحفظ" تعكس تعديلاتك غير المحفوظة.',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.accentDark),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'الأسعار الخاصة بتواريخ محددة (بالأسفل) تتفوق على هذا الجدول في '
            'تواريخها فقط.',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  static const double _dayColWidth = 56;

  Widget _buildHeaderRow() {
    return Row(
      children: [
        const SizedBox(width: _dayColWidth),
        for (final t in columns)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                key: ValueKey('effHeader_${keyOf(t)}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(keyOf(t)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  decoration: BoxDecoration(
                    color: selectedKey == keyOf(t)
                        ? AppColors.primaryPale
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(t?.icon ?? Icons.layers_outlined,
                          size: 15, color: AppColors.primary),
                      const SizedBox(height: 2),
                      Text(
                        t?.shortLabel ?? 'عام',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayRow(int day) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _dayColWidth,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  ChaletPricingService.weekdayLabels[day],
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ),
            for (final t in columns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildCell(t, day),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(ChaletStayType? t, int day) {
    final now = effectiveWeekdayPrice(draft, t, day);
    final before = effectiveWeekdayPrice(saved, t, day);
    final changed = now != before;
    final style = PriceSourceStyle.of(now.source);
    final selected = selectedKey == keyOf(t);

    return InkWell(
      key: ValueKey('effCell_${keyOf(t)}_$day'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelect(keyOf(t)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: changed
              ? AppColors.accent.withValues(alpha: 0.14)
              : selected
                  ? AppColors.primaryPale.withValues(alpha: 0.55)
                  : style.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: changed ? AppColors.accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '₪${formatPriceNumber(now.price)}',
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            Text(
              style.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: style.color,
              ),
            ),
            if (changed)
              const Text(
                'بعد الحفظ',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final s in PriceSource.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: PriceSourceStyle.of(s).color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _legendText(s),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }

  static String _legendText(PriceSource s) {
    switch (s) {
      case PriceSource.typeWeekday:
        return 'يوم النوع: سعر يوم لهذا النوع';
      case PriceSource.defaultWeekday:
        return 'يوم «عام»: سعر يوم لكل الأنواع';
      case PriceSource.typeBase:
        return 'احتياطي: سعر احتياطي للنوع';
      case PriceSource.chaletDefault:
        return 'افتراضي: سعر الشاليه';
    }
  }
}
