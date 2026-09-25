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
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/luxury_widgets.dart';
import '../profile/profile_provider.dart';
import '../../widgets/common/login_prompt.dart';
import 'dart:async';

part 'widgets/city_picker_sheet.dart';
part 'widgets/home_header.dart';
part 'widgets/home_sections.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  // لأجزاء الشاشة (extensions بملفات part) التي لا تستطيع استدعاء
  // setState المحمي مباشرة.
  void _setState(VoidCallback fn) => setState(fn);

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
    } catch (e, st) {
      // فشل صامت (مثلاً أول تشغيل بدون توفر التخزين بعد) — يتصرف كأنه
      // ما في اختيار محفوظ، فتظهر شاشة الاختيار الإجبارية كالمعتاد.
      reportError(e, st, context: 'home.read_city_pref');
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
    } catch (e, st) {
      // فشل صامت — لا داعي لإظهار خطأ عام بسبب عداد ثانوي بالهيدر.
      reportError(e, st, context: 'home.unread_count');
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
    } catch (e, st) {
      // فشل صامت — أسوأ حالة إنه يرجع يسأل المرة الجاية، مش أهم من تعطيل
      // باقي الشاشة.
      reportError(e, st, context: 'home.save_city_pref');
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

}
