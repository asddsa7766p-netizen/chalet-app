import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Luxury, scroll-aware AppBar with collapsing + gradient + glass + gold border.
/// Designed to be used inside a CustomScrollView as a Sliver.
class LuxuryCollapsingAppBar extends StatelessWidget {
  final String appTitle;
  final String userName;
  final String cityName;
  final int unreadNotificationsCount;
  final List<NotificationPreview> notificationsPreview;

  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onOpenNotifications;
  final VoidCallback onProfile;

  final VoidCallback? onHeartPulse;

  final double expandedHeight;
  final double toolbarMinHeight;

  const LuxuryCollapsingAppBar({
    super.key,
    required this.appTitle,
    required this.userName,
    required this.cityName,
    required this.unreadNotificationsCount,
    required this.notificationsPreview,
    required this.onSearch,
    required this.onFilter,
    required this.onOpenNotifications,
    required this.onProfile,
    this.onHeartPulse,
    this.expandedHeight = 120,
    this.toolbarMinHeight = 70,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final topColor = const Color(0xFF1A2332);
    final bottomColor = const Color(0xFF0F1620);

    // In dark mode we keep gold accents and deepen background.
    final darkBg = const Color(0xFF0A0E14);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: Colors.transparent,
      leading: null,
      actions: null,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final currentExtent = constraints.maxHeight;
          final delta =
              (expandedHeight - currentExtent).clamp(0.0, expandedHeight);
          final denom =
              (expandedHeight - toolbarMinHeight).clamp(1.0, double.infinity);
          final t = (delta / denom).clamp(0.0, 1.0); // 0 expanded -> 1 compact

          // blur increases with scrolling
          final blurT = ((1 - t) * 0.2) + (t * 0.8);
          final sigma = lerpDouble(20, 0, t) * (isDark ? 1.1 : 1.0);

          // parallax
          final parallaxTop = -delta * 0.12;

          // searchbar fade out
          final searchFade =
              lerpDouble(1.0, 0.0, easeInOutCubic(t)).clamp(0.0, 1.0);
          final searchBlur = lerpDouble(0, 10, t);

          // gold border
          final borderOpacity = lerpDouble(0.0, 1.0, t).clamp(0.0, 1.0);

          // avatar size
          final avatarSize = lerpDouble(44, 36, t);
          final iconSize = lerpDouble(44, 40, t);

          // title
          final titleScale = lerpDouble(1.0, 0.92, t);

          final surfaceColor = isDark
              ? darkBg
              : Color.lerp(topColor, bottomColor, t) ?? bottomColor;

          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? topColor : topColor).withOpacity(0.98),
              (isDark ? bottomColor : bottomColor).withOpacity(0.98),
            ],
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // Parallax gradient background
              Positioned(
                top: parallaxTop,
                left: 0,
                right: 0,
                height: expandedHeight + 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),

              // Glass layer
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      color: surfaceColor.withOpacity(isDark ? 0.55 : 0.45),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              // Main content
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: lerpDouble(expandedHeight, toolbarMinHeight, t),
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left actions (visually left in RTL is the same row order; Flutter handles RTL)
                              _LeftActions(
                                iconSize: iconSize,
                                onSearch: onSearch,
                                onFilter: onFilter,
                                onHeartPulse: onHeartPulse,
                                progress: t,
                              ),

                              Expanded(
                                child: _CenterTitleBlock(
                                  title: appTitle,
                                  userName: userName,
                                  cityName: cityName,
                                  progress: t,
                                  titleScale: titleScale,
                                ),
                              ),

