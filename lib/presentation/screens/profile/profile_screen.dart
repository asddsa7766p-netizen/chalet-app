import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../../data/providers/favorites_provider.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/language_bottom_sheet.dart';
import '../settings/about_app_screen.dart' show AboutAppScreen;
import '../settings/privacy_security_screen.dart' show PrivacySecurityScreen;
import '../settings/settings_screen.dart' show SettingsScreen;
import '../settings/help_support_screen.dart' show HelpSupportScreen;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _isHost = false;
  bool _isAdmin = false; // ✅ جديد
  int _completedCount = 0;
  int _favoritesCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AuthService.instance.getCurrentProfile(),
        BookingService.instance.getMyBookings(),
      ]);
      final profile = results[0] as UserProfile?;
      final bookings = results[1] as List<BookingModel>;
      final completed =
          bookings.where((b) => b.status == BookingStatus.completed).length;
      final favState = ref.read(favoritesProvider).valueOrNull;
      if (mounted) {
        setState(() {
          _profile = profile;
          _isHost = profile?.isOwner == true || profile?.role == 'owner';
          _isAdmin = profile?.isAdmin == true; // ✅ جديد
          _completedCount = completed;
          _favoritesCount = favState?.length ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isHost = false;
          _isAdmin = false;
        });
      }
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
        context.go('/auth/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              child: Column(
                children: [
                  _buildHeader(),
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
                              value: '$_favoritesCount',
                              accent: const Color(0xFF883454))),
                    ],
                  ),

                  // ✅ زر لوحة تحكم الأدمن — مخفي تماماً عن غير الأدمن
                  if (_isAdmin) ...[
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
                  if (_isHost) ...[
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

                  const SizedBox(height: 14),

                  _sectionTitle('إعدادات الحساب'),
                  const SizedBox(height: 8),

                  _menuRow(
                    icon: Icons.calendar_month_rounded,
                    iconBg: AppColors.primary.withOpacity(0.15),
                    iconColor: AppColors.primary,
                    label: 'حجوزاتي',
                    trailingText: null,
                    onTap: () => context.go('/home', extra: 3),
                  ),
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.favorite_rounded,
                    iconBg: AppColors.error.withOpacity(0.12),
                    iconColor: AppColors.error,
                    label: 'المفضلة',
                    trailingText: null,
                    onTap: () => context.go('/home', extra: 2),
                  ),
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.notifications_active_rounded,
                    iconBg: const Color(0xFF2ECC71).withOpacity(0.15),
                    iconColor: const Color(0xFF2ECC71),
                    label: 'التنبيهات',
                    trailingText: '2',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),

                  const SizedBox(height: 16),

                  if (!_isHost)
                    GestureDetector(
                      onTap: () => context.push('/owner-add-chalet'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.85),
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
                                color: Colors.white.withOpacity(0.15),
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
                                              Colors.white.withOpacity(0.85))),
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
                      color: AppColors.primary.withOpacity(0.08),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.15)),
                    ),
                  ),

                  _sectionTitle('التطبيق والتفضيلات'),
                  const SizedBox(height: 8),

                  _menuRow(
                    icon: Icons.language_rounded,
                    iconBg: Colors.white.withOpacity(0.8),
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
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.support_agent_rounded,
                    iconBg: Colors.white.withOpacity(0.8),
                    iconColor: AppColors.textSecondary,
                    label: 'الدعم الفني',
                    trailingText: null,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen())),
                  ),
                  const SizedBox(height: 10),
                  _menuRow(
                    icon: Icons.settings_rounded,
                    iconBg: Colors.white.withOpacity(0.8),
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
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
              style: TextStyle(
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
            style: TextStyle(
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
                      border: Border.all(color: iconColor.withOpacity(0.25)),
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

  Widget _buildHeader() {
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
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: _profile?.avatarUrl != null
                  ? NetworkImage(_profile!.avatarUrl!)
                  : null,
              child: _profile?.avatarUrl == null
                  ? Text((_profile?.fullName ?? 'م').characters.first,
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
                onTap: _showEditProfile,
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
                Text(_profile?.fullName ?? 'المستخدم',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    _profile?.email ??
                        AuthService.instance.currentUser?.email ??
                        '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                if (_profile?.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(_profile!.phone!,
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
                    if (_isAdmin)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A6D3B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF8A6D3B).withOpacity(0.4)),
                        ),
                        child: const Text('🛡️ أدمن',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8A6D3B))),
                      ),
                    if (_isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
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

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _profile?.fullName);
    final phoneCtrl = TextEditingController(text: _profile?.phone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                controller: nameCtrl,
                label: AppStrings.fullName,
                prefixIcon: Icons.person_outline),
            const SizedBox(height: 12),
            CustomTextField(
                controller: phoneCtrl,
                label: AppStrings.phone,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            AppButton(
              label: 'حفظ التغييرات',
              onPressed: () async {
                await AuthService.instance.updateProfile(
                    fullName: nameCtrl.text, phone: phoneCtrl.text);
                Navigator.pop(ctx);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// NOTIFICATIONS SCREEN
// ============================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notifs = await NotificationsService.instance.getNotifications();
      if (mounted)
        setState(() {
          _notifications = notifs;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.allNotifications),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await NotificationsService.instance.markAllAsRead();
                _load();
              },
              child: const Text(AppStrings.markAllRead,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 64, color: AppColors.sand),
                      SizedBox(height: 14),
                      Text('لا يوجد إشعارات',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                    ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _NotifTile(
                      notification: _notifications[i],
                      onTap: () async {
                        if (!_notifications[i].isRead) {
                          await NotificationsService.instance
                              .markAsRead(_notifications[i].id);
                          setState(() => _notifications[i] = NotificationModel(
                                id: _notifications[i].id,
                                userId: _notifications[i].userId,
                                title: _notifications[i].title,
                                body: _notifications[i].body,
                                type: _notifications[i].type,
                                isRead: true,
                                createdAt: _notifications[i].createdAt,
                              ));
                        }
                      },
                    ),
                  ),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  const _NotifTile({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white
              : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: notification.isRead
                  ? AppColors.border
                  : AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Center(
                  child: Text(notification.icon,
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                          color: AppColors.textPrimary)),
                  if (notification.body != null) ...[
                    const SizedBox(height: 4),
                    Text(notification.body!,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                      '${notification.createdAt.day}/${notification.createdAt.month}/${notification.createdAt.year}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textMuted)),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
