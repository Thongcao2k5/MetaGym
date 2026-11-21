import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
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
    this.borderColor,
    this.onTap,
    this.featured = false,
    this.solid = false,
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

  /// Stable Level 1 surface for forms, long lists and reading content.
  final bool solid;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final enableBlur =
        !solid && featured && !MetaGymTheme.isFlutterTestEnvironment;

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

    final surface = Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: solid
            ? MetaGymTheme.cardSurface
            : featured
            ? const Color(0xB82D2824)
            : const Color(0xC42B2622),
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ??
              (solid ? MetaGymTheme.cardBorder : const Color(0xA3A79D92)),
          width: solid ? 1 : 1.1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (!solid)
              const Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0x70FFF6EA)),
                ),
              ),
            interactiveContent,
          ],
        ),
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
/// Tập luyện/Lịch dạy, Trợ lý AI, Tin nhắn, Hồ sơ):
/// - Huy hiệu `MG` gradient cam bo góc 13px (`42x42`), viền sáng nhẹ + shadow.
/// - Nhãn eyebrow cam viết hoa (`10.5px`, `w700`).
/// - Tiêu đề chính (`18px`, `w700`, `#F7F9FC`) và mô tả phụ tùy chọn.
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
                      style: const TextStyle(
                        color: MetaGymTheme.brandOrange,
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
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
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
                        style: const TextStyle(
                          color: Color(0xFFB8B0A8),
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
            style: const TextStyle(
              color: MetaGymTheme.darkTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Nút tròn trên thanh tiêu đề giống `_CircleHeaderGlassButton` ở Trang chủ & Hồ sơ:
/// - Vùng chạm Android: `48x48` (hình tròn hiển thị `44x44`)
/// - Nền: `Color(0x9E2F2924)`
/// - Viền: `1px Color(0x95ADA295)`
class MetaGymCircleIconButton extends StatefulWidget {
  const MetaGymCircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
    super.key,
  });

  final IconData icon;
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
    final label = widget.tooltip ?? _iconActionName(widget.icon);
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
                      ? const Color(0x2EFF5A36)
                      : const Color(0x9E2F2924),
                  border: Border.all(
                    color: widget.isActive
                        ? MetaGymTheme.brandOrange
                        : const Color(0x95ADA295),
                    width: widget.isActive ? 1.1 : 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: const Color(0xFFF7F9FC),
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
