import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class HostDashboardScreen extends StatelessWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة المالك'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              icon: Icons.home_work_rounded,
              title: 'مشروعي',
              subtitle: 'شاليهي',
              color: AppColors.primaryPale.withOpacity(0.35),
              onTap: () => context.push('/host-chalet'),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.calendar_today_rounded,
              title: 'الحجوزات',
              subtitle: 'استقبال وإدارة الطلبات',
              color: AppColors.info.withOpacity(0.12),
              onTap: () => context.push('/host-bookings'),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.video_collection_rounded,
              title: 'Reels',
              subtitle: 'نشر فيديوهات عن شاليهك',
              color: AppColors.primaryPale.withOpacity(0.35),
              onTap: () => context.push('/host-reels'),
            ),
            const SizedBox(height: 14),
            _card(
              icon: Icons.analytics_rounded,
              title: 'الإحصائيات',
              subtitle: 'دخل وحجوزات',
              color: AppColors.info.withOpacity(0.12),
              onTap: () => context.push('/host-statistics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sand),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
