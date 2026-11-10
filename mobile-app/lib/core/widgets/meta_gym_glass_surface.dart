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
          // Lớp phủ scrim obsidian 65-70% để bảo đảm độ tương phản tối đa cho chữ
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30F1115), // 70% scrim
                  Color(0x9E0F1115), // 62% scrim
                  Color(0xB30F1115), // 70% scrim
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

/// Thẻ Card chuẩn Dark Performance UI cho Meta Gym:
/// - Nền tối ổn định: Color(0xFF181B22) (MetaGymTheme.cardSurface)
/// - Viền 1px chuẩn: Color(0xFF262A34) (MetaGymTheme.cardBorder)
/// - Vệt sáng cạnh trên tinh tế: Color(0x1AFFFFFF)
/// - Không dùng blur đại trà để tối ưu hóa hiệu năng và độ sắc nét chữ
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

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: MetaGymTheme.cardBorder, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: MetaGymTheme.cardSurface,
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: Container(
          padding: padding,
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
                        Color(0x1AFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
