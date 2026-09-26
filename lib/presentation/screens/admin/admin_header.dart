part of 'admin_dashboard_screen.dart';

// ═══════════════════════════ ترويسة لوحة الإدارة ══════════════════════════

/// ترويسة لوحة الإدارة (كحلي + ذهبي): العنوان، الإعدادات (اللغة والثيم
/// فقط)، وتسجيل الخروج. لوحة الإدارة واجهة الأدمن الكاملة، فلا زر لتصفّح
/// التطبيق؛ والخروج الحقيقي يعيده للرئيسية كضيف.
class AdminDashboardHeader extends StatelessWidget {
  /// للاختبارات؛ الافتراضي [AuthService.signOut].
  final Future<void> Function()? signOut;

  const AdminDashboardHeader({super.key, this.signOut});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من حساب الإدارة؟',
      action: 'تسجيل الخروج',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await (signOut ?? AuthService.instance.signOut)();
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'تعذر تسجيل الخروج، يرجى المحاولة مرة أخرى.',
            isError: true);
      }
      return;
    }
    // main.dart يعيد جلب البروفايل/المفضلة عند signedOut، والراوتر يرى ضيفاً.
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('admin_header'),
      color: AdminColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
              IconButton(
                key: const Key('admin_settings_button'),
                tooltip: 'الإعدادات',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const SettingsScreen(languageAndThemeOnly: true))),
                icon: const Icon(Icons.settings_rounded,
                    color: AdminColors.onNavy),
              ),
              IconButton(
                key: const Key('admin_sign_out_button'),
                tooltip: 'تسجيل الخروج',
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded,
                    color: AdminColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
