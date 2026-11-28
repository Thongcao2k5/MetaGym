import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _signingOut = false;
  String? _signOutError;

  SessionController? _watchSession(BuildContext context) {
    try {
      return context.watch<SessionController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  SessionController? _readSession(BuildContext context) {
    try {
      return context.read<SessionController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _handleSignOut() async {
    if (_signingOut) return;
    final session = _readSession(context);
    if (session == null) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      await session.signOut();
    } catch (_) {
      if (mounted) {
        setState(() {
          _signOutError = 'Không thể đăng xuất lúc này. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? user = _watchSession(context)?.user;
    final theme = Theme.of(context);
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: MetaGymTheme.pageGutter,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: palette.surfaceSolid,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(
                          color: palette.borderSolid,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  color: MetaGymTheme.onPrimary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'META GYM · WEB ADMIN',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: palette.primaryText,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cổng vận hành trên trình duyệt',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: palette.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Tài khoản Quản trị viên chỉ sử dụng trên Web Admin',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ứng dụng di động Meta Gym chỉ phục vụ Hội viên và Huấn luyện viên. Vui lòng đăng nhập Meta Gym Web Admin trên trình duyệt để quản lý tài khoản, gói Gym/Coach, thanh toán tại quầy, sự cố và nhật ký hệ thống.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.textSecondary,
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          if (user != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: palette.surfaceRaised,
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                                border: Border.all(
                                  color: palette.borderSolid,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: palette.reflection,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: palette.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: palette.textSecondary,
                                                fontSize: 13,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_signOutError != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? palette.error.withValues(alpha: 0.10)
                                    : const Color(0xFF24161A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.error.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: palette.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _signOutError!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: isLight
                                                ? palette.error
                                                : const Color(0xFFFFB2B6),
                                            fontSize: 13,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            key: const Key('admin-sign-out-button'),
                            onPressed: _signingOut ? null : _handleSignOut,
                            style: FilledButton.styleFrom(
                              backgroundColor: MetaGymTheme.primary,
                              foregroundColor: MetaGymTheme.onPrimary,
                              disabledBackgroundColor: MetaGymTheme.primary
                                  .withValues(alpha: 0.45),
                              disabledForegroundColor: MetaGymTheme.onPrimary
                                  .withValues(alpha: 0.72),
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                              ),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: _signingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MetaGymTheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded, size: 20),
                            label: Text(
                              _signingOut ? 'Đang đăng xuất…' : 'Đăng xuất',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
