import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

String _fmtMetricNum(double val) => val == val.roundToDouble()
    ? val.toInt().toString()
    : val.toStringAsFixed(1);

class _PlateSpec {
  const _PlateSpec({
    required this.weight,
    required this.label,
    required this.height,
    required this.thickness,
    required this.fill,
    required this.stroke,
  });

  final double weight;
  final String label;
  final double height;
  final double thickness;
  final Color fill;
  final Color stroke;
}

const List<_PlateSpec> _kOlympicPlates = [
  _PlateSpec(
    weight: 25,
    label: '25',
    height: 50,
    thickness: 10,
    fill: Color(0xFFFF5E36),
    stroke: Color(0xFFFF9276),
  ),
  _PlateSpec(
    weight: 20,
    label: '20',
    height: 46,
    thickness: 9,
    fill: Color(0xFF56A8F5),
    stroke: Color(0xFF9ED0FF),
  ),
  _PlateSpec(
    weight: 10,
    label: '10',
    height: 38,
    thickness: 7,
    fill: Color(0xFFC4CCDA),
    stroke: Color(0xFFFFFFFF),
  ),
  _PlateSpec(
    weight: 5,
    label: '5',
    height: 32,
    thickness: 6,
    fill: Color(0xFFDAB066),
    stroke: Color(0xFFF5DCA6),
  ),
  _PlateSpec(
    weight: 2.5,
    label: '2.5',
    height: 25,
    thickness: 5,
    fill: Color(0xFF3B4252),
    stroke: Color(0xFF8E95A5),
  ),
  _PlateSpec(
    weight: 1.25,
    label: '1.25',
    height: 20,
    thickness: 4,
    fill: Color(0xFF2B303C),
    stroke: Color(0xFF6E778A),
  ),
];

List<_PlateSpec> _resolvePlatesPerSide(double weightKg) {
  var rem = math.max(0.0, (weightKg - 20.0) / 2.0);
  final chosen = <_PlateSpec>[];
  for (final plate in _kOlympicPlates) {
    while (rem >= plate.weight - 0.01 && chosen.length < 6) {
      chosen.add(plate);
      rem -= plate.weight;
    }
  }
  return chosen;
}

