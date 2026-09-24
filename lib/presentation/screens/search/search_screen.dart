import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/login_prompt.dart';
import '../../../data/providers/favorites_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  // ✅ إصلاح: كان مسار '/search?city=...' القادم من الرئيسية (أقسام المدن)
  // و'/search?type=pool' (فئات الرئيسية) يُهملان بالكامل — GoRoute كانت
  // تبني SearchScreen() بدون أي معطيات، فتفتح الشاشة دائمًا بلا فلترة
  // فعلية بغض النظر عن رابط الدخول. الآن الفلتر الأولي يُمرَّر فعليًا.
  final String? initialCity;
  final bool initialHasPool;
  final bool initialHasWifi;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialCity,
    this.initialHasPool = false,
    this.initialHasWifi = false,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

// قيمة "عدد الضيوف" الافتراضية — لا تُحتسب كفلتر نشط طالما لم يغيّرها
// المستخدم (تُرسل دائماً للـbackend، لكنها لا تُعرض كشريحة فلتر فعّال).
const int _kDefaultGuests = 2;

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();

  // ✅ إصلاح: حقلا السعر كانا يبنيان TextEditingController جديداً بكل
  // build() (داخل الودجت مباشرة) بدل الاحتفاظ بمرجع ثابت — يعني كل
  // ضغطة حرف تعيد بناء الحقل بمؤشر/تحكّم جديد فيفقد المستخدم مكان
  // الكتابة والتركيز أثناء الكتابة. الآن اثنان Controller ثابتان.
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  late String _city = widget.initialCity ?? 'الكل';
  double? _minPrice;
  double? _maxPrice;
  int _guests = _kDefaultGuests;

  late bool _hasPool = widget.initialHasPool;
  late bool _hasWifi = widget.initialHasWifi;
  bool _hasBbq = false;
  bool _hasParking = false;

  bool _loading = false;
  String? _error;
  List<ChaletModel> _results = [];

  // Debounce timer for live search while typing.
  Timer? _debounce;

  // ✅ إصلاح: بدون رقم طلب، ردّ متأخر لطلب قديم (كتابة سريعة/تغيير فلتر)
  // كان يستطيع الكتابة فوق نتيجة طلب أحدث فتظهر نتائج لا تطابق الفلاتر.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
    }
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await ChaletService.instance.getChalets(
        city: _city,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        hasPool: _hasPool,
        hasWifi: _hasWifi,
        hasBbq: _hasBbq,
        hasParking: _hasParking,
        minGuests: _guests,
        searchQuery: _searchCtrl.text,
        limit: 30,
      );

      if (mounted && requestId == _requestId) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = 'تعذر تحميل النتائج، يرجى المحاولة لاحقاً';
          _loading = false;
        });
      }
    }
  }

  // Called on every keystroke in the search field.
  // Debounced so we don't hit the backend on every single character.
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _load();
    });
  }

  void _resetFilters() {
    _debounce?.cancel();
    setState(() {
      _city = 'الكل';
      _minPrice = null;
      _maxPrice = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _guests = _kDefaultGuests;
      _hasPool = false;
      _hasWifi = false;
      _hasBbq = false;
      _hasParking = false;
    });
    _load();
  }

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
    int draftGuests = _guests;
    bool draftPool = _hasPool;
    bool draftWifi = _hasWifi;
    bool draftBbq = _hasBbq;
    bool draftParking = _hasParking;

    final minCtrl = TextEditingController(
        text: draftMin == null ? '' : draftMin.toStringAsFixed(0));
    final maxCtrl = TextEditingController(
        text: draftMax == null ? '' : draftMax.toStringAsFixed(0));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, setSheetState) {
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
                                draftCity = 'الكل';
                                draftMin = null;
                                draftMax = null;
                                minCtrl.clear();
                                maxCtrl.clear();
                                draftGuests = _kDefaultGuests;
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
                              _sheetSectionLabel('الميزانية لليلة (₪)'),
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
                                          double.tryParse(v.trim()),
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
                                          double.tryParse(v.trim()),
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
                                            if (draftGuests > 1) {
                                              draftGuests--;
                                            }
                                          }),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: Text('$draftGuests',
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.charcoal)),
                                        ),
                                        _circleBtn(
                                          Icons.add_rounded,
                                          () => setSheetState(
                                              () => draftGuests++),
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
                          setState(() {
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
        });
      },
    );

    minCtrl.dispose();
    maxCtrl.dispose();
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

  // ------------------------------------------------------------
  // شرائح الفلاتر النشطة فعلياً (المُطبَّقة على _results الحالية) —
  // تُشتق من نفس الحقول التي استُخدمت بآخر _load() ناجح، فتعكس دائماً
  // الحقيقة بدل تخمين ما هو مُطبَّق (مطلب: فهم واضح للفلاتر الحالية).
  // ------------------------------------------------------------
  List<_ActiveFilter> get _activeFilters {
    final chips = <_ActiveFilter>[];
    if (_city != 'الكل') {
      chips.add(_ActiveFilter(_city, () {
        setState(() => _city = 'الكل');
        _load();
      }));
    }
    if (_minPrice != null) {
      chips.add(_ActiveFilter('من ₪${_minPrice!.toStringAsFixed(0)}', () {
        setState(() {
          _minPrice = null;
          _minPriceCtrl.clear();
        });
        _load();
      }));
    }
    if (_maxPrice != null) {
      chips.add(_ActiveFilter('إلى ₪${_maxPrice!.toStringAsFixed(0)}', () {
        setState(() {
          _maxPrice = null;
          _maxPriceCtrl.clear();
        });
        _load();
      }));
    }
    if (_guests != _kDefaultGuests) {
      chips.add(_ActiveFilter('$_guests+ ضيوف', () {
        setState(() => _guests = _kDefaultGuests);
        _load();
      }));
    }
    if (_hasPool) {
      chips.add(_ActiveFilter(AppStrings.pool, () {
        setState(() => _hasPool = false);
        _load();
      }));
    }
    if (_hasWifi) {
      chips.add(_ActiveFilter(AppStrings.wifi, () {
        setState(() => _hasWifi = false);
        _load();
      }));
    }
    if (_hasBbq) {
      chips.add(_ActiveFilter('أدوات شواء', () {
        setState(() => _hasBbq = false);
        _load();
      }));
    }
    if (_hasParking) {
      chips.add(_ActiveFilter('موقف سيارات', () {
        setState(() => _hasParking = false);
        _load();
      }));
    }
    return chips;
  }

  // ✅ يميّز بين سببين مختلفين لنتيجة فارغة بلا أي طلب شبكة إضافي أو
  // تعديل على getChalets/منطق الفلاتر — فقط بالاعتماد على حالة الفلاتر
  // الحالية بالواجهة وقت وصول نتيجة فارغة فعلية من الخادم:
  //   - المدينة هي الفلتر النشط الوحيد (لا سعر/ضيوف/مرافق/نص بحث) → على
  //     الأغلب لا توجد شاليهات بهذه المدينة أصلاً حالياً، فنعرض "قريباً
  //     في [المدينة]" بدل حالة فارغة عامة.
  //   - غير ذلك (فلاتر أخرى فعّالة أو نص بحث) → نُبقي حالة "لا توجد
  //     نتائج" العامة الحالية كما هي دون أي تغيير، لأن السبب غامض
  //     (قد تكون المدينة نفسها فيها شاليهات لكن الجمع مع فلتر آخر
  //     استبعدها جميعاً).
  bool get _isCityOnlyEmptyResult {
    if (_city == 'الكل') return false;
    final hasOtherFilters = _minPrice != null ||
        _maxPrice != null ||
        _guests != _kDefaultGuests ||
        _hasPool ||
        _hasWifi ||
        _hasBbq ||
        _hasParking ||
        _searchCtrl.text.trim().isNotEmpty;
    return !hasOtherFilters;
  }

  void _clearCityFilter() {
    setState(() => _city = 'الكل');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = _activeFilters;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.explore),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _openFiltersSheet,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: AppStrings.filters,
                ),
                if (activeFilters.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${activeFilters.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildSearchField(),
              ),
            ),
            if (activeFilters.isNotEmpty)
              SliverToBoxAdapter(child: _buildActiveFiltersRow(activeFilters)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _loading
                          ? 'جارِ البحث...'
                          : '${_results.length} نتيجة',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    // ✅ إصلاح Layout: هذا الزر داخل Row (بجانب نص عدد
                    // النتائج) — لا يُقيَّد عرضه من الأب كما بالأزرار
                    // الأخرى بالملف (تلك كلها أعمدة Column تُقيّد العرض
                    // تلقائياً). ثيم التطبيق (app_theme.dart) يفرض
                    // minimumSize: Size(double.infinity, 52) افتراضياً
                    // على كل OutlinedButton ما لم يُستبدل صراحة، وهذا كان
                    // يجعل الزر يطلب عرضاً لا نهائياً داخل Row غير مقيّد
                    // له، فيرمي "BoxConstraints forces an infinite width"
                    // ويمنع فتح الشاشة بالكامل. الحل: تحديد minimumSize/
                    // tapTargetSize صراحة بقيم محدودة بدل الاعتماد على
                    // قيمة الثيم الافتراضية — يعمل بنفس الشكل على الويب
                    // والموبايل لأنها مسألة قيود تخطيط بحتة، لا خاصة بمنصة.
                    OutlinedButton.icon(
                      onPressed: _openFiltersSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        activeFilters.isEmpty
                            ? AppStrings.filters
                            : '${AppStrings.filters} (${activeFilters.length})',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(child: _buildErrorState())
            else if (_loading)
              SliverToBoxAdapter(child: _buildLoadingState())
            else if (_results.isEmpty)
              SliverToBoxAdapter(
                child: _isCityOnlyEmptyResult
                    ? _buildCityComingSoonState(_city)
                    : _buildEmptyState(hasFilters: activeFilters.isNotEmpty),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final chalet = _results[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: ChaletCard(
                          chalet: chalet,
                          horizontal: true,
                          // ✅ إصلاح: القلب بنتائج البحث كان معطّلاً بلا وظيفة
                          // (onFavoriteTap = null) ويعرض دائماً "غير مفضّل"
                          // حتى للشاليه المفضّل فعلاً بالرئيسية.
                          isFavorite: ref.watch(isFavoriteProvider(chalet.id)),
                          onFavoriteTap: () {
                            if (!requireAuth(
                                context,
                                PendingAuthAction('toggle_favorite',
                                    {'chaletId': chalet.id}))) {
                              return;
                            }
                            ref
                                .read(favoritesProvider.notifier)
                                .toggleFavorite(chalet);
                          },
                          onTap: () => context.push(
                            '/home/chalet/${chalet.id}',
                            extra: chalet,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow(List<_ActiveFilter> filters) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == filters.length) {
              return TextButton(
                onPressed: _resetFilters,
                child: const Text('مسح الكل',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
              );
            }
            final f = filters[i];
            return InkWell(
              onTap: f.onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPale,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f.label,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        children: List.generate(
          4,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: ShimmerCard(height: 130),
          ),
        ),
      ),
    );
  }

  // ✅ إصلاح: كانت حالة الخطأ نصاً فقط بلا أي زر لإعادة المحاولة — يضطر
  // المستخدم للسحب للتحديث (RefreshIndicator) بدون أي إشارة أن ذلك ممكن.
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 44, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ حالة مخصّصة: مدينة محدَّدة بلا أي شاليهات فيها حالياً (بدل صفحة
  // فارغة/حالة عامة غير مناسبة). لا تفترض وجود شاليهات مستقبلاً بأي
  // موعد، فقط توضّح أن الخدمة غير متاحة بهذه المدينة "حالياً" وتقترح
  // إجراءً فورياً حقيقياً (إزالة فلتر المدينة). نفس Design System
  // المستخدم بباقي الشاشات (AppColors + دوائر أيقونات + أزرار موحّدة).
  Widget _buildCityComingSoonState(String city) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.villa_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'قريبًا في $city',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'نعمل على إضافة شاليهات جديدة في هذه المدينة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _clearCityFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('استكشف المدن المتاحة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ إصلاح: كانت حالة عدم وجود نتائج مجرد جملة رمادية بلا أي اقتراح
  // للمستخدم. الآن رسالة أوضح + زر مباشر لمسح الفلاتر عندما تكون هي
  // السبب الأرجح لعدم ظهور نتائج.
  Widget _buildEmptyState({required bool hasFilters}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 14),
            const Text(
              'لا توجد شاليهات مطابقة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'جرّب توسيع نطاق السعر أو تغيير المدينة أو إزالة بعض الفلاتر'
                  : 'جرّب كلمة بحث مختلفة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _resetFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('مسح كل الفلاتر',
                    style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return CustomTextField(
      controller: _searchCtrl,
      label: '',
      hint: 'اسم الشاليه أو موقعه... ',
      prefixIcon: Icons.search_rounded,
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildCityDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: {
            'الكل',
            ...AppStrings.cities,
          }.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
    );
  }

  Widget _amenityChip(
    String label,
    IconData icon,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryPale.withOpacity(0.4)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryPale : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilter {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilter(this.label, this.onRemove);
}
