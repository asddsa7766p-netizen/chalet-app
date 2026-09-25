import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/support_contact.dart';

/// Help & Support screen — reused from SettingsScreen and ProfileScreen.
///
/// كل بطاقة تواصل تظهر فقط إن كانت قناتها معرَّفة بـ AppStrings، وتفتحها
/// فعلياً عند الضغط (لا بطاقات بلا وظيفة).
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر فتح التطبيق المناسب على جهازك',
            style: TextStyle(fontFamily: 'Cairo')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.help)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              if (SupportContact.hasEmail)
                _ContactCard(
                  icon: Icons.email_outlined,
                  title: 'البريد الإلكتروني',
                  subtitle: SupportContact.email,
                  onTap: () => _open(context, SupportContact.emailUri),
                ),
              if (SupportContact.hasPhone)
                _ContactCard(
                  icon: Icons.phone_outlined,
                  title: 'واتساب',
                  subtitle: SupportContact.phone,
                  onTap: () => _open(context, SupportContact.whatsappUri),
                ),
              if (!SupportContact.hasAny)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'قنوات التواصل غير متاحة حالياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryPale.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: AppColors.charcoal,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppColors.textHint),
      ),
    );
  }
}
