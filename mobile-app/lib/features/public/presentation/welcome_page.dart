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
          // 1. Logo & tên thương hiệu căn giữa hoàn toàn
          AuthStaggeredEntrance(
            delayMs: 0,
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF7A4D), MetaGymTheme.brandOrange],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.40),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Meta Gym',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'COACHING & TRAINING STUDIO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Vạch nhấn nhỏ cân giữa
          AuthStaggeredEntrance(
            delayMs: 50,
            child: Center(
              child: Container(
                width: 44,
                height: 3,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Câu khẩu hiệu & mô tả ngắn căn giữa đều chữ
          const AuthStaggeredEntrance(
            delayMs: 90,
            child: Column(
              children: [
                Text(
                  'Đồng hành cùng\nhành trình luyện tập của bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Theo dõi lịch tập, chỉ số cơ thể và kết nối 1:1 cùng Huấn luyện viên cá nhân.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD5CCBF),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. Hai nút Đăng nhập & Đăng ký nằm ngay phía dưới chữ ở giữa màn hình
          AuthStaggeredEntrance(
            delayMs: 140,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthPrimaryButton(
                    buttonKey: const Key('welcome-login-button'),
                    label: 'Đăng nhập',
                    onPressed: () => context.go(AppRoutes.login),
                  ),
                  const SizedBox(height: 12),
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
