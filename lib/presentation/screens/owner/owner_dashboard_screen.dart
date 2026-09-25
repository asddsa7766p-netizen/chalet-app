import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/booking_period.dart';
import '../../../data/models/models.dart';
import '../../../data/services/dashboard_service.dart';
import '../../../data/services/services.dart'
    show AuthService, BookingService, ChaletService;
import '../../../data/services/notification_service.dart';
import '../profile/profile_provider.dart';
import 'manual_booking_sheet.dart';
import 'owner_bottom_nav.dart';

/// لوحة تحكم المالك — كروت إحصائيات، ترحيب مع أفاتار، بانر إكمال
/// الإعداد (مشروط ببيانات حقيقية)، حجوزات قادمة حقيقية، إجراءات
/// سريعة، أداء الشاليهات.
///
/// ⚠️ ملاحظة: بعض المقاييس ما زالت غير متوفرة من الـ backend (مشاهدات
/// الشاليه، معدل الإشغال، التقييمات) وتُعرض بقيمة "—" بدل اختلاق أرقام.
class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  int _unreadCount = 0;

  final OwnerDashboardRange _range = OwnerDashboardRange.today;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  OwnerDashboardStats? _stats;
  List<BookingModel> _upcomingBookings = [];
  int _pendingCount = 0;
  // فشل جلب الحجوزات وحده: القسم يقول ذلك صراحة بدل "لا توجد حجوزات".
  bool _bookingsFailed = false;

  // بانر "أكمل الإعداد" — قابل للإخفاء يدويًا من المستخدم لهذه الجلسة،
  // ويظهر فقط إذا كان المالك لا يملك أي شاليه بعد فعليًا (_hasChalets).
  // ✅ إصلاح: سابقًا كان يظهر دائمًا بغض النظر عن وجود شاليهات فعلية.
  bool _showSetupBanner = true;
  bool _hasChalets = true;

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
    final ownerId = AuthService.instance.currentUser?.id ?? '';
    // الطلبات تبدأ معاً (متوازية)، لكن غير مقترنة كما كانت بـ Future.wait:
    // فشل طلب ثانوي لا يُسقط اللوحة كلها، بل يبقي قيمته السابقة/الافتراضية
    // (نفس فلسفة _init() بـ owner_calendar_screen.dart). الإحصائيات وحدها
    // أساسية.
    final statsF =
        DashboardService.instance.getOwnerDashboardStats(range: _range);
    final profileF = AuthService.instance
        .getCurrentProfile()
        .then<UserProfile?>((p) => p)
        .catchError((_) => _profile);
    final unreadF = NotificationService.instance
        .getUnreadCount()
        .catchError((_) => _unreadCount);
    final bookingsF = BookingService.instance
        .getIncomingBookings()
        .then<List<BookingModel>?>((b) => b)
        .catchError((_) => null);
    final chaletsF = ChaletService.instance
        .getOwnerChalets(ownerId)
        .then<List<Map<String, dynamic>>?>((c) => c)
        .catchError((_) => null);
    try {
      final stats = await statsF;
      final profile = await profileF;
      final unread = await unreadF;
      final allBookings = await bookingsF;
      final chalets = await chaletsF;
      if (!mounted) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // ✅ "الحجوزات القادمة" الحقيقية: قيد الانتظار أو مؤكدة، بتاريخ
      // وصول اليوم أو لاحقًا، مرتبة بالأقرب أولًا — بدل بطاقة CTA ثابتة.
      final upcoming = (allBookings ?? const <BookingModel>[])
          .where((b) =>
              (b.status == BookingStatus.pending ||
                  b.status == BookingStatus.confirmed) &&
              !b.checkIn.isBefore(today))
          .toList()
        ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

      setState(() {
        _profile = profile;
        _stats = stats;
        _unreadCount = unread;
        _bookingsFailed = allBookings == null;
        if (allBookings != null) {
          _upcomingBookings = upcoming.take(3).toList();
          _pendingCount = allBookings
              .where((b) => b.status == BookingStatus.pending)
              .length;
        }
        // عند الفشل لا نفترض "لا شاليهات" (كان سيُظهر بانر الإعداد خطأً).
        if (chalets != null) _hasChalets = chalets.isNotEmpty;
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

  // ✅ إصلاح (Problem #3): تحديث مقتصر فقط على عدّاد الإشعارات غير المقروءة
  // بعد الرجوع من شاشة الإشعارات، بدل استدعاء _load() الكامل الذي كان
  // يُعيد تحميل البروفايل/الإحصائيات/الحجوزات/الشاليهات ويصفّر موضع
  // التمرير وحالة loading بلا أي داعٍ فعلي (كل ما تغيّر هو حالة القراءة).
  Future<void> _refreshUnreadCount() async {
    final count = await NotificationService.instance
        .getUnreadCount()
        .catchError((_) => _unreadCount);
    if (!mounted) return;
    setState(() => _unreadCount = count);
  }

  Future<void> _confirmBackToCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('العودة كمستخدم؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        content: const Text(
          'ستفقد صفة "مالك شاليه" مؤقتًا ولن تتمكن من الوصول للوحة التحكم، '
          'لكن يمكنك العودة إليها لاحقًا من صفحة "حسابي" دون فقدان أي '
          'بيانات. هل تريد المتابعة؟',
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
      final success = await AuthService.instance.becomeCustomer();
      if (!mounted) return;
      if (success) {
        // ✅ إصلاح: بدون هذا، Riverpod يبقى يعرض profileProvider القديم
        // (role=owner) لحد ما يُعاد بناؤه من مكان آخر — فتضل شاشة
        // "حسابي" (وأي شاشة تراقب profileProvider) خارج التزامن مع
        // Supabase فعليًا بعد التبديل مباشرة.
        ref.invalidate(profileProvider);
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تعذر تنفيذ العملية، يرجى المحاولة لاحقاً')),
        );
      }
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
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          color: AppColors.primary,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        // ✅ إصلاح: _confirmBackToCustomer() كانت دالة كاملة (حوار تأكيد +
        // استدعاء becomeCustomer()) لكن غير مربوطة بأي زر بالواجهة إطلاقًا
        // — ميزة موجودة بالكود لكن المالك لا يقدر يصل لها من أي مكان.
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary),
            onSelected: (value) {
              if (value == 'become_customer') _confirmBackToCustomer();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'become_customer',
                child: Text('العودة كمستخدم',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
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
        if (_showSetupBanner && !_hasChalets) ...[
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
                _refreshUnreadCount();
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
                  color: AppColors.primary,
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
                color: AppColors.primary,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أكمل معلومات شاليهك لزيادة الحجوزات',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal)),
                SizedBox(height: 2),
                Text('أضف الصور والأسعار والمرافق لجذب المزيد من الضيوف',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
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
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
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
        // ✅ إصلاح: العنوان كان "الأرباح هذا الشهر" رغم أن _range (أعلى هذا
        // الملف) ثابت على OwnerDashboardRange.today ولا توجد واجهة لتغييره،
        // فكانت البطاقة تعرض بيانات "اليوم" بعنوان "الشهر" — بيانات مالية
        // مضلِّلة. لا يوجد نطاق "الشهر الحالي" جاهز بـ DashboardService
        // (lastMonth يعني الشهر الماضي الكامل، ليس الحالي)، فتم تصحيح
        // النص ليطابق البيانات الفعلية المعروضة (اليوم) بدل تغيير النطاق.
        _statCard(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.primary,
          title: 'أرباح اليوم',
          value: '₪${(s?.totalRevenue ?? 0).toStringAsFixed(0)}',
          footer: null,
        ),
        // ✅ إصلاح: نفس المشكلة — الرقم محسوب من _stats بنطاق اليوم فقط
        // (عبر _range=today)، فتمت إضافة "اليوم" للعنوان بدل ترك "حجوزات
        // مؤكدة" بلا نطاق زمني (كان يُفهم منها أنها إجمالي كل الحجوزات).
        _statCard(
          icon: Icons.calendar_today_outlined,
          iconColor: const Color(0xFFC9A24B),
          title: 'حجوزات مؤكدة اليوم',
          value: '$confirmed',
          footer: 'حجز',
        ),
        // ✅ إصلاح: قيمة حقيقية محسوبة من getIncomingBookings() (status ==
        // pending) بدل "—" ثابتة. قابلة للضغط لأنها تحتاج فعل من المالك.
        _statCard(
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFFC9A24B),
          title: 'طلبات قيد الانتظار',
          value: _bookingsFailed ? '—' : '$_pendingCount',
          footer: 'طلب',
          onTap: _pendingCount > 0 ? () => context.go('/owner-bookings') : null,
        ),
        _statCard(
          icon: Icons.visibility_outlined,
          iconColor: AppColors.primary,
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
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onTap != null
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.sand,
        ),
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
                    color: AppColors.primary)),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  // ─── الحجوزات القادمة ────────────────────────────────────
  // ✅ إصلاح: كانت بطاقة CTA ثابتة لا تعرض أي حجز فعلي. الآن تعرض حتى 3
  // حجوزات قادمة حقيقية (من نفس getIncomingBookings() المستخدمة أصلًا
  // بشاشة "إدارة الحجوزات")، مع حالة فارغة صادقة إن لم توجد.
  Widget _buildUpcomingBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_upcomingBookings.isNotEmpty)
              GestureDetector(
                onTap: () => context.go('/owner-bookings'),
                child: const Row(
                  children: [
                    Text('عرض الكل',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    Icon(Icons.chevron_left,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              )
            else
              const SizedBox.shrink(),
            const Text('الحجوزات القادمة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal)),
          ],
        ),
        const SizedBox(height: 12),
        if (_upcomingBookings.isEmpty)
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
                  Text(
                      _bookingsFailed
                          ? 'تعذر تحميل الحجوزات القادمة'
                          : 'لا توجد حجوزات قادمة حالياً',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('عرض سجل الحجوزات',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Icon(Icons.chevron_left,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              for (final b in _upcomingBookings) ...[
                _upcomingBookingTile(b),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.pending;
      case BookingStatus.confirmed:
        return AppColors.confirmed;
      case BookingStatus.cancelled:
        return AppColors.cancelled;
      case BookingStatus.rejected:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.completed;
    }
  }

  Widget _upcomingBookingTile(BookingModel b) {
    final statusColor = _statusColor(b.status);
    return GestureDetector(
      onTap: () => context.go('/owner-bookings'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withValues(alpha: 0.08),
                image: (b.chaletImage != null && b.chaletImage!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(b.chaletImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (b.chaletImage == null || b.chaletImage!.isEmpty)
                  ? const Icon(Icons.home_work_rounded,
                      color: AppColors.primary, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.chaletName ?? 'شاليه',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${b.guestName?.isNotEmpty == true ? b.guestName : 'ضيف'} · '
                    '${b.isMultiDay ? b.dateLabel : arabicDayLabel(b.checkIn, withYear: false)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                  Text(
                    b.periodWithTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₪${b.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(b.status.arabicLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
  // ✅ إصلاح: الشريط أصبح widget مشترك (OwnerBottomNav) تستخدمه أيضًا
  // شاشتا "شاليهاتي" و"الحجوزات"، بدل بقائه محصورًا هنا فقط. كما
  // استُبدل زر "الرسائل" الميت بـ"الإشعارات" الحقيقية.
  Widget _buildBottomNav() {
    final location = GoRouterState.of(context).uri.toString();
    return OwnerBottomNav(currentRoute: location, unreadCount: _unreadCount);
  }
}
