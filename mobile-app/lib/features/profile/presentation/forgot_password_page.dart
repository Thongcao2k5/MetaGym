import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_glass_scaffold.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _inputController = TextEditingController();
  bool _obscureNewPassword = true;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submitStep(
    PasswordResetController reset,
    Future<bool> Function() action,
  ) async {
    final previousStep = reset.step;
    final succeeded = await action();
    if (succeeded && previousStep != reset.step && mounted) {
      _inputController.clear();
      if (!_obscureNewPassword) {
        setState(() => _obscureNewPassword = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final reset = context.watch<PasswordResetController>();
    final (
      title,
      subtitle,
      label,
      hintText,
      icon,
      stepIndex,
      action,
    ) = switch (reset.step) {
      PasswordResetStep.requestCode => (
        'Quên mật khẩu',
        'Nhập email đã đăng ký để nhận mã xác minh 6 chữ số.',
        'Email',
        'name@example.com',
        Icons.alternate_email_rounded,
        0,
        () => reset.requestCode(_inputController.text),
      ),
      PasswordResetStep.verifyCode => (
        'Xác minh mã',
        'Nhập mã xác minh 6 chữ số vừa được gửi đến email của bạn.',
        'Mã gồm 6 chữ số',
        '123456',
        Icons.mark_email_read_outlined,
        1,
        () => reset.verifyCode(_inputController.text),
      ),
      PasswordResetStep.setPassword => (
        'Đặt mật khẩu mới',
        'Tạo mật khẩu mới có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và chữ số.',
        'Mật khẩu mới',
        'Nhập mật khẩu mới',
        Icons.lock_outline_rounded,
        2,
        () => reset.resetPassword(_inputController.text),
      ),
      PasswordResetStep.completed => (
        'Đã đổi mật khẩu',
        'Tài khoản của bạn đã sẵn sàng với mật khẩu mới.',
        '',
        '',
        Icons.check_circle_outline_rounded,
        3,
        () async {
          context.go(AppRoutes.login);
          return false;
        },
      ),
    };

    final buttonLabel = reset.step == PasswordResetStep.completed
        ? 'Về đăng nhập'
        : reset.isBusy
        ? 'Đang xử lý…'
        : 'Tiếp tục';

    return AuthAtmosphereScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStaggeredEntrance(
            delayMs: 0,
            child: AuthTopHeader(
              onBack: reset.isBusy
                  ? null
                  : () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(AppRoutes.login);
                      }
                    },
            ),
          ),
          const SizedBox(height: 18),
          AuthStaggeredEntrance(
            delayMs: 70,
            child: WarmSmokeGlass(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResetStepProgress(currentStepIndex: stepIndex),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (reset.step != PasswordResetStep.completed)
                    AuthGlassField(
                      fieldKey: const Key('forgot-password-input'),
                      controller: _inputController,
                      label: label,
                      hintText: hintText,
                      icon: icon,
                      obscureText:
                          reset.step == PasswordResetStep.setPassword &&
                          _obscureNewPassword,
                      keyboardType: switch (reset.step) {
                        PasswordResetStep.requestCode =>
                          TextInputType.emailAddress,
                        PasswordResetStep.verifyCode => TextInputType.number,
                        _ => null,
                      },
                      textInputAction: TextInputAction.done,
                      autofillHints: switch (reset.step) {
                        PasswordResetStep.requestCode => const [
                          AutofillHints.email,
                        ],
                        PasswordResetStep.setPassword => const [
                          AutofillHints.newPassword,
                        ],
                        _ => null,
                      },
                      helperText: reset.step == PasswordResetStep.setPassword
                          ? 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số'
                          : null,
                      onSubmitted: reset.isBusy
                          ? null
                          : (_) => _submitStep(reset, action),
                      suffixIcon: reset.step == PasswordResetStep.setPassword
                          ? IconButton(
                              tooltip: _obscureNewPassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () => setState(
                                () =>
                                    _obscureNewPassword = !_obscureNewPassword,
                              ),
                              icon: MetaGymResolvedIcon(_obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined, size: 20, fallbackColor: palette.textWarmMuted),
                            )
                          : null,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.metricPanelBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: palette.success.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MetaGymSvgIcon(MetaGymIcons.stateSuccess, size: 20, fallbackIcon: Icons.check_circle_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mật khẩu đã được cập nhật. Hãy đăng nhập lại.',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reset.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(message: reset.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    isLoading: reset.isBusy,
                    label: buttonLabel,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: reset.isBusy
                        ? null
                        : () => _submitStep(reset, action),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetStepProgress extends StatelessWidget {
  const _ResetStepProgress({required this.currentStepIndex});

  final int currentStepIndex;

  static const _labels = <String>['Email', 'Xác minh', 'Mật khẩu mới'];

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final duration =
        MetaGymTheme.isFlutterTestEnvironment ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.metricPanelBorder, width: 1),
      ),
      child: Row(
        children: List.generate(_labels.length, (index) {
          final isCompleted = index < currentStepIndex;
          final isActive = index == currentStepIndex;
          final barColor = isCompleted
              ? palette.success
              : isActive
              ? MetaGymTheme.brandOrange
              : isLight
              ? palette.borderSolid
              : Colors.white.withValues(alpha: 0.14);
          final labelColor = isCompleted || isActive
              ? palette.textPrimary
              : palette.textSecondary;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _labels.length - 1 ? 0 : 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCompleted) ...[
                        MetaGymSvgIcon(MetaGymIcons.stateSuccess, size: 12, fallbackIcon: Icons.check_circle_rounded),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          _labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 11.5,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
