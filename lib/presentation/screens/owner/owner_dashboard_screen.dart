import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/services/dashboard_service.dart';
import '../../../data/services/services.dart' show AuthService;

/// لوحة تحكم المالك (الإحصائيات).
///
/// ⚠️ إعادة تصميم كاملة عن النسخة السابقة:
/// - الهوية اللونية تحولت من نمط كحلي/ذهبي منفصل عن باقي التطبيق، إلى
///   هوية فلسطينية متّسقة مع AppColors المستخدمة في بقية الشاشات (أخضر
///   AppColors.primary، رملي/كريمي AppColors.sand/cream).
/// - تمت إزالة 8 متغيرات ألوان كانت معرّفة وغير مستخدمة إطلاقًا في الكود
///   القديم (بقايا تصميم لم يكتمل).
/// - زر "العودة كمستخدم" أصبح يطلب تأكيدًا قبل تنفيذه (سابقًا كان ينفذ
///   فورًا بضغطة واحدة، وكان بإمكانه إلغاء صفة "مالك" عن المستخدم بالخطأ
///   حتى لو كان لديه شاليهات فعلية).
/// - البطاقات نفسها (الحجوزات، المتوسط اليومي، الملغاة، الإيرادات، الرسم
///   البياني، تفصيل الشاليهات، الوصول السريع) محفوظة بنفس البنية كما طُلب،
///   فقط بألوان وهوية جديدة.
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  OwnerDashboardRange _range = OwnerDashboardRange.today;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  OwnerDashboardStats? _stats;

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
      final profile = await AuthService.instance.getCurrentProfile();
      final stats =
          await DashboardService.instance.getOwnerDashboardStats(range: _range);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات لوحة التحكم';
      });
    }
  }

  Future<void> _confirmBackToCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('العودة كمستخدم؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text(
          'ستفقد صفة "مالك شاليه" ولن تتمكن من الوصول للوحة التحكم إلا بعد '
          'إضافة شاليه جديد. هل تريد المتابعة؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('العودة كمستخدم',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthService.instance.becomeCustomer();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنفيذ العملية: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _buildAppBar(),
              _buildTitle(),
              _buildFilters(),
              Expanded(
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: _buildBody(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────
  Widget _buildAppBar() {
    final name = _profile?.fullName ?? 'مالك شاليه';
    final initial = name.isNotEmpty ? name.characters.first : 'م';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Text('لوحة المالك',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                        fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _confirmBackToCustomer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: const Text(
                'العودة كمستخدم',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Title ────────────────────────────────────────────────
  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'لوحة التحكم',
          style: TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // ─── Filters ──────────────────────────────────────────────
  Widget _buildFilters() {
    final ranges = [
      (OwnerDashboardRange.today, 'اليوم'),
      (OwnerDashboardRange.yesterday, 'أمس'),
      (OwnerDashboardRange.last7Days, 'آخر 7 أيام'),
      (OwnerDashboardRange.lastMonth, 'الشهر الماضي'),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = _range == ranges[i].$1;
          return GestureDetector(
            onTap: () async {
              if (_range == ranges[i].$1) return;
              setState(() => _range = ranges[i].$1);
              await _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                ranges[i].$2,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────
  Widget _buildBody() {
    if (_error != null) return _buildErrorState();

    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    if (s.totalBookings == 0 && s.byChaletRevenue.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _bookingsCard(s)),
            const SizedBox(width: 10),
            Expanded(child: _avgDailyCard(s)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _cancelledCard(s)),
            const SizedBox(width: 10),
            Expanded(child: _revenueCard(s)),
          ],
        ),
        const SizedBox(height: 10),
        _chartCard(s),
        if (s.byChaletRevenue.isNotEmpty) ...[
          const SizedBox(height: 10),
          _chaletBreakdown(s),
        ],
        const SizedBox(height: 10),
        _quickAccess(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            _error ?? 'حدث خطأ',
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _load,
            child: const Text('إعادة المحاولة',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
          const SizedBox(height: 16),
          _quickAccess(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Icon(Icons.bar_chart_rounded, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 14),
        Text(
          'لا توجد بيانات حجوزات خلال ${_range.arLabel}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _quickAccess(),
      ],
    );
  }

  // ─── بطاقة إجمالي الحجوزات ───────────────────────────────
  Widget _bookingsCard(OwnerDashboardStats s) {
    final total = s.totalBookingsSpot + s.totalBookingsExternal;
    final spotPct = total > 0 ? (s.totalBookingsSpot / total * 100).round() : 0;
    final extPct =
        total > 0 ? (s.totalBookingsExternal / total * 100).round() : 0;

    return _statCard(
      color: AppColors.primary,
      title: 'إجمالي الحجوزات',
      value: '$total',
      subtitle: 'تفصيل حسب المصدر',
      bottom: Row(
        children: [
          Expanded(
              child: _miniBox(
                  'شاليه سبوت', '${s.totalBookingsSpot}', '$spotPct%')),
          const SizedBox(width: 6),
          Expanded(
              child:
                  _miniBox('خارجي', '${s.totalBookingsExternal}', '$extPct%')),
        ],
      ),
    );
  }

  // ─── بطاقة متوسط يومي ────────────────────────────────────
  Widget _avgDailyCard(OwnerDashboardStats s) {
    return _statCard(
      color: AppColors.primary.withOpacity(0.75),
      title: 'متوسط الحجوزات اليومية',
      value: s.avgDailyBookings.toStringAsFixed(1),
      subtitle: 'حجوزات في اليوم',
      bottom: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            s.avgDailyBookings == 0
                ? 'لا توجد بيانات'
                : 'أداء ${_range.arLabel}',
            style: const TextStyle(
                fontFamily: 'Cairo', color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }

  // ─── بطاقة ملغاة ومرفوضة ─────────────────────────────────
  Widget _cancelledCard(OwnerDashboardStats s) {
    final total = s.cancelledByUser + s.cancelledOrRejectedByOwner;
    final userPct = total > 0 ? (s.cancelledByUser / total * 100).round() : 0;
    final ownerPct =
        total > 0 ? (s.cancelledOrRejectedByOwner / total * 100).round() : 0;

    return _statCard(
      color: AppColors.error,
      title: 'ملغاة ومرفوضة',
      value: '$total',
      subtitle: 'تفصيل إلغاء الحجوزات',
      bottom: Row(
        children: [
          Expanded(
              child: _miniBox(
                  'ألغاه المستأجر', '${s.cancelledByUser}', '$userPct%')),
          const SizedBox(width: 6),
          Expanded(
              child: _miniBox('رفضها المسؤول',
                  '${s.cancelledOrRejectedByOwner}', '$ownerPct%')),
        ],
      ),
    );
  }

  // ─── بطاقة الإيرادات ──────────────────────────────────────
  Widget _revenueCard(OwnerDashboardStats s) {
    final total = s.totalRevenue;
    final spotPct = total > 0 ? (s.totalRevenueSpot / total * 100).round() : 0;
    final extPct =
        total > 0 ? (s.totalRevenueExternal / total * 100).round() : 0;

    return _statCard(
      color: const Color(
          0xFF8A6D3B), // ذهبي ترابي، متوافق مع الهوية الفلسطينية دون افتراض وجود لون غير مؤكد بـ AppColors
      title: 'إجمالي الإيرادات',
      value: '₪${total.toStringAsFixed(0)}',
      subtitle: 'إجمالي الإيرادات حسب المصدر',
      bottom: Row(
        children: [
          Expanded(
              child: _miniBox('شاليه سبوت',
                  '₪${s.totalRevenueSpot.toStringAsFixed(0)}', '$spotPct%')),
          const SizedBox(width: 6),
          Expanded(
              child: _miniBox('خارجي',
                  '₪${s.totalRevenueExternal.toStringAsFixed(0)}', '$extPct%')),
        ],
      ),
    );
  }

  // ─── Widget مساعد للبطاقات الملونة ───────────────────────
  Widget _statCard({
    required Color color,
    required String title,
    required String value,
    required String subtitle,
    required Widget bottom,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.1)),
          Text(subtitle,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white60, fontSize: 9)),
          const SizedBox(height: 10),
          bottom,
        ],
      ),
    );
  }

  // ─── Mini box داخل البطاقات ───────────────────────────────
  Widget _miniBox(String label, String val, String pct) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white70, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(val,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          Text(pct,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white60, fontSize: 9)),
        ],
      ),
    );
  }

  // ─── رسم بياني ────────────────────────────────────────────
  Widget _chartCard(OwnerDashboardStats s) {
    final hasData = s.byChaletRevenue.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('توزيع الإيرادات حسب الشاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: hasData
                ? CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _ChartPainter(
                      points: () {
                        final max = s.byChaletRevenue
                            .map((e) => e.revenue)
                            .reduce((a, b) => a > b ? a : b);
                        return s.byChaletRevenue
                            .map((e) => max > 0 ? e.revenue / max : 0.0)
                            .toList();
                      }(),
                    ),
                  )
                : Center(
                    child: Text(
                      'لا توجد بيانات كافية للعرض',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textMuted,
                          fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── تفصيل الشاليهات ──────────────────────────────────────
  Widget _chaletBreakdown(OwnerDashboardStats s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تفصيل الإيرادات لكل شاليه',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...s.byChaletRevenue.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.chaletName.isNotEmpty
                                ? row.chaletName
                                : 'شاليه',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'حجوزات: ${row.bookingsCount}',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textSecondary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₪${row.revenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── وصول سريع ───────────────────────────────────────────
  Widget _quickAccess() {
    final items = [
      (Icons.home_work_rounded, 'شاليهاتي', '/owner-chalets'),
      (Icons.add_rounded, 'إضافة شاليه', '/owner-add-chalet'),
      (Icons.calendar_month_rounded, 'الحجوزات', '/owner-bookings'),
      (Icons.public_rounded, 'خارجي', '/owner-external'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('وصول سريع',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 3,
          children: items
              .map((item) => GestureDetector(
                    onTap: () => context.go(item.$3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(item.$1, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(item.$2,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'الرئيسية', '/owner-dashboard'),
      (
        Icons.home_work_rounded,
        Icons.home_work_outlined,
        'الشاليهات',
        '/owner-chalets'
      ),
      (
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
        'الحجوزات',
        '/owner-bookings'
      ),
      (Icons.public_rounded, Icons.public_outlined, 'خارجي', '/owner-external'),
      (
        Icons.person_rounded,
        Icons.person_outline_rounded,
        'حسابي',
        '/owner-profile'
      ),
    ];

    final location = GoRouterState.of(context).uri.toString();
    int currentIndex = items.indexWhere((i) => location.startsWith(i.$4));
    if (currentIndex < 0) currentIndex = 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final active = i == currentIndex;
            return GestureDetector(
              onTap: () => context.go(items[i].$4),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(
                    horizontal: active ? 12 : 8, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? items[i].$1 : items[i].$2,
                      color: Colors.white.withOpacity(active ? 1.0 : 0.65),
                      size: 22,
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Text(items[i].$3,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Chart Painter ────────────────────────────────────────────
class _ChartPainter extends CustomPainter {
  final List<double> points;
  _ChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // نسخة دفاعية بسيطة: لو نقطة واحدة فقط، لا يمكن رسم خط (يحتاج نقطتين
    // على الأقل)، فنرسم خطًا أفقيًا بسيطًا بدل رمي خطأ قسمة على صفر
    // (points.length - 1 = 0).
    if (points.length == 1) {
      final paint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5;
      final y = size.height - (points.first.clamp(0.0, 1.0) * size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final pts = List.generate(points.length, (i) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height - (points[i].clamp(0.0, 1.0) * size.height);
      return Offset(x, y);
    });

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final cp1 = Offset((prev.dx + curr.dx) / 2, prev.dy);
      final cp2 = Offset((prev.dx + curr.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    final fillPath = Path.from(linePath)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
