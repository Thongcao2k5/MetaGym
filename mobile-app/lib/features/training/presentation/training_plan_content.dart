import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

String _formatIsoToDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  final parts = raw.trim().split('T').first.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return raw;
}

String _equipmentAssetFor(TrainingExercise exercise) {
  final lower = exercise.exerciseName.toLowerCase();
  if (lower.contains('dumbbell') ||
      lower.contains('db ') ||
      lower.contains('tạ đơn')) {
    return MetaGymIcons.equipDumbbell;
  }
  if (lower.contains('barbell') ||
      lower.contains('deadlift') ||
      lower.contains('squat') ||
      lower.contains('bench press') ||
      lower.contains('thanh đòn')) {
    return MetaGymIcons.equipBarbell;
  }
  if (lower.contains('cable') ||
      lower.contains('pulldown') ||
      lower.contains('rope') ||
      lower.contains('face pull') ||
      lower.contains('cáp')) {
    return MetaGymIcons.equipCable;
  }
  if (lower.contains('machine') ||
      lower.contains('leg press') ||
      lower.contains('extension') ||
      lower.contains('calf') ||
      lower.contains('máy')) {
    return MetaGymIcons.equipMachine;
  }
  if (lower.contains('band') || lower.contains('kháng lực')) {
    return MetaGymIcons.equipResistanceBand;
  }
  if (lower.contains('cardio') ||
      lower.contains('treadmill') ||
      lower.contains('bike') ||
      lower.contains('run')) {
    return MetaGymIcons.equipCardio;
  }
  return MetaGymIcons.workoutSetReps;
}

String _mealAssetFor(String mealType) => switch (mealType) {
  'BREAKFAST' => MetaGymIcons.mealBreakfast,
  'LUNCH' => MetaGymIcons.mealLunch,
  'DINNER' => MetaGymIcons.mealDinner,
  _ => MetaGymIcons.mealSnack,
};

