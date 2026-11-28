import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class TrainingPlanContent extends StatelessWidget {
  const TrainingPlanContent({required this.plan, super.key});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Card
        MetaGymGlassCard(
          padding: const EdgeInsets.all(MetaGymTheme.cardPadding),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipActiveBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: MetaGymTheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '${plan.statusLabel} · Phiên bản ${plan.version}',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: MetaGymTheme.fontFamily,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.metricPanelBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.metricPanelBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MetaGymSvgIcon(MetaGymIcons.actionCoachWorkweek, size: 14, fallbackIcon: Icons.calendar_view_week_rounded),
                          const SizedBox(width: 4),
                          Text(
                            '${plan.days.length} ngày tập',
                            style: TextStyle(
                              color: palette.textWarmMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: MetaGymTheme.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02,
                    fontFamily: MetaGymTheme.fontFamily,
                  ),
                ),
                if (plan.goal?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MetaGymSvgIcon(MetaGymIcons.settingTrainingGoal, size: 16, fallbackIcon: Icons.track_changes_rounded),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Mục tiêu: ${plan.goal}',
                          style: TextStyle(
                            color: palette.textWarmMuted,
                            fontSize: 14,
                            fontFamily: MetaGymTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (plan.startDate != null ||
                    plan.endDate != null ||
                    plan.publishedAt != null) ...[
                  const SizedBox(height: 14),
                  Divider(
                    color: palette.borderSolid.withValues(alpha: 0.7),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (plan.startDate != null)
                        _MetaInfoPill(
                          icon: Icons.play_circle_outline_rounded,
                          text: 'Bắt đầu: ${plan.startDate}',
                        ),
                      if (plan.endDate != null)
                        _MetaInfoPill(
                          icon: Icons.event_available_rounded,
                          text: 'Kết thúc: ${plan.endDate}',
                        ),
                      if (plan.publishedAt != null)
                        _MetaInfoPill(
                          icon: Icons.verified_outlined,
                          text: 'Công bố: ${plan.publishedAt}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Day by Day details
        for (final day in plan.days)
          Builder(
            builder: (context) {
              final dayFocuses = resolveMuscleFocusSet(
                day.title,
                exerciseNames: day.exercises
                    .map((exercise) => exercise.exerciseName)
                    .toList(),
              );
              return MetaGymGlassCard(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MuscleAnatomyTile(
                          focuses: dayFocuses,
                          width: 34,
                          height: 40,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.metricPanelBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette.metricPanelBorder,
                            ),
                          ),
                          child: Text(
                            'Buổi ${day.dayNumber}',
                            style: TextStyle(
                              color: palette.reflection,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: MetaGymTheme.fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ngày ${day.dayNumber}: ${day.title}',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: MetaGymTheme.fontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (day.scheduledDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lịch ngày ${day.scheduledDate!.substring(8, 10)}/${day.scheduledDate!.substring(5, 7)}/${day.scheduledDate!.substring(0, 4)}',
                        style: TextStyle(
                          color: palette.textWarmMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (day.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          day.notes!,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                            fontFamily: MetaGymTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    if (day.exercises.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.metricPanelBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.metricPanelBorder),
                        ),
                        child: Center(
                          child: Text(
                            'Chưa có bài tập.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              fontFamily: MetaGymTheme.fontFamily,
                            ),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < day.exercises.length; i++)
                        _ExerciseCard(exercise: day.exercises[i], index: i + 1),
                    const SizedBox(height: 10),
                    Text(
                      'Lịch ăn',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (day.meals.isEmpty)
                      Text(
                        'Coach chưa xếp lịch ăn cho ngày này.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      )
                    else
                      for (final meal in day.meals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 18, fallbackIcon: Icons.restaurant_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${meal.typeLabel}${meal.scheduledTime == null ? '' : ' · ${meal.scheduledTime}'}',
                                      style: TextStyle(
                                        color: palette.textWarmMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      meal.title,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (meal.notes?.isNotEmpty == true)
                                      Text(
                                        meal.notes!,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MetaInfoPill extends StatelessWidget {
  const _MetaInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MetaGymResolvedIcon(icon, size: 14, fallbackColor: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.index});

  final TrainingExercise exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.metricPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & order row
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.metricPanelBorder),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: palette.reflection,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: MetaGymTheme.fontFamily,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: MetaGymTheme.fontFamily,
                  ),
                ),
              ),
              MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 16, fallbackIcon: Icons.fitness_center_rounded),
            ],
          ),

          if (exercise.prescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.chipActiveBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MetaGymTheme.primary.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                exercise.prescription,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: MetaGymTheme.tabularFigures,
                  fontFamily: MetaGymTheme.fontFamily,
                ),
              ),
            ),
          ],

          if (exercise.weightGuidance?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                MetaGymSvgIcon(MetaGymIcons.bodyWeightScale, size: 14, fallbackIcon: Icons.scale_rounded),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mức tạ: ${exercise.weightGuidance}',
                    style: TextStyle(
                      color: palette.textWarmMuted,
                      fontSize: 13,
                      fontFamily: MetaGymTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (exercise.instructions?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              exercise.instructions!,
              style: TextStyle(
                color: palette.textWarmMuted,
                fontSize: 13,
                height: 1.35,
                fontFamily: MetaGymTheme.fontFamily,
              ),
            ),
          ],

          if (exercise.safetyNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: palette.warning.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetaGymSvgIcon(MetaGymIcons.settingSecurityShield, size: 15, fallbackIcon: Icons.security_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý an toàn: ${exercise.safetyNotes}',
                      style: TextStyle(
                        color: palette.warning,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontFamily: MetaGymTheme.fontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (exercise.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              exercise.notes!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                fontFamily: MetaGymTheme.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
