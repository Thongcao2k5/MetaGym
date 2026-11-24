import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Nền hình ảnh phòng gym kết hợp ánh sáng môi trường (Ambient Depth Lights)
/// và lớp phủ scrim đồng bộ với DESIGN.md và tokens.css (hỗ trợ cả Dark & Light).
class MetaGymBackground extends StatelessWidget {
  const MetaGymBackground({this.useSolidFallback = false, super.key});

  final bool useSolidFallback;

  static const AssetImage bannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);

    if (useSolidFallback) {
      return IgnorePointer(child: ColoredBox(color: palette.canvas));
    }

    if (isLight) {
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.canvas,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF0F7), Color(0xFFE1E8F2), Color(0xFFDCE4EE)],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: bannerAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: MetaGymTheme.darkCanvas),
            ),
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
            // Lớp phủ scrim đồng bộ (72–84% tương phản đọc chữ)
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
      ),
    );
  }
}

/// Thẻ Hero Kính Ấm (Hero Smoked-Glass Card — Level 2 Performance Glass):
/// - Bo góc: 24px (`MetaGymTheme.radiusGlassDock`)
/// - Bọc `RepaintBoundary` quanh `BackdropFilter` và tự tắt blur khi bật Reduced Motion.
class MetaGymHeroGlassCard extends StatelessWidget {
  const MetaGymHeroGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.useSolidFallback = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool useSolidFallback;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final useGlass = !useSolidFallback && !disableAnimations && !isLight;
    final enableBlur = useGlass && !MetaGymTheme.isFlutterTestEnvironment;

    final cardSurface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [Color(0xFFFFFFFF), Color(0xFFF9FBFE)]
              : useGlass
              ? const [
                  MetaGymWarmGlassTokens.heroTop,
                  MetaGymWarmGlassTokens.heroBottom,
                ]
              : const [Color(0xFF23201D), Color(0xFF1B1917)],
        ),
        border: Border.all(
          color: isLight
              ? palette.warmGlassBorder
              : MetaGymWarmGlassTokens.heroBorder,
          width: isLight ? 1.0 : 1.2,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SizedBox(
              height: 1,
              child: ColoredBox(
                color: isLight
                    ? palette.glassHighlight
                    : MetaGymWarmGlassTokens.heroHighlight,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    final Widget wrapped = enableBlur
        ? RepaintBoundary(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MetaGymTheme.performanceGlassBlur,
                  sigmaY: MetaGymTheme.performanceGlassBlur,
                ),
                child: cardSurface,
              ),
            ),
          )
        : cardSurface;

    if (margin != null) {
      return Padding(padding: margin!, child: wrapped);
    }
    return wrapped;
  }
}

/// Thẻ nội dung tiêu chuẩn (mặc định Level 1 Solid Surface `#181B22` + viền 1px `#262A34`
/// theo quy tắc 80/20 của DESIGN.md).
///
/// Truyền `solid: false` (hoặc `featured: true`) khi cần thẻ Kính Ấm có kiểm soát;
/// mọi lớp blur đều bọc `RepaintBoundary` và tôn trọng `disableAnimations`.
class MetaGymGlassCard extends StatelessWidget {
  const MetaGymGlassCard({
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
    this.featured = false,
    this.solid = true,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool featured;

  /// Stable Level 1 surface for forms, long lists and reading content (default `true`).
  final bool solid;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isSolidSurface = solid && !featured;
    final enableBlur =
        !isSolidSurface &&
        featured &&
        !isLight &&
        !disableAnimations &&
        !MetaGymTheme.isFlutterTestEnvironment;

    final Widget innerContent = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final Widget interactiveContent = onTap != null
        ? MetaGymTap(
            onTap: onTap,
            borderRadius: radius,
            splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
            highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
            focusColor: MetaGymTheme.reflectionBlue.withValues(alpha: 0.16),
            child: innerContent,
          )
        : innerContent;

    final Color resolvedBg;
    if (isLight) {
      resolvedBg = palette.surfaceSolid;
    } else if (isSolidSurface) {
      resolvedBg = palette.surfaceSolid;
    } else if (disableAnimations) {
      resolvedBg = const Color(0xFF1F1C1A);
    } else {
      resolvedBg = featured
          ? MetaGymWarmGlassTokens.cardFeaturedFill
          : MetaGymWarmGlassTokens.cardFill;
    }

    final Color resolvedBorder =
        borderColor ??
        (isLight
            ? palette.borderSolid
            : isSolidSurface
            ? palette.borderSolid
            : MetaGymWarmGlassTokens.cardBorder);

    final surface = Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: radius,
        border: Border.all(
          color: resolvedBorder,
          width: isSolidSurface || isLight ? 1 : 1.1,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (!isSolidSurface && !isLight)
              const Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(
                    color: MetaGymWarmGlassTokens.cardHighlight,
                  ),
                ),
              ),
            interactiveContent,
          ],
        ),
      ),
    );

    final Widget wrapped = enableBlur
        ? RepaintBoundary(
            child: ClipRRect(
              borderRadius: radius,
              clipBehavior: clipBehavior,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MetaGymTheme.performanceGlassBlur,
                  sigmaY: MetaGymTheme.performanceGlassBlur,
                ),
                child: surface,
              ),
            ),
          )
        : surface;

    if (margin != null) {
      return Padding(padding: margin!, child: wrapped);
    }
    return wrapped;
  }
}

