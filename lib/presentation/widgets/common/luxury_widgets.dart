import 'package:flutter/material.dart';

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
