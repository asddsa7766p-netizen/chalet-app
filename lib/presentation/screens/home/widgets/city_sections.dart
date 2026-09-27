import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/chalet_model.dart';
import '../../../widgets/common/common_widgets.dart' show ShimmerCard;

/// أقصى عدد شاليهات بقسم مدينة بالرئيسية ("عرض الكل" للباقي).
const citySectionLimit = 10;

/// ترتيب أقسام المدن بالرئيسية من [counts] (عدد شاليهات كل مدينة):
/// - المدن التي فيها شاليهات فقط، الأكثر شاليهات أولاً (التعادل بترتيب
///   [AppStrings.cities]).
/// - عند اختيار مدينة ([selectedCity] ليست "الكل"): قسمها أولاً ثم الباقي.
List<String> orderCitySections(Map<String, int> counts, String selectedCity) {
  int rank(String c) {
    final i = AppStrings.cities.indexOf(c);
    return i < 0 ? AppStrings.cities.length : i;
  }

  final cities = [
    for (final e in counts.entries)
      if (e.value > 0) e.key,
  ]..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : rank(a).compareTo(rank(b));
    });
  if (selectedCity != AppStrings.allCities && cities.remove(selectedCity)) {
    cities.insert(0, selectedCity);
  }
  return cities;
}

/// أقسام المدن كـ sliver كسول: يُبنى القسم (ويبدأ جلب شاليهاته العشرة)
/// فقط عند اقترابه من الشاشة أثناء التمرير، لا كل المدن دفعة واحدة.
/// [loadCity] يجب أن يحفظ نتيجة كل مدينة (memoize) حتى لا يُعاد الجلب عند
/// الرجوع بالتمرير.
class CitySectionsSliver extends StatelessWidget {
  final List<String> cities;
  final Future<List<ChaletModel>> Function(String city) loadCity;
  final void Function(String city) onRetry;
  final void Function(String city) onViewAll;
  final Widget Function(ChaletModel chalet) cardBuilder;

  const CitySectionsSliver({
    super.key,
    required this.cities,
    required this.loadCity,
    required this.onRetry,
    required this.onViewAll,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => CityChaletsSection(
          key: ValueKey('city_section_${cities[i]}'),
          city: cities[i],
          chalets: loadCity(cities[i]),
          onRetry: () => onRetry(cities[i]),
          onViewAll: () => onViewAll(cities[i]),
          cardBuilder: cardBuilder,
        ),
        childCount: cities.length,
      ),
    );
  }
}

/// قسم مدينة واحدة: "شاليهات <المدينة>" + "عرض الكل"، وحتى
/// [citySectionLimit] شاليهات بتمرير أفقي. يختفي إن لم يرجع شيئاً.
class CityChaletsSection extends StatelessWidget {
  final String city;
  final Future<List<ChaletModel>> chalets;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final Widget Function(ChaletModel chalet) cardBuilder;

  const CityChaletsSection({
    super.key,
    required this.city,
    required this.chalets,
    required this.onRetry,
    required this.onViewAll,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChaletModel>>(
      future: chalets,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final items = (snap.data ?? const <ChaletModel>[])
            .take(citySectionLimit)
            .toList();
        if (!loading && !snap.hasError && items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text(
                      'عرض الكل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    'شاليهات $city',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 230,
                child: snap.hasError
                    ? Center(
                        child: TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تعذر التحميل، إعادة المحاولة',
                              style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: loading ? 2 : items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => loading
                            ? const SizedBox(
                                width: 220,
                                child: ShimmerCard(
                                    height: 230,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(18))),
                              )
                            : cardBuilder(items[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
