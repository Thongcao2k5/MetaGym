import 'dart:ui' as ui;

import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Target muscle-group / training focus displayed on the 1-person anatomy tile.
enum MuscleFocus {
  chest,
  shoulders,
  back,
  arms,
  core,
  legs,
  glutes,
  upper,
  full,
  cardio,
  none,
}

/// Ordered muscle regions selectable in personal training & workouts.
const List<MuscleFocus> selectableMuscleFocuses = [
  MuscleFocus.chest,
  MuscleFocus.shoulders,
  MuscleFocus.back,
  MuscleFocus.arms,
  MuscleFocus.core,
  MuscleFocus.legs,
  MuscleFocus.glutes,
  MuscleFocus.full,
  MuscleFocus.cardio,
];

/// Returns the short Vietnamese display label for [focus].
String muscleFocusLabel(MuscleFocus focus) => switch (focus) {
  MuscleFocus.chest => 'Ngực',
  MuscleFocus.shoulders => 'Vai',
  MuscleFocus.back => 'Lưng · Xô',
  MuscleFocus.arms => 'Tay',
  MuscleFocus.core => 'Bụng',
  MuscleFocus.legs => 'Chân · Đùi',
  MuscleFocus.glutes => 'Mông',
  MuscleFocus.upper => 'Thân trên',
  MuscleFocus.full => 'Toàn thân',
  MuscleFocus.cardio => 'Cardio',
  MuscleFocus.none => 'Mặc định',
};

/// Serializes [focus] into a stable storage key, or `null` for `none`.
String? muscleFocusKey(MuscleFocus focus) =>
    focus == MuscleFocus.none ? null : focus.name;

/// Serializes a set of [MuscleFocus] items into a compact storage key string.
String? serializeMuscleFocuses(Iterable<MuscleFocus> focuses) {
  final list = focuses
      .where((item) => item != MuscleFocus.none)
      .map((item) => item.name)
      .toSet()
      .toList();
  if (list.isEmpty) return null;
  return list.join(',');
}

/// Parses a single key string into [MuscleFocus].
MuscleFocus muscleFocusFromKey(String? key) {
  if (key == null || key.trim().isEmpty) return MuscleFocus.none;
  final first = key.split(',').first.trim().toLowerCase();
  for (final value in MuscleFocus.values) {
    if (value.name == first) return value;
  }
  return MuscleFocus.none;
}

/// Parses a stored comma-separated focus key string into a set of [MuscleFocus].
Set<MuscleFocus> parseMuscleFocusSet(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final result = <MuscleFocus>{};
  for (final token in raw.split(',')) {
    final normalized = token.trim().toLowerCase();
    for (final value in MuscleFocus.values) {
      if (value != MuscleFocus.none && value.name == normalized) {
        result.add(value);
      }
    }
  }
  return result;
}

/// Infers all active [MuscleFocus] targets from an explicit key, title, exercises, or muscles.
Set<MuscleFocus> resolveMuscleFocusSet(
  String? title, {
  List<String> exerciseNames = const [],
  List<String> targetMuscles = const [],
  String? explicitKey,
}) {
  final explicit = parseMuscleFocusSet(explicitKey);
  if (explicit.isNotEmpty) return explicit;

  final combined = [
    if (title != null && title.trim().isNotEmpty) title.trim(),
    ...targetMuscles,
    ...exerciseNames,
  ].join(' ').toLowerCase();
  if (combined.isEmpty) return const {};

  final matched = <MuscleFocus>{};
  if (combined.contains('toàn thân') || combined.contains('full body')) {
    matched.add(MuscleFocus.full);
  }
  if (combined.contains('cardio') ||
      combined.contains('hiit') ||
      combined.contains('tim mạch') ||
      combined.contains('chạy bộ') ||
      combined.contains('đạp xe')) {
    matched.add(MuscleFocus.cardio);
  }
  if (combined.contains('thân trên') || combined.contains('upper')) {
    matched.add(MuscleFocus.upper);
  }
  if (combined.contains('ngực') ||
      combined.contains('chest') ||
      combined.contains('bench')) {
    matched.add(MuscleFocus.chest);
  }
  if (combined.contains('vai') ||
      combined.contains('shoulder') ||
      combined.contains('delt')) {
    matched.add(MuscleFocus.shoulders);
  }
  if (combined.contains('lưng') ||
      combined.contains('xô') ||
      combined.contains('back') ||
      combined.contains('lat') ||
      combined.contains('pull') ||
      combined.contains('row')) {
    matched.add(MuscleFocus.back);
  }
  if (combined.contains('tay') ||
      combined.contains('bicep') ||
      combined.contains('tricep') ||
      combined.contains('arm')) {
    matched.add(MuscleFocus.arms);
  }
  if (combined.contains('bụng') ||
      combined.contains('core') ||
      combined.contains('abs') ||
      combined.contains('plank')) {
    matched.add(MuscleFocus.core);
  }
  if (combined.contains('mông') ||
      combined.contains('glute') ||
      combined.contains('hip thrust')) {
    matched.add(MuscleFocus.glutes);
  }
  if (combined.contains('chân') ||
      combined.contains('đùi') ||
      combined.contains('leg') ||
      combined.contains('squat') ||
      combined.contains('quad') ||
      combined.contains('bắp chân')) {
    matched.add(MuscleFocus.legs);
  }
  return matched;
}

