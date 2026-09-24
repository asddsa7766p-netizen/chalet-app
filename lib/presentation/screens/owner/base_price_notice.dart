import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/pricing_service.dart';
import 'pricing_preview.dart';

/// إشعار داخل بطاقة نوع الإقامة يوضّح أثر "السعر الاحتياطي" الفعلي.
///
/// أربع حالات منفصلة (حسب [BasePriceImpact.status]):
/// - notSet: لا شيء.
/// - ignored: لن يُطبَّق على أي يوم (كل الأيام مغطّاة بسعر يسبقه).
/// - partial: يُطبَّق على أيام محددة فقط (لا تُعرض عبارة "لن يُطبَّق").
/// - applied: يُطبَّق على كل الأيام.
///
/// في ignored وpartial يظهر زر ينقل المالك مباشرة لضبط أسعار أيام هذا النوع.
class BasePriceNotice extends StatelessWidget {
  final ChaletStayType type;
  final BasePriceImpact impact;
  final VoidCallback onOpenTypePrices;

  const BasePriceNotice({
    super.key,
    required this.type,
    required this.impact,
    required this.onOpenTypePrices,
  });

  @override
  Widget build(BuildContext context) {
    final price = impact.price;
    if (impact.status == BasePriceStatus.notSet || price == null) {
      return const SizedBox.shrink();
    }
    final p = '₪${formatPriceNumber(price)}';

    switch (impact.status) {
      case BasePriceStatus.applied:
        return _box(
          key: _key(BasePriceStatus.applied),
          color: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
          title: 'سيُطبَّق $p على كل الأيام',
          body: 'لأنه ما فيه سعر يوم (لهذا النوع أو «عام») يسبقه.',
        );
      case BasePriceStatus.ignored:
        return _box(
          key: _key(BasePriceStatus.ignored),
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          title: 'السعر الاحتياطي $p لن يُطبَّق على أي يوم',
          body: _ignoredReason(),
          action: true,
        );
      case BasePriceStatus.partial:
        return _box(
          key: _key(BasePriceStatus.partial),
          color: AppColors.warning,
          icon: Icons.info_outline_rounded,
          title:
              'السعر الاحتياطي $p يُطبَّق على ${describeWeekdays(impact.appliedDays)} فقط',
          body: _partialRest(),
          action: true,
        );
      case BasePriceStatus.notSet:
        return const SizedBox.shrink();
    }
  }

  Key _key(BasePriceStatus s) => ValueKey('baseImpact_${type.dbValue}_${s.name}');

  String _ignoredReason() {
    final byType = impact.coveredByTypeDays;
    final byDefault = impact.coveredByDefaultDays;
    if (byDefault.isEmpty) {
      return 'لأن كل أيام الأسبوع لها سعر يوم خاص بنوع "${type.label}".';
    }
    if (byType.isEmpty) {
      return 'لأن كل أيام الأسبوع لها سعر «عام»، وسعر «عام» يسبق السعر الاحتياطي.';
    }
    return 'لأن كل الأيام مغطّاة: ${describeWeekdays(byType)} بأسعار هذا النوع، '
        'و${describeWeekdays(byDefault)} بأسعار «عام».';
  }

  String _partialRest() {
    final segments = <String>[
      if (impact.coveredByTypeDays.isNotEmpty)
        '${describeWeekdays(impact.coveredByTypeDays)} بأسعار هذا النوع',
      if (impact.coveredByDefaultDays.isNotEmpty)
        '${describeWeekdays(impact.coveredByDefaultDays)} بأسعار «عام»',
    ];
    return 'باقي الأيام مغطّاة بسعر أعلى أولوية: ${segments.join('، و')}.';
  }

  Widget _box({
    required Key key,
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    bool action = false,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 26, top: 2),
            child: Text(
              body,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (action)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('baseImpactAction_${type.dbValue}'),
                onPressed: onOpenTypePrices,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(
                  'اضبط أسعار الأيام لهذا النوع',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
