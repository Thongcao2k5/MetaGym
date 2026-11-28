import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Proportional viewport scaling for tablet devices (`shortestSide >= 600dp`).
///
/// On phones (`shortestSide < 600dp`), this widget is a no-op (`scale == 1.0`).
/// On tablets (Android/iOS), it uniformly scales both width and height of every
/// component, typography, icon, card, button, dialog, and bottom sheet while:
/// - Multiplying `devicePixelRatio` by `scale` so text, SVGs, and imagery stay
///   razor-sharp at native physical resolution.
/// - Dividing `padding`, `viewPadding`, `viewInsets`, and `systemGestureInsets`
///   by `scale` so status bars, gesture bars, taskbars, and soft keyboards map
///   1:1 to physical screen metrics.
/// - Preserving `virtualWidth >= 600dp` on 10–11" tablets (e.g., SM X520
///   `823x1317dp` -> `scale ≈ 1.35` -> `609x974dp` virtual viewport) so tablet
///   gutters and multi-column breakpoints continue to work naturally.
class MetaGymResponsiveScale extends StatelessWidget {
  const MetaGymResponsiveScale({
    super.key,
    required this.child,
    this.enabled,
  });

  final Widget child;

  /// Overrides automatic platform/test detection when provided (useful in tests).
  final bool? enabled;

  /// Minimum `shortestSide` (in logical dp) considered a tablet.
  static const double tabletBreakpoint = 600.0;

  /// Minimum and maximum proportional scale factors applied on tablets.
  static const double minTabletScale = 1.12;
  static const double maxTabletScale = 1.42;

  /// Computes the proportional tablet scale factor for a given logical [size].
  ///
  /// Returns `1.0` for phones (`shortestSide < 600dp`), ramping smoothly from
  /// `1.12` (small 7–8" tablets) through `~1.35` (10.9" tablets such as SM X520)
  /// up to `1.42` (12.4"+ large tablets).
  static double scaleForSize(Size size) {
    final shortestSide = size.shortestSide;
    if (shortestSide < tabletBreakpoint || !shortestSide.isFinite) {
      return 1.0;
    }
    final raw = 1.0 + ((shortestSide - 520.0) / 860.0);
    return raw.clamp(minTabletScale, maxTabletScale);
  }

  static bool _shouldApplyForPlatform() {
    if (MetaGymTheme.isFlutterTestEnvironment) {
      return false;
    }
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    final shouldApply = enabled ?? _shouldApplyForPlatform();
    if (!shouldApply) {
      return child;
    }

    final mq = MediaQuery.of(context);
    final scale = scaleForSize(mq.size);
    if (scale <= 1.0 || mq.size.isEmpty) {
      return child;
    }

    final virtualSize = Size(mq.size.width / scale, mq.size.height / scale);
    final scaledData = mq.copyWith(
      size: virtualSize,
      devicePixelRatio: mq.devicePixelRatio * scale,
      padding: mq.padding / scale,
      viewPadding: mq.viewPadding / scale,
      viewInsets: mq.viewInsets / scale,
      systemGestureInsets: mq.systemGestureInsets / scale,
    );

    return MediaQuery(
      data: scaledData,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: virtualSize.width,
          height: virtualSize.height,
          child: child,
        ),
      ),
    );
  }
}
