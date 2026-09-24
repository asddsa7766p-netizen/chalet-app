import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';

class LuxurySearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;

  const LuxurySearchBar({
    super.key,
    this.controller,
    this.hintText = 'بحث',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  void _clear() {
    if (onClear != null) {
      onClear!();
      return;
    }
    controller?.clear();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    // زر المسح يتبع نص الحقل مباشرة (يستمع للـ controller) بدل الاعتماد
    // على إعادة بناء من المستدعي — كان لا يظهر/يختفي أثناء الكتابة.
    if (ctrl == null) return _field(context, hasText: false);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) =>
          _field(context, hasText: value.text.isNotEmpty),
    );
  }

  Widget _field(BuildContext context, {required bool hasText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.textHint,
          ),
          filled: true,
          fillColor: AppColors.white,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: hasText
              ? IconButton(
                  key: const Key('luxury_search_clear'),
                  tooltip: 'مسح',
                  onPressed: _clear,
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class LuxurySectionHeader extends StatelessWidget {
  final String title;
  final String emoji;

  const LuxurySectionHeader({
    super.key,
    required this.title,
    this.emoji = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (emoji.isNotEmpty) ...[
          Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class LuxuryShimmerCard extends StatelessWidget {
  final double height;

  const LuxuryShimmerCard({
    super.key,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.sand,
      highlightColor: Colors.white,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class LuxuryEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const LuxuryEmptyState({
    super.key,
    this.icon = Icons.search_off_rounded,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 56, color: AppColors.primaryLight),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
