part of '../owner_dashboard_screen.dart';

extension _DashboardActionsSection on _OwnerDashboardScreenState {
  Future<void> _addManualBooking() async {
    final saved = await openManualBookingSheet(context);
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حجز الفترة', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
      ),
    );
    _load();
  }

  // ─── إجراءات سريعة ───────────────────────────────────────
  Widget _buildQuickActions() {
    // ⚠️ TODO: راوتات "إدارة الأسعار" و"إدارة الصور" غير موجودة صراحةً
    // بـ app_router.dart الحالي عندك (فيه chalet_pricing_screen.dart
    // كملف لكن بلا route مسجّل بالراوتر يلي شفناه). اربطهم بالراوت
    // الصحيح إذا كان مختلف عن يلي حطيته هون.
    final items = <(IconData, String, VoidCallback)>[
      // "حجز يدوي" أولاً لأنه الأكثر استخداماً: يفتح ورقة الإدخال مباشرة
      // (قائمة الحجوزات اليدوية متاحة من شاشة الحجوزات).
      (Icons.edit_calendar_rounded, 'حجز يدوي', _addManualBooking),
      (
        Icons.add_rounded,
        'إضافة شاليه جديد',
        () => context.go('/owner-add-chalet')
      ),
      (
        Icons.calendar_month_rounded,
        'التقويم',
        () => context.go('/owner-calendar')
      ),
      (Icons.home_work_outlined, 'شاليهاتي', () => context.go('/owner-chalets')),
      (
        Icons.person_outline_rounded,
        'حسابي',
        () => context.go('/owner-profile')
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إجراءات سريعة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: items
              .map((item) => GestureDetector(
                    onTap: item.$3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.$1, color: AppColors.primary, size: 24),
                          const SizedBox(height: 8),
                          Text(item.$2,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ─── أداء الشاليهات ──────────────────────────────────────
  Widget _buildPerformanceSection() {
    final s = _stats;

    // متوسط قيمة الحجز = الإيرادات ÷ عدد الحجوزات (تقدير من البيانات
    // المتاحة فعليًا).
    final totalBookingsCount =
        (s?.totalBookingsSpot ?? 0) + (s?.totalBookingsExternal ?? 0);
    final avgBookingValue =
        totalBookingsCount > 0 ? (s!.totalRevenue / totalBookingsCount) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/owner-reports'),
                child: const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 15, color: AppColors.textHint),
                    SizedBox(width: 4),
                    Text('عرض التقارير',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textHint)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('أداء شاليهك',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal)),
            ],
          ),
          const SizedBox(height: 4),
          // _stats بنطاق اليوم (_range)، مثل "أرباح اليوم" (كان "هذا الشهر").
          const Align(
            alignment: Alignment.centerRight,
            child: Text('اليوم',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 16),
          // "معدل الإشغال" و"التقييمات" حُذفا: لا حساب لهما بالخادم فكانا
          // "—" دائماً.
          Row(
            children: [
              Expanded(
                child: _performanceMetric(
                  label: 'متوسط قيمة الحجز',
                  value: totalBookingsCount > 0
                      ? '₪${avgBookingValue.toStringAsFixed(0)}'
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _performanceMetric({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: AppColors.textSecondary)),
      ],
    );
  }
}
