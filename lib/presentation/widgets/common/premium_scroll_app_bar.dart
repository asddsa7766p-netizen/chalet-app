import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Premium, scroll-aware SliverAppBar with adaptive blur, shadow and micro-interactions.
///
/// Notes:
/// - Built to be production-friendly and reuseable.
/// - Works with any CustomScrollView using slivers.
class PremiumScrollAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? avatar;
  final int notificationCount;

  final double expandedHeight;
  final double toolbarMinHeight;
  final double shadowStart;
  final double blurStart;

  final double parallaxAmount;

  final VoidCallback? onSearch;
  final VoidCallback? onFilter;

  /// Background blend colors.
  /// [topColor] is used while the AppBar is transparent/expanded.
  /// [surfaceColor] is used while the AppBar becomes solid/compact.
  final Color topColor;
  final Color surfaceColor;

  const PremiumScrollAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.notificationCount = 0,
    this.expandedHeight = 190,
    this.toolbarMinHeight = 64,
    this.shadowStart = 80,
    this.blurStart = 28,
    this.parallaxAmount = 18,
    this.onSearch,
    this.onFilter,
    this.topColor = const Color(0xFF0D1A08),
    this.surfaceColor = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: surfaceColor,
      leading: null,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final currentExtent = constraints.maxHeight;
          final delta =
              (expandedHeight - currentExtent).clamp(0.0, expandedHeight);
          final denom =
              (expandedHeight - toolbarMinHeight).clamp(1.0, double.infinity);
          final t = (delta / denom).clamp(0.0, 1.0);

          // Adaptive visual layers
          final blurT = ((delta - blurStart) / 70.0).clamp(0.0, 1.0);
          final shadowT = ((delta - shadowStart) / 60.0).clamp(0.0, 1.0);
          final compactT = easeOutCubic(t);

          // Typography morph
          final titleScale = lerpDouble(1.2, 1.0, compactT);
          final titleY = lerpDouble(18.0, 0.0, compactT);
          final titleOpacity = lerpDouble(1.0, 0.96, compactT);
          final subtitleOpacity = lerpDouble(1.0, 0.0, compactT);

          // Color blend: transparent -> surface
          final bgColor =
              Color.lerp(topColor, surfaceColor, compactT) ?? surfaceColor;

          // AppBar height (for SafeArea content)
          final appBarHeight =
              lerpDouble(expandedHeight, toolbarMinHeight, compactT);

          // Parallax background translate
          final parallaxTop = -delta * (parallaxAmount / expandedHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Parallax gradient
              Positioned(
                top: parallaxTop,
                left: 0,
                right: 0,
                height: expandedHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withOpacity(
                          (0.95 * (1 - t) + 0.1).clamp(0.0, 1.0).toDouble(),
                        ),
                        AppColors.primary.withOpacity(0.35 * (1 - t) + 0.05),
                        bgColor,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Glass layer
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: lerpDouble(18.0, 0.0, blurT),
                      sigmaY: lerpDouble(18.0, 0.0, blurT),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      color: bgColor.withOpacity(
                          lerpDouble(0.18, 1.0, compactT).clamp(0.0, 1.0)),
                    ),
                  ),
                ),
              ),

              // Shadow (only when needed)
              Positioned(
                left: 12,
                right: 12,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: shadowT,
                    curve: Curves.easeOutCubic,
                    child: Container(
                      height: 18,
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Main content row
              SizedBox(
                height: appBarHeight,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LeftActions(
                          progress: compactT,
                          onSearch: onSearch,
                          onFilter: onFilter,
                        ),
                        Expanded(
                          child: Center(
                            child: _TitleBlock(
                              title: title,
                              subtitle: subtitle,
                              titleScale: titleScale,
                              titleY: titleY,
                              titleOpacity: titleOpacity,
                              subtitleOpacity: subtitleOpacity,
                              greetingPulse: compactT < 0.55,
                            ),
                          ),
                        ),
                        _RightActions(
                          progress: compactT,
                          avatar: avatar,
                          notificationCount: notificationCount,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Stretch / pull hint (small glow at top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopGlow(progress: compactT),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopGlow extends StatelessWidget {
  final double progress;
  const _TopGlow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final glowOpacity =
        lerpDouble(0.0, 1.0, 1 - progress)!.clamp(0.0, 1.0).toDouble();

    return IgnorePointer(
      child: Opacity(
        opacity: glowOpacity,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.accent.withOpacity(0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftActions extends StatelessWidget {
  final double progress;
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;

  const _LeftActions({
    required this.progress,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final compact = progress;
    final size = lerpDouble(44, 40, compact);

    return SizedBox(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _GlassIconButton(
            icon: Icons.search_rounded,
            onTap: onSearch,
            progress: compact,
            size: size,
            glow: true,
          ),
          const SizedBox(width: 10),
          _GlassIconButton(
            icon: Icons.filter_list_rounded,
            onTap: onFilter,
            progress: compact,
            size: size,
          ),
        ],
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  final double progress;
  final Widget? avatar;
  final int notificationCount;

  const _RightActions({
    required this.progress,
    required this.avatar,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final badgeOpacity =
        lerpDouble(0.0, 1.0, easeOutCubic(progress))!.clamp(0.0, 1.0);
    final size = lerpDouble(44, 40, progress);

    return SizedBox(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _GlassIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: null,
                  progress: progress,
                  size: size,
                ),
                if (notificationCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Opacity(
                      opacity: badgeOpacity,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.9),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          notificationCount > 99 ? '99+' : '$notificationCount',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PremiumAvatar(avatar: avatar, progress: progress),
        ],
      ),
    );
  }
}

class _PremiumAvatar extends StatelessWidget {
  final Widget? avatar;
  final double progress;

  const _PremiumAvatar({required this.avatar, required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = lerpDouble(44, 40, progress);
    final borderOpacity = lerpDouble(0.35, 0.18, progress);

    return SizedBox(
      width: size,
      height: size,
      child: Hero(
        tag: 'premium-avatar',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.09),
            border: Border.all(
              color: AppColors.accent.withOpacity(borderOpacity),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: avatar ??
                const Icon(Icons.person_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final String title;
  final String? subtitle;

  final double titleScale;
  final double titleY;
  final double titleOpacity;
  final double subtitleOpacity;

  final bool greetingPulse;

  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.titleScale,
    required this.titleY,
    required this.titleOpacity,
    required this.subtitleOpacity,
    required this.greetingPulse,
  });

  @override
  Widget build(BuildContext context) {
    final pulse = greetingPulse
        ? (0.92 +
            (math.sin(DateTime.now().millisecond / 1000.0 * math.pi) * 0.08))
        : 1.0;

    return Transform.translate(
      offset: Offset(0, titleY),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: titleOpacity,
            curve: Curves.easeOutCubic,
            child: Transform.scale(
              scale: titleScale * pulse,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.2,
                  height: 1.05,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ),
          if (subtitle != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: subtitleOpacity,
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  subtitle ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withOpacity(0.95),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double progress;
  final double size;
  final bool glow;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.progress,
    required this.size,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgOpacity = lerpDouble(0.18, 0.10, easeOutCubic(progress));
    final iconOpacity = lerpDouble(1.0, 0.92, easeOutCubic(progress));
    final glowOpacity = glow ? lerpDouble(0.35, 0.0, progress) : 0.0;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        hoverColor: Colors.white.withOpacity(0.08),
        splashColor: Colors.white.withOpacity(0.14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (glow)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glowOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(bgOpacity),
                border: Border.all(
                  color: Colors.white.withOpacity(0.14),
                  width: 1,
                ),
              ),
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: iconOpacity,
                  curve: Curves.easeOutCubic,
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