/// Primary [MuscleFocus] resolved from [title] and optional exercise/muscle metadata.
MuscleFocus resolveMuscleFocus(
  String? title, {
  List<String> exerciseNames = const [],
  List<String> targetMuscles = const [],
  String? explicitKey,
}) {
  final set = resolveMuscleFocusSet(
    title,
    exerciseNames: exerciseNames,
    targetMuscles: targetMuscles,
    explicitKey: explicitKey,
  );
  if (set.isEmpty) return MuscleFocus.none;
  return set.first;
}

/// Returns `true` when [targets] should face the posterior (back) side.
///
/// Front muscles (chest, core, front shoulders) keep the front facing view;
/// posterior muscles (back/lats, glutes) flip to the back facing view unless
/// chest is explicitly highlighted.
bool isPosteriorMuscleView(Set<MuscleFocus> targets) {
  if (targets.isEmpty) return false;
  if (targets.contains(MuscleFocus.chest) ||
      targets.contains(MuscleFocus.core) ||
      targets.contains(MuscleFocus.full) ||
      targets.contains(MuscleFocus.cardio) ||
      targets.contains(MuscleFocus.upper)) {
    return false;
  }
  return targets.contains(MuscleFocus.back) ||
      targets.contains(MuscleFocus.glutes);
}

/// Human-readable label summarizing one or more selected [targets].
String summarizeMuscleFocuses(Set<MuscleFocus> targets) {
  final valid = targets.where((item) => item != MuscleFocus.none).toList();
  if (valid.isEmpty) return muscleFocusLabel(MuscleFocus.none);
  return valid.map(muscleFocusLabel).join(' · ');
}

/// Compact dark-studio 1-person full-body thumbnail highlighting target muscles.
class MuscleAnatomyTile extends StatelessWidget {
  const MuscleAnatomyTile({
    this.focus = MuscleFocus.none,
    this.focuses,
    this.width = 58,
    this.height = 68,
    this.isUpcoming = true,
    this.selected = false,
    super.key,
  });

  final MuscleFocus focus;
  final Set<MuscleFocus>? focuses;
  final double width;
  final double height;
  final bool isUpcoming;
  final bool selected;

  Set<MuscleFocus> get _resolvedTargets {
    if (focuses != null && focuses!.isNotEmpty) {
      return focuses!.where((item) => item != MuscleFocus.none).toSet();
    }
    if (focus != MuscleFocus.none) return {focus};
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final targets = _resolvedTargets;
    final hasFocus = targets.isNotEmpty;
    final radius = width <= 48 ? 11.0 : 14.0;
    return Opacity(
      opacity: isUpcoming ? 1.0 : 0.72,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2230), Color(0xFF12161F)],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            width: selected ? 1.6 : 1.0,
            color: selected
                ? MetaGymTheme.brandOrange
                : hasFocus && isUpcoming
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                : const Color(0xFF2B3547),
          ),
          boxShadow: (selected || isUpcoming)
              ? [
                  BoxShadow(
                    color: selected
                        ? MetaGymTheme.brandOrange.withValues(alpha: 0.24)
                        : const Color(0x59000000),
                    blurRadius: selected ? 14 : 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(
          size: Size(width - 6, height - 6),
          painter: _UnifiedAnatomyPainter(targets),
        ),
      ),
    );
  }
}

