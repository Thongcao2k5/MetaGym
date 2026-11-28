import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icon_mapper.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';

/// Renders a Meta Gym custom SVG icon from `assets/svg/` with optional tint,
/// Light Mode color adaptation, accessible semantics, and a safe fallback when
/// an asset cannot be decoded.
///
/// By default, [color] is `null` so multi-tone Soft-Line Duotone SVGs preserve
/// their designed gradients and `#FF5E36` / `#E8EDF5` accents in Dark Mode and
/// automatically adapt light strokes to crisp graphite in Light Mode (matching
/// `tokens.css` and [MetaGymIcon]). Pass [color] only when tinting monochrome
/// or adaptive outline icons, or pass `adaptForLightMode: false` for icons on
/// colored/dark surfaces.
class MetaGymSvgIcon extends StatelessWidget {
  const MetaGymSvgIcon(
    this.assetPath, {
    super.key,
    this.size = 24,
    this.width,
    this.height,
    this.color,
    this.adaptForLightMode,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
    this.fallbackIcon,
  });

  final String assetPath;
  final double size;
  final double? width;
  final double? height;
  final Color? color;
  final bool? adaptForLightMode;
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
    final shouldAdaptLight =
        color == null &&
        Theme.of(context).brightness == Brightness.light &&
        (adaptForLightMode ??
            !MetaGymIcon.shouldPreserveOriginalColors(assetPath));

    final svg = SvgPicture.asset(
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

    if (shouldAdaptLight) {
      return ColorFiltered(
        colorFilter: MetaGymIcon.lightModeColorFilter,
        child: svg,
      );
    }
    return svg;
  }
}

/// Renders a Meta Gym SVG via [resolveMetaGymSvgAsset] when [icon] has a
/// mapped preview asset, falling back to Material [Icon] otherwise.
class MetaGymResolvedIcon extends StatelessWidget {
  const MetaGymResolvedIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.fallbackColor,
    this.adaptForLightMode,
    this.semanticsLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? fallbackColor;
  final bool? adaptForLightMode;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final asset = resolveMetaGymSvgAsset(icon);
    if (asset != null) {
      return MetaGymSvgIcon(
        asset,
        size: size,
        color: color,
        adaptForLightMode: adaptForLightMode,
        semanticsLabel: semanticsLabel,
        fallbackIcon: icon,
      );
    }
    return Icon(
      icon,
      size: size,
      color: fallbackColor ?? color ?? MetaGymTheme.paletteOf(context).textPrimary,
      semanticLabel: semanticsLabel,
    );
  }
}
