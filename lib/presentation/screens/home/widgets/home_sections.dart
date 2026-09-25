part of '../home_tab.dart';

extension _HomeSections on _HomeTabState {
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
                    child: ShimmerCard(
                        height: 230,
                        borderRadius: BorderRadius.all(Radius.circular(18))),
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
                    child: ShimmerCard(
                        height: 230,
                        borderRadius: BorderRadius.all(Radius.circular(18))),
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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
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
                          color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.95),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'بالقرب منك',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              Text(
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
          border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                        color: AppColors.primary.withValues(alpha: 0.08),
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
                  color: AppColors.accent.withValues(alpha: 0.2), width: 2),
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
