import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';
import '../../widgets/common/common_widgets.dart';
import '../../../data/services/host_service.dart';
import '../settings/about_app_screen.dart' show AboutAppScreen;
import '../settings/privacy_security_screen.dart' show PrivacySecurityScreen;
import '../settings/settings_screen.dart' show SettingsScreen;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await AuthService.instance.getCurrentProfile();
      final isHost = await HostService.instance.isHost();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isHost = isHost;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isHost = false;
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
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Account Section
                  _buildSection('الحساب', [
                    _item(Icons.person_outline, 'البيانات الشخصية',
                        onTap: () => _showEditProfile()),
                    _item(Icons.calendar_today_outlined, AppStrings.myBookings,
                        onTap: () {}),
                    _item(Icons.favorite_outline_rounded, AppStrings.favorites,
                        onTap: () {}),
                  ]),

                  if (_isHost) ...[
                    const SizedBox(height: 12),
                    _buildHostSection(),
                  ],
                  const SizedBox(height: 12),

                  // Settings Section
                  _buildSection('الإعدادات', [
                    _item(Icons.lock_outline, 'تغيير كلمة المرور',
                        onTap: () => _showChangePassword()),
                    _item(
                        Icons.notifications_outlined, AppStrings.notifications,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotificationsScreen()))),
                    _item(Icons.shield_outlined, AppStrings.privacy,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const PrivacySecurityScreen()))),
                    _item(Icons.info_outline_rounded, 'عن التطبيق',
                        onTap: () => _showAbout()),
                  ]),
                  const SizedBox(height: 12),

                  // Logout
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.error, size: 18),
                      ),
                      title: const Text(AppStrings.logout,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error)),
                      onTap: _logout,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {/* TODO: Upload avatar */},
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _profile?.avatarUrl != null
                      ? NetworkImage(_profile!.avatarUrl!)
                      : null,
                  child: _profile?.avatarUrl == null
                      ? Text((_profile?.fullName ?? 'م').characters.first,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_profile?.fullName ?? 'المستخدم',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                    _profile?.email ??
                        AuthService.instance.currentUser?.email ??
                        '',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7))),
                if (_profile?.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(_profile!.phone!,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7))),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditProfile(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(title,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sand),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              if (e.key < items.length - 1) {
                return Column(
                    children: [e.value, const Divider(height: 1, indent: 52)]);
              }
              return e.value;
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label,
      {required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryPale.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textHint),
      onTap: onTap,
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

  void _showChangePassword() {
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();
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
            const Text('تغيير كلمة المرور',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            CustomTextField(
                controller: newPass,
                label: AppStrings.newPassword,
                prefixIcon: Icons.lock_outline,
                obscureText: true),
            const SizedBox(height: 12),
            CustomTextField(
                controller: confirmPass,
                label: AppStrings.confirmNewPassword,
                prefixIcon: Icons.lock_outline,
                obscureText: true),
            const SizedBox(height: 20),
            AppButton(
              label: AppStrings.updatePassword,
              onPressed: () async {
                if (newPass.text == confirmPass.text &&
                    newPass.text.length >= 8) {
                  await AuthService.instance.updatePassword(newPass.text);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لوحة المالك',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'انتقال إلى لوحة المالك',
            onPressed: () => context.push('/host-dashboard'),
            icon: Icons.home_work_rounded,
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutAppScreen()),
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
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _loading = false;
        });
      }
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
                    ],
                  ),
                )
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
              ? AppColors.white
              : AppColors.primaryPale.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  notification.isRead ? AppColors.sand : AppColors.primaryPale),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sand),
              ),
              child: Center(
                child: Text(notification.icon,
                    style: const TextStyle(fontSize: 20)),
              ),
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
                          color: AppColors.charcoal)),
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
                          color: AppColors.textHint)),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
