import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';

/// Khung toàn màn hình đồng bộ DNA "Futuristic Performance Glass" của Member Home & Coach Home.
class AuthAtmosphereScaffold extends StatelessWidget {
  const AuthAtmosphereScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Nền phòng tập & ambient glow đồng bộ 1:1 với Member Home
          const Positioned.fill(child: MetaGymBackground()),
          // 2. Căn chính giữa màn hình (tự cuộn mượt khi màn hình nhỏ hoặc bật bàn phím)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 20).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu thương hiệu squircle "MG" đồng bộ Member Home, hỗ trợ Hero transition.
class MetaGymBrandBadge extends StatelessWidget {
  const MetaGymBrandBadge({
    this.size = 44,
    this.borderRadius = 14,
    this.fontSize = 15,
    this.enableHero = true,
    super.key,
  });

  final double size;
  final double borderRadius;
  final double fontSize;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0x47FFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45FF5A36),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'MG',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          height: 1.0,
        ),
      ),
    );

    if (!enableHero) return badge;
    return Hero(
      tag: 'meta-gym-auth-brand-badge',
      flightShuttleBuilder: (_, _, _, _, toCtx) =>
          Material(type: MaterialType.transparency, child: toCtx.widget),
      child: badge,
    );
  }
}

/// Thẻ kính khói ấm nằm giữa màn hình đồng bộ 1:1 với `MetaGymHeroGlassCard`.
class WarmSmokeGlass extends StatelessWidget {
  const WarmSmokeGlass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.featured = true,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    final inner = padding != null
        ? Padding(padding: padding!, child: child)
        : child;
    final enableBlur =
        featured &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MetaGymTheme.isFlutterTestEnvironment;

    final surface = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? null : const Color(0xC42B2622),
        gradient: featured
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xCD342D28), Color(0xC829241F)],
              )
            : null,
        borderRadius: radius,
        border: Border.all(color: const Color(0xB7B3A99D), width: 1.2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x75FFF5E9)),
            ),
          ),
          SizedBox(width: double.infinity, child: inner),
        ],
      ),
    );

    if (!enableBlur) {
      return surface;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: surface,
        ),
      ),
    );
  }
}

/// Thanh trên cùng gọn gàng ngay phía trên thẻ: nút Back kính tròn + Huy hiệu MG & META GYM căn giữa.
class AuthTopHeader extends StatelessWidget {
  const AuthTopHeader({
    required this.onBack,
    this.showBackButton = true,
    super.key,
  });

  final VoidCallback? onBack;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          _WarmCircleBackButton(onPressed: onBack)
        else
          const SizedBox(width: 48),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MetaGymBrandBadge(size: 38, borderRadius: 12, fontSize: 13),
                    SizedBox(width: 10),
                    Text(
                      'META GYM',
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _WarmCircleBackButton extends StatelessWidget {
  const _WarmCircleBackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Quay lại',
      child: Tooltip(
        message: 'Quay lại',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x9E2F2924),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x95ADA295),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: onPressed == null
                        ? const Color(0x88F7F9FC)
                        : const Color(0xFFF7F9FC),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh chuyển chế độ Đăng nhập / Đăng ký Member bên trong thẻ kính ấm.
class AuthModeSegmentSwitch extends StatelessWidget {
  const AuthModeSegmentSwitch({
    required this.isLogin,
    required this.onSelectLogin,
    required this.onSelectRegister,
    super.key,
  });

  final bool isLogin;
  final VoidCallback? onSelectLogin;
  final VoidCallback? onSelectRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x80211E1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x9A8C8176), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeTab(
              tabKey: const Key('auth-mode-login'),
              label: 'Đăng nhập',
              selected: isLogin,
              onTap: isLogin ? null : onSelectLogin,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _AuthModeTab(
              tabKey: const Key('auth-mode-register'),
              label: 'Đăng ký Member',
              selected: !isLogin,
              onTap: !isLogin ? null : onSelectRegister,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration =
        MetaGymTheme.isFlutterTestEnvironment ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tabKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF38302A) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xC8C0B4A6) : Colors.transparent,
                width: 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: MetaGymTheme.brandOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFF7F9FC)
                              : const Color(0xFFB7B2AF),
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiệu ứng trượt nhẹ lên + phóng nhẹ + mờ dần theo nhịp khi vào màn hình (tắt trong test & giảm chuyển động).
class AuthStaggeredEntrance extends StatefulWidget {
  const AuthStaggeredEntrance({
    required this.child,
    this.delayMs = 0,
    super.key,
  });

