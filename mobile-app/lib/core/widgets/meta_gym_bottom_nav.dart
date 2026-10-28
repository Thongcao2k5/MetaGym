import 'package:flutter/material.dart';

/// Floating bottom navigation bar matching the Meta Gym design mockup.
///
/// Features:
/// - 5 tabs in exact order: Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ.
/// - Floating compact dock with dark graphite background and rounded corners.
/// - Protruding circular AI button in the center with coral gradient and glow.
/// - Thin outline icons and legible labels for standard tabs.
/// - Smooth sliding active indicator that glides between tabs.
/// - Respects device reduce motion settings (`MediaQuery.disableAnimations`).
/// - Minimum 44×44 px touch targets for all items and bottom safe area support.
class MetaGymBottomNav extends StatelessWidget {
  const MetaGymBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Nominal height of the floating bar itself (excluding protrusion & bottom margin).
  static const double barHeight = 64.0;

  /// Upward protrusion of the center AI button.
  static const double aiProtrusion = 14.0;

  /// Bottom margin from screen bottom / safe area.
  static const double bottomMargin = 12.0;

  /// Returns total safe bottom inset needed so scrollable content is never obscured.
  static double contentBottomPadding(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return barHeight + aiProtrusion + bottomMargin + bottomInset + 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final animDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
    const animCurve = Curves.easeOutCubic;

    // Alignment X in [-1.0, 1.0] for 5 items:
    // Slot 0: -0.80, Slot 1: -0.40, Slot 2: 0.0, Slot 3: 0.40, Slot 4: 0.80
    final indicatorAlignmentX = -0.8 + (currentIndex.clamp(0, 4) * 0.4);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin + bottomInset),
      child: SizedBox(
        height: barHeight + aiProtrusion,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Floating Dock Bar Background
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF14181F),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: const Color(0xFF282F3B),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Sliding Active Indicator Underneath Tab
                  AnimatedAlign(
                    alignment: Alignment(indicatorAlignmentX, 1.0),
                    duration: animDuration,
                    curve: animCurve,
                    child: FractionallySizedBox(
                      widthFactor: 0.2, // 1/5 of the bar width
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: currentIndex == 2 ? 0.0 : 1.0,
                          duration: animDuration,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            width: 26,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5E3A),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF5E3A).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 5 Tab items row
                  Row(
                    children: [
                      // 0: Trang chủ
                      Expanded(
                        child: _NavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Trang chủ',
                          isSelected: currentIndex == 0,
                          animDuration: animDuration,
                          onTap: () => onTap(0),
                        ),
                      ),
                      // 1: Tập luyện
                      Expanded(
                        child: _NavItem(
                          icon: Icons.fitness_center_outlined,
                          activeIcon: Icons.fitness_center_rounded,
                          label: 'Tập luyện',
                          isSelected: currentIndex == 1,
                          animDuration: animDuration,
                          onTap: () => onTap(1),
                        ),
                      ),
                      // 2: Spacer for the protruding AI button in the center
                      const Expanded(
                        child: SizedBox(
                          height: barHeight,
                          width: double.infinity,
                        ),
                      ),
                      // 3: Tin nhắn
                      Expanded(
                        child: _NavItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          activeIcon: Icons.chat_bubble_rounded,
                          label: 'Tin nhắn',
                          isSelected: currentIndex == 3,
                          animDuration: animDuration,
                          onTap: () => onTap(3),
                        ),
                      ),
                      // 4: Hồ sơ
                      Expanded(
                        child: _NavItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Hồ sơ',
                          isSelected: currentIndex == 4,
                          animDuration: animDuration,
                          onTap: () => onTap(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Center Protruding AI Button
            Positioned(
              top: 0,
              child: _AiCenterButton(
                isSelected: currentIndex == 2,
                animDuration: animDuration,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.animDuration,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Duration animDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFFF5E3A);
    const inactiveColor = Color(0xFF8B94A0);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            child: SizedBox(
              height: MetaGymBottomNav.barHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: animDuration,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      key: ValueKey<bool>(isSelected),
                      size: 23,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: 0.1,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiCenterButton extends StatelessWidget {
  const _AiCenterButton({
    required this.isSelected,
    required this.animDuration,
    required this.onTap,
  });

  final bool isSelected;
  final Duration animDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const buttonSize = 58.0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'AI',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: buttonSize / 2 + 6,
          highlightShape: BoxShape.circle,
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            child: AnimatedContainer(
              duration: animDuration,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF7E58),
                    Color(0xFFFF4820),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.35),
                  width: isSelected ? 2.2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5E3A).withValues(
                      alpha: isSelected ? 0.65 : 0.42,
                    ),
                    blurRadius: isSelected ? 20 : 14,
                    spreadRadius: isSelected ? 2.5 : 1.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  SizedBox(height: 1),
                  Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
