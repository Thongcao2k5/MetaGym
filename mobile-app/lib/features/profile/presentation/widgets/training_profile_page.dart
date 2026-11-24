import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/body_metric_pickers.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';

/// Màn hình **5.3 Thể trạng & Mục tiêu** đồng bộ `tab5-profile.js` (`member-training-profile`):
/// - Card 1: Mục tiêu tập luyện (`setting_training_goal.svg`) + 4 chip gợi ý nhanh
/// - Card 2: Chiều cao & Cân nặng (`body_measure_tape.svg`) + pill BMI trực tiếp + 2 ô tương tác
///   mở **Thước Laser Đứng** (`Laser ↗`) và **Cân Đĩa Tạ Vòng Cung** (`Cân tạ ↗`)
/// - Card 3: Trình độ tập luyện + Mức độ vận động hàng ngày (`.filter-pill`)
/// - Thanh CTA đáy `.bottom-cta-dock`: `Lưu thay đổi`.
class TrainingProfileDetailPage extends StatefulWidget {
  const TrainingProfileDetailPage({
    required this.fitnessGoal,
    required this.heightCm,
    required this.weightKg,
    required this.experienceLevel,
    required this.activityLevel,
    required this.onSave,
    super.key,
  });

  final String fitnessGoal;
  final double heightCm;
  final double weightKg;
  final String experienceLevel;
  final String activityLevel;
  final Future<bool> Function(
    String goal,
    double heightCm,
    double? updatedWeightKg,
    String experienceLevel,
    String activityLevel,
  )
  onSave;

  static String experienceLabel(String code) => switch (code) {
    'BEGINNER' => 'Mới bắt đầu',
    'INTERMEDIATE' => 'Trung cấp',
    'ADVANCED' => 'Nâng cao',
    _ => code,
  };

  static String activityLabel(String code) => switch (code) {
    'LOW' => 'Ít vận động',
    'MODERATE' => 'Trung bình',
    'HIGH' => 'Vận động cao',
    _ => code,
  };

  @override
  State<TrainingProfileDetailPage> createState() =>
      _TrainingProfileDetailPageState();
}

class _TrainingProfileDetailPageState extends State<TrainingProfileDetailPage> {
  late final TextEditingController _goalCtrl = TextEditingController(
    text: widget.fitnessGoal,
  );
  late double _heightCm = widget.heightCm > 0 ? widget.heightCm : 174.0;
  late double _weightKg = widget.weightKg > 0 ? widget.weightKg : 72.4;
  late String _experience = widget.experienceLevel;
  late String _activity = widget.activityLevel;
  bool _weightModified = false;
  bool _isSaving = false;

  static const List<({String chipLabel, String value})> _goalPresets = [
    (
      chipLabel: 'Tăng cơ giảm mỡ · 4 buổi/tuần',
      value: 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
    ),
    (
      chipLabel: 'Giảm mỡ siết cơ · Cardio & HIIT',
      value: 'Giảm mỡ siết cơ · Cardio & HIIT',
    ),
    (chipLabel: 'Tăng sức mạnh tối đa', value: 'Tăng sức mạnh tối đa'),
    (
      chipLabel: 'Cải thiện sức bền & Phục hồi',
      value: 'Cải thiện sức bền & Phục hồi',
    ),
  ];

