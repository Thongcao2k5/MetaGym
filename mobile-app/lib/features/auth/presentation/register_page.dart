import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_glass_scaffold.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = true;
  String _passwordInput = '';

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = _openTerms;
    _privacyTap = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openTerms() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(AppRoutes.terms);
    }
  }

  void _openPrivacy() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(AppRoutes.privacyPolicy);
    }
  }

  void _submit(AuthController auth) {
    if (!_acceptedTerms) return;
    auth.register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    void clearErrorsOnEdit(String _) {
      if (auth.fieldErrors.isNotEmpty || auth.errorMessage != null) {
        auth.clearErrors();
      }
    }

    final formBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tạo tài khoản hội viên',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Khởi tạo hồ sơ cá nhân để đặt lịch PT 1:1 và theo dõi chỉ số cơ thể.',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: MetaGymWarmGlassTokens.subtitleMuted,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        AuthGlassField(
          fieldKey: const Key('register-name'),
          controller: _nameController,
          label: 'Họ và tên',
          hintText: 'Nguyễn Minh Quân',
          icon: Icons.person_outline_rounded,
          svgIcon: MetaGymIcons.settingPersonalInfo,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          errorText: auth.fieldErrors['fullName'],
          onChanged: clearErrorsOnEdit,
        ),
        const SizedBox(height: 10),
        AuthGlassField(
          fieldKey: const Key('register-email'),
          controller: _emailController,
          label: 'Email',
          hintText: 'minhquan@metagym.vn',
          icon: Icons.alternate_email_rounded,
          svgIcon: MetaGymIcons.commEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          errorText: auth.fieldErrors['email'],
          onChanged: clearErrorsOnEdit,
        ),
        const SizedBox(height: 10),
        AuthGlassField(
          fieldKey: const Key('register-password'),
          controller: _passwordController,
          label: 'Mật khẩu',
          hintText: 'Tạo mật khẩu bảo mật',
          icon: Icons.lock_outline_rounded,
          svgIcon: MetaGymIcons.settingPasswordKey,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: auth.isSubmitting ? null : (_) => _submit(auth),
          autofillHints: const [AutofillHints.newPassword],
          errorText: auth.fieldErrors['password'],
          onChanged: (value) {
            clearErrorsOnEdit(value);
            setState(() => _passwordInput = value);
          },
          suffixIcon: IconButton(
            key: const Key('register-toggle-password'),
            tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: MetaGymSvgIcon(
              _obscurePassword
                  ? MetaGymIcons.authShowPassword
                  : MetaGymIcons.authHidePassword,
              size: 20,
              fallbackIcon: _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PasswordStrengthMeter(password: _passwordInput),
        const SizedBox(height: 10),
        InkWell(
          key: const Key('register-accept-terms'),
          borderRadius: BorderRadius.circular(10),
          onTap: auth.isSubmitting
              ? null
              : () => setState(() => _acceptedTerms = !_acceptedTerms),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _acceptedTerms
                          ? MetaGymTheme.brandOrange
                          : const Color(0x88181513),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _acceptedTerms
                            ? MetaGymTheme.brandOrange
                            : MetaGymWarmGlassTokens.cardBorder,
                      ),
                    ),
                    child: _acceptedTerms
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                        children: [
                          const TextSpan(text: 'Tôi đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản sử dụng',
                            recognizer: _termsTap,
                            style: const TextStyle(
                              color: MetaGymTheme.reflectionBlue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' và '),
                          TextSpan(
                            text: 'Chính sách bảo mật',
                            recognizer: _privacyTap,
                            style: const TextStyle(
                              color: MetaGymTheme.reflectionBlue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(
                            text: ' dữ liệu sức khỏe của Meta Gym.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (auth.errorMessage != null) ...[
          const SizedBox(height: 10),
          AuthErrorBanner(
            bannerKey: const Key('auth-error'),
            message: auth.errorMessage!,
          ),
        ],
        const SizedBox(height: 12),
        AuthPrimaryButton(
          buttonKey: const Key('register-submit'),
          isLoading: auth.isSubmitting,
          label: auth.isSubmitting ? 'Đang đăng ký…' : 'Đăng ký',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: auth.isSubmitting || !_acceptedTerms
              ? null
              : () => _submit(auth),
        ),
      ],
    );

    if (AuthShellScope.isEmbedded(context)) {
      return formBody;
    }

    return AuthModeShell(
      isLogin: false,
      onBack: auth.isSubmitting
          ? null
          : () {
              auth.clearErrors();
              context.go(AppRoutes.login);
            },
      onSelectLogin: auth.isSubmitting
          ? null
          : () {
              auth.clearErrors();
              context.go(AppRoutes.login);
            },
      onSelectRegister: null,
      child: formBody,
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasUpper = RegExp('[A-Z]').hasMatch(password);
    final hasLower = RegExp('[a-z]').hasMatch(password);
    final hasDigit = RegExp('[0-9]').hasMatch(password);

    final score = [
      hasLength,
      hasUpper,
      hasLower,
      hasDigit,
    ].where((met) => met).length;

    final Color barColor = switch (score) {
      4 => MetaGymTheme.success,
      3 => MetaGymTheme.warning,
      >= 1 => MetaGymTheme.brandOrange,
      _ => Colors.white.withValues(alpha: 0.14),
    };

    final (statusLabel, statusColor) = switch (score) {
      4 => ('Đạt chuẩn', MetaGymTheme.success),
      3 => ('Khá tốt', MetaGymTheme.warning),
      >= 1 => ('Cần bổ sung', MetaGymTheme.brandOrange),
      _ => ('4 điều kiện', MetaGymWarmGlassTokens.subtitleMuted),
    };

    final barDuration =
        MetaGymTheme.isFlutterTestEnvironment ||
            MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Container(
      key: const Key('register-password-strength'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: MetaGymWarmGlassTokens.metricPanelFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetaGymWarmGlassTokens.metricPanelBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Độ mạnh mật khẩu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymWarmGlassTokens.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (index) {
              final active = index < score;
              return Expanded(
                child: AnimatedContainer(
                  duration: barDuration,
                  curve: Curves.easeOutCubic,
                  height: 4,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active
                        ? barColor
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RuleBadge(label: '≥ 8 ký tự', met: hasLength),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RuleBadge(label: 'Chữ hoa', met: hasUpper),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _RuleBadge(label: 'Chữ thường', met: hasLower),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RuleBadge(label: 'Chữ số', met: hasDigit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleBadge extends StatelessWidget {
  const _RuleBadge({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? MetaGymTheme.success : MetaGymWarmGlassTokens.mutedText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
