import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:provider/provider.dart';

class CoachTrainingPage extends StatefulWidget {
  const CoachTrainingPage({this.service, super.key});

  final CoachTrainingService? service;

  @override
  State<CoachTrainingPage> createState() => _CoachTrainingPageState();
}

class _CoachTrainingPageState extends State<CoachTrainingPage> {
  CoachTrainingService? _service;
  List<CoachMemberSummary> _members = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachTrainingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _members = const [];
      _error = null;
    });
    try {
      final members = await _service!.getMembers();
      if (mounted) setState(() => _members = members);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.canvas,
        extendBodyBehindAppBar: true,
        appBar: _buildCoachDarkAppBar(
          context,
          title: 'Giáo trình của Coach',
          canPop: canPop,
          onRefresh: _loading ? null : _load,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.primary,
                    backgroundColor: colors.surface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: _scrollPadding(context),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            onPressed: _load,
                            expand: true,
                          ),
                        ] else ...[
                          _SectionHeaderRow(
                            icon: Icons.fitness_center_rounded,
                            title: 'Chọn hội viên',
                            badge: '${_members.length} hội viên',
                          ),
                          const SizedBox(height: 12),
                          if (_members.isEmpty)
                            const _EmptyStateCard(
                              icon: Icons.group_outlined,
                              title: 'Chưa có hội viên đang phụ trách.',
                              subtitle: 'Hội viên đang đồng hành sẽ hiển thị tại đây để bạn thiết kế giáo trình tập luyện.',
                            )
                          else
                            for (final member in _members)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                onTap: () async {
                                  await MetaGymNavigation.pushOnce<void>(
                                    context,
                                    MetaGymPageRoute(
                                      builder: (_) => _MemberPlansPage(
                                        member: member,
                                        service: _service!,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _load();
                                },
                                child: Row(
                                  children: [
                                    CoachingAvatar(
                                      fullName: member.memberFullName,
                                      size: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.memberFullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          CoachingPill(
                                            label: member.statusLabel,
                                            tone: member.status == 'ACTIVE'
                                                ? CoachingPillTone.green
                                                : CoachingPillTone.amber,
                                            icon: member.status == 'ACTIVE'
                                                ? Icons.check_circle_outline
                                                : Icons.pause_circle_outline,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: palette.textSecondary,
                                    ),
                                  ],
                                ),
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

class _MemberPlansPage extends StatefulWidget {
  const _MemberPlansPage({required this.member, required this.service});

  final CoachMemberSummary member;
  final CoachTrainingService service;

  @override
  State<_MemberPlansPage> createState() => _MemberPlansPageState();
}

class _MemberPlansPageState extends State<_MemberPlansPage> {
  List<TrainingPlan> _plans = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _plans = const [];
      _error = null;
    });
    try {
      final plans = await widget.service.getPlans(widget.member.memberId);
      if (mounted) setState(() => _plans = plans);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlan(String id) async {
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachPlanDetailPage(
          id: id,
          service: widget.service,
          memberId: widget.member.memberId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final id = await MetaGymNavigation.pushOnce<String>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: widget.member.memberId,
          service: widget.service,
        ),
      ),
    );
    if (!mounted || id == null) return;
    await _load();
    if (mounted) await _openPlan(id);
  }

  Set<MuscleFocus> _resolvePlanFocuses(TrainingPlan plan) {
    final focuses = <MuscleFocus>{};
    for (final day in plan.days) {
      focuses.addAll(
        resolveMuscleFocusSet(
          day.title,
          exerciseNames: day.exercises.map((e) => e.exerciseName).toList(),
        ),
      );
    }
    return focuses;
  }

  CoachingPillTone _planPillTone(String status) => switch (status) {
    'ACTIVE' => CoachingPillTone.green,
    'DRAFT' => CoachingPillTone.amber,
    _ => CoachingPillTone.neutral,
  };

  IconData _planPillIcon(String status) => switch (status) {
    'ACTIVE' => Icons.verified_outlined,
    'DRAFT' => Icons.edit_note_rounded,
    _ => Icons.archive_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visiblePlans = _plans
        .where(
          (plan) =>
              widget.service is! CoachTrainingApi || plan.status != 'DRAFT',
        )
        .toList();
    final canCreate =
        widget.service is! CoachTrainingApi ||
        !_plans.any((plan) => plan.status == 'ACTIVE');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.canvas,
        extendBodyBehindAppBar: true,
        appBar: _buildCoachDarkAppBar(
          context,
          title: 'Giáo trình · ${widget.member.memberFullName}',
          canPop: Navigator.of(context).canPop(),
          onRefresh: _loading ? null : _load,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.primary,
                    backgroundColor: colors.surface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: _scrollPadding(context),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            onPressed: _load,
                            expand: true,
                          ),
                        ] else ...[
                          CoachingGraphiteCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CoachingAvatar(
                                  fullName: widget.member.memberFullName,
                                  size: 42,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.member.memberFullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${visiblePlans.length} giáo trình đã tạo',
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CoachingPill(
                                  label: widget.member.statusLabel,
                                  tone: widget.member.status == 'ACTIVE'
                                      ? CoachingPillTone.green
                                      : CoachingPillTone.amber,
                                ),
                              ],
                            ),
                          ),
                          if (canCreate) ...[
                            const SizedBox(height: 12),
                            CoachingPrimaryButton(
                              label: 'Tạo giáo trình',
                              icon: Icons.add_rounded,
                              onPressed: _create,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _SectionHeaderRow(
                            icon: Icons.layers_outlined,
                            title: 'Danh sách giáo trình',
                            badge: '${visiblePlans.length} bản',
                          ),
                          const SizedBox(height: 12),
                          if (visiblePlans.isEmpty)
                            const _EmptyStateCard(
                              icon: Icons.assignment_outlined,
                              title: 'Chưa có giáo trình nào.',
                              subtitle: 'Nhấn "Tạo giáo trình" để thiết kế lịch tập và bữa ăn theo ngày cho hội viên.',
                            )
                          else
                            for (final plan in visiblePlans) ...[
                              _PlanSummaryCard(
                                plan: plan,
                                focuses: _resolvePlanFocuses(plan),
                                pillTone: _planPillTone(plan.status),
                                pillIcon: _planPillIcon(plan.status),
                                onTap: () => _openPlan(plan.id),
                              ),
                            ],
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

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.plan,
    required this.focuses,
    required this.pillTone,
    required this.pillIcon,
    required this.onTap,
  });

  final TrainingPlan plan;
  final Set<MuscleFocus> focuses;
  final CoachingPillTone pillTone;
  final IconData pillIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MuscleAnatomyTile(
            focuses: focuses,
            width: 52,
            height: 64,
            isUpcoming: plan.status != 'ARCHIVED',
            selected: plan.status == 'ACTIVE',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoachingPill(
                  label: '${plan.statusLabel} · Phiên bản ${plan.version}',
                  tone: pillTone,
                  icon: pillIcon,
                ),
                const SizedBox(height: 8),
                Text(
                  plan.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (plan.goal?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.goal!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: palette.reflection,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.days.length} ngày tập',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (focuses.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.accessibility_new_rounded,
                            size: 13,
                            color: palette.primaryText,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              summarizeMuscleFocuses(focuses),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Icon(
              Icons.chevron_right_rounded,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

PreferredSizeWidget _buildCoachDarkAppBar(
  BuildContext context, {
  required String title,
  required bool canPop,
  VoidCallback? onRefresh,
}) {
  final palette = MetaGymTheme.paletteOf(context);
  return AppBar(
    automaticallyImplyLeading: false,
    leadingWidth: 72,
    leading: canPop
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MetaGymCircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
        : null,
    titleSpacing: canPop ? 8 : 16,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: onRefresh,
          ),
        ),
      ),
    ],
    backgroundColor: Colors.transparent,
    foregroundColor: palette.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}

EdgeInsets _scrollPadding(BuildContext context) {
  final media = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    16,
    media.top + kToolbarHeight + 12,
    16,
    media.bottom + 24,
  );
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.icon,
    required this.title,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      children: [
        Icon(icon, color: palette.primaryText, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        CoachingPill(label: badge, tone: CoachingPillTone.neutral),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.metricPanelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.metricPanelBorder),
            ),
            child: Icon(icon, color: palette.textSecondary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