  bool _isPresetSelected(({String chipLabel, String value}) preset) {
    final current = _goalCtrl.text.trim();
    if (current == preset.value || current == preset.chipLabel) return true;
    if (preset.chipLabel.startsWith('Tăng cơ giảm mỡ') &&
        current.toLowerCase().contains('tăng cơ giảm mỡ')) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _openHeightPicker() async {
    final picked = await showHeightStadiometerPicker(
      context,
      initialHeightCm: _heightCm,
      referenceWeightKg: _weightKg,
    );
    if (picked != null && mounted) {
      setState(() => _heightCm = picked);
    }
  }

  Future<void> _openWeightPicker() async {
    final picked = await showWeightBarbellDialPicker(
      context,
      initialWeightKg: _weightKg,
      referenceHeightCm: _heightCm,
    );
    if (picked != null && mounted) {
      setState(() {
        _weightKg = picked;
        _weightModified = true;
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final nextGoal = _goalCtrl.text.trim().isNotEmpty
        ? _goalCtrl.text.trim()
        : widget.fitnessGoal;
    final ok = await widget.onSave(
      nextGoal,
      _heightCm,
      _weightModified ? _weightKg : null,
      _experience,
      _activity,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final bmi = calculateBmiInfo(_heightCm, _weightKg);
    final bmiColor = bmi.colorFor(colors);

    return ProfileSubPageScaffold(
      eyebrow: 'Hồ sơ cá nhân',
      title: 'Thể trạng & Mục tiêu',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Mục tiêu tập luyện + Presets
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MetaGymIcon(
                      MetaGymIcons.settingTrainingGoal,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Mục tiêu tập luyện',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProfileLabeledTextField(
                  controller: _goalCtrl,
                  hintText: 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
                  minLines: 1,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in _goalPresets)
                      ProfileFilterPill(
                        label: preset.chipLabel,
                        compact: true,
                        selected: _isPresetSelected(preset),
                        onTap: () =>
                            setState(() => _goalCtrl.text = preset.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 2: Chiều cao & Cân nặng + Live BMI + Thước Laser / Cân Đĩa Tạ
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const MetaGymIcon(
                      MetaGymIcons.bodyMeasureTape,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Chiều cao & Cân nặng',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        key: const Key('training-bmi-pill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bmiColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusFull,
                          ),
                        ),
                        child: Text(
                          '● BMI ${bmi.bmi.toStringAsFixed(1)} · ${bmi.label}',
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
                  ],
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BodyMetricTile(
                          key: const Key('training-height-card'),
                          label: 'Chiều cao',
                          actionHint: 'Laser',
                          actionColor: colors.primaryText,
                          borderColor: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.34,
                          ),
                          value: '${_heightCm.round()} cm',
                          valueColor: colors.primaryText,
                          subValue:
                              '${formatHeightFeetInches(_heightCm)} · ${bmi.zone == BmiZone.normal ? 'Chuẩn thể hình' : bmi.label}',
                          onTap: _openHeightPicker,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BodyMetricTile(
                          key: const Key('training-weight-card'),
                          label: 'Cân nặng',
                          actionHint: 'Cân tạ',
                          actionColor: colors.info,
                          borderColor: colors.info.withValues(alpha: 0.36),
                          value: '${_weightKg.toStringAsFixed(1)} kg',
                          valueColor: colors.textPrimary,
                          subValue: formatWeightLbs(_weightKg),
                          onTap: _openWeightPicker,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 3: Trình độ & Mức độ vận động hàng ngày
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trình độ tập luyện',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in const [
                      'BEGINNER',
                      'INTERMEDIATE',
                      'ADVANCED',
                    ])
                      ProfileFilterPill(
                        label: TrainingProfileDetailPage.experienceLabel(code),
                        selected: _experience == code,
                        onTap: () => setState(() => _experience = code),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Mức độ vận động hàng ngày',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in const ['LOW', 'MODERATE', 'HIGH'])
                      ProfileFilterPill(
                        label: TrainingProfileDetailPage.activityLabel(code),
                        selected: _activity == code,
                        onTap: () => setState(() => _activity = code),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          key: const Key('training-profile-save-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: Text(
            _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _BodyMetricTile extends StatelessWidget {
  const _BodyMetricTile({
    required this.label,
    required this.actionHint,
    required this.actionColor,
    required this.borderColor,
    required this.value,
    required this.valueColor,
    required this.subValue,
    required this.onTap,
    super.key,
  });

  final String label;
  final String actionHint;
  final Color actionColor;
  final Color borderColor;
  final String value;
  final Color valueColor;
  final String subValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final radius = BorderRadius.circular(16);
    return Material(
      color: colors.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        semanticLabel: '$label $value, chạm để mở $actionHint',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            actionHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.north_east_rounded,
                          size: 11.5,
                          color: actionColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
