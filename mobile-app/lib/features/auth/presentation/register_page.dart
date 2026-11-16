import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
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
  String _passwordInput = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AuthAtmosphereScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStaggeredEntrance(
            delayMs: 0,
            child: AuthTopHeader(
              onBack: auth.isSubmitting
                  ? null
                  : () {
                      auth.clearErrors();
                      context.go(AppRoutes.welcome);
                    },
            ),
          ),
          const SizedBox(height: 20),
          AuthStaggeredEntrance(
            delayMs: 70,
            child: WarmSmokeGlass(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Đăng ký Member',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tạo tài khoản hội viên để bắt đầu\nlộ trình luyện tập cá nhân.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD5CCBF),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthGlassField(
                    fieldKey: const Key('register-name'),
                    controller: _nameController,
                    label: 'Họ và tên',
                    hintText: 'Nguyễn Văn A',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    errorText: auth.fieldErrors['fullName'],
                  ),
                  const SizedBox(height: 14),
                  AuthGlassField(
                    fieldKey: const Key('register-email'),
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'name@example.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    errorText: auth.fieldErrors['email'],
                  ),
                  const SizedBox(height: 14),
                  AuthGlassField(
                    fieldKey: const Key('register-password'),
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    hintText: 'Tạo mật khẩu bảo mật',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    errorText: auth.fieldErrors['password'],
                    onChanged: (value) =>
                        setState(() => _passwordInput = value),
                    suffixIcon: IconButton(
                      key: const Key('register-toggle-password'),
                      tooltip:
                          _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: const Color(0xFFD9CFC1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PasswordStrengthMeter(password: _passwordInput),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(
                      bannerKey: const Key('auth-error'),
                      message: auth.errorMessage!,
                    ),
                  ],
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    buttonKey: const Key('register-submit'),
                    isLoading: auth.isSubmitting,
                    label: auth.isSubmitting ? 'Đang đăng ký…' : 'Đăng ký',
                    onPressed: auth.isSubmitting
                        ? null
                        : () => auth.register(
                            fullName: _nameController.text,
                            email: _emailController.text,
                            password: _passwordController.text,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const Text(
                        'Đã có tài khoản?',
                        style: TextStyle(
                          color: Color(0xFFD5CCBF),
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isSubmitting
                            ? null
                            : () {
                                auth.clearErrors();
                                context.go(AppRoutes.login);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: MetaGymTheme.brandOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

    return Container(
      key: const Key('register-password-strength'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x80181513),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66A79D92), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (index) {
              final active = index < score;
              return Expanded(
                child: Container(
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
              Expanded(child: _RuleBadge(label: '≥ 8 ký tự', met: hasLength)),
              Expanded(child: _RuleBadge(label: 'Chữ hoa', met: hasUpper)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _RuleBadge(label: 'Chữ thường', met: hasLower)),
              Expanded(child: _RuleBadge(label: 'Chữ số', met: hasDigit)),
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
    final color = met ? MetaGymTheme.success : const Color(0xFFD0C7BC);
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
