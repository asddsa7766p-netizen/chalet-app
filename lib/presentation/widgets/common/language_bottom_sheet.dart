import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_state_providers.dart';

/// Shared language selection bottom sheet used by both
/// ProfileScreen and SettingsScreen.
class LanguageBottomSheet extends ConsumerWidget {
  const LanguageBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
    final currentCode = locale.locale.languageCode;

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
            _LangOption(
              code: 'ar',
              label: 'العربية',
              icon: Icons.language_rounded,
              selected: currentCode == 'ar',
              onTap: () async {
                await ref.read(localeNotifierProvider).setLanguage('ar');
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _LangOption(
              code: 'en',
              label: 'English',
              icon: Icons.language_rounded,
              selected: currentCode == 'en',
              onTap: () async {
                await ref.read(localeNotifierProvider).setLanguage('en');
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String code;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption({
    required this.code,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
}
