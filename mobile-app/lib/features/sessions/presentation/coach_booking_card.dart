import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

DateTime _gymTime(DateTime time) => time.toUtc().add(const Duration(hours: 7));

String _hhmm(DateTime time) => time.toIso8601String().substring(11, 16);

String _ddmmyyyy(DateTime time) =>
    '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';

String formatMemberBookingWindow(
  String startsAtStr, {
  String? endsAtStr,
  required DateTime now,
}) {
  final start = _gymTime(DateTime.parse(startsAtStr));
  final end = endsAtStr != null
      ? _gymTime(DateTime.parse(endsAtStr))
      : start.add(const Duration(minutes: 90));
  final today = _gymTime(now);
  final startDay = DateTime(start.year, start.month, start.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final diffDays = startDay.difference(todayDay).inDays;
  final prefix = switch (diffDays) {
    0 => 'Hôm nay',
    1 => 'Ngày mai',
    _ => _ddmmyyyy(start),
  };
  return '$prefix · ${_hhmm(start)} – ${_hhmm(end)}';
}

/// Member booking card displaying curriculum muscle focus, time range, and actions.
class CoachMemberBookingCard extends StatelessWidget {
  const CoachMemberBookingCard({
    required this.booking,
    required this.isUpcoming,
    required this.now,
    required this.primaryTitle,
    this.matchedDay,
    this.canReschedule = false,
    this.busy = false,
    this.onOpenCurriculum,
    this.onCancel,
    this.onReschedule,
    super.key,
  });

  final CoachRecord booking;
  final bool isUpcoming;
  final DateTime now;
  final String primaryTitle;
  final TrainingDay? matchedDay;
  final bool canReschedule;
  final bool busy;
  final VoidCallback? onOpenCurriculum;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  bool get _isToday {
    if (!isUpcoming) return false;
    final start = _gymTime(DateTime.parse(booking['startsAt'] as String));
    final today = _gymTime(now);
    return start.year == today.year &&
        start.month == today.month &&
        start.day == today.day;
  }

  Widget _buildStatusChip(String status, Object? chargedAt) {
    return switch (status) {
      'BOOKED' => const CoachingPill(
        label: 'Đã đặt',
        tone: CoachingPillTone.coral,
      ),
      'COMPLETED' => const CoachingPill(
        label: 'Đã hoàn thành',
        tone: CoachingPillTone.green,
      ),
      'CANCELLED' when chargedAt != null => const CoachingPill(
        label: 'Đã hủy · Đã trừ lượt',
        tone: CoachingPillTone.amber,
      ),
      _ => const CoachingPill(label: 'Đã hủy', tone: CoachingPillTone.neutral),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final startsAtStr = booking['startsAt'] as String;
    final endsAtStr = booking['endsAt'] as String?;
    final startsAt = DateTime.tryParse(startsAtStr);
    final status = booking['status'] as String;
    final reason = booking['reason'] as String?;
    final chargedAt = booking['chargedAt'];
    final hasCurriculum = matchedDay != null;
    final focuses = hasCurriculum
        ? resolveCoachMuscleFocusSet(
            matchedDay!.title,
            exerciseNames: matchedDay!.exercises
                .map((exercise) => exercise.exerciseName)
                .toList(),
          )
        : const <CoachMuscleFocus>{};
    final timeLabel = formatMemberBookingWindow(
      startsAtStr,
      endsAtStr: endsAtStr,
      now: now,
    );
    final showActions =
        status == 'BOOKED' &&
        isUpcoming &&
        startsAt != null &&
        startsAt.isAfter(now);

    final startGym = startsAt != null ? _gymTime(startsAt) : null;
    final weekdayBadge = startGym == null
        ? 'PT'
        : startGym.weekday == 7
        ? 'CN'
        : 'T${startGym.weekday + 1}';
    final dayNumBadge = startGym == null
        ? '--'
        : startGym.day.toString().padLeft(2, '0');
    final durationMinutes = () {
      if (startsAt == null) return 90;
      final endParsed = endsAtStr != null ? DateTime.tryParse(endsAtStr) : null;
      if (endParsed == null) return 90;
      final diff = endParsed.difference(startsAt).inMinutes;
      return diff > 0 ? diff : 90;
    }();

    final mainRow = hasCurriculum
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoachMuscleAnatomyTile(focuses: focuses, isUpcoming: isUpcoming),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            timeLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _isToday
                                  ? (isLight
                                        ? palette.primaryText
                                        : const Color(0xFFFF9B82))
                                  : (isLight
                                        ? palette.textSecondary
                                        : const Color(0xFFE4DAD1)),
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(status, chargedAt),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      primaryTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.metricPanelBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.metricPanelBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color: palette.primaryText,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Giáo án · ${matchedDay!.exercises.length} bài tập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isLight
                                    ? palette.textPrimary
                                    : const Color(0xFFE4DAD1),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: palette.textWarmMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ô lịch ngày đầy đặn thay cho icon nhỏ đơn điệu
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 50,
                    decoration: BoxDecoration(
                      color: palette.metricPanelBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUpcoming
                            ? MetaGymTheme.brandOrange.withValues(alpha: 0.55)
                            : palette.metricPanelBorder,
                        width: 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          color: isUpcoming
                              ? MetaGymTheme.brandOrange.withValues(
                                  alpha: isLight ? 0.14 : 0.22,
                                )
                              : (isLight
                                    ? palette.surfaceRaised
                                    : const Color(0x28FFFFFF)),
                          alignment: Alignment.center,
                          child: Text(
                            weekdayBadge,
                            style: TextStyle(
                              color: isUpcoming
                                  ? palette.primaryText
                                  : palette.textWarmMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              dayNumBadge,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFeatures: MetaGymTheme.tabularFigures,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isLight
                            ? palette.surfaceSolid
                            : const Color(0xFF2B2622),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUpcoming
                              ? MetaGymTheme.brandOrange.withValues(alpha: 0.65)
                              : palette.borderSolid,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: isUpcoming
                            ? palette.primaryText
                            : palette.textWarmMuted,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: _buildStatusChip(status, chargedAt),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.metricPanelBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: palette.metricPanelBorder,
                            ),
                          ),
                          child: Text(
                            '$durationMinutes phút',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      primaryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14.5,
                        height: 1.22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12.5,
                          color: _isToday
                              ? (isLight
                                    ? palette.primaryText
                                    : const Color(0xFFFF9B82))
                              : palette.textWarmMuted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _isToday
                                  ? (isLight
                                        ? palette.primaryText
                                        : const Color(0xFFFF9B82))
                                  : palette.textWarmMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _isToday
            ? null
            : (isLight ? palette.surfaceSolid : const Color(0xC42B2622)),
        gradient: _isToday
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? [const Color(0xFFFFF4EF), palette.surfaceSolid]
                    : const [Color(0xD8442C23), Color(0xC82B2622)],
                stops: const [0, 0.58],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isToday
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.72)
              : (isLight ? palette.borderSolid : const Color(0xA3A79D92)),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x140F172A)
                : const Color(0x4A000000),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 18,
              right: 18,
              child: IgnorePointer(
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(
                    color: isLight
                        ? palette.glassHighlight
                        : const Color(0x70FFF6EA),
                  ),
                ),
              ),
            ),
            if (_isToday)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onOpenCurriculum != null)
                    MetaGymTap(
                      onTap: onOpenCurriculum,
                      borderRadius: BorderRadius.circular(12),
                      child: mainRow,
                    )
                  else
                    mainRow,
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Lý do: $reason',
                      style: TextStyle(
                        color: isLight
                            ? palette.textSecondary
                            : const Color(0xFFE4DAD1),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: 8),
                    Divider(
                      color: isLight
                          ? palette.borderSolid
                          : const Color(0x26FFF5E9),
                      height: 1,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              backgroundColor: palette.metricPanelBg,
                              side: BorderSide(
                                color: palette.error.withValues(alpha: 0.55),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: busy ? null : onCancel,
                            child: Text(
                              'Hủy buổi',
                              style: TextStyle(
                                color: isLight
                                    ? palette.error
                                    : const Color(0xFFFF9A94),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (canReschedule) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                backgroundColor: palette.metricPanelBg,
                                foregroundColor: palette.textPrimary,
                                side: BorderSide(
                                  color: MetaGymTheme.brandOrange.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: busy ? null : onReschedule,
                              icon: Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: palette.primaryText,
                              ),
                              label: Text(
                                'Đổi giờ',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
