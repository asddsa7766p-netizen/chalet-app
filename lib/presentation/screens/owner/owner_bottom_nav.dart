import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

/// شريط التنقّل السفلي المشترك لكل شاشات قسم المالك (لوحة التحكم،
/// شاليهاتي، الحجوزات). مستخرج من owner_dashboard_screen.dart ليكون
/// نفس الشريط متاحًا على أكثر من شاشة، بدل بقائه محصورًا داخل شاشة
/// لوحة التحكم فقط — ما كان يجبر المالك على الرجوع للوحة التحكم في كل
/// مرة يريد التنقّل بين "شاليهاتي" و"الحجوزات".
///
/// ✅ إصلاح: "الرسائل" كانت هنا زر ميت (onTap فاضي، لا توجد شاشة رسائل
/// فعلية). استُبدلت بـ"الإشعارات" التي لديها شاشة وبيانات حقيقية
/// بالفعل (OwnerNotificationsScreen + NotificationService)، بدل ترك
/// زر ظاهر بلا أي وظيفة.
class OwnerBottomNav extends StatelessWidget {
  final String currentRoute;
  final int unreadCount;

  const OwnerBottomNav({
    super.key,
    required this.currentRoute,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_work_outlined,
                label: 'شاليهاتي',
                active: currentRoute.startsWith('/owner-chalets'),
                onTap: () => context.go('/owner-chalets'),
              ),
              _navItem(
                icon: Icons.notifications_none_rounded,
                label: 'الإشعارات',
                active: currentRoute.startsWith('/owner-notifications'),
                showBadge: unreadCount > 0,
                onTap: () => context.push('/owner-notifications'),
              ),
              GestureDetector(
                onTap: () => context.go('/owner-add-chalet'),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
              _navItem(
                icon: Icons.calendar_month_outlined,
                label: 'التقويم',
                // شاشة قائمة الحجوزات (/owner-bookings) عرض ثانٍ للتقويم، فيبقى الزر فعّالاً.
                active: currentRoute.startsWith('/owner-calendar') ||
                    currentRoute.startsWith('/owner-bookings'),
                onTap: () => context.go('/owner-calendar'),
              ),
              _navItem(
                icon: Icons.home_outlined,
                label: 'الرئيسية',
                active: currentRoute.startsWith('/owner-dashboard'),
                onTap: () => context.go('/owner-dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    final color = active ? AppColors.primary : AppColors.textHint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (showBadge)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
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
