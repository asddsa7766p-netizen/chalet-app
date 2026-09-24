import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/models.dart';
import '../../../data/services/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  // ✅ إصلاح: فشل التحميل كان يظهر كـ "لا توجد إشعارات" (مضلّل).
  bool _loadError = false;
  // 0 = الكل، 1 = غير المقروءة، 2 = العروض (كانت أزراراً شكلية بلا وظيفة).
  int _filter = 0;

  List<NotificationModel> get _visible {
    switch (_filter) {
      case 1:
        return _notifications.where((n) => !n.isRead).toList();
      case 2:
        return _notifications.where((n) => n.type == 'offer').toList();
      default:
        return _notifications;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final notifs = await NotificationsService.instance.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  Future<void> _runAndReload(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحديث الإشعارات، يرجى المحاولة مرة أخرى',
              style: TextStyle(fontFamily: 'Cairo')),
        ));
      }
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          AppStrings.allNotifications,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: TextButton(
                onPressed: () => _runAndReload(
                    () => NotificationsService.instance.markAllAsRead()),
                child: Text(
                  AppStrings.markAllRead,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _loadError
              ? _buildLoadError()
              : _notifications.isEmpty
              ? _buildEmpty()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      _buildTabSwitcher(),
                      const SizedBox(height: 14),
                      _buildDividerDecor(),
                      const SizedBox(height: 14),
                      if (_visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('لا توجد إشعارات في هذا التصنيف',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ),
                      ..._visible
                          .map((n) => _NotificationCard(
                                notification: n,
                                onTap: () async {
                                  if (n.isRead) return;
                                  await _runAndReload(() =>
                                      NotificationsService.instance
                                          .markAsRead(n.id));
                                },
                              ))
                          .toList(),
                      const SizedBox(height: 28),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            size: 64,
            color: AppColors.sand,
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('تعذر تحميل الإشعارات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        _pill(text: 'الكل', selected: _filter == 0, onTap: () => _setFilter(0)),
        const SizedBox(width: 10),
        _pill(
            text: 'غير المقروءة',
            selected: _filter == 1,
            onTap: () => _setFilter(1)),
        const SizedBox(width: 10),
        _pill(
            text: 'العروض', selected: _filter == 2, onTap: () => _setFilter(2)),
      ],
    );
  }

  void _setFilter(int f) => setState(() => _filter = f);

  Widget _pill(
      {required String text, required bool selected, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _pillBody(text: text, selected: selected),
    );
  }

  Widget _pillBody({required String text, required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary
            : AppColors.textPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDividerDecor() {
    return Opacity(
      opacity: 0.5,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final Future<void> Function() onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    final String type = notification.type ?? '';

    final Color iconBg;
    final Color iconColor;
    final IconData icon;

    switch (type) {
      case 'offer':
        iconBg = AppColors.primary.withOpacity(0.10);
        iconColor = AppColors.primary;
        icon = Icons.celebration_rounded;
        break;
      case 'payment':
      case 'payment_confirmed':
        iconBg = AppColors.primary.withOpacity(0.10);
        iconColor = AppColors.primary;
        icon = Icons.payments_rounded;
        break;
      case 'booking_confirmed':
        iconBg = AppColors.primary.withOpacity(0.10);
        iconColor = AppColors.primary;
        icon = Icons.check_circle_rounded;
        break;
      case 'reminder':
        iconBg = AppColors.primary.withOpacity(0.10);
        iconColor = AppColors.primary;
        icon = Icons.notifications_active_rounded;
        break;
      default:
        iconBg = AppColors.primary.withOpacity(0.10);
        iconColor = AppColors.primary;
        icon = Icons.notifications_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () async {
          if (notification.isRead) return;
          await onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withOpacity(0.35)
                  : AppColors.border,
              width: 1,
            ),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight:
                                  isUnread ? FontWeight.w900 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    if (notification.body != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        notification.body!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    }
    if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    }
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} أيام';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
