import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:provider/provider.dart';

/// One Coach-authored calendar day of the active curriculum.
class MemberDayPlanPage extends StatefulWidget {
  const MemberDayPlanPage({
    required this.day,
    this.session,
    this.planTitle,
    super.key,
  });

  final TrainingDay day;
  final TrainingSession? session;
  final String? planTitle;

  @override
  State<MemberDayPlanPage> createState() => _MemberDayPlanPageState();
}

class _MemberDayPlanPageState extends State<MemberDayPlanPage> {
  List<ProgressComment> _feedback = const [];
  bool _loadingFeedback = false;

  @override
  void initState() {
    super.initState();
    if (widget.session?.status == 'COMPLETED') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFeedback());
    }
  }

  Future<void> _loadFeedback() async {
    setState(() => _loadingFeedback = true);
    try {
      final workoutService = context.read<MemberWorkoutService>();
      final progressService = context.read<MemberProgressService>();
      final workouts = await workoutService.getPage(1);
      final logIds = workouts
          .where((log) {
            final date = DateTime.tryParse(log.performedAt)?.toLocal();
            if (date == null) return false;
            final key =
                '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            return key == widget.day.scheduledDate;
          })
          .map((log) => log.id)
          .toSet();
      final comments = await progressService.getComments();
      if (mounted) {
        setState(
          () => _feedback = comments
              .where((comment) => logIds.contains(comment.workoutLogId))
              .toList(),
        );
      }
    } catch (_) {
      // A completed session can exist before the Member creates a workout log.
    } finally {
      if (mounted) setState(() => _loadingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.day.scheduledDate;
    final dateLabel = date != null && date.length == 10
        ? '${date.substring(8, 10)}/${date.substring(5, 7)}/${date.substring(0, 4)}'
        : 'Chưa chọn ngày';
    final status = widget.session?.statusLabel ?? 'Đã lên lịch';
    final statusColor = switch (widget.session?.status) {
      'CANCELLED' || 'MEMBER_ABSENT' => MetaGymTheme.warningAmber,
      _ => MetaGymTheme.progressGreen,
    };
    final focuses = resolveMuscleFocusSet(
      widget.day.title,
      exerciseNames: widget.day.exercises.map((e) => e.exerciseName).toList(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Kế hoạch trong ngày')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/gym_banner.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0xB80F1115))),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MuscleAnatomyTile(
                          focuses: focuses,
                          width: 56,
                          height: 66,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.planTitle?.isNotEmpty == true) ...[
                                Text(
                                  'GIÁO TRÌNH · ${widget.planTitle}',
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: MetaGymTheme.brandOrange,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.day.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.day.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.day.notes!,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
                        ),
                      ),
                    ],
                    if (widget.session?.cancellationReason?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lý do: ${widget.session!.cancellationReason}',
                        style: const TextStyle(
                          color: MetaGymTheme.warningAmber,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(Icons.fitness_center_rounded, 'Lịch tập'),
                    const SizedBox(height: 10),
                    if (widget.day.exercises.isEmpty)
                      const Text(
                        'Coach chưa thêm bài tập.',
                        style: TextStyle(color: MetaGymTheme.darkTextSecondary),
                      )
                    else
                      for (final exercise in widget.day.exercises) ...[
                        Text(
                          exercise.exerciseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (exercise.prescription.isNotEmpty)
                          Text(
                            exercise.prescription,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        if (exercise.notes?.isNotEmpty == true)
                          Text(
                            exercise.notes!,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(Icons.restaurant_menu_rounded, 'Lịch ăn'),
                    const SizedBox(height: 10),
                    if (widget.day.meals.isEmpty)
                      const Text(
                        'Coach chưa xếp bữa ăn cho ngày này.',
                        style: TextStyle(color: MetaGymTheme.darkTextSecondary),
                      )
                    else
                      for (final meal in widget.day.meals) ...[
                        Text(
                          '${meal.typeLabel}${meal.scheduledTime == null ? '' : ' · ${meal.scheduledTime}'}',
                          style: const TextStyle(
                            color: MetaGymTheme.progressGreen,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          meal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (meal.notes?.isNotEmpty == true)
                          Text(
                            meal.notes!,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
              if (widget.session?.status == 'COMPLETED') ...[
                const SizedBox(height: 16),
                _section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(
                        Icons.rate_review_outlined,
                        'Nhận xét của Coach',
                      ),
                      const SizedBox(height: 10),
                      if (_loadingFeedback)
                        const LinearProgressIndicator()
                      else if (_feedback.isEmpty)
                        const Text(
                          'Chưa có nhận xét cho nhật ký tập ngày này.',
                          style: TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
                          ),
                        )
                      else
                        for (final comment in _feedback)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              comment.content,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _heading(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 18, color: MetaGymTheme.brandOrange),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _section({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xC42B2622),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xA3A79D92)),
    ),
    child: child,
  );
}
