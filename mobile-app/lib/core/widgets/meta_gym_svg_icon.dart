import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Renders a Meta Gym custom SVG icon from `assets/svg/` with optional tint,
/// accessible semantics, and a safe fallback when an asset cannot be decoded.
///
/// By default, [color] is `null` so multi-tone Soft-Line Duotone SVGs preserve
/// their designed gradients and `#FF5E36` / `#E8EDF5` accents. Pass [color]
/// only when tinting monochrome or adaptive outline icons.
class MetaGymSvgIcon extends StatelessWidget {
  const MetaGymSvgIcon(
    this.assetPath, {
    super.key,
    this.size = 24,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
    this.fallbackIcon,
  });

  final String assetPath;
  final double size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;
  final String? semanticsLabel;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    final colorFilter = color != null
        ? ColorFilter.mode(color!, BlendMode.srcIn)
        : null;

    return SvgPicture.asset(
      assetPath,
      width: resolvedWidth,
      height: resolvedHeight,
      fit: fit,
      colorFilter: colorFilter,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null || semanticsLabel!.isEmpty,
      placeholderBuilder: (_) => SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: fallbackIcon != null
            ? Icon(
                fallbackIcon,
                size: size,
                color: color ?? MetaGymTheme.paletteOf(context).textSecondary,
              )
            : null,
      ),
      errorBuilder: (_, _, _) => SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: fallbackIcon != null
            ? Icon(
                fallbackIcon,
                size: size,
                color: color ?? MetaGymTheme.paletteOf(context).textSecondary,
              )
            : Icon(
                Icons.broken_image_outlined,
                size: size * 0.8,
                color: MetaGymTheme.paletteOf(context).textSecondary,
              ),
      ),
    );
  }
}