/// Ô thông tin con bên trong thẻ (đồng bộ Dark & Light mode theo `tokens.css`).
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
    final palette = MetaGymTheme.paletteOf(context);
    final radius = BorderRadius.circular(17);
    return Material(
      color: palette.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.metricPanelBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
        highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
        focusColor: MetaGymTheme.reflectionBlue.withValues(alpha: 0.16),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Header thương hiệu Meta Gym dùng chung cho các tab chính (Trang chủ,
/// Tập luyện/Lịch dạy, Trợ lý AI, Tin nhắn, Hồ sơ).
class MetaGymBrandHeader extends StatelessWidget {
  const MetaGymBrandHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.inlineSubtitle = false,
    this.leading,
    this.actions = const <Widget>[],
    this.actionSpacing = 8,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool inlineSubtitle;
  final Widget? leading;
  final List<Widget> actions;
  final double actionSpacing;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final trimmedSubtitle = subtitle?.trim();
    final hasSubtitle = trimmedSubtitle != null && trimmedSubtitle.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0x40FFFFFF),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4DFF5A36),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'MG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    if (hasSubtitle && inlineSubtitle) ...[
                      const SizedBox(height: 1),
                      Text(
                        trimmedSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isLight
                              ? palette.textSecondary
                              : MetaGymWarmGlassTokens.subtitleMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final action in actions) ...[
                SizedBox(width: actionSpacing),
                action,
              ],
            ],
          ),
        ),
        if (hasSubtitle && !inlineSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            trimmedSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Nút tròn trên thanh tiêu đề (48×48dp hit target, vòng hiển thị 44×44).
/// Hỗ trợ cả `IconData` lẫn `svgAsset` từ [MetaGymIcons].
class MetaGymCircleIconButton extends StatefulWidget {
  const MetaGymCircleIconButton({
    this.icon,
    required this.onTap,
    this.svgAsset,
    this.tooltip,
    this.isActive = false,
    super.key,
  }) : assert(icon != null || svgAsset != null);

  final IconData? icon;
  final String? svgAsset;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool isActive;

  @override
  State<MetaGymCircleIconButton> createState() =>
      _MetaGymCircleIconButtonState();
}

class _MetaGymCircleIconButtonState extends State<MetaGymCircleIconButton> {
  bool _tapLocked = false;
  Timer? _tapGuard;

  void _handleTap() {
    final callback = widget.onTap;
    if (_tapLocked || callback == null) return;
    setState(() => _tapLocked = true);
    _tapGuard?.cancel();
    _tapGuard = Timer(MetaGymTheme.pageTransitionDuration, () {
      if (mounted) setState(() => _tapLocked = false);
    });
    callback();
  }

  @override
  void dispose() {
    _tapGuard?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final label =
        widget.tooltip ??
        (widget.icon != null ? _iconActionName(widget.icon!) : 'Hành động');
    final button = Semantics(
      button: true,
      enabled: widget.onTap != null && !_tapLocked,
      label: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: MetaGymTap(
            onTap: widget.onTap == null || _tapLocked ? null : _handleTap,
            customBorder: const CircleBorder(),
            splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
            highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.10),
            focusColor: MetaGymTheme.reflectionBlue.withValues(alpha: 0.18),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? palette.chipActiveBg
                      : isLight
                      ? palette.surfaceSolid
                      : MetaGymWarmGlassTokens.circleButtonFill,
                  border: Border.all(
                    color: widget.isActive
                        ? MetaGymTheme.brandOrange
                        : isLight
                        ? palette.borderSolid
                        : MetaGymWarmGlassTokens.circleButtonBorder,
                    width: widget.isActive ? 1.1 : 1,
                  ),
                ),
                child: Center(
                  child: widget.svgAsset != null
                      ? MetaGymSvgIcon(
                          widget.svgAsset!,
                          size: 20,
                          fallbackIcon: widget.icon,
                        )
                      : Icon(
                          widget.icon ?? Icons.circle_outlined,
                          size: 20,
                          color: palette.textPrimary,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip == null || widget.tooltip!.isEmpty) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

String _iconActionName(IconData icon) {
  if (icon == Icons.arrow_back_rounded ||
      icon == Icons.arrow_back_ios_new_rounded) {
    return 'Quay lại';
  }
  if (icon == Icons.refresh_rounded) return 'Tải lại';
  if (icon == Icons.notifications_none_rounded) return 'Thông báo';
  if (icon == Icons.chat_bubble_outline_rounded) return 'Tin nhắn';
  if (icon == Icons.close_rounded || icon == Icons.close) return 'Đóng';
  if (icon == Icons.search_rounded) return 'Tìm kiếm';
  if (icon == Icons.edit_outlined || icon == Icons.edit_rounded) {
    return 'Chỉnh sửa';
  }
  return 'Hành động';
}
