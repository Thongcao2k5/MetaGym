import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';

enum _TrainingFilter { all, hasPlan, noPlan }

enum _PlansFilter { all, active, archived, draft }

class _TrainingMemberStats {
  const _TrainingMemberStats({
    this.hasTraining = false,
    this.activePlanTitle,
    this.activeGoal,
    this.activeVersion,
    this.trainingDays = 0,
    this.exerciseCount = 0,
  });

  final bool hasTraining;
  final String? activePlanTitle;
  final String? activeGoal;
  final int? activeVersion;
  final int trainingDays;
  final int exerciseCount;
}

/// Màn hình **3.1 Chọn hội viên tập luyện** — chuyên trách giáo trình bài tập.
class CoachTrainingPage extends StatefulWidget {
  const CoachTrainingPage({
    this.service,
    this.previewMode = false,
    this.initialMembers,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachTrainingService? service;
  final bool previewMode;
  final List<CoachMemberSummary>? initialMembers;
  final bool useSolidGlassFallback;

  @override
  State<CoachTrainingPage> createState() => _CoachTrainingPageState();
}

class _CoachTrainingPageState extends State<CoachTrainingPage> {
  final TextEditingController _searchController = TextEditingController();

  CoachTrainingService? _trainingService;
  ApiClient? _apiClient;
  bool _initialized = false;

  List<CoachMemberSummary> _members = const [];
  Map<String, _TrainingMemberStats> _stats = const {};
  _TrainingFilter _filter = _TrainingFilter.all;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _apiClient = optionalProvider<ApiClient>(context);
    _trainingService =
        widget.service ??
        optionalProvider<CoachTrainingService>(context) ??
        (_apiClient == null ? null : CoachTrainingApi(_apiClient!));

    if (widget.initialMembers != null) {
      setState(() {
        _members = widget.initialMembers!;
        _loading = false;
      });
      return;
    }

    if (widget.previewMode) {
      setState(() {
        _members = _demoMembers;
        _stats = _demoStats;
        _loading = false;
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const List<CoachMemberSummary> _demoMembers = [
    CoachMemberSummary(
      relationshipId: 'rel-1',
      memberId: 'm-1',
      memberFullName: 'Nguyễn Minh Quân',
      status: 'ACTIVE',
    ),
    CoachMemberSummary(
      relationshipId: 'rel-2',
      memberId: 'm-2',
      memberFullName: 'Trần Thảo Vy',
      status: 'ACTIVE',
    ),
    CoachMemberSummary(
      relationshipId: 'rel-3',
      memberId: 'm-3',
      memberFullName: 'Phạm Quốc Bảo',
      status: 'ACTIVE',
    ),
    CoachMemberSummary(
      relationshipId: 'rel-4',
      memberId: 'm-4',
      memberFullName: 'Đỗ Khánh Linh',
      status: 'ACTIVE',
    ),
  ];

  static const Map<String, _TrainingMemberStats> _demoStats = {
    'm-1': _TrainingMemberStats(
      hasTraining: true,
      activePlanTitle: 'Upper / Lower Split',
      activeGoal: 'Lưu ý vai phải · Không đẩy quá góc 90°',
      activeVersion: 3,
      trainingDays: 4,
      exerciseCount: 18,
    ),
    'm-2': _TrainingMemberStats(
      hasTraining: true,
      activePlanTitle: 'Glutes & Core',
      activeVersion: 2,
      trainingDays: 3,
      exerciseCount: 12,
    ),
    'm-3': _TrainingMemberStats(
      hasTraining: true,
      activePlanTitle: 'Push / Pull / Legs',
      activeVersion: 1,
      trainingDays: 4,
      exerciseCount: 16,
    ),
    'm-4': _TrainingMemberStats(),
  };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _members = const [];
      _stats = const {};
      _error = null;
    });

    try {
      List<CoachMemberSummary> members;
      if (_trainingService != null) {
        members = await _trainingService!.getMembers();
      } else if (_apiClient != null) {
        members = await CoachMembersApi(_apiClient!).getMembers();
      } else {
        setState(() => _error = 'Chức năng Giáo trình tập cần kết nối máy chủ.');
        return;
      }

      if (!mounted) return;
      setState(() => _members = members);
      await _enrichStats(members);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enrichStats(List<CoachMemberSummary> members) async {
    final ts = _trainingService;
    if (ts == null || members.isEmpty) return;

    final nextStats = <String, _TrainingMemberStats>{};
    await Future.wait(
      members.map((member) async {
        try {
          final plans = await ts.getPlans(member.memberId);
          var chosen =
              plans.where((p) => p.status == 'ACTIVE').firstOrNull ??
              plans.firstOrNull;
          if (chosen != null && chosen.days.isEmpty) {
            try {
              chosen = await ts.getPlan(chosen.id);
            } catch (_) {}
          }
          if (chosen == null) {
            nextStats[member.memberId] = const _TrainingMemberStats();
            return;
          }
          final exercises = chosen.days.fold<int>(
            0,
            (sum, d) => sum + d.exercises.length,
          );
          nextStats[member.memberId] = _TrainingMemberStats(
            hasTraining: true,
            activePlanTitle: chosen.title,
            activeGoal: chosen.goal,
            activeVersion: chosen.version,
            trainingDays: chosen.days.length,
            exerciseCount: exercises,
          );
        } catch (_) {
          nextStats[member.memberId] = const _TrainingMemberStats();
        }
      }),
    );

    if (mounted) setState(() => _stats = nextStats);
  }

  Future<void> _openTrainingPlans(CoachMemberSummary member) async {
    final ts = _trainingService;
    if (ts == null && !widget.previewMode) {
      showCoachingSnackBar(
        context,
        'Chức năng Giáo trình tập khả dụng khi kết nối máy chủ.',
      );
      return;
    }
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachMemberPlansPage(
          member: member,
          service: ts,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
    if (mounted && !widget.previewMode && widget.initialMembers == null) {
      await _load();
    }
  }

  bool _hasTrainingPlan(CoachMemberSummary member) =>
      _stats[member.memberId]?.hasTraining == true;

  List<CoachMemberSummary> _filteredMembers() {
    final q = _searchController.text.trim().toLowerCase();
    return _members.where((member) {
      final hasPlan = _hasTrainingPlan(member);
      final matchesFilter = switch (_filter) {
        _TrainingFilter.all => true,
        _TrainingFilter.hasPlan => hasPlan,
        _TrainingFilter.noPlan => !hasPlan,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      final st = _stats[member.memberId];
      final planTitle = st?.activePlanTitle?.toLowerCase() ?? '';
      return member.memberFullName.toLowerCase().contains(q) ||
          member.statusLabel.toLowerCase().contains(q) ||
          planTitle.contains(q);
    }).toList();
  }

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GIÁO ÁN TẬP LUYỆN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chọn hội viên tập luyện',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quản lý giáo trình bài tập & tiến độ từng học viên',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    final activeMembersCount = _members
        .where((m) => m.status == 'ACTIVE')
        .length;
    final hasPlanCount = _members.where(_hasTrainingPlan).length;
    final noPlanCount = _members.length - hasPlanCount;
    final totalExercisesCount = _members.fold<int>(
      0,
      (sum, m) => sum + (_stats[m.memberId]?.exerciseCount ?? 0),
    );
    final visibleMembers = _filteredMembers();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, colors),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          )
                        : RefreshIndicator(
                            color: MetaGymTheme.primary,
                            backgroundColor: colors.overlayGlass,
                            onRefresh: widget.previewMode ? () async {} : _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                gutter,
                                4,
                                gutter,
                                media.bottom + 36,
                              ),
                              children: [
                                if (_error != null) ...[
                                  CoachingErrorBanner(message: _error!),
                                  CoachingSecondaryButton(
                                    label: 'Thử lại',
                                    onPressed: _load,
                                    expand: true,
                                  ),
                                ] else ...[
                                  MetaGymHeroGlassCard(
                                    useSolidFallback:
                                        widget.useSolidGlassFallback,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const MetaGymIcon(
                                              MetaGymIcons.actionCoachPlans,
                                              size: 18,
                                              color: MetaGymTheme.brandOrange,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Tổng quan giáo án tập',
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            CoachingPill(
                                              label:
                                                  '$activeMembersCount HV đang theo',
                                              tone: CoachingPillTone.coral,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CoachingSummaryMetricTile(
                                                value: '$hasPlanCount',
                                                label: 'Đang áp dụng',
                                                valueColor:
                                                    MetaGymTheme.brandOrange,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CoachingSummaryMetricTile(
                                                value: '$noPlanCount',
                                                label: 'Chưa có lịch',
                                                valueColor: colors.warning,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CoachingSummaryMetricTile(
                                                value: '$totalExercisesCount',
                                                label: 'Bài tập giao',
                                                valueColor: colors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_members.isEmpty)
                                    MetaGymGlassCard(
                                      solid: widget.useSolidGlassFallback,
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: colors.metricPanelBg,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: colors.metricPanelBorder,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: MetaGymIcon(
                                              MetaGymIcons.emptyCurriculum,
                                              size: 24,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Chưa có hội viên đang phụ trách.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Hội viên đang đồng hành sẽ hiển thị tại đây để bạn thiết kế giáo trình tập luyện theo từng ngày.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 13,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    CoachingMemberSearchField(
                                      fieldKey: const Key('hub-member-search'),
                                      controller: _searchController,
                                      hintText:
                                          'Tìm hội viên hoặc tên giáo trình…',
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        CoachingFilterChip(
                                          key: const Key('hub-filter-all'),
                                          label: 'Tất cả (${_members.length})',
                                          selected:
                                              _filter == _TrainingFilter.all,
                                          onTap: () => setState(
                                            () =>
                                                _filter = _TrainingFilter.all,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          key: const Key('hub-filter-complete'),
                                          label: 'Đã có giáo án ($hasPlanCount)',
                                          selected:
                                              _filter ==
                                              _TrainingFilter.hasPlan,
                                          onTap: () => setState(
                                            () => _filter =
                                                _TrainingFilter.hasPlan,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          key: const Key('hub-filter-pending'),
                                          label:
                                              'Chưa có giáo án ($noPlanCount)',
                                          selected:
                                              _filter == _TrainingFilter.noPlan,
                                          onTap: () => setState(
                                            () => _filter =
                                                _TrainingFilter.noPlan,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Hội viên tập luyện',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Chạm để mở giáo trình tập',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (visibleMembers.isEmpty)
                                      MetaGymGlassCard(
                                        solid: widget.useSolidGlassFallback,
                                        padding: const EdgeInsets.all(18),
                                        child: Text(
                                          'Không có hội viên nào khớp bộ lọc hiện tại.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      )
                                    else
                                      for (
                                        var i = 0;
                                        i < visibleMembers.length;
                                        i++
                                      )
                                        _buildMemberCard(
                                          colors,
                                          visibleMembers[i],
                                          i,
                                        ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(
    MetaGymColors colors,
    CoachMemberSummary member,
    int index,
  ) {
    final st = _stats[member.memberId];
    final hasTraining = st?.hasTraining == true;
    final isFeatured = index == 0 && hasTraining && member.status == 'ACTIVE';

    final primaryLine = !hasTraining
        ? 'Chưa có giáo trình tập · Cần thiết lập lịch mới'
        : [
            if (st!.activePlanTitle?.isNotEmpty == true) st.activePlanTitle!,
            if (st.trainingDays > 0) '${st.trainingDays} ngày/tuần',
            if (st.exerciseCount > 0) '${st.exerciseCount} bài tập',
          ].join(' · ');

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: isFeatured
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
          : null,
      onTap: () => _openTrainingPlans(member),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: member.memberFullName,
                size: 44,
                paletteIndex: index,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.memberFullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        CoachingPill(
                          label: !hasTraining && member.status == 'ACTIVE'
                              ? 'Chưa thiết lập'
                              : member.statusLabel,
                          tone: !hasTraining && member.status == 'ACTIVE'
                              ? CoachingPillTone.amber
                              : member.status == 'ACTIVE'
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary.withValues(alpha: 0.88),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    if (st?.activeGoal?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        st!.activeGoal!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textWarmMuted,
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
          const SizedBox(height: 10),
          CoachingCardActionChip(
            key: Key('hub-open-training-${member.memberId}'),
            label: hasTraining
                ? 'Mở giáo trình tập ›'
                : '+ Tạo giáo trình tập',
            accentColor: hasTraining ? MetaGymTheme.brandOrange : colors.warning,
            borderColor: (hasTraining ? MetaGymTheme.brandOrange : colors.warning)
                .withValues(alpha: 0.45),
            onTap: () => _openTrainingPlans(member),
          ),
        ],
      ),
    );
  }
}

/// Màn hình **3.2 Danh sách giáo trình tập** (`_MemberPlansPage`).
class CoachMemberPlansPage extends StatefulWidget {
  const CoachMemberPlansPage({
    required this.member,
    this.service,
    this.previewMode = false,
    this.initialPlans,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachMemberSummary member;
  final CoachTrainingService? service;
  final bool previewMode;
  final List<TrainingPlan>? initialPlans;
  final bool useSolidGlassFallback;

  @override
  State<CoachMemberPlansPage> createState() => _CoachMemberPlansPageState();
}

class _CoachMemberPlansPageState extends State<CoachMemberPlansPage> {
  List<TrainingPlan> _plans = const [];
  _PlansFilter _filter = _PlansFilter.all;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlans != null) {
      _plans = widget.initialPlans!;
      _loading = false;
    } else if (widget.previewMode || widget.service == null) {
      _plans = _demoPlans;
      _loading = false;
    } else {
      _load();
    }
  }

  static const List<TrainingPlan> _demoPlans = [
    TrainingPlan(
      id: 'demo-active-1',
      title: 'Upper / Lower Split — Hypertrophy 4 tuần',
      goal: 'Tránh góc đẩy vai > 90° · Tăng cơ nạc',
      status: 'ACTIVE',
      version: 3,
      startDate: '2026-11-10',
      endDate: '2026-12-08',
      days: [
        TrainingDay(
          dayNumber: 1,
          title: 'Ngực trên · Vai · Tay sau',
          scheduledDate: '2026-11-10',
          notes: 'Khởi động khớp vai 5 phút với dây kháng lực nhẹ.',
          exercises: [
            TrainingExercise(
              exerciseId: 'ex-1',
              exerciseName: 'Incline Dumbbell Press',
              displayOrder: 1,
              sets: 4,
              reps: '8–10',
              restSeconds: 90,
              weightGuidance: '22 kg/tay',
              instructions: 'Kiểm soát pha hạ tạ 3 giây, giữ khuỷu tay 45°.',
            ),
            TrainingExercise(
              exerciseId: 'ex-2',
              exerciseName: 'Cable Lateral Raise',
              displayOrder: 2,
              sets: 4,
              reps: '12–15',
              restSeconds: 60,
              weightGuidance: '7,5 kg',
            ),
          ],
        ),
        TrainingDay(
          dayNumber: 2,
          title: 'Lưng xô · Tay trước',
          scheduledDate: '2026-11-12',
          exercises: [
            TrainingExercise(
              exerciseId: 'ex-3',
              exerciseName: 'Wide-Grip Lat Pulldown',
              displayOrder: 1,
              sets: 4,
              reps: '10–12',
              restSeconds: 90,
              weightGuidance: '55 kg',
            ),
          ],
        ),
      ],
    ),
    TrainingPlan(
      id: 'demo-arch-1',
      title: 'Làm quen kỹ thuật cơ bản (Nền tảng)',
      goal: 'Toàn thân · Hoàn thành 12/12 buổi',
      status: 'ARCHIVED',
      version: 2,
      days: [
        TrainingDay(dayNumber: 1, title: 'Toàn thân 1'),
        TrainingDay(dayNumber: 2, title: 'Toàn thân 2'),
        TrainingDay(dayNumber: 3, title: 'Toàn thân 3'),
      ],
    ),
  ];

  Future<void> _load() async {
    if (widget.service == null) return;
    setState(() {
      _loading = true;
      _plans = const [];
      _error = null;
    });
    try {
      final plans = await widget.service!.getPlans(widget.member.memberId);
      final hydrated = await Future.wait(
        plans.map((plan) async {
          if (plan.days.isNotEmpty) return plan;
          try {
            return await widget.service!.getPlan(plan.id);
          } catch (_) {
            return plan;
          }
        }),
      );
      if (mounted) setState(() => _plans = hydrated);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlan(TrainingPlan plan) async {
    if (widget.service == null) {
      showCoachingSnackBar(context, 'Chi tiết giáo trình cần kết nối dịch vụ.');
      return;
    }
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachPlanDetailPage(
          id: plan.id,
          service: widget.service!,
          memberId: widget.member.memberId,
          memberName: widget.member.memberFullName,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
    if (mounted && !widget.previewMode && widget.initialPlans == null) {
      await _load();
    }
  }

  Future<void> _createOrUpdate([TrainingPlan? existing]) async {
    if (widget.service == null) {
      showCoachingSnackBar(context, 'Soạn giáo trình cần kết nối dịch vụ.');
      return;
    }
    final id = await MetaGymNavigation.pushOnce<String>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: widget.member.memberId,
          memberName: widget.member.memberFullName,
          plan: existing,
          service: widget.service!,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
    if (!mounted || id == null) return;
    if (!widget.previewMode && widget.initialPlans == null) {
      await _load();
    }
    if (mounted) {
      final refreshed = _plans.where((p) => p.id == id).firstOrNull;
      await _openPlan(
        refreshed ??
            TrainingPlan(id: id, title: '', status: 'DRAFT', version: 1),
      );
    }
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

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors, {
    required bool canCreate,
  }) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GIÁO ÁN TẬP LUYỆN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.member.memberFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (canCreate) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              key: const Key('member-plans-header-add'),
              svgAsset: MetaGymIcons.commonAdd,
              icon: Icons.add_rounded,
              tooltip: 'Tạo giáo trình mới',
              onTap: _loading ? null : () => _createOrUpdate(),
            ),
          ],
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            key: const Key('member-plans-header-nutrition'),
            svgAsset: MetaGymIcons.actionNutrition,
            icon: Icons.restaurant_menu_rounded,
            tooltip: 'Thực đơn 7 ngày',
            onTap: _loading
                ? null
                : () => MetaGymNavigation.pushOnce<void>(
                    context,
                    MetaGymPageRoute(
                      builder: (_) => MealPlansPage(
                        memberId: widget.member.memberId,
                        memberName: widget.member.memberFullName,
                        editable: widget.member.status == 'ACTIVE',
                        apiClient: optionalProvider<ApiClient>(context),
                        previewMode: widget.previewMode,
                        useSolidGlassFallback: widget.useSolidGlassFallback,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    final visiblePlans = _plans
        .where(
          (plan) =>
              widget.service is! CoachTrainingApi || plan.status != 'DRAFT',
        )
        .toList();
    final activePlan = visiblePlans
        .where((p) => p.status == 'ACTIVE')
        .firstOrNull;
    final canCreate =
        widget.service is! CoachTrainingApi ||
        !_plans.any((plan) => plan.status == 'ACTIVE');

    final activeCount = visiblePlans.where((p) => p.status == 'ACTIVE').length;
    final archivedCount = visiblePlans
        .where((p) => p.status == 'ARCHIVED')
        .length;
    final draftCount = visiblePlans.where((p) => p.status == 'DRAFT').length;

    final filteredPlans = switch (_filter) {
      _PlansFilter.all => visiblePlans,
      _PlansFilter.active =>
        visiblePlans.where((p) => p.status == 'ACTIVE').toList(),
      _PlansFilter.archived =>
        visiblePlans.where((p) => p.status == 'ARCHIVED').toList(),
      _PlansFilter.draft =>
        visiblePlans.where((p) => p.status == 'DRAFT').toList(),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, colors, canCreate: canCreate),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          )
                        : RefreshIndicator(
                            color: MetaGymTheme.primary,
                            backgroundColor: colors.overlayGlass,
                            onRefresh: widget.previewMode ? () async {} : _load,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                gutter,
                                4,
                                gutter,
                                118 + media.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_error != null) ...[
                                    CoachingErrorBanner(message: _error!),
                                    CoachingSecondaryButton(
                                      label: 'Thử lại',
                                      onPressed: _load,
                                      expand: true,
                                    ),
                                  ] else ...[
                                    MetaGymHeroGlassCard(
                                      useSolidFallback:
                                          widget.useSolidGlassFallback,
                                      padding: const EdgeInsets.all(15),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CoachingAvatar(
                                                fullName: widget
                                                    .member
                                                    .memberFullName,
                                                size: 42,
                                              ),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      activePlan?.title ?? 'Thiết lập lộ trình tập',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color:
                                                            colors.textPrimary,
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${visiblePlans.length} giáo trình đã tạo',
                                                      style: TextStyle(
                                                        color: colors
                                                            .textWarmMuted,
                                                        fontSize: 12,
                                                        fontFeatures:
                                                            MetaGymTheme
                                                                .tabularFigures,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              CoachingPill(
                                                label:
                                                    widget.member.statusLabel,
                                                tone:
                                                    widget.member.status ==
                                                        'ACTIVE'
                                                    ? CoachingPillTone.green
                                                    : CoachingPillTone.amber,
                                              ),
                                            ],
                                          ),
                                          if (activePlan?.goal
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colors.warning
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: colors.warning
                                                      .withValues(alpha: 0.34),
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  MetaGymIcon(
                                                    MetaGymIcons.healthInjury,
                                                    size: 16,
                                                    color: colors.warning,
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Expanded(
                                                    child: Text(
                                                      activePlan!.goal!.trim(),
                                                      style: TextStyle(
                                                        color: colors.warning,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        CoachingFilterChip(
                                          label:
                                              'Tất cả (${visiblePlans.length})',
                                          selected: _filter == _PlansFilter.all,
                                          onTap: () => setState(
                                            () => _filter = _PlansFilter.all,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          label: 'Đang áp dụng ($activeCount)',
                                          selected:
                                              _filter == _PlansFilter.active,
                                          onTap: () => setState(
                                            () => _filter = _PlansFilter.active,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          label: 'Lưu trữ ($archivedCount)',
                                          selected:
                                              _filter == _PlansFilter.archived,
                                          onTap: () => setState(
                                            () =>
                                                _filter = _PlansFilter.archived,
                                          ),
                                        ),
                                        if (draftCount > 0)
                                          CoachingFilterChip(
                                            label: 'Bản nháp ($draftCount)',
                                            selected:
                                                _filter == _PlansFilter.draft,
                                            onTap: () => setState(
                                              () =>
                                                  _filter = _PlansFilter.draft,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Giáo trình bài tập',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Chạm để xem chi tiết',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (filteredPlans.isEmpty)
                                      MetaGymGlassCard(
                                        solid: widget.useSolidGlassFallback,
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          children: [
                                            MetaGymIcon(
                                              MetaGymIcons.emptyWorkout,
                                              size: 28,
                                              color: colors.textSecondary,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Chưa có giáo trình nào.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Nhấn "Tạo giáo trình" để thiết kế lịch tập và bữa ăn theo ngày cho hội viên.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      for (final plan in filteredPlans)
                                        _PlanSummaryCard(
                                          useSolidGlassFallback:
                                              widget.useSolidGlassFallback,
                                          plan: plan,
                                          focuses: _resolvePlanFocuses(plan),
                                          pillTone: _planPillTone(plan.status),
                                          pillIcon: _planPillIcon(plan.status),
                                          onTap: () => _openPlan(plan),
                                        ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (!_loading && _error == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    12,
                    gutter,
                    media.bottom + 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.canvas.withValues(alpha: 0.0),
                        colors.canvas.withValues(alpha: 0.90),
                        colors.canvas,
                      ],
                      stops: const [0.0, 0.30, 1.0],
                    ),
                  ),
                  child: canCreate
                      ? CoachingPrimaryButton(
                          key: const Key('member-plans-create-btn'),
                          label: 'Tạo giáo trình',
                          icon: Icons.add_rounded,
                          onPressed: () => _createOrUpdate(),
                        )
                      : CoachingPrimaryButton(
                          key: const Key('member-plans-update-btn'),
                          label: 'Cập nhật giáo trình hiện tại',
                          icon: Icons.edit_outlined,
                          onPressed: activePlan == null
                              ? null
                              : () => _createOrUpdate(activePlan),
                        ),
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
    required this.useSolidGlassFallback,
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

  String _formatDateRange() {
    String fmt(String raw) {
      final parts = raw.split('T').first.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return raw;
    }

    if (plan.startDate != null && plan.endDate != null) {
      return '${fmt(plan.startDate!)} – ${fmt(plan.endDate!)}';
    }
    if (plan.startDate != null) return 'Bắt đầu: ${fmt(plan.startDate!)}';
    return '';
  }

  final bool useSolidGlassFallback;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isActive = plan.status == 'ACTIVE';
    final totalExercises = plan.days.fold<int>(
      0,
      (sum, d) => sum + d.exercises.length,
    );
    final dateRange = _formatDateRange();

    return Opacity(
      opacity: plan.status == 'ARCHIVED' ? 0.88 : 1.0,
      child: MetaGymGlassCard(
        solid: useSolidGlassFallback,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        borderColor: isActive
            ? MetaGymTheme.brandOrange.withValues(alpha: 0.44)
            : null,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MuscleAnatomyTile(
              focuses: focuses,
              width: 52,
              height: 64,
              isUpcoming: plan.status != 'ARCHIVED',
              selected: isActive,
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
                      color: colors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (plan.goal?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan.goal!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12.5,
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
                          MetaGymIcon(
                            MetaGymIcons.workoutPlanCalendar,
                            size: 13,
                            color: colors.reflection,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateRange.isNotEmpty
                                  ? '$dateRange · ${plan.days.length} ngày'
                                  : totalExercises > 0
                                  ? '${plan.days.length} ngày tập · $totalExercises bài tập'
                                  : '${plan.days.length} ngày tập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (focuses.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.accessibility_new_rounded,
                              size: 13,
                              color: MetaGymTheme.brandOrange,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                summarizeMuscleFocuses(focuses),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$totalExercises bài tập đã thiết lập',
                            style: TextStyle(
                              color: colors.textWarmMuted,
                              fontSize: 12,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                        const Text(
                          'Chi tiết ›',
                          style: TextStyle(
                            color: MetaGymTheme.brandOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
