import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_card.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

/// Dedicated history view for Member's completed and cancelled Coach sessions.
class CoachBookingHistoryPage extends StatelessWidget {
  const CoachBookingHistoryPage({
    required this.bookings,
    required this.matchPlanDay,
    required this.onOpenPlanDay,
    super.key,
  });

  final List<CoachRecord> bookings;
  final TrainingDay? Function(String startsAt) matchPlanDay;
  final void Function(TrainingDay? day) onOpenPlanDay;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final now = DateTime.now();
    final completedCount = bookings
        .where((b) => b['status'] == 'COMPLETED')
        .length;
    final cancelledCount = bookings.length - completedCount;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lịch sử buổi tập',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Các buổi đã tập & đã hủy với Coach',
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      6,
                      16,
                      MediaQuery.paddingOf(context).bottom + 32,
                    ),
                    children: [
                      MetaGymHeroGlassCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: MetaGymMetricPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đã hoàn thành',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount buổi',
                                      style: TextStyle(
                                        color: palette.success,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MetaGymMetricPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đã hủy / Khác',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$cancelledCount buổi',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: palette.primaryText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Các buổi đã tập & đã hủy',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${bookings.length} buổi',
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (bookings.isEmpty)
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Chưa có lịch sử buổi tập với Coach.',
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final booking in bookings) ...[
                          Builder(
                            builder: (context) {
                              final matchedDay = matchPlanDay(
                                booking['startsAt'] as String,
                              );
                              final coachName = booking['coachName'] as String?;
                              return CoachMemberBookingCard(
                                booking: booking,
                                isUpcoming: false,
                                now: now,
                                primaryTitle:
                                    matchedDay?.title ??
                                    (coachName != null &&
                                            coachName.trim().isNotEmpty
                                        ? coachName.trim()
                                        : 'Huấn luyện viên'),
                                matchedDay: matchedDay,
                                onOpenCurriculum: matchedDay != null
                                    ? () => onOpenPlanDay(matchedDay)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
