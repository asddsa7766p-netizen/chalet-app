part of 'admin_dashboard_screen.dart';

// ═══════════════════════════ تبويب 1: نظرة عامة ═══════════════════════════

enum _StatsRange { all, thisMonth, last30Days }

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _loading = true;
  String? _error;
  AdminOverviewStats? _stats;
  _StatsRange _range = _StatsRange.all;
  int _gen = 0;

  static const _statusLabels = {
    'pending': 'قيد الانتظار',
    'confirmed': 'مؤكد',
    'completed': 'مكتمل',
    'cancelled': 'ملغى',
    'rejected': 'مرفوض',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime?, DateTime?) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _StatsRange.all:
        return (null, null);
      case _StatsRange.thisMonth:
        return (
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 1),
        );
      case _StatsRange.last30Days:
        return (
          DateTime(today.year, today.month, today.day - 29),
          DateTime(today.year, today.month, today.day + 1),
        );
    }
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _bounds();
      final stats =
          await AdminService.instance.getOverviewStats(from: from, to: to);
      if (!mounted || gen != _gen) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = _errorText(e, 'تعذر تحميل الإحصائيات، يرجى المحاولة مرة أخرى.');
      });
    }
  }

  void _setRange(_StatsRange r) {
    if (r == _range) return;
    setState(() => _range = r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) return _errorView(_error!, _load);

    final s = _stats!;
    final cards = [
      (Icons.people_alt_rounded, 'إجمالي المستخدمين', '${s.totalUsers}',
          AppColors.primary),
      (Icons.verified_user_rounded, 'المستخدمون النشطون', '${s.activeUsers}',
          AppColors.primary.withValues(alpha: 0.85)),
      (Icons.home_work_rounded, 'المالكون', '${s.totalOwners}',
          AppColors.primary.withValues(alpha: 0.75)),
      (Icons.villa_rounded, 'الشاليهات المعتمدة',
          '${s.approvedChalets} / ${s.totalChalets}', const Color(0xFF8A6D3B)),
      (Icons.pending_actions_rounded, 'بانتظار الموافقة', '${s.pendingChalets}',
          AdminColors.gold),
      // مرفوضة بانتظار تعديل المالك وإعادة إرسالها (خارج "بانتظار الموافقة").
      (Icons.block_rounded, 'الشاليهات المرفوضة', '${s.rejectedChalets}',
          AppColors.error),
      (Icons.calendar_month_rounded, 'حجوزات التطبيق', '${s.totalBookings}',
          AppColors.primary),
      (Icons.edit_calendar_rounded, 'حجوزات يدوية', '${s.externalBookings}',
          AppColors.primary.withValues(alpha: 0.75)),
      (Icons.attach_money_rounded, 'إجمالي الإيرادات',
          '₪${s.totalRevenue.toStringAsFixed(0)}', const Color(0xFF8A6D3B)),
      (Icons.account_balance_rounded, 'إيرادات المنصة',
          '₪${s.platformRevenue.toStringAsFixed(0)}', const Color(0xFF6B5530)),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final r in _StatsRange.values)
                ChoiceChip(
                  label: Text(
                    switch (r) {
                      _StatsRange.all => 'كل الوقت',
                      _StatsRange.thisMonth => 'هذا الشهر',
                      _StatsRange.last30Days => 'آخر 30 يوماً',
                    },
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  selected: _range == r,
                  onSelected: (_) => _setRange(r),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'المدى يطبَّق على الحجوزات والإيرادات حسب تاريخ الحجز.',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(color: AppColors.primary),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4),
            itemBuilder: (context, i) {
              final c = cards[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: c.$4, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(c.$1, color: Colors.white, size: 22),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(c.$3,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ),
                    Text(c.$2,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 11)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('حجوزات التطبيق حسب الحالة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (s.bookingsByStatus.isEmpty)
            const Text('لا توجد حجوزات بهذا المدى',
                style: TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary))
          else
            for (final e in s.bookingsByStatus.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_statusLabels[e.key] ?? e.key,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary)),
                    ),
                    Text('${e.value}',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