  final Widget child;
  final int delayMs;

  @override
  State<AuthStaggeredEntrance> createState() => _AuthStaggeredEntranceState();
}

class _AuthStaggeredEntranceState extends State<AuthStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;
  Animation<double>? _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (MetaGymTheme.isFlutterTestEnvironment) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    _controller = controller;
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: 0.985, end: 1.0).animate(curved);

    if (widget.delayMs <= 0) {
      controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity!,
      child: SlideTransition(
        position: _slide!,
        child: ScaleTransition(scale: _scale!, child: widget.child),
      ),
    );
  }
}

/// Ô nhập liệu tách lớp gọn bên trong thẻ kính khói ấm.
class AuthGlassField extends StatefulWidget {
  const AuthGlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.fieldKey,
    this.hintText,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.suffixIcon,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthGlassField> createState() => _AuthGlassFieldState();
}

class _AuthGlassFieldState extends State<AuthGlassField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (_focused != focused) {
          setState(() => _focused = focused);
        }
      },
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(
          color: MetaGymTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: MetaGymTheme.brandOrange,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          helperText: widget.helperText,
          errorText: widget.errorText,
          labelStyle: const TextStyle(
            color: Color(0xFFD5CCBF),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(color: Color(0xA6C4BAAE), fontSize: 13.5),
          helperStyle: const TextStyle(
            color: Color(0xFFC4BAAE),
            fontSize: 11.5,
          ),
          helperMaxLines: 2,
          errorMaxLines: 2,
          prefixIcon: Icon(
            widget.icon,
            size: 20,
            color: _focused
                ? MetaGymTheme.brandOrange
                : const Color(0xFFD9CFC1),
          ),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: _focused
              ? const Color(0x9E28231F)
              : const Color(0x80211E1C),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x9A8C8176), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x9A8C8176), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: MetaGymTheme.brandOrange,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: MetaGymTheme.dangerCoral,
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: MetaGymTheme.dangerCoral,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ báo lỗi kính đỏ nổi bật trên nền tối.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, this.bannerKey, super.key});

  final String message;
  final Key? bannerKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MetaGymTheme.dangerCoral.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetaGymTheme.dangerCoral.withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: MetaGymTheme.dangerCoral,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              key: bannerKey,
              style: const TextStyle(
                color: Color(0xFFFFD8DB),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút CTA chính màu cam Meta Gym kèm hiệu ứng nhún scale mượt khi bấm.
class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.isLoading = false,
    this.trailingIcon,
    super.key,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MetaGymTheme.pressDuration;

    return Listener(
      onPointerDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: FilledButton(
            key: widget.buttonKey,
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              disabledBackgroundColor: MetaGymTheme.brandOrange.withValues(
                alpha: 0.48,
              ),
              foregroundColor: MetaGymTheme.onBrandOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: MetaGymTheme.fontFamily,
                fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            child: widget.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: MetaGymTheme.isFlutterTestEnvironment
                              ? 0.65
                              : null,
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : widget.trailingIcon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(widget.trailingIcon, size: 18),
                    ],
                  )
                : Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Nút phụ kính khói ấm chuẩn Member Home kèm hiệu ứng nhún nhẹ khi bấm.
class AuthSecondaryGlassButton extends StatefulWidget {
  const AuthSecondaryGlassButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<AuthSecondaryGlassButton> createState() =>
      _AuthSecondaryGlassButtonState();
}

class _AuthSecondaryGlassButtonState extends State<AuthSecondaryGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MetaGymTheme.pressDuration;

    return Listener(
      onPointerDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            key: widget.buttonKey,
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: MetaGymTheme.textPrimary,
              backgroundColor: const Color(0xC42B2622),
              side: const BorderSide(color: Color(0xA3A79D92), width: 1.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: MetaGymTheme.fontFamily,
                fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