class TrainingPlanContent extends StatefulWidget {
  const TrainingPlanContent({
    required this.plan,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final TrainingPlan plan;
  final bool useSolidGlassFallback;

  @override
  State<TrainingPlanContent> createState() => _TrainingPlanContentState();
}

class _TrainingPlanContentState extends State<TrainingPlanContent> {
  int _selectedDayIndex = 0;

  @override
  void didUpdateWidget(covariant TrainingPlanContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plan.days.isEmpty) {
      _selectedDayIndex = 0;
    } else if (_selectedDayIndex >= widget.plan.days.length) {
      _selectedDayIndex = widget.plan.days.length - 1;
    }
  }

  CoachingPillTone _statusTone(String status) => switch (status) {
    'ACTIVE' => CoachingPillTone.green,
    'DRAFT' => CoachingPillTone.amber,
    _ => CoachingPillTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final plan = widget.plan;
    final totalExercises = plan.days.fold<int>(
      0,
      (sum, day) => sum + day.exercises.length,
    );
    final totalMeals = plan.days.fold<int>(
      0,
      (sum, day) => sum + day.meals.length,
    );

    final selectedDay = plan.days.isEmpty
        ? null
        : plan.days[_selectedDayIndex.clamp(0, plan.days.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Card (Level 2 Warm Smoked Glass / Daylight Studio)
        MetaGymHeroGlassCard(
          useSolidFallback: widget.useSolidGlassFallback,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CoachingPill(
                      label: '${plan.statusLabel} · Phiên bản ${plan.version}',
                      tone: _statusTone(plan.status),
                      icon: plan.status == 'ACTIVE'
                          ? Icons.verified_outlined
                          : Icons.edit_note_rounded,
                    ),
                    Text(
                      '${plan.days.length} ngày/tuần',
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                if (plan.startDate != null ||
                    plan.endDate != null ||
                    plan.goal?.isNotEmpty == true ||
                    plan.publishedAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: MetaGymIcon(
                          MetaGymIcons.workoutPlanCalendar,
                          size: 14,
                          color: colors.textWarmMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (plan.startDate != null && plan.endDate != null)
                              '${_formatIsoToDisplay(plan.startDate)} – ${_formatIsoToDisplay(plan.endDate)}'
                            else if (plan.startDate != null)
                              'Bắt đầu: ${_formatIsoToDisplay(plan.startDate)}'
                            else if (plan.endDate != null)
                              'Kết thúc: ${_formatIsoToDisplay(plan.endDate)}',
                            if (plan.goal?.trim().isNotEmpty == true)
                              plan.goal!.trim(),
                            if (plan.publishedAt != null &&
                                plan.startDate == null &&
                                plan.endDate == null)
                              'Công bố: ${_formatIsoToDisplay(plan.publishedAt)}',
                          ].join(' · '),
                          style: TextStyle(
                            color: colors.textWarmMuted,
                            fontSize: 12,
                            height: 1.4,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetricTile(
                        value: '${plan.days.length}',
                        label: 'Ngày tập',
                        valueColor: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricTile(
                        value: '$totalExercises',
                        label: 'Bài tập',
                        valueColor: MetaGymTheme.brandOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricTile(
                        value: '$totalMeals',
                        label: 'Bữa ăn',
                        valueColor: colors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (plan.days.isEmpty)
          MetaGymGlassCard(
            solid: widget.useSolidGlassFallback,
            padding: const EdgeInsets.all(18),
            child: Center(
              child: Text(
                'Giáo trình chưa có ngày tập nào.',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ),
          )
        else ...[
          // Day Switcher Tabs (Wrap to avoid horizontal scroll conflicts and overflow)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < plan.days.length; i++)
                _DayFilterChip(
                  key: Key('plan-detail-day-tab-$i'),
                  label:
                      'Ngày ${plan.days[i].dayNumber} · ${plan.days[i].title}',
                  selected: _selectedDayIndex == i,
                  onTap: () => setState(() => _selectedDayIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedDay != null)
            _SelectedDaySection(
              useSolidGlassFallback: widget.useSolidGlassFallback,
              day: selectedDay,
              colors: colors,
              isLight: isLight,
            ),
        ],
      ],
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  const _HeroMetricTile({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymMetricPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayFilterChip extends StatelessWidget {
  const _DayFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(999);

    return Material(
      color: selected
          ? (isLight
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.14)
                : colors.chipActiveBg)
          : colors.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : colors.metricPanelBorder,
          width: selected ? 1.2 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? (isLight
                                ? colors.primaryText
                                : colors.chipActiveText)
                          : colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDaySection extends StatelessWidget {
  const _SelectedDaySection({
    required this.useSolidGlassFallback,
    required this.day,
    required this.colors,
    required this.isLight,
  });

  final TrainingDay day;
  final MetaGymColors colors;
  final bool isLight;

  final bool useSolidGlassFallback;

  @override
  Widget build(BuildContext context) {
    final dayFocuses = resolveMuscleFocusSet(
      day.title,
      exerciseNames: day.exercises.map((e) => e.exerciseName).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Warmup & Overview Banner
        MetaGymGlassCard(
          solid: useSolidGlassFallback,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          borderColor: colors.warning.withValues(alpha: 0.36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MuscleAnatomyTile(
                focuses: dayFocuses,
                width: 40,
                height: 48,
                selected: dayFocuses.isNotEmpty,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MetaGymIcon(
                          MetaGymIcons.workoutWarmup,
                          size: 16,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ngày ${day.dayNumber}: ${day.title}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (day.scheduledDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lịch ngày ${_formatIsoToDisplay(day.scheduledDate)}',
                        style: TextStyle(
                          color: colors.reflection,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                    if (day.notes?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        day.notes!.trim(),
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Section Header: Exercises
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Bài tập Ngày ${day.dayNumber} (${day.exercises.length} bài)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${day.exercises.length} mục',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
        ),

        if (day.exercises.isEmpty)
          MetaGymGlassCard(
            solid: useSolidGlassFallback,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Chưa có bài tập.',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ),
          )
        else
          for (var i = 0; i < day.exercises.length; i++)
            _ExerciseDetailCard(
              useSolidGlassFallback: useSolidGlassFallback,
              exercise: day.exercises[i],
              index: i + 1,
              colors: colors,
              isLight: isLight,
            ),

        // Day Meals
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch ăn',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${day.meals.length} bữa',
                style: TextStyle(
                  color: colors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        if (day.meals.isEmpty)
          MetaGymGlassCard(
            solid: useSolidGlassFallback,
            padding: const EdgeInsets.all(14),
            child: Text(
              'Coach chưa xếp lịch ăn cho ngày này.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          )
        else
          MetaGymGlassCard(
            solid: useSolidGlassFallback,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var m = 0; m < day.meals.length; m++) ...[
                  if (m > 0)
                    Divider(
                      color: colors.border.withValues(alpha: 0.6),
                      height: 16,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: MetaGymIcon(
                          _mealAssetFor(day.meals[m].mealType),
                          size: 18,
                          color: colors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${day.meals[m].typeLabel}${day.meals[m].scheduledTime == null ? '' : ' · ${day.meals[m].scheduledTime}'}',
                              style: TextStyle(
                                color: colors.textWarmMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              day.meals[m].title,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (day.meals[m].notes?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 2),
                              Text(
                                day.meals[m].notes!.trim(),
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({
    required this.useSolidGlassFallback,
    required this.exercise,
    required this.index,
    required this.colors,
    required this.isLight,
  });

  final bool useSolidGlassFallback;
  final TrainingExercise exercise;
  final int index;
  final MetaGymColors colors;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final restText = exercise.restSeconds != null
        ? 'Nghỉ ${exercise.restSeconds}s'
        : null;
    final guidanceText = exercise.weightGuidance?.trim().isNotEmpty == true
        ? 'Mức tạ: ${exercise.weightGuidance!.trim()}'
        : null;
    final summaryParts = <String>[
      if (exercise.prescription.isNotEmpty) exercise.prescription,
      if (restText != null) restText,
      if (guidanceText != null) guidanceText,
    ];

    return MetaGymGlassCard(
      solid: useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.metricPanelBorder),
            ),
            alignment: Alignment.center,
            child: MetaGymIcon(
              _equipmentAssetFor(exercise),
              size: 24,
              color: MetaGymTheme.brandOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '$index. ${exercise.exerciseName}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CoachingPill(
                      label: '#$index',
                      tone: index == 1
                          ? CoachingPillTone.coral
                          : CoachingPillTone.neutral,
                    ),
                  ],
                ),
                if (summaryParts.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    summaryParts.join(' · '),
                    style: TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                      height: 1.35,
                    ),
                  ),
                ],
                if (exercise.instructions?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    exercise.instructions!.trim(),
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
                if (exercise.safetyNotes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MetaGymIcon(
                          MetaGymIcons.exerciseSafetyShield,
                          size: 15,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lưu ý an toàn: ${exercise.safetyNotes!.trim()}',
                            style: TextStyle(
                              color: colors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (exercise.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    exercise.notes!.trim(),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
