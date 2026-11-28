import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Typed registry for Meta Gym 3D transparent WebP button icons.
abstract final class MetaGym3dIcons {
  static const String _root = 'assets/images/icons_3d';

  static const String actionSchedule = '$_root/action_schedule_3d.webp';
  static const String actionCurriculum = '$_root/action_curriculum_3d.webp';
  static const String actionNutrition = '$_root/action_nutrition_3d.webp';
  static const String actionCoach = '$_root/action_coach_3d.webp';
  static const String equipMachine = '$_root/equip_machine_3d.webp';
  static const String checkinBadge = '$_root/checkin_badge_3d.webp';
  static const String bodyWeightScale = '$_root/body_weight_scale_3d.webp';
  static const String coachSearch = '$_root/coach_search_3d.webp';
}

/// Renders a pre-rendered 3D button icon with a restrained radial backlight
/// halo so dark obsidian silhouettes stand out cleanly on both Dark and Light
/// Mode surfaces, with graceful Material icon fallback.
class MetaGym3dIcon extends StatelessWidget {
  const MetaGym3dIcon(
    this.assetPath, {
    super.key,
    this.size = 34,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
    this.fallbackIcon,
    this.showBacklight = true,
    this.backlightColor,
  });

  final String assetPath;
  final double size;
  final BoxFit fit;
  final String? semanticsLabel;
  final IconData? fallbackIcon;
  final bool showBacklight;
  final Color? backlightColor;

  Color _resolvedAccent() {
    if (backlightColor != null) return backlightColor!;
    if (assetPath == MetaGym3dIcons.actionNutrition) {
      return MetaGymTheme.success;
    }
    return MetaGymTheme.brandOrange;
  }

  List<Color> _haloColors(Color accent, bool isLight) {
    final isBrandOrange = accent.toARGB32() == MetaGymTheme.brandOrange.toARGB32();
    if (isLight) {
      if (isBrandOrange) {
        return const [
          Color(0x57FF5E36),
          Color(0x38FF6E44),
          Color(0x14FF8258),
          Color(0x00FF5E36),
        ];
      }
      return [
        accent.withValues(alpha: 0.32),
        accent.withValues(alpha: 0.19),
        accent.withValues(alpha: 0.07),
        accent.withValues(alpha: 0.0),
      ];
    }

    if (isBrandOrange) {
      return const [
        Color(0x70FF7648),
        Color(0x3DFF5E36),
        Color(0x1AA9C7E8),
        Color(0x00FF5E36),
      ];
    }
    return [
      accent.withValues(alpha: 0.40),
      accent.withValues(alpha: 0.20),
      MetaGymTheme.reflectionBlue.withValues(alpha: 0.10),
      accent.withValues(alpha: 0.0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final accent = _resolvedAccent();
    final haloSize = size * 1.8;
    final b = isLight ? 1.06 : 1.12;

    final image = ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        b, 0, 0, 0, 0,
        0, b, 0, 0, 0,
        0, 0, b, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticsLabel,
        excludeFromSemantics: semanticsLabel == null || semanticsLabel!.isEmpty,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: fallbackIcon != null
                ? Icon(
                    fallbackIcon,
                    size: size * 0.72,
                    color: MetaGymTheme.paletteOf(context).textSecondary,
                  )
                : Icon(
                    Icons.broken_image_outlined,
                    size: size * 0.68,
                    color: MetaGymTheme.paletteOf(context).textSecondary,
                  ),
          ),
        ),
      ),
    );

    if (!showBacklight) return image;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            width: haloSize,
            height: haloSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: _haloColors(accent, isLight),
                    stops: isLight
                        ? const [0.0, 0.48, 0.68, 0.88]
                        : const [0.0, 0.44, 0.68, 0.88],
                  ),
                ),
              ),
            ),
          ),
          image,
        ],
      ),
    );
  }
}
