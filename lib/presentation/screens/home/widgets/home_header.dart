part of '../home_tab.dart';

extension _HomeHeader on _HomeTabState {
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
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
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
                    color: AppColors.accentLight.withValues(alpha: 0.35),
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
}
