part of 'search_screen.dart';

extension _SearchFiltersSheet on _SearchScreenState {
  // ------------------------------------------------------------
  // ✅ إعادة تصميم: الفلاتر التفصيلية (مدينة/سعر/ضيوف/مرافق) انتقلت من
  // نموذج طويل دائم الظهور فوق النتائج إلى Bottom Sheet واحد، بنمط
  // "تطبيق" صريح وموحّد لكل الفلاتر معاً (بدل تطبيق فوري للمدينة وتطبيق
  // يدوي للباقي كما كان سابقاً — سلوك غير متسق). التعديلات داخل الشيت
  // مسودة محلية فقط ولا تُطبَّق على النتائج إلا بالضغط على "تطبيق
  // الفلاتر"، فما تتغيّر شرائح الفلاتر النشطة فوق القائمة قبل التأكيد.
  // ------------------------------------------------------------
  Future<void> _openFiltersSheet() async {
    String draftCity = _city;
    double? draftMin = _minPrice;
    double? draftMax = _maxPrice;
    int? draftGuests = _guests;
    bool draftPool = _hasPool;
    bool draftWifi = _hasWifi;
    bool draftBbq = _hasBbq;
    bool draftParking = _hasParking;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // متحكما السعر يملكهما _SheetPriceControllers فيُحرَّران عند إزالة
        // الورقة من الشجرة فعلاً (بعد حركة الإغلاق)، لا فور اكتمال هذا
        // الـ Future والورقة ما زالت تُرسم.
        return _SheetPriceControllers(
            initialMin: draftMin,
            initialMax: draftMax,
            builder: (minCtrl, maxCtrl) =>
                StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                draftCity = AppStrings.allCities;
                                draftMin = null;
                                draftMax = null;
                                minCtrl.clear();
                                maxCtrl.clear();
                                draftGuests = null;
                                draftPool = false;
                                draftWifi = false;
                                draftBbq = false;
                                draftParking = false;
                              });
                            },
                            child: const Text('مسح الكل',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                          ),
                          const Text(
                            'تصفية النتائج',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sheetSectionLabel('المدينة'),
                              const SizedBox(height: 8),
                              _buildCityDropdown(
                                value: draftCity,
                                onChanged: (v) =>
                                    setSheetState(() => draftCity = v),
                              ),
                              const SizedBox(height: 18),
                              _sheetSectionLabel('الميزانية — السعر يبدأ من (₪)'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: minCtrl,
                                      label: '',
                                      hint: 'سعر أدنى',
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => draftMin =
                                          parseLocalizedDouble(v),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: maxCtrl,
                                      label: '',
                                      hint: 'سعر أعلى',
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => draftMax =
                                          parseLocalizedDouble(v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _sheetSectionLabel('عدد الضيوف (الحد الأدنى)'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.sand),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('الضيوف',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.charcoal)),
                                    Row(
                                      children: [
                                        _circleBtn(
                                          Icons.remove_rounded,
                                          () => setSheetState(() {
                                            final g = draftGuests;
                                            // من 1 للأسفل: رجوع لـ "أي عدد" (لا فلتر).
                                            if (g != null) {
                                              draftGuests = g > 1 ? g - 1 : null;
                                            }
                                          }),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text(draftGuests?.toString() ?? 'أي عدد',
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.charcoal)),
                                        ),
                                        _circleBtn(
                                          Icons.add_rounded,
                                          () => setSheetState(
                                              () => draftGuests =
                                                  (draftGuests ?? 0) + 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _sheetSectionLabel('المرافق'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _amenityChip(
                                    AppStrings.pool,
                                    Icons.pool_rounded,
                                    draftPool,
                                    (v) => setSheetState(() => draftPool = v),
                                  ),
                                  _amenityChip(
                                    AppStrings.wifi,
                                    Icons.wifi_rounded,
                                    draftWifi,
                                    (v) => setSheetState(() => draftWifi = v),
                                  ),
                                  _amenityChip(
                                    'أدوات شواء',
                                    Icons.outdoor_grill_rounded,
                                    draftBbq,
                                    (v) => setSheetState(() => draftBbq = v),
                                  ),
                                  _amenityChip(
                                    'موقف سيارات',
                                    Icons.local_parking_rounded,
                                    draftParking,
                                    (v) =>
                                        setSheetState(() => draftParking = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'تطبيق الفلاتر',
                        icon: Icons.filter_list_rounded,
                        onPressed: () {
                          _setState(() {
                            _city = draftCity;
                            _minPrice = draftMin;
                            _maxPrice = draftMax;
                            _guests = draftGuests;
                            _hasPool = draftPool;
                            _hasWifi = draftWifi;
                            _hasBbq = draftBbq;
                            _hasParking = draftParking;
                          });
                          Navigator.of(sheetContext).pop();
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }));
      },
    );
  }

  Widget _sheetSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      );
}

/// يملك متحكمي نص السعر الأدنى/الأعلى لورقة الفلاتر ويحرّرهما بـ dispose()
/// الخاص به، أي حين تُزال الورقة من الشجرة بعد انتهاء حركة إغلاقها.
class _SheetPriceControllers extends StatefulWidget {
  const _SheetPriceControllers({
    required this.initialMin,
    required this.initialMax,
    required this.builder,
  });

  final double? initialMin;
  final double? initialMax;
  final Widget Function(
      TextEditingController minCtrl, TextEditingController maxCtrl) builder;

  @override
  State<_SheetPriceControllers> createState() => _SheetPriceControllersState();
}

class _SheetPriceControllersState extends State<_SheetPriceControllers> {
  late final _min = TextEditingController(text: _text(widget.initialMin));
  late final _max = TextEditingController(text: _text(widget.initialMax));

  static String _text(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_min, _max);
}
