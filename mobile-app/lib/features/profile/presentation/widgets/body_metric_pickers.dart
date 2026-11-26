import 'package:meta_gym_app/core/theme/theme_controller.dart';

import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Phân loại BMI đồng bộ `calcBmiInfo()` trong `screens-preview.html`.
enum BmiZone { underweight, normal, overweight, obese }

@immutable
class BmiInfo {
  const BmiInfo({
    required this.bmi,
    required this.label,
    required this.zone,
    required this.barFraction,
  });

  final double bmi;
  final String label;
  final BmiZone zone;

  /// Vị trí điểm chỉ báo trên thanh BMI 4 vùng (0.04..0.96).
  final double barFraction;

  Color colorFor(MetaGymColors colors) => switch (zone) {
    BmiZone.underweight => colors.info,
    BmiZone.normal => colors.success,
    BmiZone.overweight => colors.warning,
    BmiZone.obese => colors.error,
  };
}

/// Tính chỉ số BMI và vị trí trên thanh phân loại 4 mức khớp preview `5.3`.
BmiInfo calculateBmiInfo(double heightCm, double weightKg) {
  final safeHeightM = (heightCm > 0 ? heightCm : 170.0) / 100.0;
  final safeWeight = weightKg > 0 ? weightKg : 68.0;
  final raw = safeWeight / (safeHeightM * safeHeightM);
  final bmi = double.parse(raw.toStringAsFixed(1));
  if (bmi < 18.5) {
    final pct = math.max(0.04, (bmi / 18.5) * 0.24);
    return BmiInfo(
      bmi: bmi,
      label: 'Thiếu cân',
      zone: BmiZone.underweight,
      barFraction: pct,
    );
  }
  if (bmi < 25.0) {
    final pct = 0.24 + ((bmi - 18.5) / 6.5) * 0.36;
    return BmiInfo(
      bmi: bmi,
      label: 'Bình thường',
      zone: BmiZone.normal,
      barFraction: pct,
    );
  }
  if (bmi < 30.0) {
    final pct = 0.60 + ((bmi - 25.0) / 5.0) * 0.22;
    return BmiInfo(
      bmi: bmi,
      label: 'Thừa cân',
      zone: BmiZone.overweight,
      barFraction: pct,
    );
  }
  final pct = math.min(0.96, 0.82 + ((bmi - 30.0) / 10.0) * 0.18);
  return BmiInfo(
    bmi: bmi,
    label: 'Béo phì',
    zone: BmiZone.obese,
    barFraction: pct,
  );
}

/// Quy đổi cm sang feet/inch (ví dụ `174 cm` -> `5'9"`).
String formatHeightFeetInches(double cm) {
  final totalInches = (cm / 2.54).round();
  return "${totalInches ~/ 12}'${totalInches % 12}\"";
}

/// Quy đổi kg sang lbs (ví dụ `72.4 kg` -> `159.6 lbs`).
String formatWeightLbs(double kg) => '${(kg * 2.20462).toStringAsFixed(1)} lbs';

/// Mở modal **Thước Laser Đứng** chọn chiều cao (`120–220 cm`), khớp preview `5.3`.
Future<double?> showHeightStadiometerPicker(
  BuildContext context, {
  required double initialHeightCm,
  required double referenceWeightKg,
}) {
  return showDialog<double>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) => _HeightStadiometerDialog(
      initialHeightCm: initialHeightCm,
      referenceWeightKg: referenceWeightKg,
    ),
  );
}

/// Mở modal **Cân Đĩa Tạ Vòng Cung** chọn cân nặng (`35.0–150.0 kg`), khớp preview `5.3`.
Future<double?> showWeightBarbellDialPicker(
  BuildContext context, {
  required double initialWeightKg,
  required double referenceHeightCm,
}) {
  return showDialog<double>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) => _WeightBarbellDialDialog(
      initialWeightKg: initialWeightKg,
      referenceHeightCm: referenceHeightCm,
    ),
  );
}

// =============================================================================
// 1. THƯỚC ĐO CHIỀU CAO LASER ĐỨNG (Vertical Laser Stadiometer)
// =============================================================================

