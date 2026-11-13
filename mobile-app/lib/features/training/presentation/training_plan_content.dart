import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

class TrainingPlanContent extends StatelessWidget {
  const TrainingPlanContent({required this.plan, super.key});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MetaGymTheme.cardPadding),
          decoration: BoxDecoration(
            color: MetaGymTheme.darkSurface,
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
            border: Border.all(color: MetaGymTheme.darkCardBorderSubtle),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MetaGymTheme.darkSurfaceRaised,
                MetaGymTheme.darkSurface,
              ],
            ),
          ),
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
                      color: const Color(0x26FF5A36),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x59FF5A36)),
                    ),
                    child: Text(
                      '${plan.statusLabel} · Phiên bản ${plan.version}',
                      style: const TextStyle(
                        color: MetaGymTheme.brandOrange,
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
                      color: const Color(0x14A9C7E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x2EA9C7E8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_view_week_rounded,
                          size: 14,
                          color: MetaGymTheme.reflectionBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.days.length} ngày tập',
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
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
                style: const TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
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
                    const Icon(
                      Icons.track_changes_rounded,
                      size: 16,
                      color: MetaGymTheme.reflectionBlue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mục tiêu: ${plan.goal}',
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
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
                const Divider(color: MetaGymTheme.darkDividerSubtle, height: 1),
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

        const SizedBox(height: 24),

        // Day by Day details
        for (final day in plan.days) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MetaGymTheme.darkSurface,
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
              border: Border.all(color: MetaGymTheme.darkCardBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1FA9C7E8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x3DA9C7E8)),
                      ),
                      child: Text(
                        'Buổi ${day.dayNumber}',
                        style: const TextStyle(
                          color: MetaGymTheme.reflectionBlue,
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
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
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
                    style: const TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
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
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextTertiary,
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
                      color: MetaGymTheme.darkSurfaceMid,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có bài tập.',
                        style: TextStyle(
                          color: MetaGymTheme.darkTextTertiary,
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
                const Text(
                  'Lịch ăn',
                  style: TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (day.meals.isEmpty)
                  const Text(
                    'Coach chưa xếp lịch ăn cho ngày này.',
                    style: TextStyle(
                      color: MetaGymTheme.darkTextTertiary,
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
                          const Icon(
                            Icons.restaurant_outlined,
                            size: 18,
                            color: MetaGymTheme.progressGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${meal.typeLabel}${meal.scheduledTime == null ? '' : ' · ${meal.scheduledTime}'}',
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  meal.title,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (meal.notes?.isNotEmpty == true)
                                  Text(
                                    meal.notes!,
                                    style: const TextStyle(
                                      color: MetaGymTheme.darkTextTertiary,
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
          ),
        ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MetaGymTheme.darkTextTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: MetaGymTheme.darkTextTertiary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetaGymTheme.darkSurfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaGymTheme.darkCardBorderSubtle),
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
                  color: const Color(0x1F222B35),
                  shape: BoxShape.circle,
                  border: Border.all(color: MetaGymTheme.darkBorderSubtle),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: MetaGymTheme.reflectionBlue,
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
                  style: const TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: MetaGymTheme.fontFamily,
                  ),
                ),
              ),
              const Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: MetaGymTheme.brandOrange,
              ),
            ],
          ),

          if (exercise.prescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x1AFF5A36),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x33FF5A36)),
              ),
              child: Text(
                exercise.prescription,
                style: const TextStyle(
                  color: MetaGymTheme.brandOrange,
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
                const Icon(
                  Icons.scale_rounded,
                  size: 14,
                  color: MetaGymTheme.reflectionBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mức tạ: ${exercise.weightGuidance}',
                    style: const TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
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
              style: const TextStyle(
                color: MetaGymTheme.darkTextSecondary,
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
                color: const Color(0x14F2A93B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x38F2A93B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 15,
                    color: MetaGymTheme.warningAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý an toàn: ${exercise.safetyNotes}',
                      style: const TextStyle(
                        color: Color(0xFFF7D08A),
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
              style: const TextStyle(
                color: MetaGymTheme.darkTextTertiary,
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
