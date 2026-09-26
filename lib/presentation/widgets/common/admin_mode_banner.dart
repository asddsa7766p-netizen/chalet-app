import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/admin_colors.dart';

/// شريط ثابت أعلى واجهة التطبيق لحساب الأدمن: يذكّره بأنه في وضع الإدارة
/// (لا حجز ولا مفضلة ولا وضع مالك) ويعيده للوحة الإدارة بضغطة.
class AdminModeBanner extends StatelessWidget {
  const AdminModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('admin_mode_banner'),
      color: AdminColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          child: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  color: AdminColors.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'وضع الإدارة',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.onNavy),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin-dashboard'),
                style: TextButton.styleFrom(
                  foregroundColor: AdminColors.gold,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.dashboard_customize_rounded, size: 16),
                label: const Text('لوحة الإدارة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
