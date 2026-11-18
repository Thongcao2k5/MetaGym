import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
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

/// Màn hình chờ khởi động Meta Gym với 5 phân cảnh mượt mà:
/// 1. Giọt nước cam mềm mại nảy nhẹ từ dưới lên tâm (Liquid Droplet)
/// 2. Giọt nước bung mượt thành hình người gồng cơ V-Taper (Bodybuilder Silhouette)
/// 3. Hình người thu gọn mượt mà trở lại thành giọt nước cam (Back to Liquid Droplet)
/// 4. Giọt nước lướt sang trái tạo thành thanh dọc màu cam rồi vẽ chữ "M"
/// 5. Lần lượt hiện các chữ cái sắc nét, hiện đại tạo thành "MetaGym" (M và G viết hoa màu cam)
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
  bool _didStartSequence = false;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.debugProgressOverride != null) {
      _morphController.value = widget.debugProgressOverride!.clamp(0.0, 1.0);
    } else if (MetaGymTheme.isFlutterTestEnvironment) {
      _morphController.value = 1.0;
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
      await precacheImage(MetaGymBackground.bannerAsset, context);
    } catch (_) {}
    if (!mounted) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _morphController.value = 1.0;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      session?.completeSplashGate();
      return;
    }

    await waitForFirstRasterizedFrame();
    if (!mounted) return;

    _pulseController.repeat();
    await _morphController.forward(from: 0.0).orCancel.catchError((_) {});
    if (!mounted) return;

    // Giữ trọn vẹn logo MetaGym hoàn chỉnh thêm 850ms trước khi chuyển mượt sang màn Đăng nhập
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    session?.completeSplashGate();
  }

  @override
  void dispose() {
    _morphController.dispose();
    _pulseController.dispose();
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
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
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
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: disableAnimations
                            ? _buildContent(
                                morphProgress: 1.0,
                                pulse: 0.0,
                                animatePulse: false,
                              )
                            : AnimatedBuilder(
                                animation: Listenable.merge([
                                  _morphController,
                                  _pulseController,
                                ]),
                                builder: (context, _) {
                                  final t =
                                      widget.debugProgressOverride?.clamp(
                                        0.0,
                                        1.0,
                                      ) ??
                                      _morphController.value;
                                  return _buildContent(
                                    morphProgress: t,
                                    pulse: _pulseController.value,
                                    animatePulse:
                                        widget.debugProgressOverride == null &&
                                        !MetaGymTheme.isFlutterTestEnvironment,
                                  );
                                },
                              ),
                      ),
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
    required double pulse,
    required bool animatePulse,
  }) {
    final breath = animatePulse
        ? 0.5 - 0.5 * math.cos(pulse * 2 * math.pi)
        : 0.5;
    final badgeFade = _interval(morphProgress, 0.68, 0.92, Curves.easeOutCubic);
    final titleFade = _interval(morphProgress, 0.74, 0.96, Curves.easeOutCubic);
    final barFade = _interval(morphProgress, 0.80, 1.0, Curves.easeOutCubic);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: 310,
            height: 204,
            child: CustomPaint(
              painter: _MetaGymMorphPainter(
                progress: morphProgress,
                pulse: breath,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StaggeredSlideFade(
          progress: badgeFade,
          offsetY: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.fromLTRB(7, 5, 14, 5),
              decoration: BoxDecoration(
                color: const Color(0x992D2824),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x66FF5E36)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'MG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PERSONAL PERFORMANCE',
                    style: TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredSlideFade(
          progress: titleFade,
          offsetY: 14,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'META GYM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.6,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Đang khởi động không gian tập luyện...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFC8C2BC),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _StaggeredSlideFade(
          progress: barFade,
          offsetY: 10,
          child: RepaintBoundary(
            child: _WarmGlassProgressBar(
              progress: animatePulse ? breath : 0.65,
            ),
          ),
        ),
      ],
    );
  }
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
    return Container(
      width: 196,
      height: 5,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x80211E1C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66A79D92), width: 1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment(-1.0 + (2.0 * progress), 0),
        widthFactor: 0.44,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(999)),
            gradient: LinearGradient(
              colors: [Color(0xFFF5B041), MetaGymTheme.brandOrange],
            ),
          ),
        ),
      ),
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
    // STEP 1 (0.00 -> 0.14): Giọt nước mềm mại (Liquid Droplet) nảy từ dưới lên tâm
    // STEP 2 (0.13 -> 0.34): Giọt nước hóa mượt thành người gồng cơ V-Taper
    // STEP 3 (0.33 -> 0.46): Người thu gọn mượt mà trở lại thành giọt nước cam
    // -------------------------------------------------------------------------
    if (progress < 0.47) {
      final riseT = _segment(progress, 0.0, 0.13, Curves.easeOutBack);
      final toAthlete = _segment(progress, 0.13, 0.27, Curves.easeOutBack);
      final backToDroplet = _segment(
        progress,
        0.33,
        0.45,
        Curves.easeInOutCubic,
      );
      final athleteMorph = _clamp(toAthlete * (1.0 - backToDroplet), 0.0, 1.12);

      // Liquid squash & stretch during initial rise and collapse
      final riseY = (1.0 - riseT) * 28.0;
      final squash = progress < 0.13
          ? math.sin(_clamp(progress / 0.13) * math.pi) * 0.18
          : 0.0;
      final scaleX = (0.45 + 0.55 * _clamp(riseT, 0.0, 1.12)) * (1.0 - squash * 0.6);
      final scaleY = (0.45 + 0.55 * _clamp(riseT, 0.0, 1.12)) * (1.0 + squash);

      _paintSmoothDropletAndAthlete(
        canvas: canvas,
        center: Offset(center.dx, center.dy + riseY),
        scaleX: scaleX,
        scaleY: scaleY,
        athleteMorph: athleteMorph,
        alpha: 1.0,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 4A (0.45 -> 0.56): Giọt nước lướt mượt sang trái & hóa thành THANH DỌC MÀU CAM
    // -------------------------------------------------------------------------
    if (progress >= 0.45 && progress < 0.58) {
      final moveT = _segment(progress, 0.45, 0.55, Curves.easeInOutCubic);
      final barMorph = _segment(progress, 0.48, 0.56, Curves.easeOutCubic);

      final currentX = ui.lerpDouble(center.dx, mLeftStemX, moveT)!;
      final currentY = center.dy;

      // Smoothly morph from liquid droplet to rounded vertical orange bar
      if (barMorph < 0.45) {
        final dropScale = 1.0 - barMorph * 0.35;
        _paintSmoothDropletAndAthlete(
          canvas: canvas,
          center: Offset(currentX, currentY),
          scaleX: dropScale,
          scaleY: 1.0 + barMorph * 0.25,
          athleteMorph: 0.0,
          alpha: 1.0,
        );
      } else {
        final tBar = (barMorph - 0.45) / 0.55;
        final w = ui.lerpDouble(18.0, stemW, tBar)!;
        final h = ui.lerpDouble(28.0, mBotY - mTopY, tBar)!;
        final r = ui.lerpDouble(9.0, stemW / 2, tBar)!;

        canvas.drawCircle(
          Offset(currentX, currentY),
          22.0,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(currentX, currentY),
              22.0,
              const [Color(0x70FF5E36), Colors.transparent],
            ),
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(currentX, currentY),
              width: w,
              height: h,
            ),
            Radius.circular(r),
          ),
          Paint()..color = MetaGymTheme.brandOrange,
        );
      }
    }

    // -------------------------------------------------------------------------
    // STEP 4B (0.55 -> 0.70): Từ thanh dọc màu cam vẽ mượt ra chữ "M"
    // STEP 5  (0.66 -> 0.95): Lần lượt hiện các chữ cái "e", "t", "a", "G", "y", "m"
    // -------------------------------------------------------------------------
    if (progress >= 0.55) {
      final mDrawProg = _segment(progress, 0.55, 0.70, Curves.easeInOutCubic);
      final mFontCrossfade = _segment(
        progress,
        0.65,
        0.74,
        Curves.easeOutCubic,
      );

      // While stroke M is drawing or crossfading into typographic 'M'
      if (mFontCrossfade < 0.99) {
        final strokeAlpha = 1.0 - mFontCrossfade * 0.85;
        // Left vertical orange bar
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(mLeftStemX, center.dy),
              width: stemW,
              height: mBotY - mTopY,
            ),
            const Radius.circular(stemW / 2),
          ),
          Paint()
            ..color = MetaGymTheme.brandOrange.withValues(alpha: strokeAlpha),
        );

        // Smooth stroke drawing of the rest of 'M'
        final mStrokePath = Path()
          ..moveTo(mLeftStemX, mTopY + 1.5)
          ..lineTo(mMidX, mBotY - 3.0)
          ..lineTo(mRightStemX, mTopY + 1.5)
          ..lineTo(mRightStemX, mBotY);

        _drawSmoothTrimmedPath(
          canvas: canvas,
          path: mStrokePath,
          endFrac: mDrawProg,
          strokeColor: MetaGymTheme.brandOrange.withValues(alpha: strokeAlpha),
          strokeWidth: stemW,
          drawGlowingTip: mDrawProg < 0.98,
        );
      }

      // Render crisp typographic 'M' crossfading in smoothly
      if (mFontCrossfade > 0.01) {
        canvas.save();
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
            color: MetaGymTheme.brandOrange.withValues(alpha: mFontCrossfade),
          ),
        );
        mTp.layout();
        mTp.paint(canvas, mPos);
        canvas.restore();
      }

      // Lần lượt hiện các chữ cái: e -> t -> a -> G (Cam) -> y -> m
      const timings = <(double, double)>[
        (0.66, 0.75), // e
        (0.70, 0.79), // t
        (0.74, 0.83), // a
        (0.78, 0.88), // G (viết hoa màu cam)
        (0.83, 0.92), // y
        (0.87, 0.96), // m
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
        final slideX = (1.0 - t) * -10.0;
        final slideY = (1.0 - t) * 6.0;
        final scale = 0.86 + 0.14 * Curves.easeOutBack.transform(t);

        final charCenter = Offset(
          baseOffset.dx + tp.width / 2 + slideX,
          baseOffset.dy + tp.height / 2 + slideY,
        );

        if (isOrangeCap && t < 0.95) {
          canvas.drawCircle(
            charCenter,
            24.0 * math.sin(t * math.pi),
            Paint()
              ..shader = ui.Gradient.radial(
                charCenter,
                24.0,
                [
                  MetaGymTheme.brandOrange.withValues(
                    alpha: 0.42 * math.sin(t * math.pi),
                  ),
                  Colors.transparent,
                ],
              ),
          );
        }

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
      }

      // Smooth glowing underline sweep beneath MetaGym
      final underlineProg = _segment(progress, 0.84, 0.98, Curves.easeOutCubic);
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
    }
  }

  /// Vẽ giọt nước mềm mại bằng đường cong Bézier (cubicTo) và biến hình mượt mà
  /// thành người gồng cơ V-Taper giống video mẫu, rồi thu ngược lại thành giọt nước.
  void _paintSmoothDropletAndAthlete({
    required Canvas canvas,
    required Offset center,
    required double scaleX,
    required double scaleY,
    required double athleteMorph,
    required double alpha,
  }) {
    if (alpha <= 0.01 || scaleX <= 0.01 || scaleY <= 0.01) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleX, scaleY);

    final m = _clamp(athleteMorph, 0.0, 1.0);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(0, -54),
        const Offset(0, 42),
        [
          const Color(0xFFFFB84D).withValues(alpha: alpha),
          const Color(0xFFF59E0B).withValues(alpha: alpha),
          MetaGymTheme.brandOrange.withValues(alpha: alpha),
        ],
        const [0.0, 0.52, 1.0],
      );

    // 1. Khi m = 0: Giọt nước mềm mại (cubic Bézier teardrop: đỉnh nhọn mượt ở trên, bầu tròn ở dưới)
    // 2. Khi m = 1: Thân khiên V-Taper mềm mại (vai rộng ở trên, eo thon vát xuống dưới)
    final dropletPath = Path()
      ..moveTo(0, -24)
      ..cubicTo(6, -14, 17, -2, 17, 9)
      ..cubicTo(17, 19, 9.5, 25, 0, 25)
      ..cubicTo(-9.5, 25, -17, 19, -17, 9)
      ..cubicTo(-17, -2, -6, -14, 0, -24)
      ..close();

    if (m <= 0.02) {
      canvas.drawPath(dropletPath, fillPaint);
    } else {
      // Smoothly cross-morph droplet into sculpted V-Taper torso shield
      final torsoScale = 0.72 + 0.28 * m;
      canvas.save();
      canvas.scale(torsoScale, torsoScale);
      final topW = ui.lerpDouble(6.0, 26.0, m)!;
      final midW = ui.lerpDouble(17.0, 22.0, m)!;
      final botY = ui.lerpDouble(25.0, 38.0, m)!;

      final morphTorso = Path()
        ..moveTo(0, -22)
        ..cubicTo(topW * 0.65, -22, topW, -19, topW * 0.96, -9)
        ..cubicTo(midW, 9, 10, 27, 0, botY)
        ..cubicTo(-10, 27, -midW, 9, -topW * 0.96, -9)
        ..cubicTo(-topW, -19, -topW * 0.65, -22, 0, -22)
        ..close();
      canvas.drawPath(morphTorso, fillPaint);
      canvas.restore();
    }

    // Đầu tròn + 2 cánh tay gồng cơ mềm mại (giống hệt silhouette trong video mẫu)
    if (athleteMorph > 0.03) {
      final armScale = athleteMorph;
      canvas.save();
      canvas.translate(0, -24.0 - 15.0 * armScale);
      canvas.scale(armScale, armScale);
      canvas.drawCircle(Offset.zero, 12.2, fillPaint);
      canvas.restore();

      for (final dir in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(dir * 21.0, -15.0);
        canvas.scale(dir * armScale, armScale);

        final arm = Path()
          ..moveTo(0, -5)
          ..cubicTo(10, -14, 24, -13, 33, -4)
          ..cubicTo(31, -18, 25, -31, 21, -39)
          ..arcToPoint(
            const Offset(32, -41),
            radius: const Radius.circular(7.5),
            clockwise: true,
          )
          ..cubicTo(39, -28, 46, -10, 41, 3)
          ..cubicTo(35, 13, 16, 12, 1, 7)
          ..close();
        canvas.drawPath(arm, fillPaint);
        canvas.restore();
      }
    }

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

    for (final metric in metrics) {
      final nextAccumulated = accumulated + metric.length;
      if (accumulated <= endLen) {
        final localEnd = (endLen - accumulated).clamp(0.0, metric.length);
        if (localEnd > 0) {
          extracted.addPath(metric.extractPath(0.0, localEnd), Offset.zero);
          final tangent = metric.getTangentForOffset(localEnd);
          if (tangent != null) {
            tipPosition = tangent.position;
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
      canvas.drawCircle(
        tipPosition,
        15.0,
        Paint()
          ..shader = ui.Gradient.radial(
            tipPosition,
            15.0,
            const [Color(0xFFFFD26E), Color(0xCCFF5E36), Colors.transparent],
            const [0.0, 0.45, 1.0],
          ),
      );
      canvas.drawCircle(
        tipPosition,
        3.5,
        Paint()..color = const Color(0xFFFFF7E6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MetaGymMorphPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
