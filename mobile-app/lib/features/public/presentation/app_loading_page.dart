import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_auth_background.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';

/// Đợi khung hình đầu tiên thực sự được GPU rasterize lên màn hình Android
/// để hiệu ứng Splash luôn bắt đầu từ 0% ngay trước mắt người dùng.
Future<void> waitForFirstRasterizedFrame() async {
  final binding = WidgetsBinding.instance;
  final completer = Completer<void>();
  void onTimings(List<ui.FrameTiming> _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  binding.addTimingsCallback(onTimings);
  binding.scheduleFrame();
  try {
    await completer.future.timeout(const Duration(milliseconds: 2200));
  } on TimeoutException catch (_) {
    // Fallback nếu thiết bị không gửi FrameTiming.
  } finally {
    binding.removeTimingsCallback(onTimings);
  }
  await Future<void>.delayed(const Duration(milliseconds: 450));
}

/// Màn hình chờ khởi động Meta Gym với 5 phân cảnh mượt mà chuẩn theo video mẫu:
/// 1. Giọt nước sáng rơi từ đỉnh xuống chạm sàn, nén dẹt rồi nảy lên thành giọt nước ngược cam vàng
/// 2. Từ hai bên hông mọc cánh tay vươn rộng rồi gập lên tư thế gồng cơ V-Taper + đầu tròn tách lên
/// 3. Đầu và hai tay thu gọn mượt vào thân V-Taper rồi tụ xuống mũi nhọn dưới đáy
/// 4. Hóa thành giọt nước sao chổi cam vàng lượn vòng tròn 360° theo chiều kim đồng hồ rồi đáp vào nét chữ M
/// 5. Đầu giọt nước cam dẫn nét vẽ chữ "M" và hiện trọn vẹn logo "MetaGym" (M, G màu cam)
class AppLoadingPage extends StatefulWidget {
  const AppLoadingPage({super.key, this.debugProgressOverride});

  /// Cho phép khóa tiến độ [0.0..1.0] khi chụp preview từng phân cảnh.
  final double? debugProgressOverride;

  @override
  State<AppLoadingPage> createState() => _AppLoadingPageState();
}

class _AppLoadingPageState extends State<AppLoadingPage>
    with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final AnimationController _pulseController;
  late final AnimationController _loadController;
  bool _didStartSequence = false;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );

    if (widget.debugProgressOverride != null) {
      _morphController.value = widget.debugProgressOverride!.clamp(0.0, 1.0);
      _loadController.value = widget.debugProgressOverride! >= 1.0 ? 1.0 : 0.0;
    } else if (MetaGymTheme.isFlutterTestEnvironment) {
      _morphController.value = 1.0;
      _loadController.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment &&
        widget.debugProgressOverride == null &&
        !_didStartSequence) {
      _didStartSequence = true;
      unawaited(_runFullSplashSequence());
    }
  }

  Future<void> _runFullSplashSequence() async {
    final session = context.read<SessionController?>();
    try {
      await precacheImage(
        MetaGymTheme.isLightPalette(context)
            ? MetaGymAuthBackground.lightAsset
            : MetaGymAuthBackground.darkAsset,
        context,
      );
    } catch (_) {}
    if (!mounted) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _morphController.value = 1.0;
      _loadController.value = 1.0;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      session?.completeSplashGate();
      return;
    }

    await waitForFirstRasterizedFrame();
    if (!mounted) return;

    _pulseController.repeat();
    await _morphController.forward(from: 0.0).orCancel.catchError((_) {});
    if (!mounted) return;

    // Khởi chạy thanh loading 0% -> 100% sau khi animation logo hoàn tất
    await _loadController.forward(from: 0.0).orCancel.catchError((_) {});
    if (!mounted) return;
    session?.completeSplashGate();
  }

  @override
  void dispose() {
    _morphController.dispose();
    _pulseController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  double _interval(double t, double start, double end, [Curve? curve]) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    final raw = (t - start) / (end - start);
    return curve != null ? curve.transform(raw) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context) &&
        widget.debugProgressOverride == null;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymAuthBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: disableAnimations
                              ? _buildContent(
                                  morphProgress: 1.0,
                                  loadProgress: 1.0,
                                  pulse: 0.0,
                                  animatePulse: false,
                                )
                              : AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _morphController,
                                    _pulseController,
                                    _loadController,
                                  ]),
                                  builder: (context, _) {
                                    final t =
                                        widget.debugProgressOverride?.clamp(
                                          0.0,
                                          1.0,
                                        ) ??
                                        _morphController.value;
                                    final loadT =
                                        widget.debugProgressOverride != null
                                        ? (t >= 1.0 ? 1.0 : 0.0)
                                        : _loadController.value;
                                    return _buildContent(
                                      morphProgress: t,
                                      loadProgress: loadT,
                                      pulse: _pulseController.value,
                                      animatePulse:
                                          widget.debugProgressOverride ==
                                              null &&
                                          !MetaGymTheme
                                              .isFlutterTestEnvironment,
                                    );
                                  },
                                ),
                        ),
                        const _SplashVersionFooter(),
                      ],
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

  Widget _buildContent({
    required double morphProgress,
    required double loadProgress,
    required double pulse,
    required bool animatePulse,
  }) {
    final breath = animatePulse
        ? 0.5 - 0.5 * math.cos(pulse * 2 * math.pi)
        : 0.5;
    final subtitleFade = _interval(
      morphProgress,
      0.74,
      0.96,
      Curves.easeOutCubic,
    );
    final barFade = _interval(loadProgress, 0.0, 0.16, Curves.easeOutCubic);
    final clampedLoad = loadProgress.clamp(0.0, 1.0);
    final barValue =
        (0.7 * Curves.easeInOutCubic.transform(clampedLoad)) +
        (0.3 * Curves.easeInOutSine.transform(clampedLoad));

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: 280,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 1 - _interval(morphProgress, 0.65, 0.78),
                  child: CustomPaint(
                    size: const Size(280, 210),
                    painter: _MetaGymMorphPainter(
                      progress: morphProgress,
                      pulse: breath,
                    ),
                  ),
                ),
                Opacity(
                  opacity: _interval(morphProgress, 0.78, 1.0),
                  child: const _SplashBrandLockup(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _StaggeredSlideFade(
          progress: subtitleFade,
          offsetY: 12,
          child: const Text(
            'Đang khởi động không gian tập luyện...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8C2BC),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _StaggeredSlideFade(
          progress: barFade,
          offsetY: 10,
          child: RepaintBoundary(
            child: _WarmGlassProgressBar(progress: barValue),
          ),
        ),
      ],
    );
  }
}

