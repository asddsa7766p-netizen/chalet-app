import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../widgets/common/luxury_widgets.dart';
import '../profile/profile_provider.dart';
import '../../widgets/common/login_prompt.dart';
import 'dart:async';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _searchCtrl = TextEditingController();
  String _selectedCity = AppStrings.allCities;

  // ✅ إصلاح: يتتبع إذا المستخدم اختار مدينة فعلياً (بدل الاعتماد بس على
  // القيمة الافتراضية "الكل"). يُستخدم لإجبار فتح شاشة اختيار المدينة
  // فقط لما ما يكون في اختيار محفوظ سابقًا لهالمستخدم (انظر
  // _initCityPreferenceThenLoad/_persistCityPreference). القيمة محفوظة
  // عبر SharedPreferences بمفتاح خاص بكل مستخدم (auth uid)، فما بترجع
  // تسأل من جديد بعد إغلاق التطبيق أو تسجيل الخروج/الدخول بنفس الحساب.
  bool _hasSelectedCity = false;

  // مفتاح SharedPreferences لتخزين المدينة المفضّلة، بشكل خاص لكل مستخدم
  // (guest إذا ما في جلسة دخول) عشان ما يختلط اختيار مستخدم بآخر على نفس
  // الجهاز.
  static const _preferredCityKeyPrefix = 'preferred_city_';

  String get _preferredCityKey =>
      '$_preferredCityKeyPrefix${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';

  // نفس مصدر المدن بكل التطبيق (AppStrings.cities) مسبوقاً بـ "الكل".
  static const _chips = [AppStrings.allCities, ...AppStrings.cities];

  // ------------------------------------------------------------
  // cities shown as their own horizontal sections on the home
  // screen, below "أماكن مميزة". Add/remove city names here and
  // the matching section appears/disappears automatically.
  //
  // ✅ إصلاح: كانت القائمة تحتوي "القدس" و"الناصرة" رغم أنه لا يمكن لأي
  // شاليه أن يحمل هاتين المدينتين أصلاً (ليستا ضمن قائمة المدن بشاشة
  // إضافة شاليه) — فكان قسماهما ميتين دائمًا (يختفيان تلقائيًا لعدم وجود
  // بيانات). استُبدلا بمدينتين حقيقيتين يمكن أن تحتويا شاليهات فعلاً.
  // ------------------------------------------------------------
  static const List<String> _featuredCitySections = [
    'جنين',
    'رام الله',
    'نابلس',
    'الخليل',
  ];

  List<ChaletModel> _featured = [];
  // مجموع الشاليهات غير المفلترة (كل المدن)، تُستخدم لبناء أقسام المدن
  // ولحساب "بالقرب منك"، وأيضاً لفلترة العرض محلياً عند اختيار مدينة من
  // الهيدر (بدون أي طلب شبكة إضافي — انظر _filterByCity).
  List<ChaletModel> _allForGrouping = [];
  bool _loading = true;
  String? _error;

  // NEW: موقع المستخدم الحالي (GPS) — يُستخدم لحساب المسافة وعرض
  // قسم "بالقرب منك". null يعني الصلاحية مرفوضة/معطلة أو لم يُجلب بعد.
  Position? _userPosition;

  // ✅ إصلاح: عدد الإشعارات غير المقروءة لجرس الهيدر. تحميل مستقل وصامت
  // عن _load() الأساسية — فشله لا يجب أن يعطّل باقي الشاشة أو يُظهر
  // حالة خطأ عامة، تمامًا كمنطق _loadUserLocation() أعلاه.
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadUnreadNotifications();
    _initCityPreferenceThenLoad();
  }

  // ✅ إصلاح: يحمّل المدينة المفضّلة المحفوظة (إن وجدت) لهذا المستخدم قبل
  // أول استدعاء لـ _load()، بدل الاعتماد على متغيّر _hasSelectedCity
  // بالذاكرة فقط. إذا في اختيار محفوظ، نطبّقه كفلتر افتراضي ونتجاوز شاشة
  // الاختيار الإجباري. إذا ما في، نعرض الشاشة الإجبارية مرة وحدة فقط ثم
  // نحفظ اختيار المستخدم عشان ما ترجع تظهر ثانية (انظر _showCityPicker).
  Future<void> _initCityPreferenceThenLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_preferredCityKey);
      if (mounted && saved != null && saved.isNotEmpty) {
        setState(() {
          _hasSelectedCity = true;
          _selectedCity = saved;
        });
      }
    } catch (_) {
      // فشل صامت (مثلاً أول تشغيل بدون توفر التخزين بعد) — يتصرف كأنه
      // ما في اختيار محفوظ، فتظهر شاشة الاختيار الإجبارية كالمعتاد.
    }

    await _load();
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

  // ✅ إصلاح: يجلب عدد الإشعارات غير المقروءة بهدوء لعرضه كنقطة على
  // جرس الهيدر. لا تُستخدم NotificationService لأي شيء آخر هنا، ولا
  // يوجد تغيير على الخدمة نفسها — نفس الاستدعاء المستخدم أصلًا بشاشات
  // أخرى (مثل لوحة تحكم المالك).
  Future<void> _loadUnreadNotifications() async {
    try {
      final count = await NotificationService.instance.getUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {
      // فشل صامت — لا داعي لإظهار خطأ عام بسبب عداد ثانوي بالهيدر.
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
      // اسم المستخدم للترحيب يأتي من profileProvider (لا جلب ثانٍ للبروفايل هنا).
      final results = await Future.wait([
        ChaletService.instance.getFeaturedChalets(),
        // مجموعة غير مفلترة (بدون تحديد مدينة) نبني منها أقسام المدن
        // ونفلترها محلياً عند اختيار مدينة من الهيدر، بدل طلب شبكة منفصل
        // لكل مدينة أو عند كل تبديل.
        ChaletService.instance.getChalets(),
      ]);
      if (mounted) {
        setState(() {
          _featured = results[0];
          _allForGrouping = results[1];
          _loading = false;
        });
      }
    } catch (e, stack) {
      reportError(e, stack, context: 'home_load');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(ChaletModel chalet) async {
    // ✅ إصلاح: الضيف كان يضغط القلب فيومض ثم يرجع بصمت (الخدمة ترفض ضيفاً
    // والمزوّد يتراجع عن التحديث المتفائل) بلا أي إرشاد لتسجيل الدخول.
    if (!requireAuth(context,
        PendingAuthAction('toggle_favorite', {'chaletId': chalet.id}))) {
      return;
    }
    await ref.read(favoritesProvider.notifier).toggleFavorite(chalet);
  }

  // ✅ إصلاح: كانت هذه الدالة تُستدعى مع كل حرف يكتبه المستخدم بمربع
  // البحث بالرئيسية (onChanged) وتخزّن النتيجة بحقل (_all) لا تعرضه أي
  // واجهة فعلياً — أي أن البحث بالرئيسية لم يكن يُظهر أي نتيجة على
  // الإطلاق رغم أنه ينفّذ طلب شبكة حقيقي لكل ضغطة مفتاح. الآن مربع
  // البحث بالرئيسية ينقل المستخدم لشاشة البحث الفعلية (SearchScreen)
  // عند الإرسال، حيث يوجد فعلاً عرض نتائج/تحميل/فراغ متكامل.
  void _submitSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    context.push('/search?q=${Uri.encodeComponent(query)}');
  }

  // ✅ إصلاح: كانت تطلق طلب شبكة كامل (وتُظهر Loading على كامل الشاشة)
  // فقط لتخزين نتيجة لا تُعرض بأي مكان (_all)، رغم أن اختيار مدينة لا
  // يغيّر أي محتوى مرئي فعلياً غير نص الهيدر. الآن الفلترة تتم محلياً
  // وفوراً على البيانات المُحمَّلة أصلاً (_allForGrouping) بدون أي طلب
  // شبكة جديد ولا وميض تحميل على باقي الأقسام.
  void _filterByCity(String city) {
    setState(() => _selectedCity = city);
  }

  // يحفظ المدينة المختارة (أو "الكل") بشكل دائم لهذا المستخدم، عشان
  // شاشة الاختيار الإجباري ما ترجع تظهر بجلسات/تشغيلات لاحقة للتطبيق.
  Future<void> _persistCityPreference(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredCityKey, city);
    } catch (_) {
      // فشل صامت — أسوأ حالة إنه يرجع يسأل المرة الجاية، مش أهم من تعطيل
      // باقي الشاشة.
    }
  }

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

    if (result != null) {
      setState(() => _hasSelectedCity = true);
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

  // ==========================================================
  // build(): matches the "مكان" home screen mock, plus the new
  // per-city sections added right after "أماكن مميزة", and the
  // new "بالقرب منك" (near you) section based on GPS location.
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: Theme.of(context).cardColor,
        // ✅ إصلاح: _error كان يُضبط عند فشل _load() لكن لا يُقرأ أبدًا —
        // فشل الشبكة كان يمر بصمت وتبقى الشاشة فارغة بلا أي رسالة.
        // الآن، عند وجود خطأ (وبعد انتهاء التحميل)، نعرض _buildError()
        // الموجودة أصلًا (بها زر "إعادة المحاولة" الذي يستدعي _load نفسها)
        // مع الإبقاء على الهيدر ظاهرًا وRefreshIndicator يعمل للسحب لإعادة
        // المحاولة أيضًا. لا تغيير على منطق _load()/_search()/المفضلة.
        child: (_error != null && !_loading)
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildTopHeader()),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: _buildError()),
                  ),
                ],
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildTopHeader()),
                  SliverToBoxAdapter(child: _buildGreeting()),
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  SliverToBoxAdapter(child: _buildWelcomeBanner()),
                  SliverToBoxAdapter(child: _buildCategoriesRow()),
                  SliverToBoxAdapter(child: _buildMostBookedSection()),
                  // NEW: "بالقرب منك" section, sorted by real distance from GPS.
                  // Hides itself automatically if location isn't available.
                  SliverToBoxAdapter(child: _buildNearYouGrid()),
                  // ✅ إصلاح: عند اختيار مدينة معيّنة من الهيدر، نعرض قسمها
                  // فقط بدل كل الأقسام الأربعة الثابتة — بما إنه فعلياً صار
                  // فلتر حقيقي (انظر _filterByCity) بدل تسمية بلا أثر مرئي.
                  for (final city in _selectedCity == AppStrings.allCities
                      ? _featuredCitySections
                      : [_selectedCity])
                    SliverToBoxAdapter(child: _buildCitySection(city)),
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).cardColor,
                        border: Border.all(color: AppColors.border),
                      ),
                      // عبر GoRouter (/notifications) حتى يمر بحراسة المسارات؛
                      // الضيف يُوجَّه لتسجيل الدخول ثم تُفتح الإشعارات.
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'الإشعارات',
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: AppColors.primary, size: 22),
                        onPressed: () async {
                          if (!requireAuth(context,
                              const PendingAuthAction('open_notifications'))) {
                            return;
                          }
                          await context.push('/notifications');
                          if (mounted) _loadUnreadNotifications();
                        },
                      ),
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).cardColor, width: 1.5),
                          ),
                        ),
                      ),
                  ],
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
                        _selectedCity == AppStrings.allCities ? 'كل المدن' : _selectedCity,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Theme.of(context).textTheme.bodyLarge?.color),
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
  // ترحيب شخصي باسم المستخدم الأول. يختفي بهدوء للضيوف.
  // ------------------------------------------------------------
  Widget _buildGreeting() {
    // الاسم من profileProvider (يتحدّث عند تسجيل الدخول/الخروج).
    final name = ref.watch(profileProvider).valueOrNull?.fullName?.trim();
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final firstName = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'مرحباً، $firstName 👋',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge?.color,
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
  // صف فئات سريعة أسفل الهيدر.
  //
  // ✅ إصلاح: كانت 3 من أصل 5 فئات ("مزارع"، "مسابح"، "أماكن إقامة") لا
  // تطابق أي فلتر حقيقي بالـbackend — ChaletModel لا يحتوي مفهوم "نوع
  // عقار" إطلاقاً (فقط مرافق boolean: مسبح/واي فاي/شواء/موقف)، وشاشة
  // البحث كانت أصلاً تتجاهل query param اسمه "type" بالكامل. الضغط على
  // "مزارع" مثلاً كان يفتح نفس نتائج "المزيد" تماماً بدون أي فلترة فعلية
  // رغم أنه يوحي بخلاف ذلك. استُبدلت بفئتين حقيقيتين فقط (مسبح/واي فاي)
  // مبنيتين على حقول فعلية موجودة، والآن SearchScreen يقرأ query param
  // "type" فعلياً (انظر search_screen.dart + app_router.dart).
  // ------------------------------------------------------------
  Widget _buildCategoriesRow() {
    final categories = [
      {'label': 'كل الشاليهات', 'icon': Icons.cottage_outlined, 'query': null},
      {'label': 'مسبح', 'icon': Icons.pool_outlined, 'query': 'pool'},
      {'label': 'واي فاي', 'icon': Icons.wifi_rounded, 'query': 'wifi'},
      {'label': 'كل الفلاتر', 'icon': Icons.tune_rounded, 'query': null},
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
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
    // ✅ إصلاح: اختيار مدينة من الهيدر كان لا يغيّر أي محتوى مرئي فعلياً
    // (فقط نص الهيدر) لأن هذا القسم كان يعرض كل الشاليهات المميزة بغض
    // النظر عن المدينة المختارة. الآن يُفلتر محلياً حسب _selectedCity.
    final pool = _selectedCity == AppStrings.allCities
        ? _featured
        : _featured.where((c) => c.city == _selectedCity).toList();
    final items = pool.take(2).toList();

    // ✅ إصلاح: سابقاً عند انتهاء التحميل بدون أي شاليهات مميزة، كان
    // العنصر النائب (skeleton) يبقى ظاهراً للأبد (itemCount:2 دائماً حتى
    // بعد _loading=false) وكأن التحميل مستمر لا نهائياً. الآن القسم
    // يختفي بهدوء بنفس منطق أقسام المدن أدناه بدل تجميد مؤشر تحميل وهمي.
    if (!_loading && items.isEmpty) return const SizedBox.shrink();

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
              itemCount: _loading ? 2 : items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (_loading) {
                  return const SizedBox(
                    width: 220,
                    child: LuxuryShimmerCard(height: 230),
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
  // one horizontal section for a given city, e.g. "شاليهات جنين".
  // Filters _allForGrouping locally (no extra network call). The whole
  // section hides itself if that city has nothing to show once loading
  // is done — no empty section on the home screen.
  // ------------------------------------------------------------
  Widget _buildCitySection(String city) {
    final chalets = _allForGrouping.where((c) => c.city == city).toList();

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
                  return const SizedBox(
                    width: 220,
                    child: LuxuryShimmerCard(height: 230),
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
          color: Theme.of(context).cardColor,
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
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
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
                            const Text(
                              AppStrings.priceFrom,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₪${chalet.pricePerNight.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
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
          color: Theme.of(context).cardColor,
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
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
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
                        'يبدأ من ₪${chalet.pricePerNight.toStringAsFixed(0)}',
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
      onSubmitted: _submitSearch,
      onClear: () => _searchCtrl.clear(),
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
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            'فشل تحميل البيانات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodyLarge?.color,
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