/// Interactive multi-group muscle selector with live 1-person preview card.
class MuscleFocusPicker extends StatelessWidget {
  const MuscleFocusPicker({
    required this.selectedKey,
    required this.onSelected,
    this.inferredTargets = const {},
    super.key,
  });

  final String? selectedKey;
  final ValueChanged<String?> onSelected;
  final Set<MuscleFocus> inferredTargets;

  void _toggleMuscle(Set<MuscleFocus> current, MuscleFocus toggled) {
    if (toggled == MuscleFocus.full || toggled == MuscleFocus.cardio) {
      if (current.length == 1 && current.contains(toggled)) {
        onSelected(null);
      } else {
        onSelected(toggled.name);
      }
      return;
    }

    final next = {...current}
      ..remove(MuscleFocus.full)
      ..remove(MuscleFocus.cardio)
      ..remove(MuscleFocus.none);

    if (next.contains(toggled)) {
      next.remove(toggled);
    } else {
      next.add(toggled);
    }
    onSelected(serializeMuscleFocuses(next));
  }

  @override
  Widget build(BuildContext context) {
    final explicitTargets = parseMuscleFocusSet(selectedKey);
    final previewTargets = explicitTargets.isNotEmpty
        ? explicitTargets
        : inferredTargets;
    final viewLabel = previewTargets.isEmpty
        ? 'Mặc định (Toàn thân)'
        : '${summarizeMuscleFocuses(previewTargets)} · ${isPosteriorMuscleView(previewTargets) ? 'Mặt sau' : 'Mặt trước'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MuscleAnatomyTile(
              focuses: previewTargets,
              width: 54,
              height: 64,
              selected: previewTargets.isNotEmpty,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biểu tượng card tập',
                    style: TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    viewLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: previewTargets.isNotEmpty
                          ? MetaGymTheme.brandOrange
                          : MetaGymTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (explicitTargets.isNotEmpty)
              TextButton(
                onPressed: () => onSelected(null),
                child: const Text(
                  'Mặc định',
                  style: TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final focus in selectableMuscleFocuses)
              _MuscleChoiceChip(
                label: muscleFocusLabel(focus),
                selected: explicitTargets.contains(focus),
                inferred:
                    explicitTargets.isEmpty && inferredTargets.contains(focus),
                onTap: () => _toggleMuscle(explicitTargets, focus),
              ),
          ],
        ),
      ],
    );
  }
}

