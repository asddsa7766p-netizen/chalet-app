import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/services.dart' show AuthService;

/// لوحة تحكم الأدمن الشاملة — makan
///
/// كل الإجراءات تمرّ عبر دوال admin_* على السيرفر (تتحقق من
/// is_current_user_admin وتسجّل بـ admin_audit_log)، والإحصائيات تُجمَّع على
/// السيرفر (admin_get_overview_stats). القوائم مرقّمة بصفحات.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _checkingAccess = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final profile = await AuthService.instance.getCurrentProfile();
      final isAdmin = profile?.isAdmin == true;
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checkingAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Text(
                    'لا تملك صلاحية الوصول لهذه الصفحة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('العودة للرئيسية',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'لوحة تحكم الأدمن',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: const Text('خروج',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Tabs ──
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
                tabs: const [
                  Tab(text: 'نظرة عامة'),
                  Tab(text: 'موافقة الشاليهات'),
                  Tab(text: 'المستخدمون'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _OverviewTab(),
                    _ChaletApprovalsTab(),
                    _UsersTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ مكوّنات مشتركة ═══════════════════════════════

void _showSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
    backgroundColor: isError ? AppColors.error : AppColors.primary,
  ));
}

/// رسالة الخطأ للأدمن: رسالة الدالة العربية إن وُجدت، وإلا [fallback].
String _errorText(Object e, String fallback) =>
    e is AdminActionException && e.message.trim().isNotEmpty
        ? e.message
        : fallback;

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.error))),
      ],
    ),
  );
  return ok == true;
}

Widget _errorView(String error, VoidCallback onRetry) {
  return Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(error,
          style: const TextStyle(
              fontFamily: 'Cairo', color: AppColors.textSecondary)),
      TextButton(
          onPressed: onRetry,
          child: const Text('إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary))),
    ]),
  );
}

/// قائمة مرقّمة بالصفحات: الصفحة الأولى عند [reset]، والتالية بـ [loadMore]
/// ما دامت آخر صفحة ممتلئة.
class _Pager {
  _Pager(this._fetch);

  final Future<List<Map<String, dynamic>>> Function(int page) _fetch;

  List<Map<String, dynamic>> items = [];
  bool hasMore = false;
  bool loadingMore = false;
  int _page = 0;
  int _gen = 0;

  /// يرجع false إن سُبق بطلب أحدث (نتيجته تُهمل).
  Future<bool> reset() async {
    final gen = ++_gen;
    final first = await _fetch(0);
    if (gen != _gen) return false;
    _page = 0;
    items = first;
    hasMore = first.length == AdminService.pageSize;
    return true;
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore) return;
    final gen = _gen;
    loadingMore = true;
    try {
      final next = await _fetch(_page + 1);
      if (gen != _gen) return;
      _page++;
      items = [...items, ...next];
      hasMore = next.length == AdminService.pageSize;
    } finally {
      loadingMore = false;
    }
  }
}

Widget _loadMoreFooter(_Pager pager, VoidCallback onLoadMore) {
  if (!pager.hasMore) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: pager.loadingMore
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary))
          : TextButton(
              key: const Key('admin_load_more'),
              onPressed: onLoadMore,
              child: const Text('تحميل المزيد',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.primary))),
    ),
  );
}

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

// ════════════════════ تبويب 2: موافقة الشاليهات ══════════════════════════

class _ChaletApprovalsTab extends StatefulWidget {
  const _ChaletApprovalsTab();
  @override
  State<_ChaletApprovalsTab> createState() => _ChaletApprovalsTabState();
}

