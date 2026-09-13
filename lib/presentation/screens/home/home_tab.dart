import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../../data/services/location_service.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../widgets/common/luxury_widgets.dart';
import 'dart:async' if (dart.library.html) 'dart:async';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _searchCtrl = TextEditingController();
  String _selectedCity = 'الكل';

  // ✅ إصلاح: يتتبع إذا المستخدم اختار مدينة فعلياً (بدل الاعتماد بس على
  // القيمة الافتراضية 'الكل'). يُستخدم لإجبار فتح شاشة اختيار المدينة
  // أول ما تفتح الشاشة، وما ينسمح تسكرها لحد ما يختار.
  //
  // ⚠️ هاد المتغيّر بالذاكرة بس (مش محفوظ)، يعني رح يرجع يطلب الاختيار
  // من جديد كل ما يعاد فتح التطبيق. إذا بدك الاختيار يصير "مرة وحدة
  // للأبد"، خزّنه بـ SharedPreferences (مثال بالأسفل بتعليق
  // _showCityPicker) وحمّل القيمة المحفوظة بـ initState.
  bool _hasSelectedCity = false;

  static const _chips = [
    'الكل',
    'رام الله',
    'نابلس',
    'جنين',
    'الخليل',
    'أريحا',
    'بيت لحم',
  ];

  // ------------------------------------------------------------
  // NEW: cities shown as their own horizontal sections on the
  // home screen, below "أماكن مميزة". Add/remove city names here
  // and the matching section appears/disappears automatically.
  // ------------------------------------------------------------
  static const List<String> _featuredCitySections = [
    'جنين',
    'رام الله',
    'القدس',
    'الناصرة',
  ];

  List<ChaletModel> _featured = [];
  List<ChaletModel> _all = [];
  // NEW: unfiltered pool of chalets used to build the per-city sections.
  List<ChaletModel> _allForGrouping = [];
  // NEW: city name -> chalets in that city, derived from _allForGrouping.
  Map<String, List<ChaletModel>> _cityChalets = {};
  bool _loading = true;
  String? _error;
  String? _userName;

  // NEW: موقع المستخدم الحالي (GPS) — يُستخدم لحساب المسافة وعرض
  // قسم "بالقرب منك". null يعني الصلاحية مرفوضة/معطلة أو لم يُجلب بعد.
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserLocation();

    // ✅ إصلاح: إجبار المستخدم على اختيار مدينة أول ما تُفتح الشاشة.
    // نستخدم addPostFrameCallback لأن showModalBottomSheet يحتاج
    // BuildContext جاهز بعد أول build، مش من جوا initState مباشرة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasSelectedCity) {
        _showCityPicker(mandatory: true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // NEW: يطلب صلاحية الموقع ويجلب الموقع الحالي بهدوء. لا يرمي أي
  // استثناء ولا يعطّل باقي الشاشة لو رُفضت الصلاحية أو كان GPS مطفي.
  Future<void> _loadUserLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (mounted && pos != null) {
      setState(() => _userPosition = pos);
    }
  }

  // NEW: المسافة بالكيلومتر بين المستخدم وشاليه معيّن، أو null إذا
  // كان موقع المستخدم أو إحداثيات الشاليه غير متوفرة.
  double? _distanceToChalet(ChaletModel chalet) {
    if (_userPosition == null || !chalet.hasLocation) return null;
    return LocationService.instance.distanceInKm(
      lat1: _userPosition!.latitude,
      lon1: _userPosition!.longitude,
      lat2: chalet.latitude!,
      lon2: chalet.longitude!,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ChaletService.instance.getFeaturedChalets(),
        ChaletService.instance.getChalets(city: _selectedCity),
        AuthService.instance.getCurrentProfile(),
        // NEW: broader pool (no city filter) so we can group it by city
        // client-side below, instead of firing one network call per city.
        ChaletService.instance.getChalets(),
      ]);
      if (mounted) {
        setState(() {
          _featured = results[0] as List<ChaletModel>;
          _all = results[1] as List<ChaletModel>;
          _userName = (results[2] as dynamic)?.fullName;
          _allForGrouping = results[3] as List<ChaletModel>;
          _cityChalets = {
            for (final city in _featuredCitySections)
              city: _allForGrouping.where((c) => c.city == city).toList(),
          };
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('HOME ERROR: $e');
      debugPrint('STACK: $stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(ChaletModel chalet) async {
    await ref.read(favoritesProvider.notifier).toggleFavorite(chalet);
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final results = await ChaletService.instance
          .getChalets(searchQuery: q, city: _selectedCity);
      if (mounted) {
        setState(() {
          _all = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _filterByCity(String city) async {
    setState(() {
      _selectedCity = city;
      _loading = true;
    });
    try {
      final results = await ChaletService.instance.getChalets(city: city);
      if (mounted) {
        setState(() {
          _all = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------
  // ✅ إصلاح: هاي الدالة كانت ناقصة بالكامل — زر المدينة بالهيدر كان
  // مربوط بـ TODO فاضي. تفتح Bottom Sheet لاختيار المدينة من نفس
  // قائمة _chips المستخدمة أصلاً بفلترة الشاليهات.
  //
  // mandatory=true (أول فتح للشاشة): الشيت غير قابل للإغلاق بالسحب
  // لأسفل ولا بالضغط خارجها، ولازم يختار مدينة عشان يكمل.
  // mandatory=false (من زر الهيدر لاحقاً): قابل للإغلاق عادي، ويقدر
  // يختار "الكل" لعرض كل المدن.
  //
  // ⚠️ إذا بدك الاختيار يتحفظ بين جلسات التطبيق (مش بس بالجلسة
  // الحالية)، ضيف شرط تحميل/حفظ عبر SharedPreferences، مثال:
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('selected_city', city);
  // واقرأها بـ initState قبل قرار إظهار الشيت الإجباري.
  // ------------------------------------------------------------
  Future<void> _showCityPicker({bool mandatory = false}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isDismissible: !mandatory,
      enableDrag: !mandatory,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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
                ...(_chips.map((city) {
                  final selected = city == _selectedCity;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected
                          ? AppColors.primary.withOpacity(0.08)
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
                                city == 'الكل'
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
                                  city == 'الكل' ? 'كل المدن' : city,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
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

    if (result != null) {
      setState(() => _hasSelectedCity = true);
      if (result != _selectedCity) {
        await _filterByCity(result);
      }
    } else if (mandatory && mounted && !_hasSelectedCity) {
      // المستخدم حاول يتهرب من الاختيار الإجباري (مثلاً بزر الرجوع
      // بالأندرويد). بما إنه isDismissible=false و enableDrag=false،
      // هاد المسار نادر الحدوث، لكن كحماية إضافية نعيد فتح الشيت.
      _showCityPicker(mandatory: true);
    }
  }

  // ==========================================================
  // build(): matches the "مكان" home screen mock, plus the new
  // per-city sections added right after "أماكن مميزة", and the
  // new "بالقرب منك" (near you) section based on GPS location.
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildWelcomeBanner()),
            SliverToBoxAdapter(child: _buildCategoriesRow()),
            SliverToBoxAdapter(child: _buildMostBookedSection()),
            // NEW: "بالقرب منك" section, sorted by real distance from GPS.
            // Hides itself automatically if location isn't available.
            SliverToBoxAdapter(child: _buildNearYouGrid()),
            // NEW: one horizontal section per city in _featuredCitySections
            for (final city in _featuredCitySections)
              SliverToBoxAdapter(child: _buildCitySection(city)),
            SliverToBoxAdapter(child: _buildInviteBanner()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // top header — bell (left) + logo (center) + city (right)
  // ------------------------------------------------------------
  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'مكان',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.primary, size: 22),
                    onPressed: () {
                      // ⚠️ TODO تاني بنفس النمط (إيقونة ظاهرة بدون وظيفة).
                      // ما عدّلتها لأنه ما في شاشة إشعارات جاهزة بعد —
                      // خبرني لو بدك أربطها بمسار موجود عندك.
                    },
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  // ✅ إصلاح: هون بالضبط كانت المشكلة — onTap فاضي (TODO).
                  onTap: () => _showCityPicker(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // ✅ إصلاح: سابقاً كانت تعرض "رام الله" ثابتة لما
                        // المدينة المختارة "الكل"، وكأنها المدينة الفعلية
                        // المختارة رغم إنه ما في اختيار حقيقي — مضلل.
                        _selectedCity == 'الكل' ? 'كل المدن' : _selectedCity,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on_rounded,
                          size: 20, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // banner is image + title only (no buttons)
  // ------------------------------------------------------------
  Widget _buildWelcomeBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GestureDetector(
        onTap: () => context.go('/search'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    _featured.isNotEmpty ? _featured.first.coverImage : '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.home_work_rounded,
                          color: Colors.grey, size: 44),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xB3000000),
                          Color(0x33000000),
                          Color(0x00000000),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  left: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'اكتشف\nأجمل الأماكن',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'احجز واستمتع بتجربة لا تُنسى',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 22,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 5 square category tiles
  // ------------------------------------------------------------
  Widget _buildCategoriesRow() {
    final categories = [
      {'label': 'شاليهات', 'icon': Icons.cottage_outlined, 'query': 'chalet'},
      {'label': 'مزارع', 'icon': Icons.agriculture_outlined, 'query': 'farm'},
      {'label': 'مسابح', 'icon': Icons.pool_outlined, 'query': 'pool'},
      {
        'label': 'أماكن إقامة',
        'icon': Icons.apartment_outlined,
        'query': 'stay'
      },
      {'label': 'المزيد', 'icon': Icons.grid_view_rounded, 'query': null},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: categories.map((cat) {
          return GestureDetector(
            onTap: () {
              final q = cat['query'] as String?;
              context.go(q == null ? '/search' : '/search?type=$q');
            },
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    cat['icon'] as IconData,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cat['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------
  // "أماكن مميزة" — now uses the shared _buildPlaceCard() so the
  // exact same card design is reused by the per-city sections below.
  // ------------------------------------------------------------
  Widget _buildMostBookedSection() {
    final items = _featured.isEmpty ? [] : _featured.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.go('/search'),
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
              const Text(
                'أماكن مميزة',
                style: TextStyle(
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
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.isEmpty ? 2 : items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (items.isEmpty) {
                  return Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: AppColors.border.withOpacity(0.2)),
                    ),
                  );
                }
                return _buildPlaceCard(items[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NEW: one horizontal section for a given city, e.g. "شاليهات جنين".
  // Pulls its chalets from _cityChalets (grouped in _load()).
  // The whole section hides itself if that city has nothing to show
  // once loading is done — no empty section on the home screen.
  // ------------------------------------------------------------
  Widget _buildCitySection(String city) {
    final chalets = _cityChalets[city] ?? const <ChaletModel>[];

    if (!_loading && chalets.isEmpty) {
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
                onPressed: () => context.go('/search?city=$city'),
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
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _loading ? 2 : chalets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (_loading) {
                  return Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: AppColors.border.withOpacity(0.2)),
                    ),
                  );
                }
                return _buildPlaceCard(chalets[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NEW: shared card widget for the horizontal "مميزة" / per-city
  // rows. Extracted out of _buildMostBookedSection so both use the
  // exact same look (heart on the right, rating badge, name/price).
  // ------------------------------------------------------------
  Widget _buildPlaceCard(ChaletModel chalet) {
    final isFav = ref.watch(isFavoriteProvider(chalet.id));
    return GestureDetector(
      onTap: () => context.push('/home/chalet/${chalet.id}', extra: chalet),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                      child: Image.network(
                        chalet.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.home_work_rounded,
                              color: Colors.grey, size: 44),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(chalet),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? Colors.red : Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            chalet.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      chalet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                '${chalet.city} , فلسطين',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A73E8),
                              ),
                            ),
                            const Text(
                              '/ الليلة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // "ادعو أصدقائك" invite banner
  // ------------------------------------------------------------
  Widget _buildInviteBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.accentLight.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ادعو أصدقائك',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'واحصل على رصيد هدية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        // ⚠️ TODO تاني بنفس النمط — ماله منطق مشاركة/دعوة
                        // مربوط بعد. خبرني لو بدك أربطه بنظام إحالة موجود.
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ادعو الآن',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.card_giftcard_rounded,
                size: 60, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // UNCHANGED helpers kept below (still used by _buildSearchBar,
  // and left in place in case other screens/tests reference them).
  // ------------------------------------------------------------

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 1,
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
                width: 1, style: BorderStyle.solid, color: Color(0x3300450d)),
            end: BorderSide(
                width: 1, style: BorderStyle.solid, color: Color(0x3300450d)),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // UPDATED: "بالقرب منك" section — now driven by real GPS distance
  // instead of a static placeholder. Sorted nearest-first, and the
  // whole section hides itself automatically when:
  //   - location permission isn't granted / GPS is off, or
  //   - no chalet has coordinates yet.
  // ------------------------------------------------------------
  Widget _buildNearYouGrid() {
    if (_userPosition == null) return const SizedBox.shrink();

    final withDistance = _allForGrouping
        .where((c) => c.hasLocation)
        .map((c) => MapEntry(c, _distanceToChalet(c)!))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (withDistance.isEmpty) return const SizedBox.shrink();

    final items = withDistance.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'بالقرب منك',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'بناءً على موقعك الحالي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 1.55,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _buildNearYouTile(items[i].key, items[i].value),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // UPDATED: now takes the real distance (km) instead of showing
  // the city name, since the whole point of this tile is proximity.
  // ------------------------------------------------------------
  Widget _buildNearYouTile(ChaletModel chalet, double distanceKm) {
    return GestureDetector(
      onTap: () => context.push('/home/chalet/${chalet.id}', extra: chalet),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: Image.network(
                chalet.coverImage,
                width: 90,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 70,
                  color: Colors.grey[200],
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.grey, size: 28),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chalet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${distanceKm.toStringAsFixed(1)} كم',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.near_me_rounded,
                            size: 12, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return LuxurySearchBar(
      controller: _searchCtrl,
      hintText: AppStrings.search,
      onChanged: _search,
      onClear: () {
        _searchCtrl.clear();
        _search('');
      },
    );
  }

  Widget _buildCityFilter() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chips.length,
        itemBuilder: (_, i) {
          final city = _chips[i];
          final selected = city == _selectedCity;
          return Padding(
            padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _filterByCity(city),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.textPrimary : AppColors.white,
                  border: Border.all(
                    color: selected ? Colors.transparent : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  city,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatured() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LuxurySectionHeader(
            title: AppStrings.featuredChalets,
            emoji: '⭐',
          ),
          const SizedBox(height: 12),
          if (_loading)
            SizedBox(
              height: 285,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (_, i) => Container(
                  width: 250,
                  margin: const EdgeInsets.only(left: 16),
                  child: const LuxuryShimmerCard(height: 285),
                ),
              ),
            )
          else if (_featured.isEmpty)
            const LuxuryEmptyState(
              icon: Icons.search_off_rounded,
              message: 'لا توجد شاليهات مميزة حالياً',
            )
          else
            SizedBox(
              height: 285,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                itemBuilder: (_, i) => Container(
                  width: 250,
                  margin: const EdgeInsets.only(left: 16),
                  child: _buildFeaturedCard(_featured[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllChalets() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accentLight],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _selectedCity == 'الكل'
                    ? 'جميع الشاليهات'
                    : 'شاليهات $_selectedCity',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            Column(
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else if (_all.isEmpty)
            const _EmptyState(message: 'لا توجد شاليهات متاحة')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _all.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildListCard(_all[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(ChaletModel chalet) {
    final isFav = ref.watch(isFavoriteProvider(chalet.id));
    return GestureDetector(
      onTap: () => context.push('/home/chalet/${chalet.id}', extra: chalet),
      child: Container(
        height: 285,
        width: 250,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 175,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        chalet.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.home_work_rounded,
                              color: Colors.grey, size: 44),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          chalet.city,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(chalet),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      chalet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            chalet.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A73E8),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              chalet.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(ChaletModel chalet) {
    final isFav = ref.watch(isFavoriteProvider(chalet.id));
    return GestureDetector(
      onTap: () => context.push('/home/chalet/${chalet.id}', extra: chalet),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                chalet.coverImage,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey[200],
                  child:
                      const Icon(Icons.home_work_rounded, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      chalet.name,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            chalet.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.grey,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleFavorite(chalet),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                        Text(
                          '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            'فشل تحميل البيانات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'تحقق من اتصالك بالإنترنت',
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.grey.withOpacity(0.2), width: 2),
              ),
              child: const Icon(Icons.home_work_outlined,
                  size: 40, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
