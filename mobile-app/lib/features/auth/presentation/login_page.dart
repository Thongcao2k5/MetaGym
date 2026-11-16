import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_glass_scaffold.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _initializedRemembered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedRemembered) {
      _initializedRemembered = true;
      final auth = context.read<AuthController>();
      _rememberMe = auth.defaultRememberMe;
      final rememberedEmail = auth.rememberedEmail;
      if (_emailController.text.isEmpty &&
          rememberedEmail != null &&
          rememberedEmail.isNotEmpty) {
        _emailController.text = rememberedEmail;
      }
    }
  }

  @override
  void dispose() {
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
                    'Đăng nhập',
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
                    'Tiếp tục lịch tập và kết nối cùng\nHuấn luyện viên của bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD5CCBF),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthGlassField(
                    fieldKey: const Key('login-email'),
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'name@example.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    errorText: auth.fieldErrors['email'],
                  ),
                  const SizedBox(height: 14),
                  AuthGlassField(
                    fieldKey: const Key('login-password'),
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu của bạn',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    errorText: auth.fieldErrors['password'],
                    suffixIcon: IconButton(
                      key: const Key('login-toggle-password'),
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
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        key: const Key('login-remember-me'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: auth.isSubmitting
                            ? null
                            : () => setState(() => _rememberMe = !_rememberMe),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _rememberMe
                                      ? MetaGymTheme.brandOrange
                                      : const Color(0x88181513),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _rememberMe
                                        ? MetaGymTheme.brandOrange
                                        : const Color(0xA3A79D92),
                                  ),
                                ),
                                child: _rememberMe
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ghi nhớ đăng nhập',
                                style: TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isSubmitting
                            ? null
                            : () => context.push(AppRoutes.forgotPassword),
                        style: TextButton.styleFrom(
                          foregroundColor: MetaGymTheme.brandOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 34),
                        ),
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(
                      bannerKey: const Key('auth-error'),
                      message: auth.errorMessage!,
                    ),
                  ],
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    buttonKey: const Key('login-submit'),
                    isLoading: auth.isSubmitting,
                    label:
                        auth.isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập',
                    onPressed: auth.isSubmitting
                        ? null
                        : () => auth.login(
                            email: _emailController.text,
                            password: _passwordController.text,
                            rememberMe: _rememberMe,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const Text(
                        'Chưa có tài khoản?',
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
                                context.go(AppRoutes.register);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: MetaGymTheme.brandOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Đăng ký Member',
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