/// Interactive Olympic Barbell & Body Fat picker sheet synced with preview 2.3/5.5.
Future<({double weightKg, double bodyFatPercent})?> showWeightBodyFatPickerSheet(
  BuildContext context, {
  double? initialWeightKg,
  double? initialBodyFatPercent,
}) {
  var weightKg = ((initialWeightKg ?? 72.4).clamp(35.0, 150.0) * 10).round() / 10;
  var bodyFat =
      ((initialBodyFatPercent ?? 16.8).clamp(5.0, 45.0) * 10).round() / 10;

  return showModalBottomSheet<({double weightKg, double bodyFatPercent})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final palette = MetaGymTheme.paletteOf(ctx);
        final plates = _resolvePlatesPerSide(weightKg);
        final plateSummary = plates.isEmpty
            ? 'Đòn 20kg'
            : '${plates.map((p) => p.label).join(' + ')} kg / bên';

        final String fatZone;
        final Color fatZoneColor;
        if (bodyFat < 12) {
          fatZone = 'Vận động viên';
          fatZoneColor = palette.primaryText;
        } else if (bodyFat <= 20) {
          fatZone = 'Chuẩn Gym';
          fatZoneColor = palette.success;
        } else {
          fatZone = 'Cần siết mỡ';
          fatZoneColor = palette.warning;
        }

        return _ModalSheetShell(
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
                          'Cân nặng & Mỡ cơ thể',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đĩa tạ Olympic & Tỷ lệ mỡ cơ thể',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SheetPill(
                    label: '± 0.1 kg',
                    color: palette.primaryText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SheetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cân nặng cơ thể',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${weightKg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 62,
                      child: CustomPaint(
                        painter: _OlympicBarbellPainter(
                          plates: plates,
                          isLight: MetaGymTheme.isLightPalette(ctx),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StepperChip(
                          key: const Key('modal-weight-minus'),
                          label: '−0.5',
                          onTap: () => setModalState(() {
                            weightKg =
                                (((weightKg - 0.5).clamp(35.0, 150.0)) * 10)
                                    .round() /
                                10;
                          }),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: _sliderTheme(ctx, MetaGymTheme.brandOrange),
                            child: Slider(
                              key: const Key('modal-weight-slider'),
                              min: 35,
                              max: 150,
                              divisions: 1150,
                              value: weightKg,
                              onChanged: (v) => setModalState(() {
                                weightKg = (v * 10).round() / 10;
                              }),
                            ),
                          ),
                        ),
                        _StepperChip(
                          key: const Key('modal-weight-plus'),
                          label: '+0.5',
                          onTap: () => setModalState(() {
                            weightKg =
                                (((weightKg + 0.5).clamp(35.0, 150.0)) * 10)
                                    .round() /
                                10;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đòn tạ 20kg + Đĩa đối xứng',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            plateSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _SheetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tỷ lệ mỡ cơ thể',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _SheetPill(label: fatZone, color: fatZoneColor),
                        const SizedBox(width: 8),
                        Text(
                          '${bodyFat.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: palette.success,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StepperChip(
                          key: const Key('modal-fat-minus'),
                          label: '−0.5',
                          onTap: () => setModalState(() {
                            bodyFat =
                                (((bodyFat - 0.5).clamp(5.0, 45.0)) * 10)
                                    .round() /
                                10;
                          }),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: _sliderTheme(ctx, palette.success),
                            child: Slider(
                              key: const Key('modal-fat-slider'),
                              min: 5,
                              max: 45,
                              divisions: 400,
                              value: bodyFat,
                              onChanged: (v) => setModalState(() {
                                bodyFat = (v * 10).round() / 10;
                              }),
                            ),
                          ),
                        ),
                        _StepperChip(
                          key: const Key('modal-fat-plus'),
                          label: '+0.5',
                          onTap: () => setModalState(() {
                            bodyFat =
                                (((bodyFat + 0.5).clamp(5.0, 45.0)) * 10)
                                    .round() /
                                10;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.borderSolid),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Huỷ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('modal-weight-apply'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop((
                          weightKg: weightKg,
                          bodyFatPercent: bodyFat,
                        )),
                        child: const Text(
                          'Áp dụng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Interactive 3-Ring Body Contour Tape Scanner synced with preview 2.3.
Future<({double chestCm, double waistCm, double hipsCm})?>
showBodyTapeScannerSheet(
  BuildContext context, {
  double? initialChestCm,
  double? initialWaistCm,
  double? initialHipsCm,
  String initialPart = 'chest',
  bool initialIsFemale = false,
}) {
  final vals = <String, double>{
    'chest': ((initialChestCm ?? (initialIsFemale ? 88 : 98)).clamp(70.0, 135.0) * 2)
            .round() /
        2,
    'waist': ((initialWaistCm ?? (initialIsFemale ? 64 : 78)).clamp(55.0, 120.0) * 2)
            .round() /
        2,
    'hip': ((initialHipsCm ?? 94).clamp(75.0, 135.0) * 2).round() / 2,
  };
  var activePart = vals.containsKey(initialPart) ? initialPart : 'chest';
  var isFemale = initialIsFemale;

  const meta = <String, ({String short, String label, double min, double max})>{
    'chest': (short: 'Ngực', label: 'Vòng ngực', min: 70, max: 135),
    'waist': (short: 'Eo', label: 'Vòng eo', min: 55, max: 120),
    'hip': (short: 'Hông', label: 'Vòng hông', min: 75, max: 135),
  };

  return showModalBottomSheet<({double chestCm, double waistCm, double hipsCm})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final palette = MetaGymTheme.paletteOf(ctx);
        Color colorFor(String part) {
          return switch (part) {
            'chest' => palette.primaryText,
            'waist' => palette.success,
            _ => palette.reflection,
          };
        }

        final cfg = meta[activePart]!;
        final activeColor = colorFor(activePart);
        final currentVal = vals[activePart]!;
        final vTaper = vals['chest']! / math.max(1.0, vals['waist']!);
        final whr = vals['waist']! / math.max(1.0, vals['hip']!);

        return _ModalSheetShell(
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
                          'Đo 3 vòng cơ thể',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chọn vòng trên hình hoặc kéo thước',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SheetPill(
                    label: isFemale
                        ? 'WHR ${whr.toStringAsFixed(2)}'
                        : 'V-Taper ${vTaper.toStringAsFixed(2)}',
                    color: palette.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Dáng người mẫu',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _GenderSegmentedPill(
                    isFemale: isFemale,
                    maleKey: const Key('tape-gender-male'),
                    femaleKey: const Key('tape-gender-female'),
                    onChanged: (female) =>
                        setModalState(() => isFemale = female),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (idx, partKey) in const ['chest', 'waist', 'hip'].indexed) ...[
                    if (idx > 0) const SizedBox(width: 8),
                    Expanded(
                      child: MetaGymTap(
                        key: Key('tape-tab-$partKey'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setModalState(() => activePart = partKey),
                        child: AnimatedContainer(
                          duration: MetaGymTheme.stateDurationOf(ctx),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: activePart == partKey
                                ? colorFor(partKey).withValues(alpha: 0.16)
                                : palette.metricPanelBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: activePart == partKey
                                  ? colorFor(partKey)
                                  : palette.metricPanelBorder,
                              width: activePart == partKey ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                meta[partKey]!.short,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_fmtMetricNum(vals[partKey]!)} cm',
                                style: TextStyle(
                                  color: activePart == partKey
                                      ? colorFor(partKey)
                                      : palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              BodyAnatomyMeasureStage(
                isFemale: isFemale,
                chestCm: vals['chest']!,
                waistCm: vals['waist']!,
                hipsCm: vals['hip']!,
                activePart: activePart,
                showCallouts: true,
                height: (MediaQuery.sizeOf(ctx).height * 0.28).clamp(
                  180.0,
                  240.0,
                ),
                borderRadius: 16,
                onTapPart: (part) => setModalState(() => activePart = part),
              ),
              const SizedBox(height: 10),
              _SheetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cfg.label,
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepperChip(
                              key: const Key('tape-minus'),
                              label: '−1',
                              onTap: () => setModalState(() {
                                vals[activePart] = (vals[activePart]! - 1)
                                    .clamp(cfg.min, cfg.max);
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${_fmtMetricNum(currentVal)} cm',
                                style: TextStyle(
                                  color: activeColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                            _StepperChip(
                              key: const Key('tape-plus'),
                              label: '+1',
                              onTap: () => setModalState(() {
                                vals[activePart] = (vals[activePart]! + 1)
                                    .clamp(cfg.min, cfg.max);
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: _sliderTheme(ctx, activeColor),
                      child: Slider(
                        key: const Key('tape-slider'),
                        min: cfg.min,
                        max: cfg.max,
                        divisions: ((cfg.max - cfg.min) * 2).round(),
                        value: currentVal,
                        onChanged: (v) => setModalState(() {
                          vals[activePart] = (v * 2).round() / 2;
                        }),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'WHR: ${whr.toStringAsFixed(2)} · ${whr <= 0.88 ? 'Chuẩn thể hình' : 'Nên siết eo'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${cfg.min.toInt()} – ${cfg.max.toInt()} cm',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.borderSolid),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Huỷ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('tape-save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop((
                          chestCm: vals['chest']!,
                          waistCm: vals['waist']!,
                          hipsCm: vals['hip']!,
                        )),
                        child: const Text(
                          'Lưu 3 vòng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Interactive Add Workout PR modal synced with preview 2.3 (exercise + kg x reps + 1RM).
Future<({String title, String result})?> showAddWorkoutPrSheet(
  BuildContext context,
) {
  const presets = <String>[
    'Đẩy ngực',
    'Kéo lưng',
    'Squat',
    'Barbell Bench Press',
    'Back Squat',
    'Romanian Deadlift',
    'Incline Dumbbell',
    'Overhead Press',
  ];

  var selectedPreset = presets[0];
  var customName = '';
  var kg = 85.0;
  var reps = 6;

  return showModalBottomSheet<({String title, String result})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final palette = MetaGymTheme.paletteOf(ctx);
        final oneRm = (kg * (1 + reps / 30)).round();
        final resolvedTitle = customName.trim().isNotEmpty
            ? customName.trim()
            : selectedPreset;

        return _ModalSheetShell(
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
                          'Thêm thành tích buổi tập',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ghi nhận mức tạ & ước tính 1RM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SheetPill(
                    label: '1RM ~$oneRm kg',
                    color: palette.primaryText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((name) {
                  final active =
                      customName.trim().isEmpty && selectedPreset == name;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setModalState(() {
                        selectedPreset = name;
                        customName = '';
                      }),
                      child: AnimatedContainer(
                        duration: MetaGymTheme.stateDurationOf(ctx),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? palette.chipActiveBg
                              : palette.metricPanelBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? MetaGymTheme.brandOrange
                                : palette.metricPanelBorder,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: active
                                ? palette.primaryText
                                : palette.textSecondary,
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('pr-custom-name'),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Hoặc nhập tên bài tập khác...',
                  hintStyle: TextStyle(
                    color: palette.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: palette.metricPanelBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.metricPanelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: MetaGymTheme.brandOrange,
                    ),
                  ),
                ),
                onChanged: (v) => setModalState(() => customName = v),
              ),
              const SizedBox(height: 10),
              _SheetPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mức tạ (kg)',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepperChip(
                              key: const Key('pr-kg-minus'),
                              label: '−2.5',
                              onTap: () => setModalState(() {
                                kg = (kg - 2.5).clamp(10.0, 200.0);
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${_fmtMetricNum(kg)} kg',
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                            _StepperChip(
                              key: const Key('pr-kg-plus'),
                              label: '+2.5',
                              onTap: () => setModalState(() {
                                kg = (kg + 2.5).clamp(10.0, 200.0);
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: _sliderTheme(ctx, MetaGymTheme.brandOrange),
                      child: Slider(
                        key: const Key('pr-kg-slider'),
                        min: 10,
                        max: 200,
                        divisions: 76,
                        value: kg,
                        onChanged: (v) => setModalState(() {
                          kg = ((v * 2).round() / 2).clamp(10.0, 200.0);
                        }),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số lần lặp (Reps)',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepperChip(
                              key: const Key('pr-rep-minus'),
                              label: '−1',
                              onTap: () => setModalState(() {
                                reps = (reps - 1).clamp(1, 25);
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$reps reps',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                            _StepperChip(
                              key: const Key('pr-rep-plus'),
                              label: '+1',
                              onTap: () => setModalState(() {
                                reps = (reps + 1).clamp(1, 25);
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.borderSolid),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Huỷ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const Key('pr-save'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop((
                          title: resolvedTitle,
                          result: '${_fmtMetricNum(kg)} kg × $reps',
                        )),
                        icon: const MetaGymSvgIcon(
                          MetaGymIcons.commonAdd,
                          size: 16,
                          color: Colors.white,
                          adaptForLightMode: false,
                          fallbackIcon: Icons.add_rounded,
                        ),
                        label: const Text(
                          'Lưu thành tích',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

SliderThemeData _sliderTheme(BuildContext context, Color accent) {
  final palette = MetaGymTheme.paletteOf(context);
  return SliderTheme.of(context).copyWith(
    activeTrackColor: accent,
    inactiveTrackColor: palette.borderSolid.withValues(alpha: 0.7),
    thumbColor: accent,
    overlayColor: accent.withValues(alpha: 0.16),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
  );
}

class _ModalSheetShell extends StatelessWidget {
  const _ModalSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final enableBlur = !isLight && !disableAnimations && !MetaGymTheme.isFlutterTestEnvironment;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final sheet = Container(
      decoration: BoxDecoration(
        color: isLight ? colors.overlayGlass : const Color(0xF2241F1C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isLight
              ? colors.overlayGlassBorder
              : MetaGymWarmGlassTokens.cardBorder,
          width: 1.1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );

    if (!enableBlur) return sheet;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MetaGymTheme.overlayGlassBlur,
          sigmaY: MetaGymTheme.overlayGlassBlur,
        ),
        child: sheet,
      ),
    );
  }
}

class _SheetPanel extends StatelessWidget {
  const _SheetPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isLight
            ? palette.surfaceRaised
            : MetaGymWarmGlassTokens.metricPanelFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? palette.borderSolid
              : MetaGymWarmGlassTokens.metricPanelBorder,
        ),
      ),
      child: child,
    );
  }
}

class _GenderSegmentedPill extends StatelessWidget {
  const _GenderSegmentedPill({
    required this.isFemale,
    required this.onChanged,
    this.maleKey,
    this.femaleKey,
  });

  final bool isFemale;
  final ValueChanged<bool> onChanged;
  final Key? maleKey;
  final Key? femaleKey;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    Widget chip({
      required Key? key,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MetaGymTheme.stateDurationOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6D48), Color(0xFFFF5E36)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : palette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.metricPanelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(
            key: maleKey,
            label: 'Nam',
            active: !isFemale,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 2),
          chip(
            key: femaleKey,
            label: 'Nữ',
            active: isFemale,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }
}

class _StepperChip extends StatelessWidget {
  const _StepperChip({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymTap(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 34),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: palette.metricPanelBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.metricPanelBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ),
    );
  }
}

class _OlympicBarbellPainter extends CustomPainter {
  const _OlympicBarbellPainter({required this.plates, required this.isLight});

  final List<_PlateSpec> plates;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final barPaint = Paint()
      ..color = isLight ? const Color(0xFF7B8798) : const Color(0xFF6F7787);
    final sleevePaint = Paint()
      ..color = isLight ? const Color(0xFF5F6B7A) : const Color(0xFF8C95A6);
    final collarPaint = Paint()
      ..color = isLight ? const Color(0xFF2B3442) : const Color(0xFFE8EDF5);

    final margin = 14.0;
    final innerLeft = size.width * 0.30;
    final innerRight = size.width * 0.70;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(margin, cy - 3, size.width - margin, cy + 3),
        const Radius.circular(3),
      ),
      barPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(innerLeft, cy - 5, innerRight, cy + 5),
        const Radius.circular(2),
      ),
      sleevePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(innerLeft - 7, cy - 10, innerLeft, cy + 10),
        const Radius.circular(2),
      ),
      collarPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(innerRight, cy - 10, innerRight + 7, cy + 10),
        const Radius.circular(2),
      ),
      collarPaint,
    );

    var leftX = innerLeft - 9;
    var rightX = innerRight + 9;
    for (final p in plates) {
      final fillPaint = Paint()..color = p.fill;
      final strokePaint = Paint()
        ..color = p.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      leftX -= p.thickness;
      final leftRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(leftX + p.thickness / 2, cy),
          width: p.thickness,
          height: p.height,
        ),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(leftRect, fillPaint);
      canvas.drawRRect(leftRect, strokePaint);
      leftX -= 2.2;

      final rightRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rightX + p.thickness / 2, cy),
          width: p.thickness,
          height: p.height,
        ),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(rightRect, fillPaint);
      canvas.drawRRect(rightRect, strokePaint);
      rightX += p.thickness + 2.2;
    }
  }

  @override
  bool shouldRepaint(covariant _OlympicBarbellPainter oldDelegate) =>
      oldDelegate.plates.length != plates.length ||
      oldDelegate.isLight != isLight ||
      (plates.isNotEmpty &&
          oldDelegate.plates.isNotEmpty &&
          oldDelegate.plates.first.weight != plates.first.weight);
}

/// High-detail anatomical full-body scanner stage matching the sculpted SVG
/// artwork from `MuscleAnatomyTile` with gender adaptation (`Nam` / `Nữ`) and
/// 3D glowing laser measurement rings for chest, waist, and hips.
class BodyAnatomyMeasureStage extends StatelessWidget {
  const BodyAnatomyMeasureStage({
    required this.isFemale,
    required this.chestCm,
    required this.waistCm,
    required this.hipsCm,
    this.activePart,
    this.showCallouts = false,
    this.width,
    this.height = 142,
    this.borderRadius = 14,
    this.onTapPart,
    super.key,
  });

  final bool isFemale;
  final double chestCm;
  final double waistCm;
  final double hipsCm;
  final String? activePart;
  final bool showCallouts;
  final double? width;
  final double height;
  final double borderRadius;
  final ValueChanged<String>? onTapPart;

  String _svgAssetFor() {
    if (isFemale) {
      return switch (activePart) {
        'chest' => MetaGymIcons.femaleBodyChest,
        'waist' => MetaGymIcons.femaleBodyCore,
        'hip' => MetaGymIcons.femaleBodyHips,
        _ => MetaGymIcons.femaleBodyDefault,
      };
    }
    return switch (activePart) {
      'chest' => MetaGymIcons.muscleChest,
      'waist' => MetaGymIcons.muscleCore,
      'hip' => MetaGymIcons.muscleLower,
      _ => MetaGymIcons.musclesDefault,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final chestColor = palette.primaryText;
    final waistColor = palette.success;
    final hipsColor = palette.reflection;
    final svgAsset = _svgAssetFor();

    final (spotY, glowColor) = switch (activePart) {
      'chest' => (-0.34, chestColor),
      'waist' => (-0.10, waistColor),
      'hip' => (0.12, hipsColor),
      _ => (-0.10, MetaGymTheme.brandOrange),
    };

    final stage = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? const [Color(0xFFF3F6FB), Color(0xFFE5ECF5)]
              : const [Color(0xFF1B2230), Color(0xFF12161F)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: activePart != null
              ? glowColor.withValues(alpha: isLight ? 0.48 : 0.54)
              : isLight
              ? palette.metricPanelBorder
              : MetaGymTheme.brandOrange.withValues(alpha: 0.36),
          width: activePart != null ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: activePart != null
                ? glowColor.withValues(alpha: isLight ? 0.14 : 0.20)
                : isLight
                ? const Color(0x140F172A)
                : const Color(0x4D000000),
            blurRadius: activePart != null ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (borderRadius - 1).clamp(0.0, 99.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 120.0;
            final maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : height;
            final svgH = (maxH - 12.0).clamp(24.0, double.infinity);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  size: Size(maxW, maxH),
                  painter: _ScannerBackdropPainter(
                    spotY: spotY,
                    glowColor: glowColor,
                    isLight: isLight,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: MetaGymTheme.stateDurationOf(context),
                      child: MetaGymSvgIcon(
                        svgAsset,
                        key: ValueKey(svgAsset),
                        width: maxW,
                        height: svgH,
                        fit: BoxFit.contain,
                        adaptForLightMode: false,
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size(maxW, maxH),
                  painter: BodyMeasurementRingsPainter(
                    isFemale: isFemale,
                    chestCm: chestCm,
                    waistCm: waistCm,
                    hipsCm: hipsCm,
                    activePart: activePart,
                    showCallouts: showCallouts,
                    chestColor: chestColor,
                    waistColor: waistColor,
                    hipsColor: hipsColor,
                    textPrimary: palette.textPrimary,
                    textSecondary: palette.textSecondary,
                    isLight: isLight,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (onTapPart == null) return stage;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final normY = (details.localPosition.dy / height).clamp(0.0, 1.0);
        if (normY < 0.35) {
          onTapPart!('chest');
        } else if (normY < 0.46) {
          onTapPart!('waist');
        } else {
          onTapPart!('hip');
        }
      },
      child: stage,
    );
  }
}

class _ScannerBackdropPainter extends CustomPainter {
  const _ScannerBackdropPainter({
    required this.spotY,
    required this.glowColor,
    required this.isLight,
  });

  final double spotY;
  final Color glowColor;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
          .withValues(alpha: isLight ? 0.08 : 0.06)
      ..strokeWidth = 0.8;
    const step = 20.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final spotCenter = Offset(
      size.width / 2,
      size.height * (0.5 + spotY * 0.5),
    );
    final spotRadius = size.shortestSide * 0.58;
    canvas.drawCircle(
      spotCenter,
      spotRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: isLight ? 0.14 : 0.22),
            glowColor.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: spotCenter, radius: spotRadius),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerBackdropPainter oldDelegate) =>
      oldDelegate.spotY != spotY ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.isLight != isLight;
}

/// Renders 3D futuristic glowing measurement rings anchored to the `180×330`
/// sculpted anatomy SVG coordinate space, with optional leader callouts.
class BodyMeasurementRingsPainter extends CustomPainter {
  const BodyMeasurementRingsPainter({
    required this.isFemale,
    required this.chestCm,
    required this.waistCm,
    required this.hipsCm,
    required this.chestColor,
    required this.waistColor,
    required this.hipsColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isLight,
    this.activePart,
    this.showCallouts = true,
  });

  final bool isFemale;
  final double chestCm;
  final double waistCm;
  final double hipsCm;
  final String? activePart;
  final bool showCallouts;
  final Color chestColor;
  final Color waistColor;
  final Color hipsColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final drawH = (size.height - 12.0).clamp(24.0, double.infinity);
    final scale = math.min(size.width / 180.0, drawH / 330.0);
    final cx = size.width / 2;
    final topY = (size.height - 330.0 * scale) / 2;

    // Live subtle expansion/contraction anchored on the sculpted SVG proportions
    final chestRx =
        ((isFemale ? 21.5 : 24.5) +
            (chestCm - (isFemale ? 88.0 : 98.0)) * 0.14) *
        scale;
    final waistRx =
        ((isFemale ? 18.5 : 23.5) +
            (waistCm - (isFemale ? 64.0 : 78.0)) * 0.16) *
        scale;
    final hipRx =
        ((isFemale ? 33.5 : 29.5) + (hipsCm - 94.0) * 0.14) * scale;

    final rings = <({
      String key,
      double y,
      double rx,
      double val,
      Color color,
      bool right,
    })>[
      (
        key: 'chest',
        y: topY + 88.0 * scale,
        rx: chestRx.clamp(12.0 * scale, 48.0 * scale),
        val: chestCm,
        color: chestColor,
        right: true,
      ),
      (
        key: 'waist',
        y: topY + 128.0 * scale,
        rx: waistRx.clamp(10.0 * scale, 44.0 * scale),
        val: waistCm,
        color: waistColor,
        right: false,
      ),
      (
        key: 'hip',
        y: topY + 165.0 * scale,
        rx: hipRx.clamp(14.0 * scale, 52.0 * scale),
        val: hipsCm,
        color: hipsColor,
        right: true,
      ),
    ];

    for (final ring in rings) {
      final isFocus = ring.key == activePart;
      final isAct = activePart == null || isFocus;
      final ovalH = (isFocus ? 13.0 : (isAct ? 10.5 : 8.5)) * scale;
      final rect = Rect.fromCenter(
        center: Offset(cx, ring.y),
        width: ring.rx * 2,
        height: ovalH.clamp(4.0, 18.0),
      );
      final strokeW =
          ((isFocus ? 2.5 : (isAct ? 1.9 : 1.25)) * scale).clamp(1.2, 2.8);

      // Soft zone glow fill inside ring
      if (isAct) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = ring.color.withValues(alpha: isFocus ? 0.18 : 0.08),
        );
        canvas.drawOval(
          rect,
          Paint()
            ..color = ring.color.withValues(alpha: isFocus ? 0.28 : 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW * 2.5,
        );
      }

      // Back half-arc (wrapping behind sculpted torso)
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = ring.color.withValues(alpha: isFocus ? 0.36 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW * 0.85,
      );

      // Crisp luminous front half-arc (in front of torso)
      canvas.drawArc(
        rect,
        0,
        math.pi,
        false,
        Paint()
          ..color = ring.color.withValues(
            alpha: isFocus ? 1.0 : (activePart == null ? 0.92 : 0.56),
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeW,
      );

      // Side laser tangent anchor ticks
      final tickAlpha = isAct ? 0.95 : 0.55;
      final tickPaint = Paint()..color = ring.color.withValues(alpha: tickAlpha);
      final tickR = (isFocus ? 2.4 : 1.8).clamp(1.3, 2.8);
      canvas.drawCircle(Offset(cx - ring.rx, ring.y), tickR, tickPaint);
      canvas.drawCircle(Offset(cx + ring.rx, ring.y), tickR, tickPaint);

      if (!showCallouts) continue;

      final leadDist = math.max(ring.rx + 36.0 * scale, 82.0 * scale);
      final startX = ring.right ? cx + ring.rx : cx - ring.rx;
      final rawEndX = ring.right ? cx + leadDist : cx - leadDist;
      final endX = rawEndX.clamp(58.0, size.width - 58.0);

      canvas.drawLine(
        Offset(startX, ring.y),
        Offset(endX, ring.y),
        Paint()
          ..color = ring.color.withValues(alpha: isAct ? 0.92 : 0.55)
          ..strokeWidth = isFocus ? 1.8 : 1.15,
      );
      canvas.drawCircle(
        Offset(endX, ring.y),
        isFocus ? 3.2 : 2.2,
        Paint()..color = ring.color.withValues(alpha: isAct ? 1.0 : 0.65),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${_fmtMetricNum(ring.val)} cm',
          style: TextStyle(
            color: isAct ? textPrimary : textSecondary,
            fontSize: isFocus ? 12.0 : 10.5,
            fontWeight: isFocus ? FontWeight.w800 : FontWeight.w700,
            fontFamily: MetaGymTheme.fontFamily,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final padX = 7.0;
      final padY = 3.5;
      final pillW = tp.width + padX * 2;
      final pillH = tp.height + padY * 2;
      final pillLeft = (ring.right ? endX + 5 : endX - 5 - pillW).clamp(
        6.0,
        size.width - pillW - 6.0,
      );
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, ring.y - pillH / 2, pillW, pillH),
        const Radius.circular(999),
      );

      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = isLight
              ? const Color(0xEBFFFFFF)
              : const Color(0xDC141822),
      );
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = ring.color.withValues(alpha: isFocus ? 0.72 : 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFocus ? 1.2 : 0.9,
      );
      tp.paint(canvas, Offset(pillLeft + padX, ring.y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant BodyMeasurementRingsPainter oldDelegate) =>
      oldDelegate.isFemale != isFemale ||
      oldDelegate.chestCm != chestCm ||
      oldDelegate.waistCm != waistCm ||
      oldDelegate.hipsCm != hipsCm ||
      oldDelegate.activePart != activePart ||
      oldDelegate.showCallouts != showCallouts ||
      oldDelegate.isLight != isLight;
}