class _SplashBrandLockup extends StatelessWidget {
  const _SplashBrandLockup();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 36,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: const MetaGymSvgIcon(
            MetaGymIcons.appIconMark,
            size: 96,
            semanticsLabel: 'Biểu tượng Meta Gym',
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: MetaGymTheme.fontFamily,
            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -1.2,
            color: MetaGymTheme.textPrimary,
          ),
          children: [
            TextSpan(
              text: 'M',
              style: TextStyle(color: MetaGymTheme.brandOrange),
            ),
            TextSpan(text: 'eta'),
            TextSpan(
              text: 'G',
              style: TextStyle(color: MetaGymTheme.brandOrange),
            ),
            TextSpan(text: 'ym'),
          ],
        ),
      ),
    ],
  );
}

class _SplashVersionFooter extends StatelessWidget {
  const _SplashVersionFooter();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: const [
      MetaGymSvgIcon(
        MetaGymIcons.settingVersion,
        size: 14,
        fallbackIcon: Icons.info_outline_rounded,
      ),
      SizedBox(width: 6),
      Flexible(
        child: Text(
          'Meta Gym v1.0.0 · Build 2026.11',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MetaGymTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ),
    ],
  );
}

class _StaggeredSlideFade extends StatelessWidget {
  const _StaggeredSlideFade({
    required this.progress,
    required this.offsetY,
    required this.child,
  });

  final double progress;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1.0 - progress) * offsetY),
        child: child,
      ),
    );
  }
}

