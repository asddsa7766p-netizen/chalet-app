import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/admin_colors.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/admin_service.dart';
import '../../widgets/common/paged_list.dart';
import '../../../data/services/services.dart' show AuthService;

part 'overview_tab.dart';
part 'chalet_approvals_tab.dart';
part 'users_tab.dart';

/// لوحة تحكم الأدمن الشاملة — makan
///
/// كل الإجراءات تمرّ عبر دوال admin_* على السيرفر (تتحقق من
/// is_current_user_admin وتسجّل بـ admin_audit_log)، والإحصائيات تُجمَّع على
/// السيرفر (admin_get_overview_stats). القوائم مرقّمة بصفحات.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _checkingAccess = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final profile = await AuthService.instance.getCurrentProfile();
      final isAdmin = profile?.isAdmin == true;
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _checkingAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _checkingAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AdminColors.navy)),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Text(
                    'لا تملك صلاحية الوصول لهذه الصفحة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('العودة للرئيسية',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // هوية الإدارة (كحلي + ذهبي) مختلفة عمداً عن أخضر واجهة الزبون، حتى يعرف
    // الأدمن دائماً أنه في وضع الإدارة.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // ── Header ──
            Material(
              key: const Key('admin_header'),
              color: AdminColors.navy,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdminColors.navyLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminColors.gold),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: AdminColors.gold),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'لوحة الإدارة',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AdminColors.onNavy),
                            ),
                            Text(
                              'وضع الإدارة · مكان',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.gold),
                            ),
                          ],
                        ),
                      ),
                      // يفتح واجهة التطبيق (بشريط "وضع الإدارة" أعلاها)، لا خروج
                      // من الحساب.
                      TextButton.icon(
                        onPressed: () => context.go('/home'),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminColors.onNavy,
                          backgroundColor: AdminColors.navyLight,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text('تصفّح التطبيق',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Tabs ──
            TabBar(
              controller: _tabController,
              labelColor: AdminColors.navy,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AdminColors.gold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
              tabs: const [
                Tab(text: 'نظرة عامة'),
                Tab(text: 'موافقة الشاليهات'),
                Tab(text: 'المستخدمون'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _OverviewTab(),
                  _ChaletApprovalsTab(),
                  _UsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ مكوّنات مشتركة ═══════════════════════════════

void _showSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
    backgroundColor: isError ? AppColors.error : AppColors.primary,
  ));
}

/// رسالة الخطأ للأدمن: رسالة الدالة العربية إن وُجدت، وإلا [fallback].
String _errorText(Object e, String fallback) =>
    e is AdminActionException && e.message.trim().isNotEmpty
        ? e.message
        : fallback;

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.error))),
      ],
    ),
  );
  return ok == true;
}

Widget _errorView(String error, VoidCallback onRetry) {
  return Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(error,
          style: const TextStyle(
              fontFamily: 'Cairo', color: AppColors.textSecondary)),
      TextButton(
          onPressed: onRetry,
          child: const Text('إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary))),
    ]),
  );
}
