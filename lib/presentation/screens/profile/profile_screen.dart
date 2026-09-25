import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:makan/presentation/screens/profile/profile_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/error_reporter.dart';
import '../../../core/utils/support_contact.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../../data/services/notification_service.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/language_bottom_sheet.dart';
import '../settings/settings_screen.dart' show SettingsScreen;
import '../settings/help_support_screen.dart' show HelpSupportScreen;
import '../home/main_screen.dart' show goToMainTab;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // NEW: البروفايل (وبالتالي isHost/isAdmin) صار يُقرأ من profileProvider
  // بدل تحميله مرة وحدة بـ initState — هيك بيتحدث تلقائيًا بأي وقت
  // ينادى فيه ref.invalidate(profileProvider) من أي مكان بالتطبيق
  // (مثلاً بعد ما يصير المستخدم "مالك" بعد إضافة شاليه)، حتى لو هاد
  // التبويب كان محفوظ بالخلفية بالتنقل السفلي.
  bool _loadingStats = true;
  int _completedCount = 0;
  int _favoritesCount = 0;
  // ✅ إصلاح: شارة التنبيهات كانت نصاً ثابتاً '2' لكل المستخدمين. الآن العدد
  // الفعلي غير المقروء (يُخفى عند الصفر).
  int _unreadNotifications = 0;

  // ✅ جديد: هل عند المستخدم شاليه معتمد (is_approved=true) مسجّل باسمه
  // فعلاً؟ يُستخدم فقط لإظهار زر "العودة إلى لوحة المالك" لمن كان مالكًا
  // سابقًا، بدون أي RPC/جدول جديد — إعادة استخدام getOwnerChalets
  // الموجودة أصلاً (نفس الاستعلام المستخدم بشاشة "شاليهاتي").
  bool _hasApprovedChalet = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // إحصائيات الحجوزات والمفضلة — ما إلها علاقة بدور المستخدم (owner/admin)،
  // فبتضل محملة محليًا زي ما كانت.
  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final bookings = await BookingService.instance.getMyBookings();
      final completed =
          bookings.where((b) => b.status == BookingStatus.completed).length;
      final favState = ref.read(favoritesProvider).valueOrNull;
      final hasApproved = await _fetchHasApprovedChalet();
      int unread = 0;
      try {
        unread = await NotificationService.instance.getUnreadCount();
      } catch (_) {
        // عدّاد ثانوي — فشله لا يعطّل باقي الإحصائيات.
      }

      if (mounted) {
        setState(() {
          _unreadNotifications = unread;
          _completedCount = completed;
          _favoritesCount = favState?.length ?? 0;
          _hasApprovedChalet = hasApproved;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  // ✅ جديد: استُخرجت من _loadStats() لإعادة استخدامها من ref.listen أدناه
  // (Problem #5) بدون تكرار منطق الفحص في مكانين.
  Future<bool> _fetchHasApprovedChalet() async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return false;
    try {
      final ownerChalets = await ChaletService.instance.getOwnerChalets(userId);
      return ownerChalets.any((c) => c['is_approved'] == true);
    } catch (_) {
      return false;
    }
  }

  // ✅ إصلاح (Problem #5): profileProvider يتحدث (ref.invalidate) من عدة
  // أماكن بالتطبيق عند تبديل الدور (Owner⇄Customer، إضافة شاليه...)، لكن
  // _hasApprovedChalet كانت تُحسب مرة واحدة فقط بـinitState ولا تتحدث بعد
  // ذلك طالما ProfileScreen باقية بالذاكرة ضمن IndexedStack. نستمع الآن
  // لتغيّرات profileProvider ونعيد فحص الشاليه المعتمد فقط (بدون لمس
  // _loadingStats أو إعادة تحميل الحجوزات/المفضلة)، فلا يوجد أي polling
  // أو Timer، ولا حلقة لأن هذا لا يُغيّر profileProvider نفسه.
  Future<void> _onProfileChanged() async {
    final hasApproved = await _fetchHasApprovedChalet();
    if (!mounted) return;
    setState(() => _hasApprovedChalet = hasApproved);
  }

  // ✅ جديد: تفعيل وضع المالك من جديد لمن كان "Owner" سابقًا، بدون المرور
  // عبر شاشة إضافة شاليه جديد. يعيد استخدام becomeOwner() الموجودة أصلاً
  // (لا RPC جديد) ويتحقق من قيمتها المرجعة بصدق بدل تجاهلها.
  Future<void> _becomeOwnerAgain() async {
    try {
      final success = await AuthService.instance.becomeOwner();
      if (!mounted) return;
      if (success) {
        ref.invalidate(profileProvider);
        context.go('/owner-dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'لا يوجد حاليًا شاليه معتمد يسمح بتفعيل وضع المالك'),
          ),
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('نعم', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.instance.signOut();
      // Clear all cached Riverpod state so the next logged-in user
      // never sees previous user's cached data.
      if (mounted) {
        ref.invalidate(favoritesProvider);
        ref.invalidate(profileProvider);
        context.go('/auth/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // NEW: مراقبة profileProvider — أي invalidate من أي مكان بالتطبيق
    // (مثلاً بعد إضافة شاليه) بيعيد بناء هاد الجزء فورًا بالقيم الجديدة.
    // ✅ إصلاح (Problem #5): ref.listen يعيد فحص الشاليه المعتمد أيضًا عند
    // أي تغيّر بـprofileProvider، حتى لا تبقى _hasApprovedChalet قديمة.
    ref.listen(profileProvider, (previous, next) => _onProfileChanged());
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isHost = profile?.isOwner == true || profile?.role == 'owner';
    final isAdmin = profile?.isAdmin == true;
    // عدد المفضلة الحي من المزوّد (كان لقطة ثابتة وقت initState فقط).
    final favoritesCount =
        ref.watch(favoritesProvider).valueOrNull?.length ?? _favoritesCount;
    final loading =
        _loadingStats || (profileAsync.isLoading && profile == null);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              child: Column(
                children: [
                  _buildHeader(profile, isHost, isAdmin),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                              label: 'حجز مكتمل',
                              value: '$_completedCount',
                              accent: AppColors.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _statCard(
                              label: 'في المفضلة',
                              value: '$favoritesCount',
                              accent: const Color(0xFF883454))),
                    ],
                  ),

                  // ✅ زر لوحة تحكم الأدمن — مخفي تماماً عن غير الأدمن
                  if (isAdmin) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/admin-dashboard'),
                        icon: const Icon(Icons.admin_panel_settings_rounded),
                        label: const Text(
                          'لوحة تحكم الأدمن',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A6D3B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  // زر لوحة تحكم المالك
                  if (isHost) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/owner-dashboard'),
                        icon: const Icon(Icons.dashboard_rounded),
                        label: const Text(
                          'لوحة تحكم المالك',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  // ✅ جديد: زر "العودة إلى لوحة المالك" — يظهر فقط لمن كان
                  // مالكًا سابقًا ولديه شاليه معتمد فعليًا (is_approved=true)
                  // مرتبط به، بدل إجباره على تعبئة شاليه جديد ليعود مالكًا.
                  if (!isHost && _hasApprovedChalet) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _becomeOwnerAgain,
                        icon: const Icon(Icons.dashboard_rounded),
                        label: const Text(
                          'العودة إلى لوحة المالك',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  _sectionTitle('إعدادات الحساب'),
                  const SizedBox(height: 8),

                  _menuRow(
                    icon: Icons.calendar_month_rounded,
                    iconBg: AppColors.primary.withValues(alpha: 0.15),
                    iconColor: AppColors.primary,
                    label: 'حجوزاتي',
                    trailingText: null,
                    onTap: () => goToMainTab(context, 3),
                  ),
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.favorite_rounded,
                    iconBg: AppColors.error.withValues(alpha: 0.12),
                    iconColor: AppColors.error,
                    label: 'المفضلة',
                    trailingText: null,
                    onTap: () => goToMainTab(context, 2),
                  ),
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.notifications_active_rounded,
                    iconBg: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                    iconColor: const Color(0xFF2ECC71),
                    label: 'التنبيهات',
                    trailingText:
                        _unreadNotifications > 0 ? '$_unreadNotifications' : null,
                    onTap: () async {
                      await context.push('/notifications');
                      try {
                        final c =
                            await NotificationService.instance.getUnreadCount();
                        if (mounted) setState(() => _unreadNotifications = c);
                      } catch (e, st) {
                        // عدّاد ثانوي: يبقى آخر رقم معروض.
                        reportError(e, st, context: 'profile_unread_count');
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  if (!isHost)
                    GestureDetector(
                      onTap: () => context.push('/owner-add-chalet'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.add_home_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('هل تود إضافة شاليه؟',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text('انضم كمالك وابدأ باستقبال الحجوزات',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color:
                                              Colors.white.withValues(alpha: 0.85))),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_left_rounded,
                                color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    height: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                  ),

                  _sectionTitle('التطبيق والتفضيلات'),
                  const SizedBox(height: 8),

                  _menuRow(
                    icon: Icons.language_rounded,
                    iconBg: Colors.white.withValues(alpha: 0.8),
                    iconColor: AppColors.primary,
                    label: 'اللغة',
                    trailingText: null,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => const LanguageBottomSheet(),
                      );
                    },
                  ),
                  // تُخفى حتى تُعتمد بيانات الدعم (AppStrings.supportPhone/Email).
                  if (SupportContact.hasAny) ...[
                    const SizedBox(height: 10),
                    _menuRow(
                      icon: Icons.support_agent_rounded,
                      iconBg: Colors.white.withValues(alpha: 0.8),
                      iconColor: AppColors.textSecondary,
                      label: 'الدعم الفني',
                      trailingText: null,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HelpSupportScreen())),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.settings_rounded,
                    iconBg: Colors.white.withValues(alpha: 0.8),
                    iconColor: AppColors.textSecondary,
                    label: 'الإعدادات',
                    trailingText: null,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('تسجيل الخروج',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
      {required String label, required String value, required Color accent}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accent)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _menuRow(
      {required IconData icon,
      required Color iconBg,
      required Color iconColor,
      required String label,
      required String? trailingText,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: iconColor.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis)),
                ]),
              ),
              if (trailingText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(trailingText,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile? profile, bool isHost, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: profile?.avatarUrl != null
                  ? NetworkImage(profile!.avatarUrl!)
                  : null,
              child: profile?.avatarUrl == null
                  // الاسم قد يكون نصاً فارغاً (لا null): characters.first
                  // على نص فارغ يرمي StateError ويُسقط الشاشة.
                  ? Text(
                      (profile?.fullName?.trim().isNotEmpty ?? false)
                          ? profile!.fullName!.trim().characters.first
                          : 'م',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary))
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showEditProfile(profile),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.edit_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(profile?.fullName ?? 'المستخدم',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    profile?.email ??
                        AuthService.instance.currentUser?.email ??
                        '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                if (profile?.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(profile!.phone!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ],
                // شارات الأدوار
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ✅ شارة الأدمن
                    if (isAdmin)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A6D3B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF8A6D3B).withValues(alpha: 0.4)),
                        ),
                        child: const Text('🛡️ أدمن',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A6D3B))),
                      ),
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Text('🏠 مالك شاليه',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfile(UserProfile? profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (saved == true && mounted) {
      // بدل _load()، ننعش الـ provider فيتحدث كل شي يعتمد عليه تلقائيًا.
      ref.invalidate(profileProvider);
    }
  }
}

/// ورقة تعديل الاسم والهاتف: تملك حقولها وتتخلّص منها، وترجع true عند
/// الحفظ الناجح. فشل الحفظ يُعرض داخل الورقة ولا يغلقها.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile? profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile?.fullName);
  late final _phone = TextEditingController(text: widget.profile?.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance
          .updateProfile(fullName: _name.text.trim(), phone: _phone.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تعديل البيانات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          CustomTextField(
              controller: _name,
              label: AppStrings.fullName,
              prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          CustomTextField(
              controller: _phone,
              label: AppStrings.phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'حفظ التغييرات',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
