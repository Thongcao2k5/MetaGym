import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:provider/provider.dart';

/// One Coach-authored calendar day of the active curriculum.
/// Synchronized with Futuristic Performance Glass / Warm Smoked Glass.
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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? 72 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? 8 : 16,
        title: const Text(
          'Kế hoạch trong ngày',
          style: TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFFF7F9FC),
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              16,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            children: [
              MetaGymHeroGlassCard(
                padding: const EdgeInsets.all(16),
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
                                    color: Color(0xFFC8C2BC),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: MetaGymTheme.brandOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.day.title,
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.day.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x80211E1C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x9A8C8176)),
                        ),
                        child: Text(
                          widget.day.notes!,
                          style: const TextStyle(
                            color: Color(0xFFE4DAD1),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                    if (widget.session?.cancellationReason?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Lý do: ${widget.session!.cancellationReason}',
                        style: const TextStyle(
                          color: MetaGymTheme.warningAmber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
                    _heading(
                      Icons.fitness_center_rounded,
                      'Lịch tập',
                      color: MetaGymTheme.brandOrange,
                    ),
                    const SizedBox(height: 12),
                    if (widget.day.exercises.isEmpty)
                      const Text(
                        'Coach chưa thêm bài tập.',
                        style: TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 13.5,
                        ),
                      )
                    else
                      for (final (index, exercise)
                          in widget.day.exercises.indexed) ...[
                        if (index > 0)
                          const Divider(color: Color(0x40A79D92), height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x80211E1C),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0x9A8C8176),
                                ),
                              ),
                              child: Text(
                                '${index + 1}'.padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.exerciseName,
                                    style: const TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (exercise.prescription.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      exercise.prescription,
                                      style: const TextStyle(
                                        color: MetaGymTheme.brandOrange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                  if (exercise.notes?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      exercise.notes!,
                                      style: const TextStyle(
                                        color: Color(0xFFE4DAD1),
                                        fontSize: 13,
                                        height: 1.4,
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
              const SizedBox(height: 16),
              _section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      Icons.restaurant_menu_rounded,
                      'Lịch ăn',
                      color: MetaGymTheme.progressGreen,
                    ),
                    const SizedBox(height: 12),
                    if (widget.day.meals.isEmpty)
                      const Text(
                        'Coach chưa xếp bữa ăn cho ngày này.',
                        style: TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 13.5,
                        ),
                      )
                    else
                      for (final (index, meal) in widget.day.meals.indexed) ...[
                        if (index > 0)
                          const Divider(color: Color(0x40A79D92), height: 20),
                        Text(
                          '${meal.typeLabel}${meal.scheduledTime == null ? '' : ' · ${meal.scheduledTime}'}',
                          style: const TextStyle(
                            color: MetaGymTheme.progressGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meal.title,
                          style: const TextStyle(
                            color: Color(0xFFF7F9FC),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (meal.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            meal.notes!,
                            style: const TextStyle(
                              color: Color(0xFFE4DAD1),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
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
                        color: MetaGymTheme.reflectionBlue,
                      ),
                      const SizedBox(height: 10),
                      if (_loadingFeedback)
                        const LinearProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                        )
                      else if (_feedback.isEmpty)
                        const Text(
                          'Chưa có nhận xét cho nhật ký tập ngày này.',
                          style: TextStyle(
                            color: Color(0xFFC8C2BC),
                            fontSize: 13.5,
                          ),
                        )
                      else
                        for (final comment in _feedback)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              comment.content,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 14,
                                height: 1.45,
                              ),
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

  Widget _heading(IconData icon, String label, {required Color color}) => Row(
    children: [
      Icon(icon, size: 19, color: color),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF7F9FC),
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
      border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
    ),
    child: child,
  );
}
