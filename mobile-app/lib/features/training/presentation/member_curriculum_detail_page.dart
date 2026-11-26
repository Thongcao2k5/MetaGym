import 'dart:ui';

import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Read-only Member view of the Coach's training and seven-day meal plan.
/// Synchronized with Member Home's Futuristic Performance Glass / Warm Smoked Glass system.
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
  CoachRecord? _mealPlan;
  String? _coachName;
  String? _error;
  String? _mealError;
  bool _loading = true;
  bool _paused = false;
  bool _heroExpanded = false;
  int _tab = 0;
  int _day = 0;
  int _weekday = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _mealError = null;
      _mealPlan = null;
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
      setState(() {
        _plan = plan;
        _day = plan.days.isEmpty
            ? 0
            : _day.clamp(0, plan.days.length - 1).toInt();
      });

      try {
        final api = CoachV2Api(context.read<ApiClient>());
        final plans = await api.list('/meal-plans/me');
        if (mounted) {
          setState(() {
            _mealPlan = plan.relationshipId == null
                ? null
                : plans
                      .where(
                        (item) =>
                            item['relationshipId'] == plan.relationshipId &&
                            item['status'] == plan.status,
                      )
                      .firstOrNull;
          });
        }
      } on ApiException catch (error) {
        if (mounted) setState(() => _mealError = error.message);
      } catch (_) {
        if (mounted) setState(() => _mealError = 'Không tải được thực đơn.');
      }

      if (!mounted) return;
      try {
        final coaching = context.read<MemberCoachingService>();
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
        // The curriculum remains readable when Coach metadata is unavailable.
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CoachRecord> get _items {
    final raw = _mealPlan?['items'];
    return raw is List
        ? raw.whereType<Map>().map((item) => CoachRecord.from(item)).toList()
        : const [];
  }

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  MetaGymColors get _colors => MetaGymColors.of(context);
  bool get _isLight => MetaGymTheme.isLightPalette(context);

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
            RefreshIndicator(
              color: MetaGymTheme.primary,
              backgroundColor: _colors.surface,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _header(context, plan),
                  if (_loading && plan == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.primary,
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
                          backgroundColor: MetaGymTheme.primary,
                          foregroundColor: MetaGymTheme.onPrimary,
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                        label: const Text(
                          'Thử lại',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else if (plan == null) ...[
                    _tabSelector(null),
                    _message(
                      icon: _tab == 0
                          ? Icons.fitness_center_outlined
                          : Icons.restaurant_menu_outlined,
                      title: _tab == 0
                          ? 'Chưa có kế hoạch tập luyện'
                          : 'Chưa có kế hoạch dinh dưỡng',
                      body:
                          'Coach chưa gửi giáo trình cho bạn. Khi Coach công bố, nội dung sẽ xuất hiện tại đây.',
                    ),
                  ] else ...[
                    _tabSelector(plan),
                    if (_paused) _pausedNotice(),
                    if (_tab == 0) _training(plan) else _nutrition(),
                  ],
                  if (!_loading && _error == null && _history.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _archivedPlans(),
                  ],
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TrainingPlan? plan) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop()) ...[
                  MetaGymCircleIconButton(
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
                        'META GYM · GIÁO TRÌNH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _palette.primaryText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Giáo trình',
                        style: TextStyle(
                          color: _palette.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _headerButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Nhắn Coach',
                  onPressed: () => MetaGymNavigation.pushPathOnce(
                    context,
                    '/member/features/messages',
                  ),
                ),
              ],
            ),
            if (plan != null) ...[
              const SizedBox(height: 14),
              _hero(plan),
            ],
            if (plan == null && !_loading && _error == null) ...[
              const SizedBox(height: 14),
              _emptyHero(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: MetaGymResolvedIcon(icon, size: 17, fallbackColor: _palette.textPrimary),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      foregroundColor: _palette.textPrimary,
      backgroundColor: _colors.circleButtonBg,
      side: BorderSide(color: _colors.circleButtonBorder, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        fontFamily: MetaGymTheme.fontFamily,
      ),
    ),
  );

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
    final disableBlur =
        MediaQuery.disableAnimationsOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment;
    final radius = BorderRadius.circular(24);
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: disableBlur ? _colors.surface : null,
        gradient: disableBlur
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_colors.warmGlassTop, _colors.warmGlassBottom],
              ),
        borderRadius: radius,
        border: Border.all(color: _colors.warmGlassBorder, width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: _colors.warmGlassHighlight),
            ),
          ),
          Padding(
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
                                color: MetaGymTheme.primary.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: MetaGymTheme.primary.withValues(
                                    alpha: 0.42,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: MetaGymSvgIcon(MetaGymIcons.actionCurriculum, size: 20, fallbackIcon: Icons.menu_book_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                plan.title,
                                style: TextStyle(
                                  color: _palette.textPrimary,
                                  fontSize: 17,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: MetaGymTheme.fontFamily,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            MetaGymResolvedIcon(_heroExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded, size: 24, fallbackColor: _palette.textPrimary),
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
                                  fontSize: 11.5,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                  fontFamily: MetaGymTheme.fontFamily,
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
                              fontFamily: MetaGymTheme.fontFamily,
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
                                    fontFamily: MetaGymTheme.fontFamily,
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
          ),
        ],
      ),
    );
    if (disableBlur) return card;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: card,
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
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Coach sẽ gửi kế hoạch tập luyện và dinh dưỡng phù hợp cho bạn.',
          style: TextStyle(
            color: _palette.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    ),
  );

  Widget _archivedPlans() => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MetaGymSvgIcon(MetaGymIcons.workoutHistory, size: 18, fallbackIcon: Icons.history_rounded),
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
              trailing: MetaGymSvgIcon(MetaGymIcons.commonChevronRight, fallbackIcon: Icons.chevron_right_rounded),
              onTap: () => MetaGymNavigation.pushOnce(
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

  Widget _tabSelector(TrainingPlan? plan) {
    final count = _mealPlan == null ? 'Chưa có' : 'T2–CN';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(5),
      decoration: _box(
        fill: _isLight ? _palette.surfaceRaised : const Color(0xD826221F),
        border: _colors.liquidGlassBorder,
        radius: 16,
      ),
      child: Row(
        children: [
          for (final (index, label, badge) in [
            (
              0,
              'Tập luyện',
              plan == null ? 'Chưa có' : '${plan.days.length} ngày',
            ),
            (1, 'Dinh dưỡng', count),
          ])
            Expanded(
              child: MetaGymTap(
                onTap: () => setState(() => _tab = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == index
                        ? (_isLight
                              ? MetaGymTheme.primary
                              : MetaGymTheme.primary.withValues(alpha: 0.20))
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _tab == index
                          ? MetaGymTheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: _tab == index
                                ? const Color(0xFFFFFFFF)
                                : _palette.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: MetaGymTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badge,
                          style: TextStyle(
                            color: _tab == index
                                ? (_isLight
                                      ? const Color(0xE6FFFFFF)
                                      : const Color(0xFFFF987E))
                                : _palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pausedNotice() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(16),
    decoration: _box(border: _palette.warning.withValues(alpha: 0.55)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MetaGymSvgIcon(MetaGymIcons.settingPrivacyLock, fallbackIcon: Icons.lock_clock_outlined),
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
          onPressed: () => MetaGymNavigation.pushOnce(
            context,
            MetaGymPageRoute(builder: (_) => const MembershipPage()),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
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
        title: 'Chưa có ngày tập',
        body: 'Coach chưa thêm bài tập vào giáo trình.',
      );
    }
    final day = days[_day];
    final dayFocuses = resolveMuscleFocusSet(
      day.title,
      exerciseNames: day.exercises.map((e) => e.exerciseName).toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _choice(
              title: 'Ngày ${days[index].dayNumber}',
              subtitle: '${days[index].exercises.length} bài tập',
              selected: _day == index,
              onTap: _paused ? null : () => setState(() => _day = index),
            ),
          ),
        ),
        if (_paused)
          const SizedBox.shrink()
        else ...[
          const SizedBox(height: 10),
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MuscleAnatomyTile(
                      focuses: dayFocuses,
                      width: 52,
                      height: 62,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày ${day.dayNumber} trong giáo án',
                            style: TextStyle(
                              color: _palette.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
                          if (day.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Lịch: ${_date(day.scheduledDate!)}',
                              style: TextStyle(
                                color: _palette.textWarmMuted,
                                fontSize: 12,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
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
          ),
          const SizedBox(height: 10),
          if (day.exercises.isEmpty)
            _message(
              icon: Icons.fitness_center_outlined,
              title: 'Chưa có bài tập',
              body: 'Coach chưa xếp bài tập cho ngày này.',
            )
          else
            for (final (index, exercise) in day.exercises.indexed)
              _exercise(exercise, index + 1),
        ],
      ],
    );
  }

  Widget _exercise(TrainingExercise exercise, int number) => _surface(
    bottom: 12,
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
                color: MetaGymTheme.primary.withValues(alpha: 0.35),
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
  );

  Widget _nutrition() {
    if (_paused) return const SizedBox.shrink();
    if (_mealError != null) {
      return _message(
        icon: Icons.error_outline_rounded,
        title: 'Chưa tải được thực đơn',
        body: _mealError!,
        action: TextButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }
    final plan = _mealPlan;
    if (plan == null) {
      return _message(
        icon: Icons.restaurant_menu_outlined,
        title: 'Chưa có thực đơn từ Coach',
        body:
            'Thực đơn 7 ngày sẽ xuất hiện khi Coach lưu hướng dẫn dinh dưỡng.',
      );
    }
    final items = _items.where((item) => item['day'] == _weekday).toList();
    final total = items.fold<double>(0, (sum, item) => sum + _kcal(item));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) => _choice(
              title: index == 6 ? 'CN' : 'T${index + 2}',
              selected: _weekday == index + 1,
              color: _palette.success,
              onTap: () => setState(() => _weekday = index + 1),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekday == 7 ? 'Chủ nhật' : 'Thứ ${_weekday + 1}'} · Lặp lại mỗi tuần',
                      style: TextStyle(
                        color: _palette.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    _status('${total.round()} kcal', _palette.success),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                plan['title'] as String? ?? 'Thực đơn của Coach',
                style: TextStyle(
                  color: _palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _message(
            icon: Icons.restaurant_outlined,
            title: 'Chưa có món cho ngày này',
            body:
                'Coach chưa thêm món vào thực đơn ${_weekday == 7 ? 'Chủ nhật' : 'Thứ ${_weekday + 1}'}.',
          )
        else
          for (final meal in const [
            ('BREAKFAST', 'Bữa sáng', Icons.wb_sunny_outlined),
            ('LUNCH', 'Bữa trưa', Icons.light_mode_outlined),
            ('DINNER', 'Bữa tối', Icons.nightlight_outlined),
          ])
            _mealGroup(meal.$1, meal.$2, meal.$3, items),
        if ((plan['content'] as String?)?.trim().isNotEmpty == true)
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý từ Coach',
                  style: TextStyle(
                    color: _palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan['content'] as String,
                  style: TextStyle(
                    color: _palette.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mealGroup(
    String key,
    String title,
    IconData icon,
    List<CoachRecord> items,
  ) {
    final foods = items.where((item) => item['meal'] == key).toList();
    final total = foods.fold<double>(0, (sum, item) => sum + _kcal(item));
    return _surface(
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymResolvedIcon(icon, size: 19, fallbackColor: _palette.success),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (foods.isNotEmpty)
                Text(
                  '${total.round()} kcal',
                  style: TextStyle(
                    color: _palette.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (foods.isEmpty)
            Text(
              'Chưa có món',
              style: TextStyle(color: _palette.textWarmMuted, fontSize: 13),
            )
          else
            for (final food in foods) ...[
              Divider(
                color: _palette.borderSolid.withValues(alpha: 0.7),
                height: 16,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      food['foodName'] as String? ?? 'Thực phẩm',
                      style: TextStyle(
                        color: _palette.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${food['grams']} g · ${_kcal(food).round()} kcal',
                    style: TextStyle(
                      color: _palette.textWarmMuted,
                      fontSize: 12.5,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _choice({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final activeColor = color ?? _palette.primaryText;
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: MetaGymTheme.stateDurationOf(context),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: _box(
          fill: selected
              ? activeColor.withValues(alpha: 0.14)
              : _colors.liquidGlass,
          border: selected ? activeColor : _colors.liquidGlassBorder,
          radius: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: selected ? activeColor : _palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: _palette.textSecondary,
                  fontSize: 11,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _surface({required Widget child, double bottom = 0}) => Container(
    margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    padding: const EdgeInsets.all(16),
    decoration: _box(),
    child: child,
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) => _surface(
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
    decoration: _box(
      fill: _palette.metricPanelBg,
      border: _palette.metricPanelBorder,
      radius: 14,
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
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: MetaGymTheme.tabularFigures,
        fontFamily: MetaGymTheme.fontFamily,
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

  BoxDecoration _box({
    Color? fill,
    Color? border,
    double radius = 20,
  }) => BoxDecoration(
    color: fill ?? _colors.liquidGlass,
    border: Border.all(color: border ?? _colors.liquidGlassBorder, width: 1.1),
    borderRadius: BorderRadius.circular(radius),
  );

  String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  double _kcal(CoachRecord food) {
    final grams = food['grams'];
    final per100 = food['kcalPer100g'];
    return grams is num && per100 is num ? grams * per100 / 100 : 0;
  }
}
