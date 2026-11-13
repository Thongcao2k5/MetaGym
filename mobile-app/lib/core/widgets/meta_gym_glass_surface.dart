import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Nền hình ảnh phòng gym kết hợp ánh sáng môi trường (Ambient Depth Lights)
/// và lớp phủ scrim obsidian mờ nhẹ đồng bộ toàn ứng dụng Meta Gym.
class MetaGymBackground extends StatelessWidget {
  const MetaGymBackground({super.key});

  static const AssetImage bannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(image: bannerAsset, fit: BoxFit.cover),
          // Ambient glow: Cool blue ở góc trên bên phải
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.85, -0.75),
                radius: 0.9,
                colors: [Color(0x2E8EB9E5), Colors.transparent],
              ),
            ),
          ),
          // Ambient glow: Warm orange ở góc dưới bên trái
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, 0.75),
                radius: 0.8,
                colors: [Color(0x24FF5A36), Colors.transparent],
              ),
            ),
          ),
          // Lớp phủ scrim obsidian để đảm bảo độ tương phản cho văn bản
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x4D080A0D),
                  Color(0x26080A0D),
                  Color(0x4D080A0D),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ Kính Kỹ Thuật Số (Liquid Frosted Glass Card) chuẩn Design System Meta Gym:
/// - Nền kính hun khói (Smoked Glass): 26% – 35% độ mờ quang học
/// - Viền phản quang vi mô: Border 1px Color(0x38D4E4FF)
/// - Vệt sáng specular highlight cạnh trên: Color(0x59FFFFFF)
/// - Đổ bóng nhẹ: blur 14px
/// - Mờ quang học: sigma 5.0 (tắt trong môi trường test để tối ưu hiệu năng)
class MetaGymGlassCard extends StatelessWidget {
  const MetaGymGlassCard({
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final enableBlur = !MetaGymTheme.isFlutterTestEnvironment;

    final cardBody = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.8, -0.6),
          end: Alignment(0.8, 0.6),
          colors: [
            Color(0x59162232), // rgba(22, 34, 50, 0.35)
            Color(0x420E1520), // rgba(14, 21, 32, 0.26)
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: const Color(0x38D4E4FF), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            height: 1,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0x59FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );

    if (!enableBlur) {
      return ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: cardBody,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: cardBody,
      ),
    );
  }
}
