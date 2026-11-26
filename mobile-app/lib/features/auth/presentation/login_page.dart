import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
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

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = _openTerms;
    _privacyTap = TapGestureRecognizer()..onTap = _openPrivacy;
  }

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
    _termsTap.dispose();
    _privacyTap.dispose();
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
    auth.login(
      email: _emailController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  Future<void> _openBiometricSheet(
    AuthController auth, {
    required bool isFaceId,
  }) async {
    final title = isFaceId ? 'Xác thực Face ID' : 'Xác thực Vân tay';
    final svg = isFaceId
        ? MetaGymIcons.authFaceId
        : MetaGymIcons.authFingerprint;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: MetaGymTheme.overlayGlass,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymSvgIcon(
                    svg,
                    size: 34,
                    fallbackIcon: isFaceId
                        ? Icons.face_rounded
                        : Icons.fingerprint_rounded,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đăng nhập nhanh vào tài khoản test local Nguyễn Minh Quân (đầy đủ dữ liệu mẫu).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('biometric-confirm-btn'),
                    onPressed: () => Navigator.of(sheetCtx).pop(true),
                    child: const Text('Xác nhận & Đăng nhập ngay'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true && mounted) {
      _emailController.text = LocalDemoAccounts.memberEmail;
      _passwordController.text = LocalDemoAccounts.demoPassword;
      _submit(auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final palette = MetaGymTheme.paletteOf(context);
    void clearErrorsOnEdit(String _) {
      if (auth.fieldErrors.isNotEmpty || auth.errorMessage != null) {
        auth.clearErrors();
      }
    }

    final formBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chào mừng trở lại',
                    style: TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Đăng nhập để tiếp tục lịch tập cùng Meta Kong & Coach.',
                    style: TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Image.asset(
              'assets/images/mascot/meta_kong_hero.webp',
              width: 62,
              height: 62,
              fit: BoxFit.contain,
              semanticLabel: 'Meta Kong chào mừng',
            ),
          ],
        ),
        const SizedBox(height: 14),
        AuthGlassField(
          fieldKey: const Key('login-email'),
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
        const SizedBox(height: 12),
        AuthGlassField(
          fieldKey: const Key('login-password'),
          controller: _passwordController,
          label: 'Mật khẩu',
          hintText: 'Nhập mật khẩu của bạn',
          icon: Icons.lock_outline_rounded,
          svgIcon: MetaGymIcons.settingPasswordKey,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: auth.isSubmitting ? null : (_) => _submit(auth),
          autofillHints: const [AutofillHints.password],
          errorText: auth.fieldErrors['password'],
          onChanged: clearErrorsOnEdit,
          suffixIcon: IconButton(
            key: const Key('login-toggle-password'),
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
        const SizedBox(height: 6),
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration:
                            MetaGymTheme.isFlutterTestEnvironment ||
                                MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
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
                                : MetaGymWarmGlassTokens.cardBorder,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: auth.isSubmitting
                  ? null
                  : () {
                      auth.clearErrors();
                      context.push(AppRoutes.forgotPassword);
                    },
              style: TextButton.styleFrom(
                foregroundColor: MetaGymTheme.reflectionBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 10),
        AuthPrimaryButton(
          buttonKey: const Key('login-submit'),
          isLoading: auth.isSubmitting,
          label: auth.isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: auth.isSubmitting ? null : () => _submit(auth),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _BiometricButton(
                buttonKey: const Key('login-face-id'),
                svgAsset: MetaGymIcons.authFaceId,
                fallbackIcon: Icons.face_rounded,
                label: 'Face ID',
                onTap: auth.isSubmitting
                    ? null
                    : () => _openBiometricSheet(auth, isFaceId: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BiometricButton(
                buttonKey: const Key('login-fingerprint'),
                svgAsset: MetaGymIcons.authFingerprint,
                fallbackIcon: Icons.fingerprint_rounded,
                label: 'Vân tay',
                onTap: auth.isSubmitting
                    ? null
                    : () => _openBiometricSheet(auth, isFaceId: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          key: const Key('login-demo-disclosure'),
          title: const Text(
            'Tài khoản demo',
            style: TextStyle(fontSize: 12, color: MetaGymTheme.textSecondary),
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('login-demo-member'),
                    onPressed: auth.isSubmitting
                        ? null
                        : () {
                            _emailController.text =
                                LocalDemoAccounts.memberEmail;
                            _passwordController.text =
                                LocalDemoAccounts.demoPassword;
                            _submit(auth);
                          },
                    icon: const Icon(Icons.person_rounded, size: 16),
                    label: const Text(
                      'Demo Hội viên',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetaGymTheme.textPrimary,
                      backgroundColor: const Color(0x66181513),
                      side: const BorderSide(color: Color(0x66FF5E36)),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('login-demo-coach'),
                    onPressed: auth.isSubmitting
                        ? null
                        : () {
                            _emailController.text =
                                LocalDemoAccounts.coachEmail;
                            _passwordController.text =
                                LocalDemoAccounts.demoPassword;
                            _submit(auth);
                          },
                    icon: const Icon(Icons.sports_gymnastics_rounded, size: 16),
                    label: const Text(
                      'Demo HLV',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetaGymTheme.textPrimary,
                      backgroundColor: const Color(0x66181513),
                      side: const BorderSide(color: Color(0x6670AEE8)),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
            children: [
              const TextSpan(text: 'Bằng việc đăng nhập, bạn đồng ý với '),
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
              const TextSpan(text: ' của Meta Gym.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MetaGymSvgIcon(
              MetaGymIcons.authVerified,
              size: 14,
              fallbackIcon: Icons.verified_user_outlined,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Không gian Hội viên & Huấn luyện viên Meta Gym',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaGymTheme.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (AuthShellScope.isEmbedded(context)) {
      return formBody;
    }

    return AuthModeShell(
      isLogin: true,
      onSelectLogin: null,
      onSelectRegister: auth.isSubmitting
          ? null
          : () {
              auth.clearErrors();
              context.go(AppRoutes.register);
            },
      child: formBody,
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.label,
    required this.onTap,
    this.buttonKey,
  });

  final Key? buttonKey;
  final String svgAsset;
  final IconData fallbackIcon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: MetaGymWarmGlassTokens.metricPanelFill,
          side: const BorderSide(
            color: MetaGymWarmGlassTokens.metricPanelBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            MetaGymSvgIcon(svgAsset, size: 18, fallbackIcon: fallbackIcon),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
