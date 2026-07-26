import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// ============================================
// LUXURY CARD - Base card with premium styling
// ============================================
class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool withGradientBorder;
  final bool withShadow;

  const LuxuryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
    this.withGradientBorder = true,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: withGradientBorder
            ? Border.all(
                color: AppColors.accent.withOpacity(0.15),
                width: 1,
              )
            : null,
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

// ============================================
// LUXURY BUTTON - Premium button with gradient
// ============================================
class LuxuryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final IconData? icon;
  final double height;
  final double borderRadius;
  final bool fullWidth;

  const LuxuryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outline = false,
    this.icon,
    this.height = 52,
    this.borderRadius = 14,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent, width: 1.5),
          minimumSize: Size(fullWidth ? double.infinity : 0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(),
      );
    }

    return Container(
      height: height,
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentLight],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: Size(fullWidth ? double.infinity : 0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: AppColors.background,
          strokeWidth: 2.5,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.background),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.background,
          ),
        ),
      ],
    );
  }
}

// ============================================
// LUXURY ICON BUTTON - Circular icon button
// ============================================
class LuxuryIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool withGradient;
  final Color? backgroundColor;
  final Color? iconColor;

  const LuxuryIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.withGradient = false,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: withGradient
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                )
              : null,
          color: withGradient ? null : (backgroundColor ?? AppColors.card),
          shape: BoxShape.circle,
          border: !withGradient
              ? Border.all(
                  color: AppColors.accent.withOpacity(0.2),
                  width: 1,
                )
              : null,
          boxShadow: withGradient
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: iconColor ??
              (withGradient ? AppColors.background : AppColors.accent),
          size: size * 0.5,
        ),
      ),
    );
  }
}

// ============================================
// LUXURY CHIP - Small badge/tag component
// ============================================
class LuxuryChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const LuxuryChip({
    super.key,
    this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [AppColors.accent, AppColors.accentLight],
              )
            : null,
        color: selected ? null : AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              selected ? AppColors.accent : AppColors.accent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.background : AppColors.accent,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Cairo',
              color: selected ? AppColors.background : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: widget,
      );
    }

    return widget;
  }
}

// ============================================
// LUXURY SEARCH BAR - Premium search input
// ============================================
class LuxurySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const LuxurySearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.textMuted,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.accent,
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

// ============================================
// LUXURY SECTION HEADER - Section title with accent
// ============================================
class LuxurySectionHeader extends StatelessWidget {
  final String title;
  final String? emoji;
  final String? actionText;
  final VoidCallback? onActionTap;

  const LuxurySectionHeader({
    super.key,
    required this.title,
    this.emoji,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            if (emoji != null) ...[
              const SizedBox(width: 6),
              Text(emoji!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionText!,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================
// LUXURY SHIMMER CARD - Loading placeholder
// ============================================
class LuxuryShimmerCard extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const LuxuryShimmerCard({
    super.key,
    this.height = 280,
    this.width,
    this.borderRadius = 20,
  });

  @override
  State<LuxuryShimmerCard> createState() => _LuxuryShimmerCardState();
}

class _LuxuryShimmerCardState extends State<LuxuryShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryLight,
                        AppColors.card,
                        AppColors.primaryLight,
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    (_controller.value * 3 - 1) * (widget.width ?? 400),
                    0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          AppColors.accent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================
// LUXURY EMPTY STATE - Empty content placeholder
// ============================================
class LuxuryEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionText;
  final VoidCallback? onActionTap;

  const LuxuryEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionTap != null) ...[
              const SizedBox(height: 20),
              LuxuryButton(
                label: actionText!,
                onPressed: onActionTap,
                fullWidth: false,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================
// LUXURY BADGE - Small status badge
// ============================================
class LuxuryBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final bool withGradient;

  const LuxuryBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.withGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: withGradient
            ? const LinearGradient(
                colors: [AppColors.accent, AppColors.accentLight],
              )
            : null,
        color: withGradient ? null : (backgroundColor ?? AppColors.card),
        borderRadius: BorderRadius.circular(20),
        boxShadow: withGradient
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ??
              (withGradient ? AppColors.background : AppColors.textPrimary),
          fontSize: 12,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================
// LUXURY DIVIDER - Styled divider
// ============================================
class LuxuryDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const LuxuryDivider({
    super.key,
    this.height = 1,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accent.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
