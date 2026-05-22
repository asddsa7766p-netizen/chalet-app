import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/chalet_model.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();

  String _city = 'الكل';
  double? _minPrice;
  double? _maxPrice;
  int _guests = 2;

  bool _hasPool = false;
  bool _hasWifi = false;

  bool _loading = false;
  String? _error;
  List<ChaletModel> _results = [];

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
      _error = null;
    });

    try {
      final results = await ChaletService.instance.getChalets(
        city: _city,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        hasPool: _hasPool,
        hasWifi: _hasWifi,
        minGuests: _guests,
        searchQuery: _searchCtrl.text,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _results = results;
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

  void _applyFilters() {
    // Keep behavior consistent with the rest of the app (explicit apply)
    _load();
  }

  void _resetFilters() {
    setState(() {
      _city = 'الكل';
      _minPrice = null;
      _maxPrice = null;
      _guests = 2;
      _hasPool = false;
      _hasWifi = false;
      _searchCtrl.clear();
      _results = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.explore),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: AppStrings.filters,
                      action: 'إعادة ضبط',
                      onAction: _resetFilters,
                    ),
                    const SizedBox(height: 12),
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildCityDropdown(),
                    const SizedBox(height: 12),
                    _buildPriceRange(),
                    const SizedBox(height: 12),
                    _buildGuests(),
                    const SizedBox(height: 12),
                    _buildAmenities(),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'تطبيق الفلاتر',
                      onPressed: _applyFilters,
                      loading: _loading,
                      icon: Icons.filter_list_rounded,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeader(
                  title: AppStrings.explore,
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              )
            else if (_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    children: List.generate(
                      4,
                      (index) => const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: ShimmerCard(height: 110),
                      ),
                    ),
                  ),
                ),
              )
            else if (_results.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'لا توجد نتائج مطابقة للبحث',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
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

  Widget _buildSearchField() {
    return CustomTextField(
      controller: _searchCtrl,
      label: '',
      hint: 'اسم الشاليه أو موقعه... ',
      prefixIcon: Icons.search_rounded,
      onChanged: (_) {},
    );
  }

  Widget _buildCityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _city,
          items: {
            'الكل',
            ...AppStrings.cities,
          }
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _city = v);
          },
        ),
      ),
    );
  }

  Widget _buildPriceRange() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الميزانية',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: TextEditingController(
                    text: _minPrice == null ? '' : _minPrice.toString(),
                  ),
                  label: '',
                  hint: 'سعر أدنى',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    setState(() => _minPrice = parsed);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  controller: TextEditingController(
                    text: _maxPrice == null ? '' : _maxPrice.toString(),
                  ),
                  label: '',
                  hint: 'سعر أعلى',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    setState(() => _maxPrice = parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildGuests() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عدد الضيوف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'الحد الأدنى للضيوف',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _circleBtn(
                Icons.remove_rounded,
                () => setState(() => _guests = (_guests > 1) ? _guests - 1 : 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '$_guests',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              _circleBtn(
                Icons.add_rounded,
                () => setState(() => _guests = _guests + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }

  Widget _buildAmenities() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المميزات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _amenityChip(
                AppStrings.pool,
                Icons.pool_rounded,
                _hasPool,
                (v) => setState(() => _hasPool = v),
              ),
              _amenityChip(
                AppStrings.wifi,
                Icons.wifi_rounded,
                _hasWifi,
                (v) => setState(() => _hasWifi = v),
              ),
            ],
          ),
        ],
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
