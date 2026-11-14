import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Nền hình ảnh phòng gym kết hợp ánh sáng môi trường (Ambient Depth Lights)
/// và lớp phủ scrim đồng bộ chính xác với Trang chủ Hội viên & Hồ sơ.
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
          // Lớp phủ scrim đồng bộ với member_dashboard_view.dart & profile_page.dart
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x9E0F1115),
                  Color(0x900F1115),
                  Color(0xAA0F1115),
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

/// Thẻ Hero Kính Ấm (Hero Smoked-Glass Card) giống thẻ GÓI TẬP & COACH ở Trang chủ:
/// - Bo góc: 24px
/// - Nền gradient: `[0xCD342D28, 0xC829241F]`
/// - Viền: `1.2px Color(0xB7B3A99D)`
/// - Vạch phản quang cạnh trên: `Color(0x75FFF5E9)`
/// - Blur: `sigma 10`
class MetaGymHeroGlassCard extends StatelessWidget {
  const MetaGymHeroGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final enableBlur = !MetaGymTheme.isFlutterTestEnvironment;

    final cardSurface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCD342D28), Color(0xC829241F)],
        ),
        border: Border.all(color: const Color(0xB7B3A99D), width: 1.2),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x75FFF5E9)),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    final Widget wrapped = enableBlur
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: cardSurface,
            ),
          )
        : cardSurface;

    if (margin != null) {
      return Padding(padding: margin!, child: wrapped);
    }
    return wrapped;
  }
}

/// Thẻ nội dung Kính Ấm (Liquid Glass Card) đồng bộ chính xác với
/// `_buildLiquidGlassCard` ở Trang chủ Hội viên & Hồ sơ:
/// - Bo góc: `MetaGymTheme.radiusCard` (20px)
/// - Nền: `featured ? Color(0xB82D2824) : Color(0xC42B2622)`
/// - Viền: `1.1px Color(0xA3A79D92)`
/// - Vạch phản quang cạnh trên: `Color(0x70FFF6EA)`
class MetaGymGlassCard extends StatelessWidget {
  const MetaGymGlassCard({
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.featured = false,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool featured;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final enableBlur = featured && !MetaGymTheme.isFlutterTestEnvironment;

    final Widget innerContent = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final surface = Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: featured ? const Color(0xB82D2824) : const Color(0xC42B2622),
        borderRadius: radius,
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 18,
            right: 18,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x70FFF6EA)),
            ),
          ),
          innerContent,
        ],
      ),
    );

    final Widget wrapped = enableBlur
        ? ClipRRect(
            borderRadius: radius,
            clipBehavior: clipBehavior,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: surface,
            ),
          )
        : surface;

    if (margin != null) {
      return Padding(padding: margin!, child: wrapped);
    }
    return wrapped;
  }
}

/// Ô thông tin con bên trong thẻ (`_buildMembershipMetricPanel` ở Trang chủ & Hồ sơ):
/// - Nền: `Color(0x80211E1C)`
/// - Bo góc: `17px`
/// - Viền: `1px Color(0x9A8C8176)`
class MetaGymMetricPanel extends StatelessWidget {
  const MetaGymMetricPanel({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(17);
    return Material(
      color: const Color(0x80211E1C),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: Color(0x9A8C8176), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Nút tròn trên thanh tiêu đề giống `_CircleHeaderGlassButton` ở Trang chủ & Hồ sơ:
/// - Kích thước: `44x44`
/// - Nền: `Color(0x9E2F2924)`
/// - Viền: `1px Color(0x95ADA295)`
class MetaGymCircleIconButton extends StatelessWidget {
  const MetaGymCircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x9E2F2924),
              border: Border.all(color: const Color(0x95ADA295), width: 1),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFF7F9FC)),
          ),
        ),
      ),
    );
  }
}