class _WarmGlassProgressBar extends StatelessWidget {
  const _WarmGlassProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round().clamp(0, 100);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 172,
          height: 5,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0x80211E1C),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x66A79D92), width: 1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                gradient: LinearGradient(
                  colors: [MetaGymTheme.brandOrange, Color(0xFFF5B041)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: MetaGymTheme.brandOrange,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaGymMorphPainter extends CustomPainter {
  const _MetaGymMorphPainter({required this.progress, required this.pulse});

  final double progress;
  final double pulse;

  static const _wordChars = <String>['M', 'e', 't', 'a', 'G', 'y', 'm'];

  static double _clamp(double v, [double min = 0.0, double max = 1.0]) =>
      v.clamp(min, max);

  static double _segment(double t, double start, double end, [Curve? curve]) {
    if (t <= start) return 0.0;
    if (t >= end) return 1.0;
    final raw = (t - start) / (end - start);
    return curve != null ? curve.transform(raw) : raw;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);

    // Subtle ambient warm performance aura
    final auraRadius = size.width * (0.40 + pulse * 0.025);
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          auraRadius,
          const [Color(0x34FF5E36), Color(0x12F5B041), Colors.transparent],
          const [0.0, 0.56, 1.0],
        ),
    );

    // Measure exact character positions for "MetaGym" using clean modern typography
    final charPainters = <TextPainter>[];
    var totalWordWidth = 0.0;
    var maxCharHeight = 0.0;

    for (var i = 0; i < _wordChars.length; i++) {
      final ch = _wordChars[i];
      final isOrangeCap = ch == 'M' || ch == 'G';
      final tp = TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            fontFamily: MetaGymTheme.fontFamily,
            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
            fontSize: 45,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.0,
            color: isOrangeCap
                ? MetaGymTheme.brandOrange
                : const Color(0xFFF7F9FC),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      charPainters.add(tp);
      totalWordWidth += tp.width + (i < _wordChars.length - 1 ? 1.2 : 0.0);
      if (tp.height > maxCharHeight) {
        maxCharHeight = tp.height;
      }
    }

    final wordStartX = center.dx - totalWordWidth / 2;
    final charOffsets = <Offset>[];
    var cursorX = wordStartX;
    for (final tp in charPainters) {
      charOffsets.add(Offset(cursorX, center.dy - tp.height / 2));
      cursorX += tp.width + 1.2;
    }

    final mWidth = charPainters[0].width;
    final mLeftStemX = charOffsets[0].dx + 4.5;
    final mRightStemX = charOffsets[0].dx + mWidth - 4.5;
    final mMidX = charOffsets[0].dx + mWidth / 2;
    final mTopY = center.dy - 17.5;
    final mBotY = center.dy + 17.5;
    const stemW = 7.4;

    // -------------------------------------------------------------------------
    // STEP 1 (0.00 -> 0.16): Giọt nước sáng rơi từ đỉnh xuống chạm sàn, nén dẹt
    //                        rồi nảy lên tâm thành giọt nước ngược (0.2s -> 0.92s)
    // -------------------------------------------------------------------------
    if (progress < 0.16) {
      _paintFallingAndReboundingDroplet(
        canvas: canvas,
        center: center,
        progress: progress,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 2 (0.16 -> 0.37): Giọt nước ngược mọc 2 tay từ hông vươn lên gồng cơ
    //                        V-Taper + đầu tròn tách lên (1.04s -> 2.12s)
    // STEP 3 (0.37 -> 0.45): Đầu và tay gập thu gọn về giọt nước ngược (2.24s -> 2.48s)
    // -------------------------------------------------------------------------
    if (progress >= 0.16 && progress < 0.45) {
      final sproutT = _segment(progress, 0.16, 0.26, Curves.easeOutBack);
      final collapseT = _segment(progress, 0.37, 0.45, Curves.easeInOutCubic);
      final athleteMorph = _clamp(sproutT * (1.0 - collapseT), 0.0, 1.08);
      final flexWave = (progress >= 0.26 && progress < 0.37)
          ? math.sin(_segment(progress, 0.26, 0.37) * math.pi)
          : 0.0;

      _paintInvertedDropletAndAthlete(
        canvas: canvas,
        center: Offset(center.dx, center.dy + 2.0 - flexWave * 2.5),
        athleteMorph: athleteMorph,
        flexWave: flexWave,
        collapsePhase: collapseT,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 4A (0.45 -> 0.63): Thu nhỏ xuống mũi nhọn dưới đáy rồi hóa thành
    //                         giọt nước sao chổi lượn vòng 360° theo chiều kim
    //                         đồng hồ quanh khung hình và đáp vào nét chữ M (2.6s -> 3.8s)
    // -------------------------------------------------------------------------
    if (progress >= 0.45 && progress < 0.635) {
      _paintCometDiveAndOrbit(
        canvas: canvas,
        center: center,
        targetStem: Offset(mLeftStemX, center.dy),
        stemWidth: stemW,
        stemHeight: mBotY - mTopY,
        progress: progress,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 4B (0.62 -> 0.74): Từ thanh dọc màu cam vẽ mượt ra chữ "M" bằng đầu giọt nước
    // STEP 5  (0.70 -> 0.96): Lần lượt hiện các chữ cái "e", "t", "a", "G", "y", "m"
    // -------------------------------------------------------------------------
    if (progress >= 0.62) {
      final mDrawProg = _segment(progress, 0.62, 0.74, Curves.easeInOutCubic);
      final mTp = charPainters[0];
      final mPos = charOffsets[0];
      mTp.text = TextSpan(
        text: 'M',
        style: TextStyle(
          fontFamily: MetaGymTheme.fontFamily,
          fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
          fontSize: 45,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.0,
          color: MetaGymTheme.brandOrange,
        ),
      );
      mTp.layout();

      if (mDrawProg >= 0.99) {
        mTp.paint(canvas, mPos);
      } else {
        final maskBounds = Rect.fromLTWH(
          mPos.dx - 12.0,
          mPos.dy - 12.0,
          mTp.width + 24.0,
          mTp.height + 24.0,
        );
        canvas.saveLayer(maskBounds, Paint());
        mTp.paint(canvas, mPos);

        // Reveal the real typographic 'M' along the traced stroke using dstIn
        canvas.saveLayer(maskBounds, Paint()..blendMode = BlendMode.dstIn);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(mLeftStemX, center.dy),
              width: 15.0,
              height: mBotY - mTopY + 12.0,
            ),
            const Radius.circular(7.5),
          ),
          Paint()..color = Colors.black,
        );

        final mStrokePath = Path()
          ..moveTo(mLeftStemX, mTopY + 1.5)
          ..lineTo(mMidX, mBotY - 3.0)
          ..lineTo(mRightStemX, mTopY + 1.5)
          ..lineTo(mRightStemX, mBotY);

        _drawSmoothTrimmedPath(
          canvas: canvas,
          path: mStrokePath,
          endFrac: mDrawProg,
          strokeColor: Colors.black,
          strokeWidth: 15.0,
          drawGlowingTip: false,
        );
        canvas.restore();
        canvas.restore();

        if (mDrawProg > 0.02 && mDrawProg < 0.98) {
          final metrics = mStrokePath.computeMetrics().toList();
          if (metrics.isNotEmpty) {
            final metric = metrics.first;
            final tangent = metric.getTangentForOffset(
              metric.length * mDrawProg,
            );
            if (tangent != null) {
              _paintDirectionalCometDroplet(
                canvas: canvas,
                position: tangent.position,
                angle: math.atan2(-tangent.vector.dy, tangent.vector.dx),
                length: 14.0,
                radius: 4.4,
              );
            }
          }
        }
      }

      // Lần lượt hiện các chữ cái: e -> t -> a -> G (Cam) -> y -> m
      const timings = <(double, double)>[
        (0.70, 0.78), // e
        (0.73, 0.81), // t
        (0.76, 0.84), // a
        (0.80, 0.89), // G (viết hoa màu cam)
        (0.84, 0.92), // y
        (0.88, 0.96), // m
      ];

      for (var i = 1; i < _wordChars.length; i++) {
        final (startT, endT) = timings[i - 1];
        final t = _segment(progress, startT, endT, Curves.easeOutCubic);
        if (t <= 0.001) continue;

        final ch = _wordChars[i];
        final isOrangeCap = ch == 'G';
        final baseColor = isOrangeCap
            ? MetaGymTheme.brandOrange
            : const Color(0xFFF7F9FC);

        final tp = charPainters[i];
        final baseOffset = charOffsets[i];
        final slideX = (1.0 - t) * -8.0;
        final slideY = (1.0 - t) * 8.0;
        final scale = 0.86 + 0.14 * Curves.easeOutBack.transform(t);

        final charCenter = Offset(
          baseOffset.dx + tp.width / 2 + slideX,
          baseOffset.dy + tp.height / 2 + slideY,
        );

        canvas.save();
        canvas.translate(charCenter.dx, charCenter.dy);
        canvas.scale(scale, scale);
        tp.text = TextSpan(
          text: ch,
          style: TextStyle(
            fontFamily: MetaGymTheme.fontFamily,
            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
            fontSize: 45,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.0,
            color: baseColor.withValues(alpha: _clamp(t)),
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();

        // Đầu giọt nước cam dẫn nét trên đỉnh chữ khi chữ đang vẽ lên (giống 4.0s -> 5.4s trong video)
        if (t > 0.04 && t < 0.92) {
          final tipArcAngle = -math.pi * 0.75 + t * math.pi * 1.35;
          final tipOffset = Offset(
            charCenter.dx + math.cos(tipArcAngle) * (tp.width * 0.36),
            charCenter.dy + math.sin(tipArcAngle) * (tp.height * 0.28),
          );
          _paintDirectionalCometDroplet(
            canvas: canvas,
            position: tipOffset,
            angle: tipArcAngle + math.pi * 0.5,
            length: 11.0 * math.sin(t * math.pi),
            radius: 4.2 * math.sin(t * math.pi),
          );
        }
      }

      // Smooth glowing underline sweep beneath MetaGym
      final underlineProg = _segment(progress, 0.86, 0.98, Curves.easeOutCubic);
      if (underlineProg > 0.01) {
        final lineStart = wordStartX;
        final lineEnd = wordStartX + totalWordWidth * underlineProg;
        final lineY = center.dy + 32.0;
        canvas.drawLine(
          Offset(lineStart, lineY),
          Offset(lineEnd, lineY),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(lineStart, lineY),
              Offset(lineEnd, lineY),
              const [
                MetaGymTheme.brandOrange,
                Color(0xFFF5B041),
                Color(0x00FF5E36),
              ],
              const [0.0, 0.72, 1.0],
            )
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
      }

      // Hiệu ứng sáng đường chéo lướt từ trái sang phải trên toàn bộ logo
      final sheenT = _segment(progress, 0.89, 1.0, Curves.easeInOutCubic);
      if (sheenT > 0.0 && sheenT < 1.0) {
        final sheenBounds = Rect.fromLTWH(
          wordStartX - 24.0,
          center.dy - 40.0,
          totalWordWidth + 48.0,
          80.0,
        );
        canvas.saveLayer(sheenBounds, Paint());
        for (var i = 0; i < _wordChars.length; i++) {
          charPainters[i]
            ..text = TextSpan(
              text: _wordChars[i],
              style: TextStyle(
                fontFamily: MetaGymTheme.fontFamily,
                fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                fontSize: 45,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.0,
                color: Colors.white,
              ),
            )
            ..layout()
            ..paint(canvas, charOffsets[i]);
        }
        canvas.saveLayer(sheenBounds, Paint()..blendMode = BlendMode.srcIn);
        final beamX = ui.lerpDouble(
          sheenBounds.left - 40.0,
          sheenBounds.right + 40.0,
          sheenT,
        )!;
        canvas.drawRect(
          sheenBounds,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(beamX - 34.0, sheenBounds.top),
              Offset(beamX + 56.0, sheenBounds.bottom),
              const [
                Color(0x00FFFFFF),
                Color(0x40FFFFFF),
                Color(0xEBFFF8E8),
                Color(0x40FFFFFF),
                Color(0x00FFFFFF),
              ],
              const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
        );
        canvas.restore();
        canvas.restore();
      }
    }
  }

  /// STEP 1 (0.00 -> 0.16):
  /// - 0.00 -> 0.09: Giọt nước sáng ấm rơi từ trên đỉnh xuống sàn (đuôi nhọn ở trên, bầu tròn ở dưới)
  /// - 0.09 -> 0.12: Chạm sàn ở phía dưới tâm và nén dẹt thành viên tròn (0.80s trong video)
  /// - 0.12 -> 0.16: Nảy vọt lên tâm và xoay thành giọt nước ngược màu vàng cam (0.92s trong video)
  void _paintFallingAndReboundingDroplet({
    required Canvas canvas,
    required Offset center,
    required double progress,
  }) {
    final topY = center.dy - 78.0;
    final floorY = center.dy + 34.0;
    final restY = center.dy + 2.0;

    late final double currentY;
    late final double scaleX;
    late final double scaleY;
    late final double invertMorph; // 0 = upright falling drop, 0.5 = round ball, 1 = inverted shield drop
    late final double
    warmColorMix; // 0 = luminous warm cream, 1 = golden orange

    if (progress < 0.09) {
      final fallT = _segment(progress, 0.0, 0.09, Curves.easeInQuad);
      currentY = ui.lerpDouble(topY, floorY, fallT)!;
      scaleX = ui.lerpDouble(0.42, 0.54, fallT)!;
      scaleY = ui.lerpDouble(0.55, 1.02, fallT)!;
      invertMorph = 0.0;
      warmColorMix = fallT * 0.25;
    } else if (progress < 0.12) {
      final squashT = _segment(progress, 0.09, 0.12, Curves.easeOutCubic);
      final squashPulse = math.sin(squashT * math.pi);
      currentY = floorY + squashPulse * 3.0;
      scaleX = ui.lerpDouble(0.54, 0.84, squashPulse)!;
      scaleY = ui.lerpDouble(1.02, 0.54, squashPulse)!;
      invertMorph = squashT * 0.5;
      warmColorMix = 0.25 + squashT * 0.30;
    } else {
      final reboundT = _segment(progress, 0.12, 0.16, Curves.easeOutCubic);
      currentY = ui.lerpDouble(floorY, restY, reboundT)!;
      scaleX = ui.lerpDouble(0.68, 1.0, reboundT)!;
      scaleY = ui.lerpDouble(0.68, 1.0, reboundT)!;
      invertMorph = 0.5 + reboundT * 0.5;
      warmColorMix = 0.55 + reboundT * 0.45;
    }

    final dropCenter = Offset(center.dx, currentY);
    canvas.save();
    canvas.translate(dropCenter.dx, dropCenter.dy);
    canvas.scale(scaleX, scaleY);

    // Quầng sáng ấm quanh giọt nước
    canvas.drawCircle(
      Offset.zero,
      26.0,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 26.0, [
          Color.lerp(
            const Color(0x66FFF6E0),
            const Color(0x66FF8C3B),
            warmColorMix,
          )!,
          Colors.transparent,
        ]),
    );

    final topColor = Color.lerp(
      const Color(0xFFFFFDF7),
      MetaGymTheme.brandOrange,
      warmColorMix,
    )!;
    final botColor = Color.lerp(
      const Color(0xFFFFE5B4),
      const Color(0xFFE84E27),
      warmColorMix,
    )!;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(const Offset(0, -24), const Offset(0, 24), [
        topColor,
        botColor,
      ]);

    // Nội suy mượt từ:
    // - Giọt nước rơi xuôi (đỉnh nhọn ở trên y=-24, bụng bầu ở dưới y=+20)
    // - Qua viên tròn nén ở đáy (invertMorph = 0.5)
    // - Sang giọt nước ngược ở tâm (đỉnh bầu rộng ở trên y=-18, đáy nhọn bầu ở dưới y=+22)
    final double topShoulderX;
    final double botBellyX;
    final double topApexY;
    final double botApexY;

    if (invertMorph <= 0.5) {
      final t = invertMorph / 0.5;
      topShoulderX = ui.lerpDouble(2.5, 14.0, t)!;
      botBellyX = ui.lerpDouble(15.0, 14.0, t)!;
      topApexY = ui.lerpDouble(-25.0, -14.0, t)!;
      botApexY = ui.lerpDouble(18.0, 14.0, t)!;
    } else {
      final t = (invertMorph - 0.5) / 0.5;
      topShoulderX = ui.lerpDouble(14.0, 16.5, t)!;
      botBellyX = ui.lerpDouble(14.0, 5.5, t)!;
      topApexY = ui.lerpDouble(-14.0, -18.0, t)!;
      botApexY = ui.lerpDouble(14.0, 22.0, t)!;
    }

    final path = Path()
      ..moveTo(0, topApexY)
      ..cubicTo(
        topShoulderX * 0.85,
        topApexY,
        topShoulderX,
        topApexY * 0.35,
        (topShoulderX + botBellyX) * 0.5,
        0,
      )
      ..cubicTo(
        botBellyX,
        botApexY * 0.45,
        botBellyX * 0.75,
        botApexY,
        0,
        botApexY,
      )
      ..cubicTo(
        -botBellyX * 0.75,
        botApexY,
        -botBellyX,
        botApexY * 0.45,
        -(topShoulderX + botBellyX) * 0.5,
        0,
      )
      ..cubicTo(
        -topShoulderX,
        topApexY * 0.35,
        -topShoulderX * 0.85,
        topApexY,
        0,
        topApexY,
      )
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.restore();
  }

  /// STEP 2 & 3 (0.16 -> 0.45):
  /// Biến hình từ giọt nước ngược (0.92s) -> mọc 2 chồi tay ở hông (1.04s) ->
  /// vươn rộng cánh tay (1.16s) -> gập cẳng tay lên tư thế Double Front Biceps +
  /// đầu tròn tách lên trên cổ (1.28s -> 2.12s) -> thu gọn về giọt nước ngược (2.24s -> 2.48s).
  void _paintInvertedDropletAndAthlete({
    required Canvas canvas,
    required Offset center,
    required double athleteMorph,
    required double flexWave,
    required double collapsePhase,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final m = _clamp(athleteMorph, 0.0, 1.0);
    final overshoot = (athleteMorph - 1.0).clamp(0.0, 0.12);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(0, -56),
        const Offset(0, 44),
        const [
          MetaGymTheme.brandOrange,
          MetaGymTheme.brandOrange,
          Color(0xFFE84E27),
        ],
        const [0.0, 0.68, 1.0],
      );

    // 1. Thân V-Taper (Inverted Teardrop Shield) vạm vỡ hơn:
    final topY = ui.lerpDouble(-18.0, -22.0, m)!;
    final botY = ui.lerpDouble(22.0, 40.0, m)!;
    final topW = ui.lerpDouble(16.5, 33.0 + flexWave * 1.6, m)!;
    final midW = ui.lerpDouble(13.5, 25.0 + flexWave * 1.0, m)!;

    final torsoPath = Path()
      ..moveTo(0, topY)
      ..cubicTo(topW * 0.58, topY, topW, topY + 3.5, topW * 0.96, topY + 15.0)
      ..cubicTo(midW, 11.0, 10.5, botY - 6.0, 0, botY)
      ..cubicTo(-10.5, botY - 6.0, -midW, 11.0, -topW * 0.96, topY + 15.0)
      ..cubicTo(-topW, topY + 3.5, -topW * 0.58, topY, 0, topY)
      ..close();

    canvas.drawPath(torsoPath, fillPaint);

    // 2. Đầu tròn tách từ đỉnh thân lên trên cổ
    if (m > 0.05) {
      final headT = _segment(m, 0.05, 0.88, Curves.easeOutCubic);
      final headY = ui.lerpDouble(-10.0, -38.5 - overshoot * 14.0, headT)!;
      final headRadius = ui.lerpDouble(8.0, 12.5, headT)!;
      canvas.drawCircle(Offset(0, headY), headRadius, fillPaint);
    }

    // 3. Hai cánh tay vạm vỡ & 2 nắm đấm (Double Front Biceps)
    if (m > 0.04) {
      final spreadT = _segment(m, 0.04, 0.55, Curves.easeOutCubic);
      final curlT = _segment(m, 0.36, 1.0, Curves.easeOutBack);
      final curlClamped = _clamp(curlT, 0.0, 1.15);

      for (final dir in const [-1.0, 1.0]) {
        canvas.save();
        canvas.scale(dir, 1.0);

        final shoulderTopY = ui.lerpDouble(0.0, -20.5, spreadT)!;
        final shoulderBotY = ui.lerpDouble(12.0, -1.5, spreadT)!;
        final shoulderX = ui.lerpDouble(11.0, 23.5, spreadT)!;

        final elbowX = ui.lerpDouble(15.0, 55.0 + flexWave * 1.8, spreadT)!;
        final elbowY = ui.lerpDouble(
          12.0,
          ui.lerpDouble(6.0, -8.0 - flexWave * 1.2, curlT)!,
          spreadT,
        )!;

        final wristX = ui.lerpDouble(
          ui.lerpDouble(17.0, 56.0, spreadT)!,
          44.0 - flexWave * 1.2,
          curlClamped,
        )!;
        final wristY = ui.lerpDouble(
          ui.lerpDouble(14.0, 2.0, spreadT)!,
          -34.0 - overshoot * 18.0 - flexWave * 1.8,
          curlClamped,
        )!;

        final bicepPeakX = ui.lerpDouble(18.0, 37.5, spreadT)!;
        final bicepPeakY = ui.lerpDouble(
          4.0,
          -26.0 - flexWave * 2.4,
          _clamp(curlT, 0.0, 1.1),
        )!;

        final armPath = Path()
          ..moveTo(shoulderX, shoulderTopY)
          ..cubicTo(
            bicepPeakX - 5.0,
            bicepPeakY,
            bicepPeakX + 4.0,
            bicepPeakY + 2.0,
            elbowX - 13.0,
            elbowY - 9.5,
          )
          ..cubicTo(
            elbowX - 12.5,
            ui.lerpDouble(elbowY - 3.0, wristY + 13.0, _clamp(curlT))!,
            wristX - 6.5,
            wristY + 4.0,
            wristX - 4.5,
            wristY,
          )
          ..lineTo(wristX + 4.5, wristY + 1.0)
          ..cubicTo(
            elbowX + 6.5,
            ui.lerpDouble(elbowY + 2.0, wristY + 18.0, _clamp(curlT))!,
            elbowX + 6.0,
            elbowY - 3.0,
            elbowX + 1.5,
            elbowY + 5.0,
          )
          ..cubicTo(
            elbowX - 6.0,
            elbowY + 11.0,
            shoulderX + 12.0,
            shoulderBotY + 3.0,
            shoulderX - 2.0,
            shoulderBotY,
          )
          ..close();

        canvas.drawPath(armPath, fillPaint);

        // Nắm đấm (clenched fist) ở cổ tay
        final fistScale = _clamp(spreadT * 1.15, 0.25, 1.0);
        final fistAngle = ui.lerpDouble(0.15, -0.28, curlClamped)!;
        canvas.save();
        canvas.translate(wristX, wristY - 3.5 * fistScale);
        canvas.rotate(fistAngle);
        canvas.scale(fistScale, fistScale);

        final fistPath = Path()
          ..moveTo(-7.5, 4.5)
          ..cubicTo(-9.0, 1.5, -9.0, -4.5, -6.5, -6.5)
          ..quadraticBezierTo(-4.0, -8.5, -1.5, -7.0)
          ..quadraticBezierTo(1.0, -8.5, 3.5, -7.0)
          ..quadraticBezierTo(6.5, -8.2, 8.0, -5.2)
          ..cubicTo(9.5, -2.5, 9.0, 3.0, 6.5, 5.2)
          ..cubicTo(4.0, 7.0, -3.5, 7.0, -7.5, 4.5)
          ..close();

        canvas.drawPath(fistPath, fillPaint);

        if (spreadT > 0.35) {
          final creasePaint = Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x7A0F1115)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          final creasePath = Path()
            ..moveTo(-4.5, -1.5)
            ..quadraticBezierTo(0.0, -0.5, 4.5, -1.5)
            ..moveTo(-5.5, 2.2)
            ..quadraticBezierTo(-1.5, 3.8, 1.5, 1.2);
          canvas.drawPath(creasePath, creasePaint);
        }

        canvas.restore();
        canvas.restore();
      }
    }

    canvas.restore();
  }

  /// STEP 4A (0.45 -> 0.635):
  /// - 0.45 -> 0.485: Giọt nước ngược thu nhỏ xuống mũi nhọn dưới đáy (2.60s trong video)
  /// - 0.485 -> 0.615: Hóa thành giọt nước sao chổi cam-vàng lượn 1 vòng 360° theo chiều
  ///                   kim đồng hồ quanh tâm (2.60s -> 3.68s trong video)
  /// - 0.605 -> 0.635: Đáp mượt vào vị trí thanh dọc chữ M bên trái
  void _paintCometDiveAndOrbit({
    required Canvas canvas,
    required Offset center,
    required Offset targetStem,
    required double stemWidth,
    required double stemHeight,
    required double progress,
  }) {
    if (progress < 0.485) {
      // Thu nhỏ từ giọt nước ngược ở tâm xuống mũi nhọn dưới đáy (2.48s -> 2.60s)
      final diveT = _segment(progress, 0.45, 0.485, Curves.easeInCubic);
      final y = ui.lerpDouble(center.dy + 2.0, center.dy + 34.0, diveT)!;
      final scale = ui.lerpDouble(1.0, 0.28, diveT)!;
      canvas.save();
      canvas.translate(center.dx, y);
      canvas.scale(scale, scale);
      _paintInvertedDropletAndAthlete(
        canvas: canvas,
        center: Offset.zero,
        athleteMorph: 0.0,
        flexWave: 0.0,
        collapsePhase: 1.0,
      );
      canvas.restore();
      return;
    }

    // Quỹ đạo lượn vòng 360° theo chiều kim đồng hồ (2.60s -> 3.68s):
    // Bắt đầu từ đáy dưới (angle = pi/2), vòng sang trái (pi), lên đỉnh (3*pi/2),
    // vòng sang phải (2*pi), xuống đáy và đáp mượt vào thanh dọc chữ M.
    final orbitT = _segment(progress, 0.485, 0.615, Curves.easeInOutSine);
    Offset orbitPos(double t) {
      // Góc quay theo chiều kim đồng hồ trong hệ tọa độ màn hình (y hướng xuống):
      // pi/2 (đáy) -> pi (trái) -> 1.5*pi (đỉnh) -> 2*pi (phải) -> 2.5*pi (đáy)
      final theta = math.pi * 0.5 + t * math.pi * 2.05;
      final rx = ui.lerpDouble(96.0, 108.0, math.sin(t * math.pi))!;
      final ry = ui.lerpDouble(54.0, 68.0, math.sin(t * math.pi))!;
      final rawOrbit = Offset(
        center.dx + rx * math.cos(theta),
        center.dy + ry * math.sin(theta),
      );
      // Pha cuối (t > 0.78) bẻ lái mượt từ đáy vòng tròn vào đúng tâm thanh dọc chữ M
      final landBlend = _segment(t, 0.78, 1.0, Curves.easeInOutCubic);
      return Offset.lerp(rawOrbit, targetStem, landBlend)!;
    }

    if (progress < 0.615) {
      final pos = orbitPos(orbitT);
      final dt = 0.015;
      final pPrev = orbitPos((orbitT - dt).clamp(0.0, 1.0));
      final pNext = orbitPos((orbitT + dt).clamp(0.0, 1.0));
      final vel = pNext - pPrev;
      final angle = vel.distance > 0.001
          ? math.atan2(vel.dy, vel.dx)
          : -math.pi / 2;

      final speedStretch = 1.0 + 0.35 * math.sin(orbitT * math.pi);
      _paintDirectionalCometDroplet(
        canvas: canvas,
        position: pos,
        angle: angle,
        length: 22.0 * speedStretch,
        radius: 5.6,
      );
    }

    // Khi vừa đáp tới vị trí chữ M (0.60 -> 0.635), dựng thành thanh dọc màu cam
    if (progress >= 0.60) {
      final barT = _segment(progress, 0.60, 0.63, Curves.easeOutCubic);
      final h = ui.lerpDouble(14.0, stemHeight, barT)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: targetStem, width: stemWidth, height: h),
          Radius.circular(stemWidth / 2),
        ),
        Paint()..color = MetaGymTheme.brandOrange,
      );
    }
  }

  /// Vẽ giọt nước sao chổi định hướng (đầu tròn hướng theo vector chuyển động [angle],
  /// đuôi nhọn kéo dài phía sau giống hệt frame 2.60s -> 3.68s trong video).
  void _paintDirectionalCometDroplet({
    required Canvas canvas,
    required Offset position,
    required double angle,
    required double length,
    required double radius,
  }) {
    if (length <= 0.5 || radius <= 0.3) return;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    // Quầng sáng ấm quanh đầu giọt nước sao chổi
    canvas.drawCircle(
      Offset(radius * 0.4, 0),
      radius * 2.8,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(radius * 0.4, 0),
          radius * 2.8,
          const [Color(0x66FFB84D), Color(0x28FF5E36), Colors.transparent],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Hình giọt nước sao chổi: Đầu tròn ở phía trước (+x), đuôi vuốt nhọn về phía sau (-length)
    final cometPath = Path()
      ..moveTo(-length, 0)
      ..cubicTo(
        -length * 0.45,
        -radius * 0.38,
        -radius * 0.2,
        -radius,
        radius * 0.35,
        -radius,
      )
      ..arcToPoint(
        Offset(radius * 0.35, radius),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..cubicTo(
        -radius * 0.2,
        radius,
        -length * 0.45,
        radius * 0.38,
        -length,
        0,
      )
      ..close();

    final cometPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(radius * 1.35, 0),
        Offset(-length, 0),
        const [Color(0xFFFFF3D1), Color(0xFFFFB84D), MetaGymTheme.brandOrange],
        const [0.0, 0.38, 1.0],
      );

    canvas.drawPath(cometPath, cometPaint);
    canvas.restore();
  }

  void _drawSmoothTrimmedPath({
    required Canvas canvas,
    required Path path,
    required double endFrac,
    required Color strokeColor,
    required double strokeWidth,
    required bool drawGlowingTip,
  }) {
    if (endFrac <= 0.001) return;

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(0.0, (sum, m) => sum + m.length);
    if (totalLength <= 0.0) return;

    final endLen = totalLength * _clamp(endFrac);
    final extracted = Path();
    var accumulated = 0.0;
    Offset? tipPosition;
    double tipAngle = 0.0;

    for (final metric in metrics) {
      final nextAccumulated = accumulated + metric.length;
      if (accumulated <= endLen) {
        final localEnd = (endLen - accumulated).clamp(0.0, metric.length);
        if (localEnd > 0) {
          extracted.addPath(metric.extractPath(0.0, localEnd), Offset.zero);
          final tangent = metric.getTangentForOffset(localEnd);
          if (tangent != null) {
            tipPosition = tangent.position;
            tipAngle = math.atan2(tangent.vector.dy, tangent.vector.dx);
          }
        }
      }
      accumulated = nextAccumulated;
    }

    canvas.drawPath(
      extracted,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (drawGlowingTip && tipPosition != null && endFrac > 0.02) {
      _paintDirectionalCometDroplet(
        canvas: canvas,
        position: tipPosition,
        angle: tipAngle,
        length: 14.0,
        radius: 4.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MetaGymMorphPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