                              // Right actions
                              _RightActions(
                                iconSize: iconSize,
                                unreadCount: unreadNotificationsCount,
                                notificationsPreview: notificationsPreview,
                                avatarSize: avatarSize,
                                onOpenNotifications: onOpenNotifications,
                                onProfile: onProfile,
                                progress: t,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Gold border
                      Opacity(
                        opacity: borderOpacity,
                        child: Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0x00000000),
                                AppColors.accent,
                                Color(0x00000000)
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Searchbar integrated under header
                      IgnorePointer(
                        ignoring: searchFade <= 0.01,
                        child: Opacity(
                          opacity: searchFade,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: searchBlur,
                                sigmaY: searchBlur,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 6, 16, 10),
                                child: _SearchBarShell(
                                  onSearchTap: onSearch,
                                  onFilterTap: onFilter,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NotificationPreview {
  final String id;
  final String title;
  final String? body;
  final bool isRead;

  NotificationPreview({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
  });
}

class _SearchBarShell extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;

  const _SearchBarShell({
    required this.onSearchTap,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.filter_list_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: onSearchTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ابحث عن شاليه أحلامك...',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.search_rounded,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _LeftActions extends StatelessWidget {
  final double iconSize;
  final double progress;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback? onHeartPulse;

  const _LeftActions({
    required this.iconSize,
    required this.progress,
    required this.onSearch,
    required this.onFilter,
    this.onHeartPulse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _GlowRippleIconButton(
            icon: Icons.search_rounded,
            size: iconSize,
            enabled: true,
            onTap: onSearch,
            onLongPress: () {
              // Placeholder: voice search UX (requires speech_to_text).
              // Keeping this as a no-op for now.
            },
            progress: progress,
          ),
          const SizedBox(width: 10),
          _GlowRippleIconButton(
            icon: Icons.filter_list_rounded,
            size: iconSize,
            enabled: true,
            onTap: onFilter,
            progress: progress,
          ),
          const SizedBox(width: 10),
          _PulseOnActionIconButton(
            icon: Icons.favorite_rounded,
            size: iconSize,
            enabled: true,
            onTap: () => onHeartPulse?.call(),
            progress: progress,
          ),
        ],
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  final double iconSize;
  final double avatarSize;
  final double progress;
  final int unreadCount;
  final List<NotificationPreview> notificationsPreview;
  final VoidCallback onOpenNotifications;
  final VoidCallback onProfile;

  const _RightActions({
    required this.iconSize,
    required this.avatarSize,
    required this.progress,
    required this.unreadCount,
    required this.notificationsPreview,
    required this.onOpenNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _GlassActionIcon(
                  icon: Icons.notifications_outlined,
                  size: iconSize,
                  onTap: () {
                    onOpenNotifications();
                    // Dropdown preview
                    _showNotificationsDropdown(context);
                  },
                  progress: progress,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: _AnimatedUnreadBadge(count: unreadCount),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onProfile,
            child: Hero(
              tag: 'luxury-avatar',
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.09),
                        border: Border.all(
                          color: AppColors.accent
                              .withOpacity(lerpDouble(0.35, 0.18, progress)),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 18),
                    ),
                    // status dot
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27AE60),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                              BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDropdown(BuildContext context) {
    final items = notificationsPreview.take(5).toList();
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(0, 0, 0, 0),
      items: items
          .map(
            (n) => PopupMenuItem<void>(
              enabled: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (!n.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.accent),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (n.body != null)
                          Text(
                            n.body!,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AnimatedUnreadBadge extends StatefulWidget {
  final int count;
  const _AnimatedUnreadBadge({required this.count});

  @override
  State<_AnimatedUnreadBadge> createState() => _AnimatedUnreadBadgeState();
}

class _AnimatedUnreadBadgeState extends State<_AnimatedUnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 0.95 + 0.07 * _c.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFC0392B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0xFFC0392B),
                    blurRadius: 16,
                    spreadRadius: 0.2),
              ],
            ),
            child: Text(
              widget.count > 99 ? '99+' : '${widget.count}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CenterTitleBlock extends StatelessWidget {
  final String title;
  final String userName;
  final String cityName;
  final double progress;
  final double titleScale;

  const _CenterTitleBlock({
    required this.title,
    required this.userName,
    required this.cityName,
    required this.progress,
    required this.titleScale,
  });

  @override
  Widget build(BuildContext context) {
    final greetingOpacity =
        lerpDouble(1.0, 0.0, easeInOutCubic(progress))!.clamp(0.0, 1.0);
    final greetingY = lerpDouble(0, 14, progress);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // App logo + title (gold gradient text)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.accent, size: 28),
              const SizedBox(width: 8),
              Transform.scale(
                scale: titleScale,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFFFFD36E),
                        Color(0xFFC8A84B),
                        Color(0xFFFFF0C2)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(rect);
                  },
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Greeting (with city)
          Opacity(
            opacity: greetingOpacity,
            child: Transform.translate(
              offset: Offset(0, greetingY),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'مرحباً، ${userName.isNotEmpty ? userName : 'ضيف'}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFAFAFA),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location_rounded,
                              size: 14, color: Color(0xFFFAFAFA)),
                          const SizedBox(width: 6),
                          Text(
                            cityName,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassActionIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final double progress;

  const _GlassActionIcon({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bgOpacity = lerpDouble(0.18, 0.10, easeOutCubic(progress));
    final iconOpacity = lerpDouble(1.0, 0.92, easeOutCubic(progress));

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        hoverColor: Colors.white.withOpacity(0.08),
        splashColor: Colors.white.withOpacity(0.14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(bgOpacity),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
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
      ),
    );
  }
}

class _GlowRippleIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double progress;

  const _GlowRippleIconButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final glowOpacity = lerpDouble(0.35, 0.0, progress);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(999),
        splashColor: AppColors.accent.withOpacity(0.18),
        hoverColor: AppColors.accent.withOpacity(0.12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (glowOpacity > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glowOpacity.clamp(0.0, 1.0),
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
                color: Colors.white.withOpacity(
                    lerpDouble(0.18, 0.10, easeOutCubic(progress))),
                border:
                    Border.all(color: Colors.white.withOpacity(0.14), width: 1),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseOnActionIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool enabled;
  final VoidCallback onTap;
  final double progress;

  const _PulseOnActionIconButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.onTap,
    required this.progress,
  });

  @override
  State<_PulseOnActionIconButton> createState() =>
      _PulseOnActionIconButtonState();
}

class _PulseOnActionIconButtonState extends State<_PulseOnActionIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = lerpDouble(0.18, 0.10, easeOutCubic(widget.progress));

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.enabled
            ? () async {
                _c.forward(from: 0);
                HapticFeedback.selectionClick();
                widget.onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(999),
        splashColor: AppColors.accent.withOpacity(0.18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final scale = 1 - 0.05 * widget.progress + 0.05 * _c.value;
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(bgOpacity),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.14), width: 1),
                ),
                child: Center(
                  child: Icon(widget.icon, size: 18, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double easeInOutCubic(double t) {
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
