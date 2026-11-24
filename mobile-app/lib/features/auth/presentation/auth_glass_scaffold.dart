import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

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
    final routeAnimation = ModalRoute.of(context)?.animation;
    final canBlur =
        featured &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MetaGymTheme.isFlutterTestEnvironment;

    final surface = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? null : MetaGymWarmGlassTokens.cardFill,
        gradient: featured
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MetaGymWarmGlassTokens.heroTop,
                  MetaGymWarmGlassTokens.heroBottom,
                ],
              )
            : null,
        borderRadius: radius,
        border: Border.all(
          color: MetaGymWarmGlassTokens.heroBorder,
          width: 1.2,
        ),
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
              child: ColoredBox(color: MetaGymWarmGlassTokens.heroHighlight),
            ),
          ),
          SizedBox(width: double.infinity, child: inner),
        ],
      ),
    );

    if (!canBlur) {
      return surface;
    }

    // DESIGN.md §2 & §9: không animate BackdropFilter trong lúc chuyển trang
    // để giữ 120fps; chỉ bật blur khi route đã dừng ổn định (completed).
    if (routeAnimation != null && !routeAnimation.isCompleted) {
      return AnimatedBuilder(
        animation: routeAnimation,
        child: surface,
        builder: (context, child) {
          if (!routeAnimation.isCompleted) {
            return RepaintBoundary(child: child!);
          }
          return RepaintBoundary(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MetaGymTheme.performanceGlassBlur,
                  sigmaY: MetaGymTheme.performanceGlassBlur,
                ),
                child: child,
              ),
            ),
          );
        },
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: MetaGymTheme.performanceGlassBlur,
            sigmaY: MetaGymTheme.performanceGlassBlur,
          ),
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
    final duration =
        MetaGymTheme.isFlutterTestEnvironment ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Row(
      children: [
        IgnorePointer(
          ignoring: !showBackButton,
          child: AnimatedOpacity(
            opacity: showBackButton ? 1.0 : 0.0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: _WarmCircleBackButton(
              onPressed: showBackButton ? onBack : null,
            ),
          ),
        ),
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
                    MetaGymBrandBadge(
                      size: 38,
                      borderRadius: 12,
                      fontSize: 13,
                      enableHero: false,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'META GYM',
                          style: TextStyle(
                            color: MetaGymTheme.brandOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Performance Studio',
                          style: TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                        ),
                      ],
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

/// Phạm vi nhận biết khi `LoginPage` / `RegisterPage` đang nằm trong `AuthModeShell`
/// của `ShellRoute` để dùng chung 1 khung kính `WarmSmokeGlass` có thể trượt mở rộng mượt mà.
class AuthShellScope extends InheritedWidget {
  const AuthShellScope({required super.child, super.key});

  static bool isEmbedded(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthShellScope>() != null;

  @override
  bool updateShouldNotify(covariant AuthShellScope oldWidget) => false;
}

/// Khung chuyển đổi mượt giữa Đăng nhập ↔ Đăng ký:
/// giữ cố định nền, header và thẻ `WarmSmokeGlass`, đồng thời cho pill tab trượt ngang
/// (`AnimatedAlign`), thẻ kính tự mở rộng/thu gọn chiều cao mượt mà (`AnimatedSize`)
/// và nội dung form trượt nhẹ kết hợp fade (`AnimatedSwitcher`).
class AuthModeShell extends StatelessWidget {
  const AuthModeShell({
    required this.isLogin,
    required this.onSelectLogin,
    required this.onSelectRegister,
    required this.child,
    this.onBack,
    super.key,
  });

  final bool isLogin;
  final VoidCallback? onSelectLogin;
  final VoidCallback? onSelectRegister;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MetaGymTheme.isFlutterTestEnvironment ||
        MediaQuery.disableAnimationsOf(context);
    final sizeDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final switchDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final slideSign = isLogin ? -1.0 : 1.0;

    final switchedContent = AnimatedSwitcher(
      duration: switchDuration,
      reverseDuration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (widget, animation) {
        if (reducedMotion) return widget;
        final isIncoming = widget.key == ValueKey<bool>(isLogin);
        final beginOffset = Offset(
          isIncoming ? 0.08 * slideSign : -0.06 * slideSign,
          0,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(animation),
            child: widget,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<bool>(isLogin),
        child: AuthShellScope(child: child),
      ),
    );

    return AuthAtmosphereScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTopHeader(onBack: onBack, showBackButton: !isLogin),
          const SizedBox(height: 12),
          WarmSmokeGlass(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthModeSegmentSwitch(
                  isLogin: isLogin,
                  onSelectLogin: onSelectLogin,
                  onSelectRegister: onSelectRegister,
                ),
                const SizedBox(height: 14),
                if (reducedMotion)
                  switchedContent
                else
                  AnimatedSize(
                    duration: sizeDuration,
                    curve: Curves.easeOutQuart,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: switchedContent,
                  ),
              ],
            ),
          ),
          const AuthVersionFooter(),
        ],
      ),
    );
  }
}

/// Thanh chuyển chế độ Đăng nhập / Đăng ký Member với pill trượt ngang mượt mà.
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
    final duration =
        MetaGymTheme.isFlutterTestEnvironment ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MetaGymWarmGlassTokens.metricPanelFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetaGymWarmGlassTokens.metricPanelBorder,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            duration: duration,
            curve: Curves.easeOutQuart,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                margin: EdgeInsets.only(
                  right: isLogin ? 2 : 0,
                  left: isLogin ? 0 : 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF38302A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xC8C0B4A6),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Row(
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
        : const Duration(milliseconds: 220);

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
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.0 : 0.0,
                    duration: duration,
                    curve: Curves.easeOutBack,
                    child: selected
                        ? Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: MetaGymTheme.brandOrange,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontFamily: MetaGymTheme.fontFamily,
                        color: selected
                            ? MetaGymTheme.textPrimary
                            : MetaGymWarmGlassTokens.subtitleMuted,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        height: 1.1,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper nhẹ giữ tương thích API; chuyển cảnh đã được xử lý đồng nhất tại
/// `_smoothAuthTransitionPage` để tránh hiệu ứng chồng lấn (double-stutter).
class AuthStaggeredEntrance extends StatelessWidget {
  const AuthStaggeredEntrance({
    required this.child,
    this.delayMs = 0,
    super.key,
  });

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) => child;
}

/// Ô nhập liệu tách lớp gọn bên trong thẻ kính khói ấm.
class AuthGlassField extends StatefulWidget {
  const AuthGlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.svgIcon,
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
  final String? svgIcon;
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
          prefixIcon: widget.svgIcon != null
              ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: MetaGymSvgIcon(
                    widget.svgIcon!,
                    size: 20,
                    fallbackIcon: widget.icon,
                  ),
                )
              : Icon(
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

/// Chân trang phiên bản đồng bộ giữa Splash, Đăng nhập và Đăng ký.
class AuthVersionFooter extends StatelessWidget {
  const AuthVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const MetaGymSvgIcon(
            MetaGymIcons.settingVersion,
            size: 14,
            fallbackIcon: Icons.info_outline_rounded,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Meta Gym v1.0.0 · Build 2026.11',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
