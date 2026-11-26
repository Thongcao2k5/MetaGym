import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';

enum _HubFilter { all, complete, pending }

enum _PlansFilter { all, active, archived, draft }

class MemberPlanningStats {
  const MemberPlanningStats({
    this.hasTraining = false,
    this.trainingDays = 0,
    this.exerciseCount = 0,
    this.hasMealPlan = false,
    this.avgKcalPerDay = 0,
  });

  final bool hasTraining;
  final int trainingDays;
  final int exerciseCount;
  final bool hasMealPlan;
  final int avgKcalPerDay;
}

class CoachTrainingPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CoachMemberPlanningHubView(
      trainingService: service,
      focusNutrition: false,
      previewMode: previewMode,
      initialMembers: initialMembers,
      useSolidGlassFallback: useSolidGlassFallback,
    );
  }
}

/// Màn hình gộp **3.1 Chọn hội viên (Tập & Dinh dưỡng)** dùng chung giữa
/// `/coach/features/training` (`coach_training_page.dart`) và
/// `/coach/features/nutrition` (`coach_nutrition_page.dart` với `structured: true`).
class CoachMemberPlanningHubView extends StatefulWidget {
  const CoachMemberPlanningHubView({
    this.trainingService,
    this.loadMembersOverride,
    this.focusNutrition = false,
    this.previewMode = false,
    this.initialMembers,
    this.initialStats,
    this.onOpenPrimaryOverride,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachTrainingService? trainingService;
  final Future<List<CoachMemberSummary>> Function()? loadMembersOverride;
  final bool focusNutrition;
  final bool previewMode;
  final List<CoachMemberSummary>? initialMembers;
  final Map<String, MemberPlanningStats>? initialStats;
  final Future<void> Function(CoachMemberSummary member)? onOpenPrimaryOverride;
  final bool useSolidGlassFallback;

  @override
  State<CoachMemberPlanningHubView> createState() =>
      _CoachMemberPlanningHubViewState();
}

class _CoachMemberPlanningHubViewState
    extends State<CoachMemberPlanningHubView> {
  final TextEditingController _searchController = TextEditingController();

  CoachTrainingService? _trainingService;
  ApiClient? _apiClient;
  bool _initialized = false;

  List<CoachMemberSummary> _members = const [];
  Map<String, MemberPlanningStats> _stats = const {};
  _HubFilter _filter = _HubFilter.all;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _apiClient = optionalProvider<ApiClient>(context);
    _trainingService =
        widget.trainingService ??
        optionalProvider<CoachTrainingService>(context) ??
        (_apiClient == null ? null : CoachTrainingApi(_apiClient!));

    if (widget.initialMembers != null) {
      setState(() {
        _members = widget.initialMembers!;
        _stats = widget.initialStats ?? const {};
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

  static const Map<String, MemberPlanningStats> _demoStats = {
    'm-1': MemberPlanningStats(
      hasTraining: true,
      trainingDays: 4,
      exerciseCount: 18,
      hasMealPlan: true,
      avgKcalPerDay: 2185,
    ),
    'm-2': MemberPlanningStats(
      hasTraining: true,
      trainingDays: 3,
      exerciseCount: 12,
      hasMealPlan: true,
      avgKcalPerDay: 1550,
    ),
    'm-3': MemberPlanningStats(
      hasTraining: true,
      trainingDays: 4,
      exerciseCount: 16,
      hasMealPlan: true,
      avgKcalPerDay: 2850,
    ),
    'm-4': MemberPlanningStats(),
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
      if (widget.loadMembersOverride != null) {
        members = await widget.loadMembersOverride!();
      } else if (_trainingService != null) {
        members = await _trainingService!.getMembers();
      } else if (_apiClient != null) {
        members = await CoachMembersApi(_apiClient!).getMembers();
      } else {
        members = const [];
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
    if (members.isEmpty) return;
    final nextStats = <String, MemberPlanningStats>{};
    await Future.wait(
      members.map((member) async {
        var hasTraining = false;
        var days = 0;
        var exercises = 0;
        var hasMeal = false;
        var avgKcal = 0;

        final ts = _trainingService;
        if (ts != null) {
          try {
            final plans = await ts.getPlans(member.memberId);
            final chosen =
                plans.where((p) => p.status == 'ACTIVE').firstOrNull ??
                plans.firstOrNull;
            if (chosen != null) {
              hasTraining = true;
              days = chosen.days.length;
              exercises = chosen.days.fold<int>(
                0,
                (sum, d) => sum + d.exercises.length,
              );
            }
          } catch (_) {}
        }

        final api = _apiClient;
        if (api != null) {
          try {
            final mealPlan = await CoachV2Api(api)
                .get('/coach/meal-plans/${member.memberId}');
            if (mealPlan['id'] != null) {
              final items = (mealPlan['items'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              hasMeal = true;
              if (items.isNotEmpty) {
                final activeDays = items
                    .map((e) => e['day'] as int?)
                    .whereType<int>()
                    .toSet()
                    .length;
                final totalKcal = items.fold<num>(
                  0,
                  (sum, e) =>
                      sum +
                      ((e['grams'] as num?) ?? 0) *
                          ((e['kcalPer100g'] as num?) ?? 0) /
                          100,
                );
                if (activeDays > 0) {
                  avgKcal = (totalKcal / activeDays).round();
                }
              }
            }
          } catch (_) {}
        }

        nextStats[member.memberId] = MemberPlanningStats(
          hasTraining: hasTraining,
          trainingDays: days,
          exerciseCount: exercises,
          hasMealPlan: hasMeal,
          avgKcalPerDay: avgKcal,
        );
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

  Future<void> _openMealPlans(CoachMemberSummary member) async {
    final api = _apiClient;
    if (api == null && !widget.previewMode) {
      showCoachingSnackBar(
        context,
        'Chức năng Thực đơn 7 ngày khả dụng khi kết nối máy chủ.',
      );
      return;
    }
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => MealPlansPage(
          memberId: member.memberId,
          memberName: member.memberFullName,
          editable: member.status == 'ACTIVE',
          apiClient: api,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
    if (mounted && !widget.previewMode && widget.initialMembers == null) {
      await _load();
    }
  }

  Future<void> _onMemberPrimaryTap(CoachMemberSummary member) async {
    if (widget.onOpenPrimaryOverride != null) {
      await widget.onOpenPrimaryOverride!(member);
      if (mounted && !widget.previewMode && widget.initialMembers == null) {
        await _load();
      }
      return;
    }
    if (widget.focusNutrition) {
      await _openMealPlans(member);
    } else {
      await _openTrainingPlans(member);
    }
  }

  String _formatNumber(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }

  String _summaryLine(CoachMemberSummary member) {
    final st = _stats[member.memberId];
    if (st == null) return 'Trạng thái: ${member.statusLabel}';
    if (!st.hasTraining && !st.hasMealPlan) {
      return 'Chưa có giáo trình tập & chưa có thực đơn';
    }
    final parts = <String>[];
    if (st.hasTraining) {
      parts.add(
        st.exerciseCount > 0
            ? 'Tập: ${st.trainingDays} ngày (${st.exerciseCount} bài)'
            : 'Tập: ${st.trainingDays} ngày',
      );
    } else {
      parts.add('Chưa có giáo trình tập');
    }
    if (st.hasMealPlan) {
      parts.add(
        st.avgKcalPerDay > 0
            ? 'Ăn: ~${_formatNumber(st.avgKcalPerDay)} kcal/ngày'
            : 'Đã thiết lập thực đơn',
      );
    } else {
      parts.add('Chưa có thực đơn');
    }
    return parts.join(' · ');
  }

  bool _isCompleteMember(CoachMemberSummary member) {
    final st = _stats[member.memberId];
    return st != null && st.hasTraining && st.hasMealPlan;
  }

  bool _isPendingMember(CoachMemberSummary member) {
    final st = _stats[member.memberId];
    if (st == null) return false;
    return !st.hasTraining || !st.hasMealPlan;
  }

  List<CoachMemberSummary> _filteredMembers() {
    final q = _searchController.text.trim().toLowerCase();
    return _members.where((member) {
      final matchesFilter = switch (_filter) {
        _HubFilter.all => true,
        _HubFilter.complete => _isCompleteMember(member),
        _HubFilter.pending => _isPendingMember(member),
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return member.memberFullName.toLowerCase().contains(q) ||
          member.statusLabel.toLowerCase().contains(q);
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
                  'GIÁO ÁN & THỰC ĐƠN',
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
                  'Chọn hội viên',
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
                  'Mở riêng Giáo trình tập hoặc Thực đơn 7 ngày',
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
    final trainingReadyCount = _members
        .where((m) => _stats[m.memberId]?.hasTraining == true)
        .length;
    final mealReadyCount = _members
        .where((m) => _stats[m.memberId]?.hasMealPlan == true)
        .length;
    final completeCount = _members.where(_isCompleteMember).length;
    final pendingCount = _members.where(_isPendingMember).length;
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
                                                'Tổng quan phụ trách',
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
                                              tone: CoachingPillTone.green,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _HubSummaryTile(
                                                value: '$trainingReadyCount',
                                                label: 'Giáo trình tập',
                                                valueColor:
                                                    MetaGymTheme.brandOrange,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _HubSummaryTile(
                                                value: '$mealReadyCount',
                                                label: 'Thực đơn 7 ngày',
                                                valueColor: colors.success,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _HubSummaryTile(
                                                value: '$pendingCount',
                                                label: 'Chờ thiết lập',
                                                valueColor: colors.warning,
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
                                            'Hội viên đang đồng hành sẽ hiển thị tại đây để bạn thiết kế giáo trình tập luyện và thực đơn 7 ngày.',
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
                                    TextField(
                                      key: const Key('hub-member-search'),
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Tìm hội viên theo tên hoặc trạng thái…',
                                        hintStyle: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 13.5,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: MetaGymIcon(
                                            MetaGymIcons.commonSearch,
                                            size: 18,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: colors.metricPanelBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: const BorderSide(
                                            color: MetaGymTheme.brandOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _HubFilterChip(
                                          key: const Key('hub-filter-all'),
                                          label: 'Tất cả (${_members.length})',
                                          selected: _filter == _HubFilter.all,
                                          onTap: () => setState(
                                            () => _filter = _HubFilter.all,
                                          ),
                                        ),
                                        _HubFilterChip(
                                          key: const Key('hub-filter-complete'),
                                          label: 'Đủ cả hai ($completeCount)',
                                          selected:
                                              _filter == _HubFilter.complete,
                                          onTap: () => setState(
                                            () => _filter = _HubFilter.complete,
                                          ),
                                        ),
                                        _HubFilterChip(
                                          key: const Key('hub-filter-pending'),
                                          label:
                                              'Chờ thiết lập ($pendingCount)',
                                          selected:
                                              _filter == _HubFilter.pending,
                                          onTap: () => setState(
                                            () => _filter = _HubFilter.pending,
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
                                            'Danh sách hội viên',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Chọn mục cần thiết lập',
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
                                          isLight,
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
    bool isLight,
    CoachMemberSummary member,
    int index,
  ) {
    final st = _stats[member.memberId];
    final hasTraining = st?.hasTraining ?? true;
    final hasMeal = st?.hasMealPlan ?? true;
    final isFeatured = index == 0 && member.status == 'ACTIVE';

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: isFeatured
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.42)
          : null,
      onTap: () => _onMemberPrimaryTap(member),
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
                          label: member.statusLabel,
                          tone: member.status == 'ACTIVE'
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summaryLine(member),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12,
                        height: 1.35,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MemberShortcutButton(
                  key: Key('hub-open-training-${member.memberId}'),
                  label: hasTraining ? 'Giáo trình tập ›' : '+ Giáo trình tập',
                  accentColor: !widget.focusNutrition || isFeatured
                      ? MetaGymTheme.brandOrange
                      : colors.textPrimary,
                  borderColor: !widget.focusNutrition && hasTraining
                      ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                      : colors.metricPanelBorder,
                  onTap: () => _openTrainingPlans(member),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MemberShortcutButton(
                  key: Key('hub-open-meal-${member.memberId}'),
                  label: hasMeal ? 'Thực đơn 7 ngày ›' : '+ Thực đơn 7 ngày',
                  accentColor: widget.focusNutrition || hasMeal
                      ? colors.success
                      : colors.textPrimary,
                  borderColor: (widget.focusNutrition || hasMeal)
                      ? colors.success.withValues(alpha: 0.45)
                      : colors.metricPanelBorder,
                  onTap: () => _openMealPlans(member),
                ),
              ),
            ],
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
      if (mounted) setState(() => _plans = plans);
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
                                        _HubFilterChip(
                                          label:
                                              'Tất cả (${visiblePlans.length})',
                                          selected: _filter == _PlansFilter.all,
                                          onTap: () => setState(
                                            () => _filter = _PlansFilter.all,
                                          ),
                                        ),
                                        _HubFilterChip(
                                          label: 'Đang áp dụng ($activeCount)',
                                          selected:
                                              _filter == _PlansFilter.active,
                                          onTap: () => setState(
                                            () => _filter = _PlansFilter.active,
                                          ),
                                        ),
                                        _HubFilterChip(
                                          label: 'Lưu trữ ($archivedCount)',
                                          selected:
                                              _filter == _PlansFilter.archived,
                                          onTap: () => setState(
                                            () =>
                                                _filter = _PlansFilter.archived,
                                          ),
                                        ),
                                        if (draftCount > 0)
                                          _HubFilterChip(
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

class _HubSummaryTile extends StatelessWidget {
  const _HubSummaryTile({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymMetricPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubFilterChip extends StatelessWidget {
  const _HubFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(999);

    return Material(
      color: selected
          ? (isLight
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.14)
                : colors.chipActiveBg)
          : colors.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : colors.metricPanelBorder,
          width: selected ? 1.2 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? (isLight ? colors.primaryText : colors.chipActiveText)
                    : colors.textSecondary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberShortcutButton extends StatelessWidget {
  const _MemberShortcutButton({
    required this.label,
    required this.accentColor,
    required this.borderColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color accentColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: colors.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: accentColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
