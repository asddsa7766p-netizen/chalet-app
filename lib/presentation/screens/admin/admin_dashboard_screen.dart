import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/admin_service.dart';

import '../../../core/constants/app_colors.dart';

/// لوحة تحكم الأدمن الشاملة — makan
///
/// مبنية على البنية الفعلية لقاعدة البيانات (jugnkxeqqgtoerlknadm):
///
/// جدول profiles:
///   full_name | email | is_owner (bool) | is_admin (bool) | is_active (bool)
///
/// جدول chalets:
///   is_approved (bool) | is_available (bool) | images (text[]) | ...
///
/// الحماية:
///   - دالة is_current_user_admin() موجودة بقاعدة البيانات
///   - سياسات RLS محمية بالفعل على جدولَي profiles و chalets
///   - هذه الشاشة تتحقق من is_admin قبل عرض أي بيانات

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
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
      final isAdmin = await AdminService.instance.isCurrentUserAdmin();
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
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.25)),
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

// ═══════════════════════════ تبويب 1: نظرة عامة ═══════════════════════════

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;

  int _totalUsers = 0;
  int _totalOwners = 0;
  int _totalChalets = 0;
  int _pendingChalets = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0;

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
      final stats = await AdminService.instance.getOverviewStats();
      if (!mounted) return;
      setState(() {
        _totalUsers = stats['totalUsers'] as int? ?? 0;
        _totalOwners = stats['totalOwners'] as int? ?? 0;
        _totalChalets = stats['totalChalets'] as int? ?? 0;
        _pendingChalets = stats['pendingChalets'] as int? ?? 0;
        _totalBookings = stats['totalBookings'] as int? ?? 0;
        _totalRevenue = (stats['totalRevenue'] as double?) ??
            (stats['totalRevenue'] is num
                ? (stats['totalRevenue'] as num).toDouble()
                : 0);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        debugPrint('ADMIN OVERVIEW ERROR: $e');
        _error = 'تعذر تحميل الإحصائيات، يرجى المحاولة مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!,
            style: const TextStyle(
                fontFamily: 'Cairo', color: AppColors.textSecondary)),
        TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary))),
      ]));
    }

    final cards = [
      (
        Icons.people_alt_rounded,
        'إجمالي المستخدمين',
        '$_totalUsers',
        AppColors.primary
      ),
      (
        Icons.home_work_rounded,
        'المالكون',
        '$_totalOwners',
        AppColors.primary.withOpacity(0.75)
      ),
      (
        Icons.villa_rounded,
        'إجمالي الشاليهات',
        '$_totalChalets',
        const Color(0xFF8A6D3B)
      ),
      (
        Icons.pending_actions_rounded,
        'بانتظار الموافقة',
        '$_pendingChalets',
        AppColors.error
      ),
      (
        Icons.calendar_month_rounded,
        'إجمالي الحجوزات',
        '$_totalBookings',
        AppColors.primary
      ),
      (
        Icons.attach_money_rounded,
        'إجمالي الإيرادات',
        '₪${_totalRevenue.toStringAsFixed(0)}',
        const Color(0xFF8A6D3B)
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
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
                Text(c.$3,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
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
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _chalets = [];
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
      final data = await AdminService.instance.getPendingChalets();
      if (!mounted) return;
      setState(() {
        _chalets = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ADMIN CHALET LOAD ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الشاليهات، يرجى المحاولة مرة أخرى.';
      });
    }
  }

  Future<void> _approve(String chaletId) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await _supabase.from('chalets').update(
          {'is_approved': true, 'is_available': true}).eq('id', chaletId);
      await _load();
      if (!mounted) return;
      _showSnack('تمت الموافقة على الشاليه ✅');
    } catch (e) {
      debugPrint('ADMIN APPROVE ERROR: $e');
      if (!mounted) return;
      _showSnack('فشلت الموافقة، يرجى المحاولة مرة أخرى.', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _reject(String chaletId) async {
    if (_actionLoading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض الشاليه',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text(
            'هل أنت متأكد من رفض وحذف هذا الشاليه؟ لا يمكن التراجع.',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رفض وحذف',
                  style:
                      TextStyle(fontFamily: 'Cairo', color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await _supabase.from('chalets').delete().eq('id', chaletId);
      await _load();
      if (!mounted) return;
      _showSnack('تم رفض وحذف الشاليه');
    } catch (e) {
      debugPrint('ADMIN REJECT ERROR: $e');
      if (!mounted) return;
      _showSnack('فشل الرفض، يرجى المحاولة مرة أخرى.', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!,
            style: const TextStyle(
                fontFamily: 'Cairo', color: AppColors.textSecondary)),
        TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary))),
      ]));
    }
    if (_chalets.isEmpty) {
      return ListView(children: const [
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
      ]);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _chalets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = _chalets[i];
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
                      Text('$city · ₪${price.toStringAsFixed(0)}/ليلة',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: ElevatedButton(
                            onPressed: _actionLoading
                                ? null
                                : () => _approve(c['id'] as String),
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
                            onPressed: _actionLoading
                                ? null
                                : () => _reject(c['id'] as String),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                  color: AppColors.error.withOpacity(0.6)),
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
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
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
      final data = await AdminService.instance.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ADMIN USERS LOAD ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المستخدمين، يرجى المحاولة مرة أخرى.';
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyActive = (user['is_active'] as bool?) ?? true;
    setState(() => _actionLoading = true);
    try {
      await _supabase
          .from('profiles')
          .update({'is_active': !currentlyActive}).eq('id', user['id']);
      await _load();
      if (!mounted) return;
      _showSnack(currentlyActive ? 'تم حظر المستخدم' : 'تم تفعيل المستخدم');
    } catch (e) {
      debugPrint('ADMIN TOGGLE ACTIVE ERROR: $e');
      if (!mounted) return;
      _showSnack('فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user) async {
    if (_actionLoading) return;
    final currentlyAdmin = (user['is_admin'] as bool?) ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            currentlyAdmin ? 'إلغاء صلاحية الأدمن' : 'منح صلاحية الأدمن',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: Text(
            currentlyAdmin
                ? 'سيفقد هذا المستخدم الوصول للوحة تحكم الأدمن.'
                : 'سيتمكن هذا المستخدم من الوصول الكامل للوحة تحكم الأدمن.',
            style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(currentlyAdmin ? 'إلغاء الصلاحية' : 'منح الصلاحية',
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _actionLoading = true);
    try {
      await _supabase
          .from('profiles')
          .update({'is_admin': !currentlyAdmin}).eq('id', user['id']);
      await _load();
      if (!mounted) return;
      _showSnack(
          currentlyAdmin ? 'تم إلغاء صلاحية الأدمن' : 'تم منح صلاحية الأدمن ✅');
    } catch (e) {
      debugPrint('ADMIN TOGGLE ADMIN ERROR: $e');
      if (!mounted) return;
      _showSnack('فشل تنفيذ العملية، يرجى المحاولة مرة أخرى.', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!,
            style: const TextStyle(
                fontFamily: 'Cairo', color: AppColors.textSecondary)),
        TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary))),
      ]));
    }

    final filtered = _searchQuery.trim().isEmpty
        ? _users
        : _users.where((u) {
            final name = (u['full_name'] as String? ?? '').toLowerCase();
            final email = (u['email'] as String? ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();

    return Column(
      children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
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
                  borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('لا يوجد نتائج',
                      style: TextStyle(
                          fontFamily: 'Cairo', color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      final name =
                          (u['full_name'] as String?)?.trim().isNotEmpty == true
                              ? u['full_name'] as String
                              : 'بدون اسم';
                      final email = u['email'] as String? ?? '';
                      final isOwner = (u['is_owner'] as bool?) ?? false;
                      final isAdmin = (u['is_admin'] as bool?) ?? false;
                      final isActive = (u['is_active'] as bool?) ?? true;
                      final initial =
                          name.isNotEmpty ? name.characters.first : '؟';

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
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.1),
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
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary)),
                                      if (isAdmin)
                                        _badge('أدمن', AppColors.primary),
                                      if (isOwner)
                                        _badge('مالك', const Color(0xFF8A6D3B)),
                                      if (!isActive)
                                        _badge('محظور', AppColors.error),
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
                                              : Icons
                                                  .check_circle_outline_rounded,
                                          size: 18,
                                          color: isActive
                                              ? AppColors.error
                                              : AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                          isActive
                                              ? 'حظر المستخدم'
                                              : 'تفعيل المستخدم',
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 13)),
                                    ])),
                                PopupMenuItem(
                                    value: 'toggle_admin',
                                    child: Row(children: [
                                      Icon(
                                          isAdmin
                                              ? Icons.remove_moderator_rounded
                                              : Icons
                                                  .admin_panel_settings_rounded,
                                          size: 18,
                                          color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                          isAdmin
                                              ? 'إلغاء صلاحية الأدمن'
                                              : 'منح صلاحية الأدمن',
                                          style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 13)),
                                    ])),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
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