class _HeightStadiometerDialog extends StatefulWidget {
  const _HeightStadiometerDialog({
    required this.initialHeightCm,
    required this.referenceWeightKg,
  });

  final double initialHeightCm;
  final double referenceWeightKg;

  @override
  State<_HeightStadiometerDialog> createState() =>
      _HeightStadiometerDialogState();
}

class _HeightStadiometerDialogState extends State<_HeightStadiometerDialog> {
  static const int _minCm = 120;
  static const int _maxCm = 220;
  static const double _pxPerCm = 7.0;

  late int _valueCm = widget.initialHeightCm.round().clamp(_minCm, _maxCm);
  double _dragAccumPx = 0;

  void _step(int delta) {
    setState(() {
      _valueCm = (_valueCm + delta).clamp(_minCm, _maxCm);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final bmi = calculateBmiInfo(_valueCm.toDouble(), widget.referenceWeightKg);
    final bmiColor = bmi.colorFor(colors);
    final ratio = (_valueCm - _minCm) / (_maxCm - _minCm);
    final silhouetteScale = 0.56 + ratio * 0.44;
    final laserBottom = 14.0 + silhouetteScale * 158.0;

    final sheet = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: colors.overlayGlass,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.overlayGlassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thước đo chiều cao',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kéo thước lên/xuống hoặc bấm nút chỉnh',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$_valueCm cm',
                          key: const Key('stadiometer-value'),
                          style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatHeightFeetInches(_valueCm.toDouble()),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stadiometer Stage: Silhouette + Laser Beam | Draggable Vertical Ruler
                Container(
                  height: 224,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRect(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 6,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: colors.reflection.withValues(
                                      alpha: 0.35,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RepaintBoundary(
                                  child: AnimatedScale(
                                    scale: silhouetteScale,
                                    alignment: Alignment.bottomCenter,
                                    duration: disableAnimations
                                        ? Duration.zero
                                        : const Duration(milliseconds: 90),
                                    curve: Curves.easeOut,
                                    child: CustomPaint(
                                      size: const Size(74, 166),
                                      painter: _AthleteSilhouettePainter(
                                        topColor: MetaGymTheme.brandOrange,
                                        bottomColor: colors.info,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedPositioned(
                                duration: disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 90),
                                curve: Curves.easeOut,
                                left: 0,
                                right: 0,
                                bottom: laserBottom.clamp(16.0, 198.0),
                                child: IgnorePointer(
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          MetaGymTheme.brandOrange.withValues(
                                            alpha: 0.20,
                                          ),
                                          MetaGymTheme.brandOrange,
                                          MetaGymTheme.brandOrange,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: MetaGymTheme.brandOrange
                                              .withValues(alpha: 0.75),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 104,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) => _dragAccumPx = 0,
                          onVerticalDragUpdate: (details) {
                            _dragAccumPx += details.delta.dy;
                            final steps = (_dragAccumPx / _pxPerCm).truncate();
                            if (steps != 0) {
                              _dragAccumPx -= steps * _pxPerCm;
                              _step(steps);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: colors.border),
                              ),
                            ),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(104, 204),
                                painter: _VerticalRulerPainter(
                                  valueCm: _valueCm,
                                  minCm: _minCm,
                                  maxCm: _maxCm,
                                  pxPerCm: _pxPerCm,
                                  majorColor: colors.textPrimary,
                                  minorColor: colors.textSecondary.withValues(
                                    alpha: 0.45,
                                  ),
                                  labelColor: colors.textSecondary,
                                  needleColor: MetaGymTheme.brandOrange,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StepChipButton(
                      key: const Key('height-step-minus'),
                      label: '− 1 cm',
                      onTap: () => _step(-1),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: bmiColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusFull,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'BMI ${bmi.bmi.toStringAsFixed(1)} · ${bmi.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: bmiColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StepChipButton(
                      key: const Key('height-step-plus'),
                      label: '+ 1 cm',
                      onTap: () => _step(1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            backgroundColor: colors.surfaceRaised,
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton(
                          key: const Key('stadiometer-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(_valueCm.toDouble()),
                          child: const Text(
                            'Xác nhận',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final child = Center(
      child: Padding(padding: const EdgeInsets.all(16), child: sheet),
    );
    if (disableAnimations ||
        MetaGymSurfacePreferences.reduceBlurOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return child;
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: child,
    );
  }
}

class _AthleteSilhouettePainter extends CustomPainter {
  const _AthleteSilhouettePainter({
    required this.topColor,
    required this.bottomColor,
  });

  final Color topColor;
  final Color bottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 80.0;
    final sy = size.height / 180.0;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          topColor.withValues(alpha: 0.95),
          bottomColor.withValues(alpha: 0.55),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 80, 180))
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(const Offset(40, 22), 13, paint);

    // Sculpted athletic silhouette matching preview SVG path
    final body = Path()
      ..moveTo(22, 44)
      ..cubicTo(22, 37, 58, 37, 58, 44)
      ..lineTo(64, 94)
      ..cubicTo(64, 98, 58, 99, 56, 95)
      ..lineTo(52, 62)
      ..lineTo(51, 112)
      ..lineTo(56, 170)
      ..cubicTo(56, 174, 47, 175, 46, 170)
      ..lineTo(41, 124)
      ..lineTo(39, 124)
      ..lineTo(34, 170)
      ..cubicTo(33, 175, 24, 174, 24, 170)
      ..lineTo(29, 112)
      ..lineTo(28, 62)
      ..lineTo(24, 95)
      ..cubicTo(22, 99, 16, 98, 16, 94)
      ..close();
    canvas.drawPath(body, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AthleteSilhouettePainter oldDelegate) =>
      oldDelegate.topColor != topColor ||
      oldDelegate.bottomColor != bottomColor;
}

class _VerticalRulerPainter extends CustomPainter {
  const _VerticalRulerPainter({
    required this.valueCm,
    required this.minCm,
    required this.maxCm,
    required this.pxPerCm,
    required this.majorColor,
    required this.minorColor,
    required this.labelColor,
    required this.needleColor,
  });

  final int valueCm;
  final int minCm;
  final int maxCm;
  final double pxPerCm;
  final Color majorColor;
  final Color minorColor;
  final Color labelColor;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final majorPaint = Paint()
      ..color = majorColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = minorColor
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final visibleRange = (size.height / (2 * pxPerCm)).ceil() + 2;
    final startCm = math.max(minCm, valueCm - visibleRange);
    final endCm = math.min(maxCm, valueCm + visibleRange);

    for (var cm = startCm; cm <= endCm; cm++) {
      final y = centerY - (cm - valueCm) * pxPerCm;
      final isMajor = cm % 10 == 0;
      final isMid = !isMajor && cm % 5 == 0;
      final tickW = isMajor ? 28.0 : (isMid ? 17.0 : 10.0);
      canvas.drawLine(
        Offset(8, y),
        Offset(8 + tickW, y),
        isMajor ? majorPaint : minorPaint,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$cm',
            style: TextStyle(
              color: labelColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: MetaGymTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(42, y - tp.height / 2));
      }
    }

    // Center coral laser needle
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      needlePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter oldDelegate) =>
      oldDelegate.valueCm != valueCm ||
      oldDelegate.majorColor != majorColor ||
      oldDelegate.minorColor != minorColor;
}

// =============================================================================
// 2. CÂN ĐĨA TẠ VÒNG CUNG (Olympic Barbell Plates + Mechanical Arc Scale Dial)
// =============================================================================

class _PlateSpec {
  const _PlateSpec({
    required this.weight,
    required this.height,
    required this.thickness,
    required this.fill,
    required this.stroke,
  });

  final double weight;
  final double height;
  final double thickness;
  final Color fill;
  final Color stroke;
}

const List<_PlateSpec> _olympicPlates = <_PlateSpec>[
  _PlateSpec(
    weight: 25,
    height: 54,
    thickness: 11,
    fill: Color(0xFFFF5E36),
    stroke: Color(0xFFFF9276),
  ),
  _PlateSpec(
    weight: 20,
    height: 50,
    thickness: 10,
    fill: Color(0xFF56A8F5),
    stroke: Color(0xFF9ED0FF),
  ),
  _PlateSpec(
    weight: 10,
    height: 42,
    thickness: 8,
    fill: Color(0xFFC4CCDA),
    stroke: Color(0xFFFFFFFF),
  ),
  _PlateSpec(
    weight: 5,
    height: 35,
    thickness: 7,
    fill: Color(0xFFDAB066),
    stroke: Color(0xFFF5DCA6),
  ),
  _PlateSpec(
    weight: 2.5,
    height: 27,
    thickness: 6,
    fill: Color(0xFF3B4252),
    stroke: Color(0xFF8E95A5),
  ),
  _PlateSpec(
    weight: 1.25,
    height: 21,
    thickness: 5,
    fill: Color(0xFF2B303C),
    stroke: Color(0xFF6E778A),
  ),
];

List<_PlateSpec> _computeBarbellPlatesPerSide(double totalKg) {
  var remSide = math.max(0.0, (totalKg - 20.0) / 2.0);
  final chosen = <_PlateSpec>[];
  for (final plate in _olympicPlates) {
    while (remSide >= plate.weight - 0.01 && chosen.length < 6) {
      chosen.add(plate);
      remSide -= plate.weight;
    }
  }
  return chosen;
}

String _formatPlateWeight(double w) =>
    w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString();

class _WeightBarbellDialDialog extends StatefulWidget {
  const _WeightBarbellDialDialog({
    required this.initialWeightKg,
    required this.referenceHeightCm,
  });

  final double initialWeightKg;
  final double referenceHeightCm;

  @override
  State<_WeightBarbellDialDialog> createState() =>
      _WeightBarbellDialDialogState();
}

class _WeightBarbellDialDialogState extends State<_WeightBarbellDialDialog> {
  static const double _minKg = 35.0;
  static const double _maxKg = 150.0;

  late double _weightKg = double.parse(
    widget.initialWeightKg.clamp(_minKg, _maxKg).toStringAsFixed(1),
  );
  double _dragStartWeight = 70.0;
  double _dragTotalDx = 0.0;

  void _step(double delta) {
    setState(() {
      _weightKg = double.parse(
        (_weightKg + delta).clamp(_minKg, _maxKg).toStringAsFixed(1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final plates = _computeBarbellPlatesPerSide(_weightKg);
    final plateSummary = plates.isEmpty
        ? 'Chỉ đòn tạ 20 kg'
        : '${plates.map((p) => _formatPlateWeight(p.weight)).join(' + ')} kg / bên';
    final bmi = calculateBmiInfo(widget.referenceHeightCm, _weightKg);
    final bmiColor = bmi.colorFor(colors);

    final sheet = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: colors.overlayGlass,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.overlayGlassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cân đĩa tạ Meta Gym',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kéo ngang mặt cân để đổi mức tạ',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.chipActiveBg,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        '± 0.1 kg',
                        style: TextStyle(
                          color: colors.primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Live Olympic Barbell + Stacked Plates Visualizer
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _OlympicBarbellPainter(plates: plates),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Đòn tạ 20kg + Đĩa đối xứng',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              plateSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Draggable Mechanical Arc Scale Dial
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _dragStartWeight = _weightKg;
                    _dragTotalDx = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    _dragTotalDx += details.delta.dx;
                    final next = (_dragStartWeight - _dragTotalDx / 14.0).clamp(
                      _minKg,
                      _maxKg,
                    );
                    final rounded = double.parse(next.toStringAsFixed(1));
                    if (rounded != _weightKg) {
                      setState(() => _weightKg = rounded);
                    }
                  },
                  child: Container(
                    height: 168,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 1.05),
                        radius: 1.0,
                        colors: [
                          MetaGymTheme.brandOrange.withValues(
                            alpha: isLight ? 0.12 : 0.16,
                          ),
                          colors.surfaceRaised,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _ArcWeightDialPainter(
                              weightKg: _weightKg,
                              minKg: _minKg,
                              maxKg: _maxKg,
                              outerRingColor: colors.border,
                              innerDiscColor: colors.surface,
                              majorTickColor: colors.textPrimary,
                              minorTickColor: colors.textSecondary.withValues(
                                alpha: 0.45,
                              ),
                              labelColor: colors.textSecondary,
                              needleColor: MetaGymTheme.brandOrange,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 12,
                          child: IgnorePointer(
                            child: Column(
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _weightKg.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 31,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.6,
                                          height: 1.0,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' kg',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  key: const Key('weight-dial-value'),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatWeightLbs(_weightKg),
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Live 4-Zone BMI Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chỉ số BMI (Cao ${widget.referenceHeightCm.round()} cm)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${bmi.bmi.toStringAsFixed(1)} · ${bmi.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: bmiColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dotLeft =
                              (constraints.maxWidth * bmi.barFraction - 7)
                                  .clamp(0.0, constraints.maxWidth - 14);
                          return SizedBox(
                            height: 14,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: const LinearGradient(
                                      stops: [
                                        0.0,
                                        0.24,
                                        0.24,
                                        0.60,
                                        0.60,
                                        0.82,
                                        0.82,
                                        1.0,
                                      ],
                                      colors: [
                                        Color(0xFF56A8F5),
                                        Color(0xFF56A8F5),
                                        Color(0xFF2ECC71),
                                        Color(0xFF2ECC71),
                                        Color(0xFFF5A623),
                                        Color(0xFFF5A623),
                                        Color(0xFFF15B64),
                                        Color(0xFFF15B64),
                                      ],
                                    ),
                                  ),
                                ),
                                AnimatedPositioned(
                                  duration: disableAnimations
                                      ? Duration.zero
                                      : const Duration(milliseconds: 100),
                                  left: dotLeft,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: MetaGymTheme.brandOrange,
                                        width: 2.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x80000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: Text(
                                const [
                                  'Thiếu cân',
                                  'Bình thường',
                                  'Thừa cân',
                                  'Béo phì',
                                ][i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: i == 0
                                    ? TextAlign.left
                                    : i == 3
                                    ? TextAlign.right
                                    : TextAlign.center,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StepChipButton(
                        key: const Key('weight-step-minus-1'),
                        label: '− 1 kg',
                        onTap: () => _step(-1.0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StepChipButton(
                        key: const Key('weight-step-minus-01'),
                        label: '− 0.1',
                        onTap: () => _step(-0.1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StepChipButton(
                        key: const Key('weight-step-plus-01'),
                        label: '+ 0.1',
                        onTap: () => _step(0.1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StepChipButton(
                        key: const Key('weight-step-plus-1'),
                        label: '+ 1 kg',
                        onTap: () => _step(1.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            backgroundColor: colors.surfaceRaised,
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton(
                          key: const Key('weight-dial-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(_weightKg),
                          child: const Text(
                            'Xác nhận',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final child = Center(
      child: Padding(padding: const EdgeInsets.all(16), child: sheet),
    );
    if (disableAnimations ||
        MetaGymSurfacePreferences.reduceBlurOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return child;
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: child,
    );
  }
}

class _OlympicBarbellPainter extends CustomPainter {
  const _OlympicBarbellPainter({required this.plates});

  final List<_PlateSpec> plates;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300.0;
    final sy = size.height / 68.0;
    canvas.save();
    canvas.scale(sx, sy);

    // Steel bar, knurling sleeve, and inner collars
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 31, 260, 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6F7787),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(92, 29, 116, 10),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF8C95A6),
    );
    final collarPaint = Paint()..color = const Color(0xFFE8EDF5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(86, 24, 7, 20),
        const Radius.circular(2),
      ),
      collarPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(207, 24, 7, 20),
        const Radius.circular(2),
      ),
      collarPaint,
    );

    var leftX = 84.0;
    var rightX = 216.0;
    for (final plate in plates) {
      leftX -= (plate.thickness + 2);
      final topY = (68.0 - plate.height) / 2.0;
      final fillPaint = Paint()..color = plate.fill;
      final strokePaint = Paint()
        ..color = plate.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final leftRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, topY, plate.thickness, plate.height),
        const Radius.circular(3),
      );
      canvas.drawRRect(leftRect, fillPaint);
      canvas.drawRRect(leftRect, strokePaint);

      final rightRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rightX, topY, plate.thickness, plate.height),
        const Radius.circular(3),
      );
      canvas.drawRRect(rightRect, fillPaint);
      canvas.drawRRect(rightRect, strokePaint);
      rightX += (plate.thickness + 2);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OlympicBarbellPainter oldDelegate) =>
      oldDelegate.plates.length != plates.length ||
      !_samePlates(oldDelegate.plates, plates);

  bool _samePlates(List<_PlateSpec> a, List<_PlateSpec> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].weight != b[i].weight) return false;
    }
    return true;
  }
}

class _ArcWeightDialPainter extends CustomPainter {
  const _ArcWeightDialPainter({
    required this.weightKg,
    required this.minKg,
    required this.maxKg,
    required this.outerRingColor,
    required this.innerDiscColor,
    required this.majorTickColor,
    required this.minorTickColor,
    required this.labelColor,
    required this.needleColor,
  });

  final double weightKg;
  final double minKg;
  final double maxKg;
  final Color outerRingColor;
  final Color innerDiscColor;
  final Color majorTickColor;
  final Color minorTickColor;
  final Color labelColor;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height + 54.0;
    final rOuter = math.min(size.width * 0.57, 186.0);
    final rInner = rOuter - 50.0;

    canvas.drawCircle(
      Offset(cx, cy),
      rOuter,
      Paint()
        ..color = outerRingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      rInner,
      Paint()
        ..color = innerDiscColor.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      rInner,
      Paint()
        ..color = outerRingColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    const degPerKg = 5.2;
    final startTick = math.max(
      (minKg * 10).round(),
      ((weightKg - 10) * 10).floor(),
    );
    final endTick = math.min(
      (maxKg * 10).round(),
      ((weightKg + 10) * 10).ceil(),
    );

    final majorPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = minorTickColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var t = startTick; t <= endTick; t++) {
      final kg = t / 10.0;
      final angleDeg = (kg - weightKg) * degPerKg;
      if (angleDeg.abs() > 46) continue;
      final rad = (angleDeg - 90.0) * math.pi / 180.0;
      final isMajor = t % 10 == 0;
      final isHalf = !isMajor && t % 5 == 0;
      final len = isMajor ? 22.0 : (isHalf ? 14.0 : 7.0);
      final p1 = Offset(
        cx + math.cos(rad) * (rOuter - 4),
        cy + math.sin(rad) * (rOuter - 4),
      );
      final p2 = Offset(
        cx + math.cos(rad) * (rOuter - 4 - len),
        cy + math.sin(rad) * (rOuter - 4 - len),
      );
      canvas.drawLine(p1, p2, isMajor ? majorPaint : minorPaint);

      if (isMajor && t % 20 == 0) {
        final labelPos = Offset(
          cx + math.cos(rad) * (rOuter - 38),
          cy + math.sin(rad) * (rOuter - 38),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: kg.toStringAsFixed(0),
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: MetaGymTheme.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2),
        );
      }
    }

    // Center coral pointer triangle + indicator shaft
    final pointer = Path()
      ..moveTo(cx, 25)
      ..lineTo(cx - 6, 11)
      ..lineTo(cx + 6, 11)
      ..close();
    canvas.drawPath(pointer, Paint()..color = needleColor);
    canvas.drawLine(
      Offset(cx, 22),
      Offset(cx, 62),
      Paint()
        ..color = needleColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcWeightDialPainter oldDelegate) =>
      oldDelegate.weightKg != weightKg ||
      oldDelegate.outerRingColor != outerRingColor;
}

class _StepChipButton extends StatelessWidget {
  const _StepChipButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
