import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_glass_scaffold.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthAtmosphereScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthStaggeredEntrance(
            delayMs: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x992D2824),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0x88A79D92),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MetaGymTheme.brandOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'META GYM · STUDIO OS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFEAE3DA),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const MetaGymBrandBadge(
                  size: 70,
                  borderRadius: 22,
                  fontSize: 23,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Meta Gym',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Không gian luyện tập & Huấn luyện cá nhân thế hệ mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFC8C2BC),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AuthStaggeredEntrance(
            delayMs: 90,
            child: WarmSmokeGlass(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0x80211E1C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x9A8C8176),
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WelcomeHighlightRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Đặt lịch PT 1:1 linh hoạt theo ca',
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0x2EA79D92),
                        ),
                        _WelcomeHighlightRow(
                          icon: Icons.bolt_rounded,
                          label: 'Giáo trình & dinh dưỡng cá nhân hóa',
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0x2EA79D92),
                        ),
                        _WelcomeHighlightRow(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Theo dõi chỉ số & Trợ lý AI 24/7',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    buttonKey: const Key('welcome-login-button'),
                    label: 'Đăng nhập',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go(AppRoutes.login),
                  ),
                  const SizedBox(height: 10),
                  AuthSecondaryGlassButton(
                    buttonKey: const Key('welcome-register-button'),
                    label: 'Đăng ký Member',
                    onPressed: () => context.go(AppRoutes.register),
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

class _WelcomeHighlightRow extends StatelessWidget {
  const _WelcomeHighlightRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x24FF5E36),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x4DFF5E36), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: MetaGymTheme.brandOrange),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF7F9FC),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
