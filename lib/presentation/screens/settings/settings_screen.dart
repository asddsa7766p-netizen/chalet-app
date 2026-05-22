import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_state_providers.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

import '../settings/about_app_screen.dart';
import '../settings/privacy_security_screen.dart';

// Settings UI with RTL support and premium styling.
// (Originally existed inside profile_screen.dart in this project.)

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kDarkMode = 'settings_dark_mode';
  static const _kNotifications = 'settings_notifications';
  static const _kLanguage = 'settings_language'; // 'ar' | 'en'
  static const _kCurrency =
      'settings_currency'; // 'ILS' | 'USD' | 'EUR' | 'JOD'

  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = 'ar';
  String _currency = 'ILS';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool(_kDarkMode) ?? false;
      _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
      _language = prefs.getString(_kLanguage) ?? 'ar';
      _currency = prefs.getString(_kCurrency) ?? 'ILS';
      _loading = false;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
    await ref.read(themeNotifierProvider).setDarkMode(value);
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
  }

  Future<void> _setLanguage(String languageCode) async {
    setState(() => _language = languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, languageCode);
    await ref.read(localeNotifierProvider).setLanguage(languageCode);
  }

  Future<void> _setCurrency(String currency) async {
    setState(() => _currency = currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, currency);
  }

  String get _currencyLabel {
    switch (_currency) {
      case 'USD':
        return 'دولار \$';
      case 'EUR':
        return 'يورو €';
      case 'JOD':
        return 'دينار JD';
      case 'ILS':
      default:
        return 'شيكل ₪';
    }
  }

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختيار اللغة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _langOption('ar', 'العربية', Icons.language_rounded),
                const SizedBox(height: 8),
                _langOption('en', 'English', Icons.language_rounded),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langOption(String code, String label, IconData icon) {
    final selected = _language == code;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await _setLanguage(code);
          if (mounted) Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryPale.withValues(alpha: 0.45)
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.sand,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCurrencyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'اختيار العملة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _currencyOption('ILS', 'شيكل ₪'),
                _currencyOption('USD', 'دولار \$'),
                _currencyOption('EUR', 'يورو €'),
                _currencyOption('JOD', 'دينار JD'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }

  Widget _currencyOption(String code, String label) {
    final selected = _currency == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_money_rounded, color: AppColors.primary),
      title: Text(
        label,
        style:
            const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
      ),
      trailing: selected
          ? Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 16, color: AppColors.white),
            )
          : null,
      onTap: () async {
        await _setCurrency(code);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsTile(
                  icon: Icons.language_rounded,
                  label: AppStrings.language,
                  value: _language == 'ar' ? 'العربية' : 'English',
                  onTap: _openLanguageSheet,
                ),
                _SettingsTile(
                  icon: Icons.attach_money_rounded,
                  label: AppStrings.currency,
                  value: _currencyLabel,
                  onTap: _openCurrencyDialog,
                ),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: AppStrings.notifications,
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _setNotifications,
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'الوضع المظلم',
                  trailing: Switch(
                    value: _darkMode,
                    onChanged: _setDarkMode,
                    activeThumbColor: AppColors.primary,
                  ),
                ),
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
                      builder: (_) => const _TermsScreen(),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  label: AppStrings.help,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _HelpSupportScreen(),
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

class _TermsScreen extends StatelessWidget {
  const _TermsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.termsAndConditions)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: const Text(
                'هذه شاشة الشروط والأحكام.\n'
                'يتم عرض النصوص القانونية هنا بشكل واضح ومناسب للهوية البصرية للتطبيق.\n\n'
                'يمكنك لاحقاً استبدال هذا النص بالصياغة الرسمية للشركة.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.8,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpSupportScreen extends StatelessWidget {
  const _HelpSupportScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.help)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: const [
              _ContactCard(
                icon: Icons.email_outlined,
                title: 'البريد الإلكتروني',
                subtitle: 'support@friendschalets.com',
              ),
              SizedBox(height: 10),
              _ContactCard(
                icon: Icons.phone_outlined,
                title: 'واتساب',
                subtitle: '+970 5X-XXXXXXX',
              ),
              SizedBox(height: 10),
              _ContactCard(
                icon: Icons.question_answer_outlined,
                title: 'الأسئلة الشائعة (FAQ)',
                subtitle: 'تعرف على أكثر الأسئلة تكراراً',
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
  final VoidCallback? onTap; // ✅ field موجود

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap, // ✅ الإصلاح — مضاف للـ constructor
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
