import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Level 2 Performance Glass bottom navigation bar for Meta Gym Member & Coach.
///
/// Order of items: Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ.
/// Follows DESIGN.md §3.2 & §5.3:
/// - Background: `rgba(18, 23, 30, 0.78)` (`MetaGymTheme.performanceGlass`)
/// - Backdrop blur: `12px` clipped inside `24px` radius (`RepaintBoundary` isolated)
/// - Border: `1px` `rgba(212, 228, 255, 0.18)` + cool top-edge specular highlight
/// - Active tab: `#FF5A36` (`MetaGymTheme.brandOrange`), inactive: `#B8C2D0`
class MetaGymBottomNav extends StatelessWidget {
  const MetaGymBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.useSolidFallback = false,
    this.warmGlass = false,
    this.secondTabLabel = 'Tập luyện',
    this.secondTabIcon = Icons.fitness_center_outlined,
  }) : assert(currentIndex >= 0 && currentIndex < 5);

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Optional solid surface fallback for low-power / frame-drop environments.
  final bool useSolidFallback;
  final bool warmGlass;
  final String secondTabLabel;
  final IconData secondTabIcon;

  static const double _barHeight = 68.0;
  static const double _aiProtrusion = 14.0;
  static const double _horizontalMargin = 16.0;
  static const double _bottomMargin = 12.0;

  /// Safe bottom padding so scrollable content is never obscured by the floating dock.
  static double contentBottomPadding(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return _barHeight + _aiProtrusion + _bottomMargin + safeBottom + 16.0;
  }

  Alignment _indicatorAlignmentForIndex(int index) {
    final x = -1.0 + (index * 0.5);
    return Alignment(x, -1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final disableAnimations = mediaQuery.disableAnimations;
    final safeBottom = mediaQuery.padding.bottom;
    final duration = disableAnimations
        ? Duration.zero
        : MetaGymTheme.localStateDuration;
    final useGlassSurface = !useSolidFallback && !disableAnimations;
    final enableBlur =
        useGlassSurface && !MetaGymTheme.isFlutterTestEnvironment;

    const capsuleRadius = BorderRadius.all(Radius.circular(34.0));

    final pillDecoration = BoxDecoration(
      color: warmGlass
          ? (useGlassSurface
                ? const Color(0xBF302923)
                : const Color(0xFF292420))
          : (useGlassSurface
                ? const Color(0xDE181B22)
                : MetaGymTheme.darkSurface),
      borderRadius: capsuleRadius,
      border: Border.all(
        color: warmGlass ? const Color(0xA3A79D92) : MetaGymTheme.cardBorder,
        width: 1.0,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000), // rgba(0, 0, 0, 0.20)
          blurRadius: 24,
          offset: Offset(0, -4),
        ),
      ],
    );

    final pillContent = Container(
      height: _barHeight,
      decoration: pillDecoration,
      child: Stack(
        children: [
          // Cool specular top-edge highlight (DESIGN.md §3.2)
          Positioned(
            top: 0,
            left: 28,
            right: 28,
            child: IgnorePointer(
              child: SizedBox(
                height: 1,
                child: ColoredBox(
                  color: warmGlass
                      ? const Color(0x70FFF5E9)
                      : const Color(0x33FFFFFF),
                ),
              ),
            ),
          ),
          // Sliding active indicator bar
          AnimatedAlign(
            alignment: _indicatorAlignmentForIndex(currentIndex),
            duration: duration,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / 5,
              child: Center(
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  width: currentIndex == 2 ? 0.0 : 28.0,
                  height: 3.0,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(3.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                        blurRadius: 6.0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 5 navigation items
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _NavTabItem(
                  label: 'Trang chủ',
                  icon: Icons.home_outlined,
                  selected: currentIndex == 0,
                  duration: duration,
                  onTap: () => onTap(0),
                ),
              ),
              Expanded(
                child: _NavTabItem(
                  label: secondTabLabel,
                  icon: secondTabIcon,
                  selected: currentIndex == 1,
                  duration: duration,
                  onTap: () => onTap(1),
                ),
              ),
              const Expanded(child: SizedBox()),
              Expanded(
                child: _NavTabItem(
                  label: 'Tin nhắn',
                  icon: Icons.chat_bubble_outline_rounded,
                  selected: currentIndex == 3,
                  duration: duration,
                  onTap: () => onTap(3),
                ),
              ),
              Expanded(
                child: _NavTabItem(
                  label: 'Hồ sơ',
                  icon: Icons.person_outline_rounded,
                  selected: currentIndex == 4,
                  duration: duration,
                  onTap: () => onTap(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          0,
          _horizontalMargin,
          _bottomMargin + safeBottom,
        ),
        child: SizedBox(
          height: _barHeight + _aiProtrusion,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Clipped Level 2 Backdrop Blur container (rounded-full capsule)
              ClipRRect(
                borderRadius: capsuleRadius,
                child: enableBlur
                    ? BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: MetaGymTheme.performanceGlassBlur,
                          sigmaY: MetaGymTheme.performanceGlassBlur,
                        ),
                        child: pillContent,
                      )
                    : pillContent,
              ),
              // Center protruding AI button
              Positioned(
                top: 0,
                bottom: 0,
                child: _AiCenterButton(
                  label: 'AI',
                  selected: currentIndex == 2,
                  warmGlass: warmGlass,
                  duration: duration,
                  onTap: () => onTap(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MetaGymTheme.brandOrange
        : MetaGymTheme.darkTextSecondary;
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return MetaGymTheme.reflectionBlue.withValues(alpha: 0.18);
      }
      if (states.contains(WidgetState.pressed)) {
        return MetaGymTheme.brandOrange.withValues(alpha: 0.18);
      }
      return Colors.transparent;
    });

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.12),
          highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.06),
          overlayColor: overlayColor,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1.0,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: Icon(icon, size: 22.0, color: color),
                ),
                const SizedBox(height: 4.0),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: MetaGymTheme.fontFamily,
                    color: color,
                    fontSize: 11.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                    height: 1.15,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiCenterButton extends StatelessWidget {
  const _AiCenterButton({
    required this.label,
    required this.selected,
    required this.warmGlass,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool warmGlass;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: MetaGymTap(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withValues(alpha: 0.26),
          highlightColor: Colors.white.withValues(alpha: 0.16),
          focusColor: MetaGymTheme.reflectionBlue.withValues(alpha: 0.2),
          child: SizedBox(
            width: 68,
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.04 : 1.0,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 52.0,
                    height: 52.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected || warmGlass
                          ? MetaGymTheme.brandOrange
                          : MetaGymTheme.darkSurfaceRaised,
                      border: Border.all(
                        color: selected || warmGlass
                            ? MetaGymTheme.brandOrange
                            : MetaGymTheme.cardBorder,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: selected ? 0.2 : (warmGlass ? 0.12 : 0.0),
                          ),
                          blurRadius: selected ? 10.0 : 6.0,
                          spreadRadius: selected ? 0.5 : 0.0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: selected || warmGlass
                            ? Colors.white
                            : MetaGymTheme.brandOrange,
                        size: 24.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: MetaGymTheme.fontFamily,
                    color: selected
                        ? MetaGymTheme.brandOrange
                        : MetaGymTheme.darkTextSecondary,
                    fontSize: 11.0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                    height: 1.15,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
