import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

const AssetImage _loadingGymBgAsset = AssetImage('assets/images/gym_banner.png');
const AssetImage _loadingArmLiftAsset = AssetImage(
  'assets/images/loading_arm_lift.jpg',
);

/// Màn hình chờ khởi động Meta Gym với đồ họa 3D cánh tay đẩy tạ chuyển động nâng hạ mượt mà.
class AppLoadingPage extends StatefulWidget {
  const AppLoadingPage({super.key});

  @override
  State<AppLoadingPage> createState() => _AppLoadingPageState();
}

class _AppLoadingPageState extends State<AppLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_loadingArmLiftAsset, context).catchError((_) {});
      precacheImage(_loadingGymBgAsset, context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền phòng tập tối đồng bộ Member Home để chuyển trang mượt mà
          Opacity(
            opacity: 0.42,
            child: Image(
              image: _loadingGymBgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: MetaGymTheme.darkCanvas),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.7),
                radius: 0.9,
                colors: [Color(0x288EB9E5), Colors.transparent],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD40A0C0F),
                  Color(0xCC0D0F13),
                  Color(0xF00A0C0F),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Khối đồ họa 3D cánh tay đẩy tạ nâng hạ mượt mà + vòng ánh sáng cam
                  SizedBox(
                    width: 268,
                    height: 268,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final press = Curves.easeInOutCubic.transform(
                          _controller.value,
                        );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Lớp chuyển tiếp tối mềm ở tâm để ảnh 3D nền đen hòa quyện không viền
                            Container(
                              width: 268,
                              height: 268,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xF5000000),
                                    Color(0xC8000000),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.56, 1.0],
                                ),
                              ),
                            ),
                            // Ảnh 3D titan-carbon đẩy lên xuống nhịp nhàng
                            Transform.translate(
                              offset: Offset(0, 10 - press * 20),
                              child: Transform.scale(
                                scale: 0.96 + press * 0.055,
                                child: child,
                              ),
                            ),
                            // Hào quang cam tỏa lực nhẹ khi đẩy tạ lên đỉnh
                            Transform.translate(
                              offset: Offset(0, -30 - press * 18),
                              child: IgnorePointer(
                                child: Container(
                                  width: 170 + press * 34,
                                  height: 170 + press * 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        MetaGymTheme.brandOrange.withValues(
                                          alpha: 0.12 + press * 0.14,
                                        ),
                                        MetaGymTheme.brandOrange.withValues(
                                          alpha: 0.03,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Vòng quỹ đạo năng lượng mảnh xung quanh
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _OrbitalLiftRingPainter(
                                  progress: press,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: SizedBox(
                        width: 236,
                        height: 236,
                        child: ShaderMask(
                          shaderCallback: (rect) {
                            return const RadialGradient(
                              radius: 0.48,
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.62, 1.0],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Image(
                            image: _loadingArmLiftAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.fitness_center_rounded,
                              size: 84,
                              color: MetaGymTheme.brandOrange,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x992D2824),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'PERSONAL PERFORMANCE',
                      style: TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'META GYM',
                    style: TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đang khởi động không gian tập luyện...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFC2C8D4),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 190,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final value = _controller.value;
                          return Stack(
                            children: [
                              Container(
                                height: 4.5,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              FractionallySizedBox(
                                alignment: Alignment(-1.0 + (2.0 * value), 0),
                                widthFactor: 0.44,
                                child: Container(
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF8C5A),
                                        MetaGymTheme.brandOrange,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitalLiftRingPainter extends CustomPainter {
  const _OrbitalLiftRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    // Vòng mảnh tĩnh
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Hai vòng cung đối xứng tỏa sáng theo nhịp đẩy tạ
    final activePaint = Paint()
      ..color = MetaGymTheme.brandOrange.withValues(alpha: 0.42 + progress * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi * 0.78 + (progress * 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 0.56,
      false,
      activePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + math.pi,
      math.pi * 0.35,
      false,
      activePaint..color = MetaGymTheme.brandOrange.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitalLiftRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
