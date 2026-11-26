import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Architectural background and scrim from the approved Auth HTML preview.
class MetaGymAuthBackground extends StatelessWidget {
  const MetaGymAuthBackground({super.key});

  static const darkAsset = AssetImage('assets/images/bg_app_dark.webp');
  static const lightAsset = AssetImage('assets/images/bg_app_light.webp');

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: isLight ? lightAsset : darkAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: MetaGymTheme.paletteOf(context).canvas),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isLight
                    ? const [
                        Color(0x0AECF1F8),
                        Color(0x05E4EBF4),
                        Color(0x0FDCE4EF),
                      ]
                    : const [
                        Color(0x140F1115),
                        Color(0x0A0F1115),
                        Color(0x240B0D12),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