class _MuscleChoiceChip extends StatelessWidget {
  const _MuscleChoiceChip({
    required this.label,
    required this.selected,
    required this.inferred,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool inferred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected || inferred;
    return Material(
      color: Colors.transparent,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.20)
                : inferred
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.10)
                : MetaGymTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? MetaGymTheme.brandOrange
                  : active
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                  : MetaGymTheme.cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? MetaGymTheme.textPrimary
                  : active
                  ? const Color(0xFFFFB099)
                  : MetaGymTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders 1 detailed, sculpted head-to-toe anatomical athlete (front or back).
class _UnifiedAnatomyPainter extends CustomPainter {
  const _UnifiedAnatomyPainter(this.targets);

  final Set<MuscleFocus> targets;

  static const _lineColor = Color(0xFF536685);
  static const _hotStroke = Color(0xFFFFA58A);

  bool _has(MuscleFocus focus) => targets.contains(focus);

  bool get _full => _has(MuscleFocus.full);
  bool get _upper => _has(MuscleFocus.upper);
  bool get _chest => _has(MuscleFocus.chest) || _upper || _full;
  bool get _shoulders => _has(MuscleFocus.shoulders) || _upper || _full;
  bool get _arms => _has(MuscleFocus.arms) || _upper || _full;
  bool get _core => _has(MuscleFocus.core) || _full;
  bool get _back => _has(MuscleFocus.back) || _full;
  bool get _glutes => _has(MuscleFocus.glutes) || _full;
  bool get _legs => _has(MuscleFocus.legs) || _full;
  bool get _cardio => _has(MuscleFocus.cardio);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80.0, size.height / 92.0);

    final baseFill = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(20, 8),
        const Offset(60, 86),
        const [Color(0xFF394861), Color(0xFF2B374B)],
      )
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..strokeJoin = StrokeJoin.round;
    final hotFill = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(18, 18),
        const Offset(62, 80),
        const [Color(0xFFFF7D57), Color(0xFFFF5E36), Color(0xFFD94420)],
        const [0.0, 0.55, 1.0],
      )
      ..style = PaintingStyle.fill;
    final hotStroke = Paint()
      ..color = _hotStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round;
    final subtleFiber = Paint()
      ..color = const Color(0x4D12161F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round;
    final slateDetail = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round;

    void drawMuscle(Path path, {bool hot = false}) {
      canvas.drawPath(path, hot ? hotFill : baseFill);
      canvas.drawPath(path, hot ? hotStroke : baseStroke);
    }

    if (isPosteriorMuscleView(targets)) {
      _paintBackPerson(
        canvas,
        drawMuscle,
        subtleFiber: subtleFiber,
        slateDetail: slateDetail,
      );
    } else {
      _paintFrontPerson(
        canvas,
        drawMuscle,
        subtleFiber: subtleFiber,
        slateDetail: slateDetail,
      );
    }

    canvas.restore();
  }

  Path _mirrored(Path left) {
    final matrix = Matrix4.identity()
      ..translateByDouble(80.0, 0.0, 0.0, 1.0)
      ..scaleByDouble(-1.0, 1.0, 1.0, 1.0);
    return left.transform(matrix.storage);
  }

  void _drawSymmetric(
    void Function(Path, {bool hot}) drawMuscle,
    Path left, {
    bool hot = false,
  }) {
    drawMuscle(left, hot: hot);
    drawMuscle(_mirrored(left), hot: hot);
  }

  void _paintHead(void Function(Path, {bool hot}) drawMuscle) {
    final head = Path()
      ..moveTo(40, 4.2)
      ..cubicTo(43.8, 4.2, 45.6, 7.0, 45.2, 10.6)
      ..cubicTo(45.0, 13.4, 43.2, 16.2, 40.0, 16.8)
      ..cubicTo(36.8, 16.2, 35.0, 13.4, 34.8, 10.6)
      ..cubicTo(34.4, 7.0, 36.2, 4.2, 40, 4.2)
      ..close();
    drawMuscle(head);
  }

  void _paintSculptedArms(
    Canvas canvas,
    void Function(Path, {bool hot}) drawMuscle, {
    required bool hotArms,
    required Paint subtleFiber,
    required Paint slateDetail,
  }) {
    // Upper arm (bicep/tricep belly)
    final upperArm = Path()
      ..moveTo(20.0, 29.8)
      ..cubicTo(17.2, 33.2, 16.4, 37.2, 17.5, 41.2)
      ..lineTo(22.4, 41.6)
      ..cubicTo(24.2, 37.8, 25.0, 34.0, 25.4, 30.8)
      ..close();
    _drawSymmetric(drawMuscle, upperArm, hot: hotArms);

    // Forearm tapering smoothly into wrist
    final forearm = Path()
      ..moveTo(17.3, 41.5)
      ..cubicTo(13.8, 44.5, 13.0, 48.2, 12.2, 52.8)
      ..lineTo(15.6, 53.6)
      ..cubicTo(18.0, 49.4, 20.6, 45.6, 22.2, 42.0)
      ..close();
    _drawSymmetric(drawMuscle, forearm, hot: hotArms);

    // Hand (remains dark slate so hands never look blocky)
    final hand = Path()
      ..moveTo(12.2, 52.8)
      ..lineTo(10.6, 56.4)
      ..lineTo(13.2, 58.2)
      ..lineTo(15.8, 55.6)
      ..lineTo(15.6, 53.6)
      ..close();
    _drawSymmetric(drawMuscle, hand);

    final fiber = hotArms ? subtleFiber : slateDetail;
    canvas.drawLine(const Offset(19.2, 33.5), const Offset(19.6, 39.2), fiber);
    canvas.drawLine(const Offset(60.8, 33.5), const Offset(60.4, 39.2), fiber);
    canvas.drawLine(const Offset(16.2, 44.5), const Offset(14.6, 50.5), fiber);
    canvas.drawLine(const Offset(63.8, 44.5), const Offset(65.4, 50.5), fiber);
  }

  void _paintFrontPerson(
    Canvas canvas,
    void Function(Path, {bool hot}) drawMuscle, {
    required Paint subtleFiber,
    required Paint slateDetail,
  }) {
    _paintHead(drawMuscle);

    // Sculpted neck + collar trapezius base
    drawMuscle(
      Path()
        ..moveTo(36.2, 16.4)
        ..lineTo(34.8, 20.4)
        ..lineTo(26.8, 23.0)
        ..lineTo(40.0, 23.8)
        ..lineTo(53.2, 23.0)
        ..lineTo(45.2, 20.4)
        ..lineTo(43.8, 16.4)
        ..close(),
    );
    canvas.drawLine(
      const Offset(36.8, 17.5),
      const Offset(40, 22.4),
      slateDetail,
    );
    canvas.drawLine(
      const Offset(43.2, 17.5),
      const Offset(40, 22.4),
      slateDetail,
    );

    // Rounded Deltoids (matching sculpted reference)
    final delt = Path()
      ..moveTo(26.8, 23.0)
      ..cubicTo(20.4, 22.8, 17.8, 26.2, 18.8, 31.0)
      ..cubicTo(21.4, 31.6, 24.4, 30.2, 26.2, 27.6)
      ..close();
    _drawSymmetric(drawMuscle, delt, hot: _shoulders);
    final deltLine = Path()
      ..moveTo(23.5, 24.4)
      ..cubicTo(21.4, 26.8, 21.2, 29.0, 22.0, 30.8);
    final deltPaint = _shoulders ? subtleFiber : slateDetail;
    canvas.drawPath(deltLine, deltPaint);
    canvas.drawPath(_mirrored(deltLine), deltPaint);

    // Sculpted Pectorals with curved lower chest contour
    final pec = Path()
      ..moveTo(26.8, 23.2)
      ..lineTo(39.2, 23.4)
      ..lineTo(39.2, 33.8)
      ..cubicTo(34.2, 35.0, 27.4, 33.6, 25.8, 29.2)
      ..cubicTo(25.4, 27.0, 25.8, 25.0, 26.8, 23.2)
      ..close();
    _drawSymmetric(drawMuscle, pec, hot: _chest);
    final pecFiber = _chest ? subtleFiber : slateDetail;
    canvas.drawLine(
      const Offset(28.5, 27.2),
      const Offset(37.5, 28.4),
      pecFiber,
    );
    canvas.drawLine(
      const Offset(51.5, 27.2),
      const Offset(42.5, 28.4),
      pecFiber,
    );

    // Sculpted waist/obliques torso frame
    drawMuscle(
      Path()
        ..moveTo(26.2, 30.8)
        ..cubicTo(28.5, 34.4, 34.0, 35.4, 40.0, 35.0)
        ..cubicTo(46.0, 35.4, 51.5, 34.4, 53.8, 30.8)
        ..cubicTo(52.4, 37.8, 51.2, 44.5, 50.2, 51.2)
        ..lineTo(40.0, 54.0)
        ..lineTo(29.8, 51.2)
        ..cubicTo(28.8, 44.5, 27.6, 37.8, 26.2, 30.8)
        ..close(),
    );

    // Individual sculpted 6-pack abs & obliques (so even full-body looks sculpted!)
    const abTops = [35.8, 40.4, 44.8];
    const abBottoms = [39.6, 44.1, 49.4];
    for (var row = 0; row < 3; row++) {
      final top = abTops[row];
      final bottom = abBottoms[row];
      final leftEdge = 33.6 + row * 0.55;
      final pad = Path()
        ..moveTo(leftEdge, top + 0.4)
        ..cubicTo(36.0, top, 38.2, top + 0.2, 39.2, top + 0.6)
        ..lineTo(39.2, bottom - 0.3)
        ..cubicTo(
          37.4,
          bottom + 0.4,
          35.2,
          bottom + 0.1,
          leftEdge + 0.4,
          bottom - 0.5,
        )
        ..close();
      _drawSymmetric(drawMuscle, pad, hot: _core);
    }

    // Serratus / oblique flank ribs
    final oblique = Path()
      ..moveTo(28.0, 34.6)
      ..lineTo(32.0, 36.8)
      ..lineTo(32.6, 48.8)
      ..lineTo(30.4, 50.4)
      ..cubicTo(29.2, 44.8, 28.4, 39.6, 28.0, 34.6)
      ..close();
    _drawSymmetric(drawMuscle, oblique, hot: _core);

    _paintSculptedArms(
      canvas,
      drawMuscle,
      hotArms: _arms,
      subtleFiber: subtleFiber,
      slateDetail: slateDetail,
    );

    // Hip / Athletic Pelvis
    drawMuscle(
      Path()
        ..moveTo(29.8, 51.2)
        ..lineTo(40.0, 54.0)
        ..lineTo(50.2, 51.2)
        ..lineTo(51.8, 56.8)
        ..lineTo(40.0, 59.8)
        ..lineTo(28.2, 56.8)
        ..close(),
    );

    // Sculpted Quadriceps (sweeping outer curve + vastus medialis teardrop)
    final quad = Path()
      ..moveTo(28.2, 56.8)
      ..cubicTo(25.0, 62.0, 26.0, 68.5, 29.2, 72.5)
      ..lineTo(36.6, 72.5)
      ..cubicTo(38.4, 68.4, 39.0, 64.0, 39.0, 59.5)
      ..close();
    _drawSymmetric(drawMuscle, quad, hot: _legs);

    final quadSweep = Path()
      ..moveTo(31.2, 58.6)
      ..cubicTo(30.2, 63.4, 31.0, 67.8, 32.8, 71.2);
    final quadPaint = _legs ? subtleFiber : slateDetail;
    canvas.drawPath(quadSweep, quadPaint);
    canvas.drawPath(_mirrored(quadSweep), quadPaint);

    // Knees
    final knee = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(32.8, 74.2),
          width: 6.2,
          height: 3.4,
        ),
      );
    _drawSymmetric(drawMuscle, knee);

    // Sculpted Gastrocnemius Calves
    final calf = Path()
      ..moveTo(29.2, 75.8)
      ..cubicTo(27.0, 78.8, 27.8, 82.4, 30.2, 85.8)
      ..lineTo(35.0, 85.8)
      ..cubicTo(36.4, 82.2, 36.8, 78.6, 36.2, 75.8)
      ..close();
    _drawSymmetric(drawMuscle, calf, hot: _legs);

    // Feet
    final foot = Path()
      ..moveTo(30.2, 85.8)
      ..lineTo(27.5, 89.0)
      ..lineTo(35.6, 89.0)
      ..lineTo(35.0, 85.8)
      ..close();
    _drawSymmetric(drawMuscle, foot);

    if (_cardio) {
      final pulse = Path()
        ..moveTo(23.5, 32.5)
        ..lineTo(30.5, 32.5)
        ..lineTo(34.2, 24.0)
        ..lineTo(39.4, 39.6)
        ..lineTo(44.0, 26.8)
        ..lineTo(47.4, 32.5)
        ..lineTo(56.5, 32.5);
      canvas.drawPath(
        pulse,
        Paint()
          ..color = MetaGymTheme.brandOrange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        pulse,
        Paint()
          ..color = _hotStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintBackPerson(
    Canvas canvas,
    void Function(Path, {bool hot}) drawMuscle, {
    required Paint subtleFiber,
    required Paint slateDetail,
  }) {
    _paintHead(drawMuscle);

    // Back of neck + hairline arch
    drawMuscle(
      Path()
        ..moveTo(36.2, 16.4)
        ..lineTo(34.8, 21.0)
        ..lineTo(45.2, 21.0)
        ..lineTo(43.8, 16.4)
        ..close(),
    );
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(40, 10.2), width: 9.2, height: 10.0),
      3.55,
      2.3,
      false,
      slateDetail,
    );

    // Sculpted Left & Right Trapezius (separated down the spine)
    final trap = Path()
      ..moveTo(35.2, 20.6)
      ..lineTo(27.0, 23.2)
      ..cubicTo(31.5, 27.6, 35.8, 30.8, 39.2, 32.2)
      ..lineTo(39.2, 21.2)
      ..close();
    _drawSymmetric(drawMuscle, trap, hot: _back);

    // Posterior Deltoids
    final rearDelt = Path()
      ..moveTo(27.0, 23.2)
      ..cubicTo(20.6, 22.8, 17.8, 26.2, 18.8, 31.0)
      ..cubicTo(21.4, 31.6, 24.4, 30.2, 26.4, 27.4)
      ..close();
    _drawSymmetric(drawMuscle, rearDelt, hot: _shoulders);

    // Spine groove / Lower-back base
    drawMuscle(
      Path()
        ..moveTo(30.2, 31.5)
        ..lineTo(49.8, 31.5)
        ..lineTo(50.2, 52.0)
        ..lineTo(29.8, 52.0)
        ..close(),
    );

    // Sculpted Wing Lats (wide sweep tapering neatly to spine fascia)
    final lat = Path()
      ..moveTo(26.8, 24.8)
      ..cubicTo(24.0, 32.2, 26.2, 40.4, 30.6, 46.2)
      ..cubicTo(33.8, 47.6, 36.8, 48.2, 38.6, 48.2)
      ..lineTo(38.6, 32.0)
      ..cubicTo(34.5, 30.2, 30.6, 27.8, 26.8, 24.8)
      ..close();
    _drawSymmetric(drawMuscle, lat, hot: _back);

    final latFiber = _back ? subtleFiber : slateDetail;
    canvas.drawLine(
      const Offset(28.5, 32.5),
      const Offset(36.2, 36.2),
      latFiber,
    );
    canvas.drawLine(
      const Offset(51.5, 32.5),
      const Offset(43.8, 36.2),
      latFiber,
    );
    canvas.drawLine(
      const Offset(40, 21.2),
      const Offset(40, 51.2),
      slateDetail,
    );

    _paintSculptedArms(
      canvas,
      drawMuscle,
      hotArms: _arms,
      subtleFiber: subtleFiber,
      slateDetail: slateDetail,
    );

    // Sculpted Glutes (rounded gluteus maximus halves)
    final glute = Path()
      ..moveTo(29.6, 52.0)
      ..cubicTo(26.2, 55.2, 26.4, 60.6, 30.0, 62.6)
      ..cubicTo(34.2, 64.0, 38.6, 62.4, 39.2, 59.0)
      ..lineTo(39.2, 52.0)
      ..close();
    _drawSymmetric(drawMuscle, glute, hot: _glutes);

    // Hamstrings
    final ham = Path()
      ..moveTo(28.6, 62.0)
      ..cubicTo(27.0, 66.4, 27.6, 70.6, 29.6, 73.6)
      ..lineTo(36.6, 73.6)
      ..cubicTo(38.0, 69.6, 38.6, 65.4, 38.6, 61.5)
      ..close();
    _drawSymmetric(drawMuscle, ham, hot: _glutes || _legs);

    // Back knee-pit crease
    canvas.drawLine(
      const Offset(30.4, 74.2),
      const Offset(35.8, 74.2),
      slateDetail,
    );
    canvas.drawLine(
      const Offset(44.2, 74.2),
      const Offset(49.6, 74.2),
      slateDetail,
    );

    // Diamond Calves & Feet
    final calf = Path()
      ..moveTo(29.6, 74.8)
      ..cubicTo(27.4, 78.2, 28.0, 82.2, 30.2, 85.8)
      ..lineTo(35.0, 85.8)
      ..cubicTo(36.4, 82.0, 36.8, 78.2, 36.2, 74.8)
      ..close();
    _drawSymmetric(drawMuscle, calf, hot: _legs);

    final foot = Path()
      ..moveTo(30.2, 85.8)
      ..lineTo(27.5, 89.0)
      ..lineTo(35.6, 89.0)
      ..lineTo(35.0, 85.8)
      ..close();
    _drawSymmetric(drawMuscle, foot);
  }

  @override
  bool shouldRepaint(_UnifiedAnatomyPainter oldDelegate) =>
      oldDelegate.targets.length != targets.length ||
      !oldDelegate.targets.containsAll(targets);
}
