import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/services/dashboard_service.dart';
import '../../../data/services/services.dart' show AuthService;
import '../../../data/services/notification_service.dart';

/// لوحة تحكم المالك — تصميم جديد بالكامل (كروت خضراء/كريمية، ترحيب مع
/// أفاتار، بانر إكمال الإعداد، حجوزات قادمة، إجراءات سريعة، أداء
/// الشاليهات).
///
/// ⚠️ ملاحظة مهمة: بعض عناصر التصميم المطلوب تحتاج بيانات غير متوفرة
/// حاليًا في [OwnerDashboardStats] أو [DashboardService] (مثل: عدد
/// مشاهدات الشاليه، التقييمات، معدل الإشغال، قائمة تفصيلية بالحجوزات
/// القادمة). تم الإبقاء على هذه العناصر بصريًا بالتصميم لكن بقيم "—"
/// أو حالة فارغة بدل اختلاق أرقام، مع تعليق ⚠️ TODO في كل موضع. لتفعيلها
/// فعليًا، يلزم توسيع DashboardService لإرجاع هذه البيانات.
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  static const Color _darkGreen = Color(0xFF3D5228);
  static const Color _cream = Color(0xFFF6F2E7);
  int _unreadCount = 0;

  OwnerDashboardRange _range = OwnerDashboardRange.today;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  OwnerDashboardStats? _stats;

  // بانر "أكمل الإعداد" — قابل للإخفاء يدويًا من المستخدم لهذه الجلسة.
  // ⚠️ TODO: الأصح أن يُبنى هذا الشرط على بيانات حقيقية (مثلاً: عدد
  // الشاليهات الناقصة الحقول)، وليس فقط قابلاً للإخفاء يدويًا.
  bool _showSetupBanner = true;

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
      final unread = await NotificationService.instance.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _stats = stats;
        _unreadCount = unread;
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر تنفيذ العملية، يرجى المحاولة لاحقاً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: _darkGreen,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      backgroundColor: _cream,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _darkGreen))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _darkGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                    child: _buildBody(),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Body ─────────────────────────────────────────────────
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_showSetupBanner) ...[
          _buildSetupBanner(),
          const SizedBox(height: 18),
        ],
        if (_error != null)
          _buildErrorState()
        else ...[
          _buildStatsGrid(),
          const SizedBox(height: 22),
          _buildUpcomingBookings(),
          const SizedBox(height: 22),
          _buildQuickActions(),
          const SizedBox(height: 22),
          _buildPerformanceSection(),
        ],
      ],
    );
  }

  // ─── Header (ترحيب) ───────────────────────────────────────
  Widget _buildHeader() {
    final name = _profile?.fullName ?? 'صاحب الشاليه';
    final avatarUrl = _profile?.avatarUrl;

    return Row(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () async {
                await context.push('/owner-notifications');
                _load();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sand),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: AppColors.charcoal, size: 20),
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Text('أهلاً 👋 $name',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal)),
          ],
        ),
        const SizedBox(width: 10),
        Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.sand,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: AppColors.textHint)
                  : null,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _darkGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, size: 8, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── بانر إكمال الإعداد ───────────────────────────────────
  Widget _buildSetupBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/owner-add-chalet'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _darkGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('متابعة الإعداد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أكمل معلومات شاليهك لزيادة الحجوزات',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal)),
                const SizedBox(height: 2),
                const Text('أضف الصور والأسعار والمرافق لجذب المزيد من الضيوف',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.trending_up_rounded, color: _darkGreen, size: 20),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _showSetupBanner = false),
            child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
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
                style: TextStyle(fontFamily: 'Cairo', color: _darkGreen)),
          ),
        ],
      ),
    );
  }

  // ─── 4 كروت إحصائيات ─────────────────────────────────────
  Widget _buildStatsGrid() {
    final s = _stats;

    // إجمالي الحجوزات (المؤكدة تقريبًا) = الإجمالي - الملغاة/المرفوضة.
    // ⚠️ TODO: هذا تقدير مبني على الحقول المتاحة حاليًا فقط، وليس عدّاً
    // دقيقًا لحالة "مؤكد" فعلية من قاعدة البيانات. لو عندك عمود/دالة
    // فعلية لعدد الحجوزات "المؤكدة" تحديدًا، استبدل هذا بها.
    final total = s?.totalBookingsSpot ?? 0;
    final cancelled =
        (s?.cancelledByUser ?? 0) + (s?.cancelledOrRejectedByOwner ?? 0);
    final confirmed = (total - cancelled).clamp(0, total);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _statCard(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: _darkGreen,
          title: 'الأرباح هذا الشهر',
          value: '₪${(s?.totalRevenue ?? 0).toStringAsFixed(0)}',
          footer: null, // ⚠️ TODO: نسبة التغير عن الشهر الماضي غير متوفرة بعد
        ),
        _statCard(
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFFC9A24B),
          title: 'حجوزات مؤكدة',
          value: '$confirmed',
          footer: 'حجز',
        ),
        _statCard(
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFFC9A24B),
          title: 'طلبات قيد الانتظار',
          value: '—', // ⚠️ TODO: غير متوفر بـ OwnerDashboardStats الحالي
          footer: 'طلب',
        ),
        _statCard(
          icon: Icons.visibility_outlined,
          iconColor: _darkGreen,
          title: 'مشاهدات الشاليه',
          value: '—', // ⚠️ TODO: تحتاج تتبّع مشاهدات فعلي من الـ backend
          footer: 'هذا الشهر',
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
          if (footer != null) ...[
            const SizedBox(height: 2),
            Text(footer,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _darkGreen)),
          ],
        ],
      ),
    );
  }

  // ─── الحجوزات القادمة ────────────────────────────────────
  // ⚠️ TODO: هذا القسم يحتاج قائمة حجوزات فعلية (تاريخ، سعر، عدد ضيوف،
  // صورة، حالة) لصاحب الشاليه. DashboardService الحالي يوفر إحصائيات
  // مجمّعة فقط (byChaletRevenue) وليس قائمة حجوزات فردية. لتفعيل هذا
  // القسم فعليًا، أضف دالة مثل:
  //   Future<List<BookingModel>> getOwnerUpcomingBookings()
  // وبعدها استبدل القائمة الفارغة تحت بنتائجها الحقيقية.
  // ─── الحجوزات القادمة ────────────────────────────────────
  Widget _buildUpcomingBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الحجوزات القادمة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.go('/owner-bookings'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sand),
            ),
            child: Column(
              children: [
                const Icon(Icons.event_note_outlined,
                    size: 32, color: AppColors.textHint),
                const SizedBox(height: 8),
                const Text('اعرض حجوزاتك القادمة بالتفصيل',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('فتح صفحة الحجوزات',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: _darkGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Icon(Icons.chevron_left, size: 18, color: _darkGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── إجراءات سريعة ───────────────────────────────────────
  Widget _buildQuickActions() {
    // ⚠️ TODO: راوتات "إدارة الأسعار" و"إدارة الصور" غير موجودة صراحةً
    // بـ app_router.dart الحالي عندك (فيه chalet_pricing_screen.dart
    // كملف لكن بلا route مسجّل بالراوتر يلي شفناه). اربطهم بالراوت
    // الصحيح إذا كان مختلف عن يلي حطيته هون.
    final items = [
      (Icons.add_rounded, 'إضافة شاليه جديد', '/owner-add-chalet'),
      (Icons.calendar_month_rounded, 'التقويم', '/owner-bookings'),
      (Icons.home_work_outlined, 'شاليهاتي', '/owner-chalets'),
      (Icons.person_outline_rounded, 'حسابي', '/owner-profile'),
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
                    onTap: () => context.go(item.$3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.$1, color: _darkGreen, size: 24),
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
          const Align(
            alignment: Alignment.centerRight,
            child: Text('هذا الشهر',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _performanceMetric(
                  label: 'معدل الإشغال',
                  // ⚠️ TODO: غير متوفر حاليًا — يحتاج حساب فعلي
                  // (أيام محجوزة ÷ أيام الفترة المتاحة).
                  value: '—',
                ),
              ),
              Expanded(
                child: _performanceMetric(
                  label: 'متوسط قيمة الحجز',
                  value: totalBookingsCount > 0
                      ? '₪${avgBookingValue.toStringAsFixed(0)}'
                      : '—',
                ),
              ),
              Expanded(
                child: _performanceMetric(
                  label: 'التقييمات',
                  // ⚠️ TODO: غير متوفر — يحتاج جدول/دالة تقييمات فعلية.
                  value: '—',
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFC9A24B),
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
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 3),
            ],
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.charcoal)),
          ],
        ),
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

  // ─── Bottom Navigation ────────────────────────────────────
  // ⚠️ ملاحظة: التصميم الجديد يعرض تبويبات مختلفة عن التصميم القديم
  // (المزيد / الرسائل / إضافة (زر مرتفع بالنص) / التقويم / الرئيسية)
  // بدل (الرئيسية / الشاليهات / الحجوزات / خارجي / حسابي). أبقيت نفس
  // الراوتات الموجودة فعليًا بالراوتر (owner-dashboard, owner-bookings,
  // owner-add-chalet) وربطت "المزيد" بصفحة الشاليهات مؤقتًا، و"الرسائل"
  // بدون راوت فعلي بعد (⚠️ TODO: أضف شاشة رسائل حقيقية إذا بدك تفعيلها).
  Widget _buildBottomNav() {
    final location = GoRouterState.of(context).uri.toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              icon: Icons.home_work_outlined,
              label: 'شاليهاتي',
              active: false,
              onTap: () => context.go('/owner-chalets'),
            ),
            _navItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'الرسائل',
              active: false,
              onTap: () {
                // ⚠️ TODO: لا توجد شاشة رسائل بعد بالراوتر.
              },
            ),
            GestureDetector(
              onTap: () => context.go('/owner-add-chalet'),
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: _darkGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            _navItem(
              icon: Icons.calendar_month_outlined,
              label: 'التقويم',
              active: false,
              onTap: () => context.go('/owner-bookings'),
            ),
            _navItem(
              icon: Icons.home_outlined,
              label: 'الرئيسية',
              active: location.startsWith('/owner-dashboard'),
              onTap: () => context.go('/owner-dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? _darkGreen : AppColors.textHint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
