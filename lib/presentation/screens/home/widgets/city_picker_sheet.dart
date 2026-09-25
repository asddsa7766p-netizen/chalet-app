part of '../home_tab.dart';

extension _CityPickerSheet on _HomeTabState {
  // ------------------------------------------------------------
  // ✅ إصلاح: هاي الدالة كانت ناقصة بالكامل — زر المدينة بالهيدر كان
  // مربوط بـ TODO فاضي. تفتح Bottom Sheet لاختيار المدينة من نفس
  // قائمة _chips المستخدمة أصلاً بفلترة الشاليهات.
  //
  // mandatory=true (أول فتح للشاشة، ما في اختيار محفوظ سابقًا): الشيت
  // غير قابل للإغلاق بالسحب لأسفل ولا بالضغط خارجها، ولازم يختار مدينة
  // عشان يكمل. mandatory=false (من زر الهيدر لاحقاً): قابل للإغلاق
  // عادي، ويقدر يختار "الكل" لعرض كل المدن.
  //
  // أي اختيار (إجباري أو من الهيدر) يُحفظ فورًا عبر SharedPreferences
  // (_preferredCityKey) فما ترجع الشاشة الإجبارية تظهر بجلسات لاحقة، وهذا
  // لا يمنع المستخدم من تغيير المدينة أو استكشاف "كل المدن" لاحقًا.
  // ------------------------------------------------------------
  Future<void> _showCityPicker({bool mandatory = false}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isDismissible: !mandatory,
      enableDrag: !mandatory,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  mandatory ? 'اختر مدينتك للمتابعة' : 'اختر المدينة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(sheetContext).textTheme.bodyLarge?.color,
                  ),
                ),
                if (mandatory) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'حتى نعرض لك أقرب الشاليهات المتاحة عندك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...(_HomeTabState._chips.map((city) {
                  final selected = city == _selectedCity;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(sheetContext).pop(city),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                city == AppStrings.allCities
                                    ? Icons.public_rounded
                                    : Icons.location_city_rounded,
                                size: 20,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  city == AppStrings.allCities ? 'كل المدن' : city,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : Theme.of(sheetContext)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_rounded,
                                    size: 20, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                })),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      _setState(() => _hasSelectedCity = true);
      unawaited(_persistCityPreference(result));
      if (result != _selectedCity) {
        _filterByCity(result);
      }
    } else if (mandatory && mounted && !_hasSelectedCity) {
      // المستخدم حاول يتهرب من الاختيار الإجباري (مثلاً بزر الرجوع
      // بالأندرويد). بما إنه isDismissible=false و enableDrag=false،
      // هاد المسار نادر الحدوث، لكن كحماية إضافية نعيد فتح الشيت.
      _showCityPicker(mandatory: true);
    }
  }
}
