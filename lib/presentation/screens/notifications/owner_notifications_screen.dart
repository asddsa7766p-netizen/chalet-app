import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/services/notification_service.dart';

class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  State<OwnerNotificationsScreen> createState() =>
      _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationModel> _items = [];

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
      final items = await NotificationService.instance.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الإشعارات';
      });
    }
  }

  // ✅ إصلاح: كانت هذه الدالة تكتفي بتعليم الإشعار كمقروء وإعادة تحميل
  // القائمة (وهذا بالضبط الـ"loading" اللي يظهر ثم يرجع المستخدم بدون
  // أي فتح فعلي) — بلا أي navigation إطلاقًا.
  //
  // جدول notifications بالإنتاج لا يحتوي عمود booking_id/related_id (ولا
  // يوجد أصلًا حقل كهذا يُملأ من trigger إنشاء الإشعار handle_booking_
  // notifications())، فما في طريقة موثوقة لفتح تفاصيل حجز معيّن بعينه من
  // الإشعار. لا يوجد أيضًا شاشة "تفاصيل حجز" منفصلة بالتطبيق أصلًا —
  // القائمة الموجودة لحجوزات المالك هي /owner-bookings. لذلك، وبأقل
  // تعديل ممكن وبدون تغيير قاعدة البيانات، إشعارات الحجز (جديد/تأكيد)
  // تفتح شاشة حجوزات المالك الموجودة فعلاً، بدل ما ترجع بلا أي فعل.
  Future<void> _onTapItem(NotificationModel item) async {
    if (!item.isRead) {
      await NotificationService.instance.markAsRead(item.id);
      _load();
    }
    if (!mounted) return;
    if (item.type == 'booking' || item.type == 'booking_confirmed') {
      context.push('/owner-bookings');
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'booking':
        return Icons.event_available_rounded;
      case 'payment':
        return Icons.account_balance_wallet_outlined;
      case 'system':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الإشعارات',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          actions: [
            if (_items.any((e) => !e.isRead))
              TextButton(
                onPressed: () async {
                  await NotificationService.instance.markAllAsRead();
                  _load();
                },
                child: const Text('تعليم الكل كمقروء',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(_error!,
                              style: const TextStyle(fontFamily: 'Cairo')),
                        ),
                      ],
                    )
                  : _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Icon(Icons.notifications_none_rounded,
                                  size: 48, color: AppColors.textHint),
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: Text('لا يوجد إشعارات حالياً',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return InkWell(
                              onTap: () => _onTapItem(item),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.isRead
                                      ? Colors.white
                                      : const Color(0xFFEFF3E9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.sand),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(_iconFor(item.type),
                                        color: AppColors.primary, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.title,
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13)),
                                          const SizedBox(height: 3),
                                          Text(item.body,
                                              style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
