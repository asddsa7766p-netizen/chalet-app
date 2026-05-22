import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import 'dart:async' if (dart.library.html) 'dart:async';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchCtrl = TextEditingController();
  String _selectedCity = 'الكل';
  List<ChaletModel> _featured = [];
  List<ChaletModel> _all = [];
  Set<String> _favoriteIds = {};
  bool _loading = true;
  String? _error;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      Timer? debounce;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ChaletService.instance.getFeaturedChalets(),
        ChaletService.instance.getChalets(city: _selectedCity),
        FavoritesService.instance.getFavoriteIds(),
        AuthService.instance.getCurrentProfile(),
      ]);
      if (mounted) {
        setState(() {
          _featured = results[0] as List<ChaletModel>;
          _all = results[1] as List<ChaletModel>;
          _favoriteIds = results[2] as Set<String>;
          _userName = (results[3] as dynamic)?.fullName;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(String chaletId) async {
    await FavoritesService.instance.toggleFavorite(chaletId);
    final ids = await FavoritesService.instance.getFavoriteIds();
    if (mounted) setState(() => _favoriteIds = ids);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildCityFilter()),
            if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              SliverToBoxAdapter(child: _buildFeatured()),
              SliverToBoxAdapter(child: _buildAllChalets()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppStrings.welcomeBack}${_userName != null ? '، ${_userName!.split(' ').first} 👋' : ''}',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      const Text(AppStrings.whereToGo,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                  Row(
                    children: [
                      _iconBtn(Icons.notifications_outlined, () {
                        // TODO: Navigate to notifications
                      }),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _search,
        decoration: InputDecoration(
          hintText: AppStrings.search,
          hintStyle: const TextStyle(
              fontFamily: 'Cairo', color: AppColors.textHint, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textHint),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textHint, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _search('');
                  })
              : null,
        ),
      ),
    );
  }

  Widget _buildCityFilter() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppStrings.cities.length,
        itemBuilder: (_, i) {
          final city = AppStrings.cities[i];
          final selected = city == _selectedCity;
          return GestureDetector(
            onTap: () => _filterByCity(city),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.sand,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(city,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : AppColors.charcoal,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatured() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: AppStrings.featuredChalets,
            action: AppStrings.seeAll,
          ),
          const SizedBox(height: 14),
          if (_loading)
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (_, i) => Container(
                    width: 220,
                    margin: const EdgeInsets.only(left: 14),
                    child: const ShimmerCard()),
              ),
            )
          else if (_featured.isEmpty)
            const _EmptyState(message: 'لا توجد شاليهات مميزة حالياً')
          else
            SizedBox(
              height: 330,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                itemBuilder: (_, i) => Container(
                  width: 230,
                  margin: const EdgeInsets.only(left: 14),
                  child: ChaletCard(
                    chalet: _featured[i],
                    isFavorite: _favoriteIds.contains(_featured[i].id),
                    onFavoriteTap: () => _toggleFavorite(_featured[i].id),
                    onTap: () => context.push('/home/chalet/${_featured[i].id}',
                        extra: _featured[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllChalets() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: _selectedCity == 'الكل'
                ? 'جميع الشاليهات'
                : 'شاليهات $_selectedCity',
          ),
          const SizedBox(height: 14),
          if (_loading)
            Column(
                children: List.generate(
                    3,
                    (_) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: const ShimmerCard(height: 110))))
          else if (_all.isEmpty)
            const _EmptyState(message: 'لا توجد شاليهات متاحة')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _all.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ChaletCard(
                  chalet: _all[i],
                  horizontal: true,
                  isFavorite: _favoriteIds.contains(_all[i].id),
                  onFavoriteTap: () => _toggleFavorite(_all[i].id),
                  onTap: () => context.push('/home/chalet/${_all[i].id}',
                      extra: _all[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('فشل تحميل البيانات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.home_work_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
