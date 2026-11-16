import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

const AssetImage _authGymBgAsset = AssetImage('assets/images/gym_banner.png');

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
          // 1. Nền phòng tập & ambient glow chuẩn MemberDashboardView
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _authGymBgAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: MetaGymTheme.darkCanvas),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.85, -0.75),
                        radius: 0.9,
                        colors: [Color(0x2E8EB9E5), Colors.transparent],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.85, 0.75),
                        radius: 0.85,
                        colors: [Color(0x24FF5A36), Colors.transparent],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x9E0F1115),
                          Color(0x900F1115),
                          Color(0xB80F1115),
                        ],
                        stops: [0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 2. Căn chính giữa màn hình (tự cuộn mượt khi màn hình nhỏ hoặc bật bàn phím)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 32).clamp(
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

/// Thẻ kính khói ấm nằm giữa màn hình đồng bộ chuẩn Member Home.
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
    final surface = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? const Color(0xCC2D2824) : const Color(0xBD2B2622),
        borderRadius: radius,
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: featured
          ? Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0x70FFF6EA)),
                  ),
                ),
                SizedBox(width: double.infinity, child: inner),
              ],
            )
          : inner,
    );

    if (!featured ||
        MediaQuery.disableAnimationsOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return surface;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: surface,
        ),
      ),
    );
  }
}

/// Thanh trên cùng gọn gàng ngay phía trên thẻ: nút Back kính tròn + Logo META GYM căn giữa.
class AuthTopHeader extends StatelessWidget {
  const AuthTopHeader({required this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WarmCircleBackButton(onPressed: onBack),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF7A4D),
                            MetaGymTheme.brandOrange,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.34,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'META GYM',
                      style: TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _WarmCircleBackButton extends StatelessWidget {
  const _WarmCircleBackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final useBlur = !MetaGymTheme.isFlutterTestEnvironment;
    final button = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xBA2B2622),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Quay lại',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: MetaGymTheme.textPrimary,
        ),
        padding: EdgeInsets.zero,
      ),
    );
    if (!useBlur) return button;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: button,
      ),
    );
  }
}

/// Hiệu ứng trượt nhẹ lên + mờ dần theo nhịp khi vào màn hình (tắt delay trong test).
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (MetaGymTheme.isFlutterTestEnvironment) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    _controller = controller;
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);

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
    if (controller == null) return widget.child;
    return FadeTransition(
      opacity: _opacity!,
      child: SlideTransition(position: _slide!, child: widget.child),
    );
  }
}

/// Ô nhập liệu tách lớp gọn bên trong thẻ kính khói ấm.
class AuthGlassField extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onChanged: onChanged,
      style: const TextStyle(
        color: MetaGymTheme.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: MetaGymTheme.brandOrange,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        labelStyle: const TextStyle(
          color: Color(0xFFD5CCBF),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0x88C4BAAE),
          fontSize: 13.5,
        ),
        helperStyle: const TextStyle(
          color: Color(0xFFC4BAAE),
          fontSize: 11.5,
        ),
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: const Color(0xFFD9CFC1),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0x80181513),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x66A79D92), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x66A79D92), width: 1.0),
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
          borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: MetaGymTheme.dangerCoral,
            width: 1.5,
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
    super.key,
  });

  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: MetaGymTheme.pressDuration,
        curve: Curves.easeOutCubic,
        child: Container(
          height: 52,
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
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            child: widget.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(widget.label),
                    ],
                  )
                : Text(widget.label),
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
    return Listener(
      onPointerDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: MetaGymTheme.pressDuration,
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: 50,
          child: OutlinedButton(
            key: widget.buttonKey,
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: MetaGymTheme.textPrimary,
              backgroundColor: const Color(0xBA2B2622),
              side: const BorderSide(color: Color(0xA3A79D92), width: 1.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
