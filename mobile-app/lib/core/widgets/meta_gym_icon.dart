import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Kích thước chuẩn cho bộ icon SVG Meta Gym (khớp `.ico-*`, `.nav-svg` trong `tokens.css`).
abstract final class MetaGymIconSize {
  static const double xs = 18.0;
  static const double sm = 22.0;
  static const double md = 26.0;
  static const double nav = 31.0;
  static const double navAi = 32.0;
  static const double lg = 34.0;
  static const double dock = 34.0;
}

/// Widget hiển thị icon SVG từ thư viện Meta Gym Preview (`assets/svg/`).
///
/// Tự động áp dụng bộ lọc màu thích ứng Light Mode khớp `tokens.css`
/// (`invert(0.92) hue-rotate(180deg) saturate(1.18) contrast(1.06)`) giúp đường nét
/// `#E8EDF5` chuyển sang graphite đậm `#1A1F27` và giữ nguyên điểm nhấn `#FF5E36`,
/// trừ các icon thương hiệu / nền cam giữ màu gốc (`nav_ai_on_primary`, `pay_*`, `auth_*`, `flag_*`).
class MetaGymIcon extends StatelessWidget {
  const MetaGymIcon(
    this.asset, {
    this.size = MetaGymIconSize.md,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.adaptForLightMode,
    this.semanticsLabel,
    this.excludeFromSemantics = false,
    super.key,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Ghi đè màu đơn sắc (dùng cho icon monochrome hoặc trạng thái tùy biến).
  final Color? color;

  /// `null`: tự động thích ứng khi theme là Light (trừ asset giữ nguyên màu gốc).
  final bool? adaptForLightMode;
  final String? semanticsLabel;
  final bool excludeFromSemantics;

  /// Ma trận chuyển đổi màu khớp `filter: invert(0.92) hue-rotate(180deg) saturate(1.18) contrast(1.06)`.
  static const List<double> lightModeMatrix = <double>[
    0.6372,
    -1.3879,
    -0.1398,
    0.0,
    241.03,
    -0.4134,
    -0.3372,
    -0.1398,
    0.0,
    241.03,
    -0.4134,
    -1.3879,
    0.9109,
    0.0,
    241.03,
    0.0,
    0.0,
    0.0,
    1.0,
    0.0,
  ];

  static const ColorFilter lightModeColorFilter = ColorFilter.matrix(
    lightModeMatrix,
  );

  static bool shouldPreserveOriginalColors(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/');
    return normalized.endsWith('/nav_ai_on_primary.svg') ||
        normalized.contains('/backgrounds/') ||
        normalized.contains('/brand/pay_') ||
        normalized.contains('/brand/auth_') ||
        normalized.contains('/brand/flag_') ||
        normalized.contains('/brand/brand_wordmark_') ||
        normalized.contains('/brand/app_icon_mark') ||
        normalized.contains('/brand/brand_mark');
  }

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final shouldAdaptLight =
        color == null &&
        isLight &&
        (adaptForLightMode ?? !shouldPreserveOriginalColors(asset));

    final svg = SvgPicture.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: excludeFromSemantics,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: w, height: h),
    );

    if (shouldAdaptLight) {
      return ColorFiltered(colorFilter: lightModeColorFilter, child: svg);
    }
    return svg;
  }
}