class _ChaletApprovalsTabState extends State<_ChaletApprovalsTab> {
  final _pager =
      _Pager((page) => AdminService.instance.getPendingChalets(page: page));
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await _pager.reset() || !mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            _errorText(e, 'تعذر تحميل الشاليهات، يرجى المحاولة مرة أخرى.');
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {});
    try {
      await _pager.loadMore();
    } catch (e) {
      if (mounted) {
        _showSnack(context, _errorText(e, 'تعذر تحميل المزيد'), isError: true);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _approve(Map<String, dynamic> chalet) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await AdminService.instance.approveChalet(chalet['id'] as String);
      if (!mounted) return;
      setState(() => _pager.items =
          _pager.items.where((c) => c['id'] != chalet['id']).toList());
      _showSnack(context, 'تمت الموافقة على الشاليه ✅');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context,
          _errorText(e, 'فشلت الموافقة، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> chalet) async {
    if (_actionLoading) return;
    final confirmed = await _confirm(
      context,
      title: 'رفض الشاليه',
      message: 'هل أنت متأكد من رفض وحذف هذا الشاليه؟ لا يمكن التراجع.',
      action: 'رفض وحذف',
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await AdminService.instance.rejectChalet(chalet['id'] as String);
      if (!mounted) return;
      setState(() => _pager.items =
          _pager.items.where((c) => c['id'] != chalet['id']).toList());
      _showSnack(context, 'تم رفض وحذف الشاليه');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context, _errorText(e, 'فشل الرفض، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) return _errorView(_error!, _load);
    final chalets = _pager.items;
    if (chalets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(children: const [
          SizedBox(height: 120),
          Icon(Icons.check_circle_outline_rounded,
              size: 56, color: AppColors.textMuted),
          SizedBox(height: 14),
          Center(
              child: Text('لا توجد شاليهات بانتظار الموافقة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: chalets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == chalets.length) return _loadMoreFooter(_pager, _loadMore);
          final c = chalets[i];
          final name = (c['name'] as String?)?.trim().isNotEmpty == true
              ? c['name'] as String
              : 'بدون اسم';
          final city = c['city'] as String? ?? '';
          final price = (c['price_per_night'] as num?)?.toDouble() ?? 0;
          // images مخزنة كـ text[] في Supabase
          final images = (c['images'] as List?)?.cast<String>() ?? [];
          final cover = images.isNotEmpty ? images.first : null;

          return Container(
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border)),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الغلاف
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: cover != null
                      ? Image.network(cover,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('$city · يبدأ من ₪${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: ElevatedButton(
                            onPressed:
                                _actionLoading ? null : () => _approve(c),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('موافقة',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton(
                            onPressed: _actionLoading ? null : () => _reject(c),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                  color:
                                      AppColors.error.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('رفض',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 68,
        height: 68,
        color: AppColors.sand,
        child: const Icon(Icons.home_work_rounded, color: AppColors.primary),
      );
}

// ════════════════════════ تبويب 3: المستخدمون ════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late final _Pager _pager = _Pager((page) =>
      AdminService.instance.getUsers(page: page, search: _searchQuery));
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  Timer? _searchDebounce;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await _pager.reset() || !mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            _errorText(e, 'تعذر تحميل المستخدمين، يرجى المحاولة مرة أخرى.');
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {});
    try {
      await _pager.loadMore();
    } catch (e) {
      if (mounted) {
        _showSnack(context, _errorText(e, 'تعذر تحميل المزيد'), isError: true);
      }
    }
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String v) {
    _searchQuery = v;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _load);
  }

  /// يستبدل صف المستخدم بالقائمة بالصف المحدَّث الذي أرجعته الدالة.
  void _replaceUser(Map<String, dynamic> updated) {
    setState(() {
      _pager.items = [
        for (final u in _pager.items)
          u['id'] == updated['id'] ? {...u, ...updated} : u,
      ];
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyActive = (user['is_active'] as bool?) ?? true;
    if (currentlyActive) {
      final confirmed = await _confirm(
        context,
        title: 'حظر المستخدم',
        message:
            'لن يتمكن هذا المستخدم من استخدام حسابه حتى تعيد تفعيله. هل تريد المتابعة؟',
        action: 'حظر',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _actionLoading = true);
    try {
      final updated =
          await AdminService.instance.toggleUserActive(user['id'] as String);
      if (!mounted) return;
      _replaceUser(updated);
      _showSnack(context,
          currentlyActive ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context,
          _errorText(e, 'فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyAdmin = (user['is_admin'] as bool?) ?? false;
    final confirmed = await _confirm(
      context,
      title: currentlyAdmin ? 'إلغاء صلاحية الأدمن' : 'منح صلاحية الأدمن',
      message: currentlyAdmin
          ? 'سيفقد هذا المستخدم الوصول للوحة تحكم الأدمن.'
          : 'سيتمكن هذا المستخدم من الوصول الكامل للوحة تحكم الأدمن.',
      action: currentlyAdmin ? 'إلغاء الصلاحية' : 'منح الصلاحية',
    );
    if (!confirmed || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      final updated =
          await AdminService.instance.toggleUserAdmin(user['id'] as String);
      if (!mounted) return;
      _replaceUser(updated);
      _showSnack(context,
          currentlyAdmin ? 'تم إلغاء صلاحية الأدمن' : 'تم منح صلاحية الأدمن ✅');
    } catch (e) {
      if (!mounted) return;
      _showSnack(context,
          _errorText(e, 'فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _pager.items;
    Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    } else if (_error != null) {
      body = _errorView(_error!, _load);
    } else if (users.isEmpty) {
      body = const Center(
          child: Text('لا يوجد نتائج',
              style: TextStyle(
                  fontFamily: 'Cairo', color: AppColors.textSecondary)));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: users.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => i == users.length
              ? _loadMoreFooter(_pager, _loadMore)
              : _userTile(users[i]),
        ),
      );
    }

    return Column(
      children: [
        // شريط البحث (على السيرفر، يشمل الصفحات غير المحمَّلة)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: _onSearchChanged,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو البريد',
              hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final name = (u['full_name'] as String?)?.trim().isNotEmpty == true
        ? (u['full_name'] as String).trim()
        : 'بدون اسم';
    final email = u['email'] as String? ?? '';
    final isOwner = (u['is_owner'] as bool?) ?? false;
    final isAdmin = (u['is_admin'] as bool?) ?? false;
    final isActive = (u['is_active'] as bool?) ?? true;
    final initial = name.characters.first;

    return Container(
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(initial,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الاسم + الشارات
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    if (isAdmin) _badge('أدمن', AppColors.primary),
                    if (isOwner) _badge('مالك', const Color(0xFF8A6D3B)),
                    if (!isActive) _badge('محظور', AppColors.error),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          // قائمة الإجراءات
          PopupMenuButton<String>(
            enabled: !_actionLoading,
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.textMuted),
            onSelected: (value) {
              if (value == 'toggle_active') _toggleActive(u);
              if (value == 'toggle_admin') _toggleAdmin(u);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'toggle_active',
                  child: Row(children: [
                    Icon(
                        isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: isActive ? AppColors.error : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(isActive ? 'حظر المستخدم' : 'تفعيل المستخدم',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  ])),
              PopupMenuItem(
                  value: 'toggle_admin',
                  child: Row(children: [
                    Icon(
                        isAdmin
                            ? Icons.remove_moderator_rounded
                            : Icons.admin_panel_settings_rounded,
                        size: 18,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(isAdmin ? 'إلغاء صلاحية الأدمن' : 'منح صلاحية الأدمن',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}
