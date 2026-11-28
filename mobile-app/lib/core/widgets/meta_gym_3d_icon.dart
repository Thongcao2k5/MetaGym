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

/// Renders a pre-rendered 3D button icon preserving its original studio colors
/// on both Dark and Light Mode surfaces, with graceful Material icon fallback.
class MetaGym3dIcon extends StatelessWidget {
  const MetaGym3dIcon(
    this.assetPath, {
    super.key,
    this.size = 34,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
    this.fallbackIcon,
  });

  final String assetPath;
  final double size;
  final BoxFit fit;
  final String? semanticsLabel;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
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
    );
  }
}
