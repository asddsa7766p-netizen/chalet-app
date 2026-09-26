import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_state_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/support_contact.dart';
import '../../widgets/common/language_bottom_sheet.dart';
import '../settings/about_app_screen.dart';
import '../settings/privacy_security_screen.dart';
import '../settings/help_support_screen.dart';
import '../settings/terms_screen.dart';

// Settings UI with RTL support and premium styling.
// (Originally existed inside profile_screen.dart in this project.)

class SettingsScreen extends ConsumerWidget {
  /// إعدادات حساب الإدارة: اللغة والثيم فقط.
  final bool languageAndThemeOnly;

  const SettingsScreen({super.key, this.languageAndThemeOnly = false});

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LanguageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeNotifierProvider).isDarkMode;
    // تفاعلي: يتحدّث فور تغيير اللغة من الورقة (كان يُقرأ مرة واحدة).
    final languageCode = ref.watch(localeNotifierProvider).locale.languageCode;

    // ملاحظة: أُزيلت ميزة العملة (لم يكن لها أي أثر على الأسعار بالتطبيق)
    // ومفتاح "الإشعارات" (كان يحفظ تفضيلاً لا يقرؤه أي جزء من التطبيق).
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.language_rounded,
            label: AppStrings.language,
            value: languageCode == 'ar' ? 'العربية' : 'English',
            onTap: () => _openLanguageSheet(context),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'الوضع المظلم',
            trailing: Switch(
              value: isDarkMode,
              onChanged: (v) => ref.read(themeNotifierProvider).setDarkMode(v),
              activeThumbColor: AppColors.primary,
            ),
          ),
          // حساب الإدارة: اللغة والثيم فقط.
          if (!languageAndThemeOnly) ...[
            _SettingsTile(
              icon: Icons.shield_outlined,
              label: AppStrings.privacy,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySecurityScreen(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.article_outlined,
              label: AppStrings.termsAndConditions,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsScreen(),
                ),
              ),
            ),
            // تُخفى حتى تُعتمد بيانات الدعم (AppStrings.supportPhone/Email).
            if (SupportContact.hasAny)
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: AppStrings.help,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpSupportScreen(),
                  ),
                ),
              ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: AppStrings.about,
              value: 'الإصدار 1.0.0',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutAppScreen(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryPale.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: trailing ??
            (value != null
                ? Text(
                    value!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  )
                : const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textHint)),
        onTap: onTap,
      ),
    );
  }
}
