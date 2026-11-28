import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_schedule_calendar.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_coach_nutrition_page.dart';
import 'package:provider/provider.dart';

/// Read-only Member view of the Coach's weekly workout curriculum using the
/// shared compact Week/Month Hero Calendar without legacy "Ngày 1/2" chips.
class MemberCurriculumDetailPage extends StatefulWidget {
  const MemberCurriculumDetailPage({this.id, required this.service, super.key});

  final String? id;
  final MemberTrainingService service;

  @override
  State<MemberCurriculumDetailPage> createState() =>
      _MemberCurriculumDetailPageState();
}

class _MemberCurriculumDetailPageState
    extends State<MemberCurriculumDetailPage> {
  TrainingPlan? _plan;
  List<TrainingPlan> _history = const [];
  String? _coachName;
  String? _error;
  bool _loading = true;
  bool _paused = false;
  bool _heroExpanded = false;

  DateTime _selectedDate = metaGymDateOnly(DateTime.now());
  MetaGymCalendarMode _calendarMode = MetaGymCalendarMode.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  T? _optional<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _coachName = null;
      _paused = false;
      if (widget.id == null) _history = const [];
    });
    try {
      final plan = widget.id == null
          ? await widget.service.getActive()
          : await widget.service.getPlan(widget.id!);
      if (!mounted) return;
      if (widget.id == null) {
        final history = await widget.service.getHistory();
        if (!mounted) return;
        setState(
          () => _history = history
              .where((item) => item.status == 'ARCHIVED' && item.id != plan?.id)
              .toList(),
        );
      }
      if (plan == null) {
        setState(() => _plan = null);
        return;
      }
      if (plan.status != 'ACTIVE' && plan.status != 'ARCHIVED') {
        setState(() => _error = 'Không tìm thấy giáo trình của bạn.');
        return;
      }
      final initialDate = _resolveInitialSelectedDate(plan);
      setState(() {
        _plan = plan;
        _selectedDate = initialDate;
      });

      if (!mounted) return;
      final coaching = _optional<MemberCoachingService>();
      if (coaching != null) {
        try {
          final relationship = await coaching.getCurrentRelationship();
          final names = await coaching.getCoachNames();
          if (mounted) {
            setState(() {
              _paused =
                  plan.status == 'ACTIVE' &&
                  relationship?.coachId == plan.coachId &&
                  relationship?.status == 'PAUSED';
              _coachName = names[plan.coachId];
            });
          }
        } catch (_) {
          // Curriculum remains readable when Coach metadata is unavailable.
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _resolveInitialSelectedDate(TrainingPlan plan) {
    final today = metaGymDateOnly(DateTime.now());
    if (_dayForDate(plan, today) != null || plan.days.isEmpty) {
      return today;
    }
    return _anchorDateForDay(plan.days.first, reference: today);
  }

  DateTime _anchorDateForDay(TrainingDay day, {DateTime? reference}) {
    final raw = day.scheduledDate;
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw.trim());
      if (parsed != null) return metaGymDateOnly(parsed);
    }
    final base = metaGymDateOnly(reference ?? _selectedDate);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    final weekdayOffset = (day.dayNumber - 1) % DateTime.daysPerWeek;
    return monday.add(Duration(days: weekdayOffset));
  }

  int _weekdayOf(TrainingDay day) => day.recurringWeekday;

  TrainingDay? _dayForDate(TrainingPlan plan, DateTime date) =>
      plan.dayForDate(date);

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  MetaGymColors get _colors => MetaGymColors.of(context);

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _palette.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.brandOrange,
                backgroundColor: _colors.surface,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.paddingOf(context).bottom + 36,
                  ),
                  children: [
                    _header(context),
                    const SizedBox(height: 12),
                    if (_loading && plan == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 64),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        ),
                      )
                    else if (_error != null)
                      _message(
                        icon: Icons.error_outline_rounded,
                        title: 'Chưa tải được giáo trình',
                        body: _error!,
                        action: FilledButton.icon(
                          onPressed: _load,
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const MetaGymSvgIcon(
                            MetaGymIcons.commonRefresh,
                            size: 18,
                            fallbackIcon: Icons.refresh_rounded,
                          ),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else if (plan == null) ...[
                      _emptyHero(),
                      const SizedBox(height: 12),
                      _message(
                        icon: Icons.fitness_center_outlined,
                        title: 'Chưa có kế hoạch tập luyện',
                        body:
                            'Coach chưa gửi giáo trình tập luyện cho bạn. Khi Coach công bố, nội dung sẽ xuất hiện tại đây.',
                      ),
                    ] else ...[
                      _hero(plan),
                      const SizedBox(height: 10),
                      if (_paused) ...[
                        _pausedNotice(),
                        const SizedBox(height: 10),
                      ],
                      _training(plan),
                    ],
                    if (!_loading && _error == null && _history.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _archivedPlans(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final hasApi = _optional<ApiClient>() != null;
    return Row(
      children: [
        if (canPop) ...[
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.commonBack,
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GIÁO TRÌNH COACH',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _palette.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Giáo trình tập luyện',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (widget.id == null && hasApi) ...[
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.actionNutrition,
            icon: Icons.restaurant_menu_rounded,
            tooltip: 'Thực đơn Coach',
            onTap: () => MetaGymNavigation.pushOnce<void>(
              context,
              MetaGymPageRoute(builder: (_) => const MemberCoachNutritionPage()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _hero(TrainingPlan plan) {
    final status = _paused
        ? 'Tạm khóa'
        : plan.status == 'ARCHIVED'
        ? 'Đã lưu trữ'
        : 'Đang áp dụng';
    final statusColor = _paused
        ? _palette.warning
        : plan.status == 'ARCHIVED'
        ? _palette.reflection
        : _palette.success;
    final coach = _coachName;

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(14),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          expanded: _heroExpanded,
          label:
              '${_heroExpanded ? 'Thu gọn' : 'Mở rộng'} thông tin giáo trình',
          child: MetaGymTap(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _heroExpanded = !_heroExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.42,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const MetaGymSvgIcon(
                          MetaGymIcons.actionCurriculum,
                          size: 20,
                          fallbackIcon: Icons.menu_book_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plan.title,
                          style: TextStyle(
                            color: _palette.textPrimary,
                            fontSize: 16.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MetaGymResolvedIcon(
                        _heroExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        fallbackColor: _palette.textPrimary,
                      ),
                    ],
                  ),
                ),
                if (_heroExpanded) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _status(status, statusColor),
                      const Spacer(),
                      if (plan.publishedAt != null)
                        Text(
                          _date(plan.publishedAt!),
                          style: TextStyle(
                            color: _palette.textWarmMuted,
                            fontSize: 12,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                    ],
                  ),
                  if (plan.goal?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      plan.goal!,
                      style: TextStyle(
                        color: _palette.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Divider(
                    color: _palette.borderSolid.withValues(alpha: 0.7),
                    height: 1,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (coach != null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: MetaGymTheme.coachAvatarBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _initials(coach),
                            style: const TextStyle(
                              color: MetaGymTheme.coachAvatarForeground,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            coach,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _palette.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      _smallChip('${plan.days.length} ngày tập'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyHero() => MetaGymHeroGlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _status('Chờ Coach', _palette.warning),
        const SizedBox(height: 12),
        Text(
          'Chưa có giáo trình',
          style: TextStyle(
            color: _palette.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Coach sẽ công bố lịch tập và hệ thống bài tập hằng tuần phù hợp với mục tiêu của bạn.',
          style: TextStyle(
            color: _palette.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    ),
  );

  Widget _pausedNotice() => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    borderColor: _palette.warning.withValues(alpha: 0.55),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MetaGymSvgIcon(
              MetaGymIcons.settingPrivacyLock,
              fallbackIcon: Icons.lock_clock_outlined,
            ),
            const SizedBox(width: 8),
            Text(
              'Giáo trình đang tạm khóa',
              style: TextStyle(
                color: _palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Kế hoạch Coach đã tạo được giữ lại. Gia hạn gói Gym để tiếp tục sử dụng khi quan hệ Coach có hiệu lực.',
          style: TextStyle(
            color: _palette.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => MetaGymNavigation.pushOnce<void>(
            context,
            MetaGymPageRoute(builder: (_) => const MembershipPage()),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Gia hạn gói tập',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _training(TrainingPlan plan) {
    final days = plan.days;
    if (days.isEmpty) {
      return _message(
        icon: Icons.calendar_today_outlined,
        title: 'Chưa có lịch tập',
        body: 'Coach chưa thêm bài tập vào giáo trình.',
      );
    }

    final visibleDays = metaGymVisibleCalendarDays(_selectedDate, _calendarMode);
    var activeDaysInPeriod = 0;
    for (final day in visibleDays) {
      if (_calendarMode == MetaGymCalendarMode.month &&
          day.month != _selectedDate.month) {
        continue;
      }
      if (_dayForDate(plan, day) != null) activeDaysInPeriod++;
    }

    final weeklyDaysCount = days.map(_weekdayOf).toSet().length;
    final selectedDay = _dayForDate(plan, _selectedDate);
    final selectedExercises = selectedDay?.exercises.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaGymScheduleCalendar(
          selectedDate: _selectedDate,
          mode: _calendarMode,
          onSelectDate: (date) => setState(() => _selectedDate = date),
          onModeChanged: (mode) => setState(() => _calendarMode = mode),
          badgeCountForDay: (day) =>
              (_dayForDate(plan, day)?.exercises.length ?? 0).clamp(0, 3),
          badgeColorForDay: (_) => _palette.success,
          stats: [
            MetaGymCalendarStat(
              label: _calendarMode == MetaGymCalendarMode.week
                  ? 'Tuần này'
                  : 'Tháng này',
              value: '$activeDaysInPeriod buổi',
              accent: _palette.primaryText,
            ),
            MetaGymCalendarStat(
              label: 'Lịch tuần',
              value: '$weeklyDaysCount/7',
              accent: _palette.success,
            ),
            MetaGymCalendarStat(
              label: 'Bài tập',
              value: '$selectedExercises bài',
              accent: _palette.reflection,
            ),
          ],
        ),
        if (!_paused) ...[
          const SizedBox(height: 12),
          if (selectedDay == null)
            _restDayCard(plan)
          else ...[
            _dayFocusCard(selectedDay),
            const SizedBox(height: 10),
            if (selectedDay.exercises.isEmpty)
              _message(
                icon: Icons.fitness_center_outlined,
                title: 'Chưa có bài tập',
                body: 'Coach chưa xếp bài tập cho ngày này.',
              )
            else
              for (final (index, exercise) in selectedDay.exercises.indexed)
                _exercise(exercise, index + 1),
          ],
        ],
      ],
    );
  }

  Widget _restDayCard(TrainingPlan plan) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: 24,
              color: _palette.reflection,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ngày nghỉ phục hồi',
                style: TextStyle(
                  color: _palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Không có buổi tập trong giáo án vào ${_dateHeading(_selectedDate).toLowerCase()}. Nghỉ ngơi đủ giấc hoặc chuyển tới buổi tập trong tuần.',
          style: TextStyle(
            color: _palette.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (plan.days.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _selectedDate = _anchorDateForDay(plan.days.first),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _palette.primaryText,
              side: BorderSide(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
              ),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.event_available_rounded, size: 18),
            label: Text(
              'Tới buổi tập gần nhất: ${plan.days.first.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _dayFocusCard(TrainingDay day) {
    final dayFocuses = resolveMuscleFocusSet(
      day.title,
      exerciseNames: day.exercises.map((e) => e.exerciseName).toList(),
    );
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MuscleAnatomyTile(
                focuses: dayFocuses,
                width: 56,
                height: 68,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateHeading(_selectedDate).toUpperCase(),
                      style: TextStyle(
                        color: _palette.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.title,
                      style: TextStyle(
                        color: _palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.isRestOrRecovery
                          ? 'Ngày nghỉ ngơi · hồi phục (không đặt lịch PT)'
                          : '${day.exercises.length} bài tập theo giáo án Coach',
                      style: TextStyle(
                        color: day.isRestOrRecovery
                            ? _palette.reflection
                            : _palette.textWarmMuted,
                        fontSize: 12,
                        fontWeight: day.isRestOrRecovery
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (day.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _note(day.notes!),
          ],
        ],
      ),
    );
  }

  Widget _exercise(TrainingExercise exercise, int number) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _smallChip(number.toString().padLeft(2, '0')),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.exerciseName,
                  style: TextStyle(
                    color: _palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (exercise.prescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _palette.chipActiveBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                exercise.prescription,
                style: TextStyle(
                  color: _palette.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ),
          ],
          if (exercise.restSeconds != null ||
              exercise.weightGuidance?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (exercise.restSeconds != null)
                  'Nghỉ ${exercise.restSeconds} giây',
                if (exercise.weightGuidance?.isNotEmpty == true)
                  'Mức tạ ${exercise.weightGuidance}',
              ].join(' · '),
              style: TextStyle(
                color: _palette.textWarmMuted,
                fontSize: 12.5,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
          for (final note in [
            exercise.instructions,
            exercise.safetyNotes,
            exercise.notes,
          ])
            if (note?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _note(note!),
            ],
        ],
      ),
    ),
  );

  Widget _archivedPlans() => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MetaGymSvgIcon(
              MetaGymIcons.workoutHistory,
              size: 18,
              fallbackIcon: Icons.history_rounded,
            ),
            const SizedBox(width: 8),
            Text(
              'Giáo trình đã lưu trữ',
              style: TextStyle(
                color: _palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final old in _history)
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                old.title,
                style: TextStyle(
                  color: _palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const MetaGymSvgIcon(
                MetaGymIcons.commonChevronRight,
                fallbackIcon: Icons.chevron_right_rounded,
              ),
              onTap: () => MetaGymNavigation.pushOnce<void>(
                context,
                MetaGymPageRoute(
                  builder: (_) => MemberCurriculumDetailPage(
                    id: old.id,
                    service: widget.service,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaGymResolvedIcon(icon, size: 24, fallbackColor: _palette.reflection),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: _palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: TextStyle(
            color: _palette.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action],
      ],
    ),
  );

  Widget _note(String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _palette.metricPanelBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _palette.metricPanelBorder),
    ),
    child: Text(
      value,
      style: TextStyle(
        color: _palette.textSecondary,
        fontSize: 12.5,
        height: 1.45,
      ),
    ),
  );

  Widget _status(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: MetaGymTheme.tabularFigures,
      ),
    ),
  );

  Widget _smallChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: _palette.metricPanelBg,
      border: Border.all(color: _palette.metricPanelBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: _palette.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: MetaGymTheme.tabularFigures,
      ),
    ),
  );

  String _dateHeading(DateTime date) {
    final today = metaGymDateOnly(DateTime.now());
    final weekday = date.weekday == 7 ? 'Chủ nhật' : 'Thứ ${date.weekday + 1}';
    final dmy = _dateObjLabel(date);
    return metaGymIsoDate(date) == metaGymIsoDate(today)
        ? 'Hôm nay · $weekday, $dmy'
        : '$weekday · $dmy';
  }

  String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _dateObjLabel(parsed);
  }

  String _dateObjLabel(DateTime parsed) =>
      '${parsed.day.toString().padLeft(2, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}
