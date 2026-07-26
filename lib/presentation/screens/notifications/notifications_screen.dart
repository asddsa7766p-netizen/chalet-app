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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final notifs = await NotificationsService.instance.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
                onPressed: () async {
                  await NotificationsService.instance.markAllAsRead();
                  await _load();
                },
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
                      ..._notifications
                          .map((n) => _NotificationCard(
                                notification: n,
                                onTap: () async {
                                  if (n.isRead) return;
                                  await NotificationsService.instance
                                      .markAsRead(n.id);
                                  await _load();
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
            'لا توجد إشعارات قديمة أخرى',
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

  Widget _buildTabSwitcher() {
    // UI only (no filtering logic)
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        _pill(text: 'الكل', selected: true),
        const SizedBox(width: 10),
        _pill(text: 'غير المقروءة', selected: false),
        const SizedBox(width: 10),
        _pill(text: 'العروض', selected: false),
      ],
    );
  }

  Widget _pill({required String text, required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
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
