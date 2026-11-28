import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_editor_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';

enum _NutritionFilter { all, hasMeal, noMeal }

class MemberNutritionStats {
  const MemberNutritionStats({
    this.hasMealPlan = false,
    this.mealTitle,
    this.avgKcalPerDay = 0,
    this.activeDaysCount = 0,
    this.mealSlotCount = 0,
    this.itemCount = 0,
    this.hasNotes = false,
  });

  final bool hasMealPlan;
  final String? mealTitle;
  final int avgKcalPerDay;
  final int activeDaysCount;
  final int mealSlotCount;
  final int itemCount;
  final bool hasNotes;
}

/// Màn hình **4.1 Chọn hội viên dinh dưỡng** — tách riêng khỏi Giáo án tập luyện.
class CoachNutritionPage extends StatefulWidget {
  const CoachNutritionPage({
    this.service,
    this.structured = false,
    this.previewMode = false,
    this.initialMembers,
    this.initialStats,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachNutritionService? service;
  final bool structured;
  final bool previewMode;
  final List<CoachMemberSummary>? initialMembers;
  final Map<String, MemberNutritionStats>? initialStats;
  final bool useSolidGlassFallback;

  @override
  State<CoachNutritionPage> createState() => _CoachNutritionPageState();
}

class _CoachNutritionPageState extends State<CoachNutritionPage> {
  final TextEditingController _searchController = TextEditingController();

  CoachNutritionService? _legacyService;
  ApiClient? _apiClient;
  bool _initialized = false;

  List<CoachMemberSummary> _members = const [];
  Map<String, MemberNutritionStats> _stats = const {};
  _NutritionFilter _filter = _NutritionFilter.all;
  String? _error;
  bool _loading = true;

  bool get _isStructuredMode =>
      widget.structured || widget.previewMode || _legacyService == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _apiClient = optionalProvider<ApiClient>(context);
    _legacyService =
        widget.service ??
        optionalProvider<CoachNutritionService>(context) ??
        (!widget.structured && _apiClient != null
            ? CoachNutritionApi(_apiClient!)
            : null);

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

  static const Map<String, MemberNutritionStats> _demoStats = {
    'm-1': MemberNutritionStats(
      hasMealPlan: true,
      mealTitle: 'Thực đơn Tăng cơ giảm mỡ Tuần 4',
      avgKcalPerDay: 2155,
      activeDaysCount: 7,
      mealSlotCount: 21,
      itemCount: 24,
      hasNotes: true,
    ),
    'm-2': MemberNutritionStats(
      hasMealPlan: true,
      mealTitle: 'Giảm mỡ & giữ cơ · Sữa hạt',
      avgKcalPerDay: 1550,
      activeDaysCount: 7,
      mealSlotCount: 21,
      itemCount: 18,
      hasNotes: true,
    ),
    'm-3': MemberNutritionStats(
      hasMealPlan: true,
      mealTitle: 'Bulk Sạch + Carb Cao Ngày Tập Chân',
      avgKcalPerDay: 2850,
      activeDaysCount: 6,
      mealSlotCount: 18,
      itemCount: 20,
      hasNotes: true,
    ),
    'm-4': MemberNutritionStats(),
  };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _members = const [];
      _stats = const {};
      _error = null;
    });

    try {
      if (!_isStructuredMode && _legacyService != null) {
        final members = await _legacyService!.getMembers();
        if (!mounted) return;
        setState(() => _members = members);
        await _enrichLegacyGuides(members);
        return;
      }

      if (_apiClient == null) {
        setState(() => _error = 'Chức năng Dinh dưỡng cần kết nối máy chủ.');
        return;
      }

      final members = await CoachMembersApi(_apiClient!).getMembers();
      if (!mounted) return;
      setState(() => _members = members);
      await _enrichStructuredMealPlans(members);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được danh sách dinh dưỡng.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enrichStructuredMealPlans(
    List<CoachMemberSummary> members,
  ) async {
    final api = _apiClient;
    if (api == null || members.isEmpty) return;

    final nextStats = <String, MemberNutritionStats>{};
    await Future.wait(
      members.map((member) async {
        try {
          final mealPlan = await CoachV2Api(
            api,
          ).get('/coach/meal-plans/${member.memberId}');
          final id = mealPlan['id'];
          if (id == null) {
            nextStats[member.memberId] = const MemberNutritionStats();
            return;
          }
          final items = (mealPlan['items'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final activeDaysCount = items
              .map((e) => e['day'] as int?)
              .whereType<int>()
              .toSet()
              .length;
          final mealSlotCount = {
            for (final e in items) '${e['day']}-${e['meal']}',
          }.length;
          final totalKcal = items.fold<num>(
            0,
            (sum, e) =>
                sum +
                ((e['grams'] as num?) ?? 0) *
                    ((e['kcalPer100g'] as num?) ?? 0) /
                    100,
          );
          final avgKcal = activeDaysCount == 0
              ? 0
              : (totalKcal / activeDaysCount).round();
          final rawNotes =
              (mealPlan['notes'] as String?) ??
              _extractLegacyNotes(mealPlan['content'] as String?);
          nextStats[member.memberId] = MemberNutritionStats(
            hasMealPlan: true,
            mealTitle: (mealPlan['title'] as String?)?.trim(),
            avgKcalPerDay: avgKcal,
            activeDaysCount: activeDaysCount,
            mealSlotCount: mealSlotCount,
            itemCount: items.length,
            hasNotes: rawNotes?.trim().isNotEmpty == true,
          );
        } catch (_) {
          nextStats[member.memberId] = const MemberNutritionStats();
        }
      }),
    );

    if (mounted) setState(() => _stats = nextStats);
  }

  Future<void> _enrichLegacyGuides(List<CoachMemberSummary> members) async {
    final svc = _legacyService;
    if (svc == null || members.isEmpty) return;
    final nextStats = <String, MemberNutritionStats>{};
    await Future.wait(
      members.map((member) async {
        try {
          final guides = await svc.getGuides(member.memberId);
          final chosen =
              guides.where((g) => g.status == 'ACTIVE').firstOrNull ??
              guides.firstOrNull;
          nextStats[member.memberId] = chosen == null
              ? const MemberNutritionStats()
              : MemberNutritionStats(
                  hasMealPlan: true,
                  mealTitle: chosen.title,
                  hasNotes: chosen.content.trim().isNotEmpty,
                );
        } catch (_) {
          nextStats[member.memberId] = const MemberNutritionStats();
        }
      }),
    );
    if (mounted) setState(() => _stats = nextStats);
  }

  String? _extractLegacyNotes(String? content) {
    if (content == null) return null;
    const start = '[NGUYÊN TẮC ĂN UỐNG]\n';
    const end = '\n[CHI TIẾT THỰC ĐƠN]\n';
    if (!content.startsWith(start)) return null;
    final endIdx = content.indexOf(end, start.length);
    final raw = endIdx < 0
        ? content.sliceCompat(start.length)
        : content.substring(start.length, endIdx);
    return raw.trim().isEmpty ? null : raw.trim();
  }

  Future<void> _openMemberNutrition(CoachMemberSummary member) async {
    if (!_isStructuredMode && _legacyService != null) {
      await MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute(
          builder: (_) => _MemberGuidesPage(
            member: member,
            service: _legacyService!,
            useSolidGlassFallback: widget.useSolidGlassFallback,
          ),
        ),
      );
      if (mounted && !widget.previewMode && widget.initialMembers == null) {
        await _load();
      }
      return;
    }

    if (_apiClient == null && !widget.previewMode) {
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
          apiClient: _apiClient,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
    if (mounted && !widget.previewMode && widget.initialMembers == null) {
      await _load();
    }
  }

  String _formatKcal(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }

  bool _hasMealPlan(CoachMemberSummary member) =>
      _stats[member.memberId]?.hasMealPlan == true;

  List<CoachMemberSummary> _filteredMembers() {
    final q = _searchController.text.trim().toLowerCase();
    return _members.where((member) {
      final hasMeal = _hasMealPlan(member);
      final matchesFilter = switch (_filter) {
        _NutritionFilter.all => true,
        _NutritionFilter.hasMeal => hasMeal,
        _NutritionFilter.noMeal => !hasMeal,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      final title = _stats[member.memberId]?.mealTitle?.toLowerCase() ?? '';
      return member.memberFullName.toLowerCase().contains(q) ||
          member.statusLabel.toLowerCase().contains(q) ||
          title.contains(q);
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
                  'DINH DƯỠNG HUẤN LUYỆN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dinh dưỡng học viên',
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
                  'Quản lý thực đơn 7 ngày & nguyên tắc ăn từng học viên',
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
    final hasMealCount = _members.where(_hasMealPlan).length;
    final noMealCount = _members.length - hasMealCount;
    final kcalValues = _members
        .map((m) => _stats[m.memberId]?.avgKcalPerDay ?? 0)
        .where((k) => k > 0)
        .toList();
    final avgKcalAll = kcalValues.isEmpty
        ? 0
        : (kcalValues.reduce((a, b) => a + b) / kcalValues.length).round();
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
                                            MetaGymIcon(
                                              MetaGymIcons.actionNutrition,
                                              size: 18,
                                              color: colors.success,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Tổng quan dinh dưỡng',
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
                                              child: CoachingSummaryMetricTile(
                                                value: '$hasMealCount',
                                                label: 'Có thực đơn',
                                                valueColor: colors.success,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CoachingSummaryMetricTile(
                                                value: '$noMealCount',
                                                label: 'Chờ thiết lập',
                                                valueColor: colors.warning,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: CoachingSummaryMetricTile(
                                                value: avgKcalAll == 0
                                                    ? '0'
                                                    : _formatKcal(avgKcalAll),
                                                label: 'TB kcal/ngày',
                                                valueColor:
                                                    MetaGymTheme.brandOrange,
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
                                              MetaGymIcons.emptyNutrition,
                                              size: 24,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Chưa có hội viên dinh dưỡng.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Hội viên đang đồng hành sẽ hiển thị tại đây để bạn thiết kế thực đơn 7 ngày và nguyên tắc ăn uống.',
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
                                      fieldKey: const Key(
                                        'nutrition-member-search',
                                      ),
                                      controller: _searchController,
                                      hintText:
                                          'Tìm hội viên hoặc tên thực đơn…',
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        CoachingFilterChip(
                                          key: const Key(
                                            'nutrition-filter-all',
                                          ),
                                          label: 'Tất cả (${_members.length})',
                                          accentColor: colors.success,
                                          selected:
                                              _filter == _NutritionFilter.all,
                                          onTap: () => setState(
                                            () => _filter =
                                                _NutritionFilter.all,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          key: const Key(
                                            'nutrition-filter-has-meal',
                                          ),
                                          label:
                                              'Đã có thực đơn ($hasMealCount)',
                                          accentColor: colors.success,
                                          selected:
                                              _filter ==
                                              _NutritionFilter.hasMeal,
                                          onTap: () => setState(
                                            () => _filter =
                                                _NutritionFilter.hasMeal,
                                          ),
                                        ),
                                        CoachingFilterChip(
                                          key: const Key(
                                            'nutrition-filter-no-meal',
                                          ),
                                          label:
                                              'Chưa có thực đơn ($noMealCount)',
                                          accentColor: colors.success,
                                          selected:
                                              _filter ==
                                              _NutritionFilter.noMeal,
                                          onTap: () => setState(
                                            () => _filter =
                                                _NutritionFilter.noMeal,
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
                                            'Hội viên dinh dưỡng',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Chạm để mở thực đơn 7 ngày',
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
                                        _buildNutritionMemberCard(
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

  Widget _buildNutritionMemberCard(
    MetaGymColors colors,
    CoachMemberSummary member,
    int index,
  ) {
    final st = _stats[member.memberId];
    final hasMeal = st?.hasMealPlan == true;
    final isFeatured = index == 0 && hasMeal && member.status == 'ACTIVE';

    final primaryMetricLine = !hasMeal
        ? 'Chưa thiết lập thực đơn 7 ngày'
        : st!.avgKcalPerDay > 0
        ? '~${_formatKcal(st.avgKcalPerDay)} kcal/ngày · ${st.activeDaysCount}/7 ngày · ${st.mealSlotCount} bữa'
        : '${st.mealTitle?.isNotEmpty == true ? st.mealTitle : 'Thực đơn 7 ngày'} · Đã sẵn sàng';

    final secondaryLine = !hasMeal
        ? 'Thiết lập bữa Sáng · Trưa · Tối và nguyên tắc ăn uống'
        : [
            if (st!.mealTitle?.isNotEmpty == true) st.mealTitle!,
            if (st.hasNotes) 'Có ghi chú ăn uống',
          ].join(' · ');

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: isFeatured ? colors.success.withValues(alpha: 0.48) : null,
      onTap: () => _openMemberNutrition(member),
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
                          label: !hasMeal && member.status == 'ACTIVE'
                              ? 'Chờ thiết lập'
                              : member.statusLabel,
                          tone: !hasMeal && member.status == 'ACTIVE'
                              ? CoachingPillTone.amber
                              : member.status == 'ACTIVE'
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryMetricLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary.withValues(alpha: 0.88),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    if (secondaryLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondaryLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: !hasMeal
                              ? colors.warning
                              : colors.textWarmMuted,
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
            key: Key('nutrition-open-meal-${member.memberId}'),
            label: hasMeal ? 'Mở thực đơn 7 ngày ›' : '+ Thiết lập thực đơn 7 ngày',
            accentColor: hasMeal ? colors.success : colors.warning,
            borderColor: (hasMeal ? colors.success : colors.warning).withValues(
              alpha: 0.45,
            ),
            onTap: () => _openMemberNutrition(member),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String sliceCompat(int start) =>
      length <= start ? '' : substring(start);
}

class _MemberGuidesPage extends StatefulWidget {
  const _MemberGuidesPage({
    required this.member,
    required this.service,
    this.useSolidGlassFallback = false,
  });

  final CoachMemberSummary member;
  final CoachNutritionService service;
  final bool useSolidGlassFallback;

  @override
  State<_MemberGuidesPage> createState() => _MemberGuidesPageState();
}

class _MemberGuidesPageState extends State<_MemberGuidesPage> {
  List<NutritionGuide> _guides = const [];
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
      _guides = const [];
      _error = null;
    });
    try {
      final guides = await widget.service.getGuides(widget.member.memberId);
      if (mounted) setState(() => _guides = guides);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hướng dẫn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(NutritionGuide? guide) async {
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachNutritionEditorPage(
          memberId: widget.member.memberId,
          service: widget.service,
          guide: guide,
        ),
      ),
    );
    if (mounted) await _load();
  }

  CoachingPillTone _guideTone(String status) => switch (status) {
    'ACTIVE' => CoachingPillTone.green,
    'DRAFT' => CoachingPillTone.amber,
    _ => CoachingPillTone.neutral,
  };

  IconData _guideIcon(String status) => switch (status) {
    'ACTIVE' => Icons.eco_outlined,
    'DRAFT' => Icons.edit_note_rounded,
    _ => Icons.history_rounded,
  };

  Color _guideAccent(MetaGymColors colors, String status) => switch (status) {
    'ACTIVE' => colors.success,
    'DRAFT' => colors.warning,
    _ => colors.reflection,
  };

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
                  'DINH DƯỠNG · COACH',
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
                            onRefresh: _load,
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
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CoachingAvatar(
                                          fullName:
                                              widget.member.memberFullName,
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
                                                  color: colors.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${_guides.length} hướng dẫn dinh dưỡng',
                                                style: TextStyle(
                                                  color: colors.textWarmMuted,
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
                                  const SizedBox(height: 12),
                                  CoachingPrimaryButton(
                                    label: 'Tạo hướng dẫn',
                                    icon: Icons.add_rounded,
                                    onPressed: () => _open(null),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.menu_book_outlined,
                                        color: colors.success,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Danh sách hướng dẫn',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      CoachingPill(
                                        label: '${_guides.length} bản',
                                        tone: CoachingPillTone.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_guides.isEmpty)
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
                                              MetaGymIcons.emptyNutrition,
                                              size: 24,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Chưa có hướng dẫn nào.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Nhấn "Tạo hướng dẫn" để soạn thực đơn và nguyên tắc dinh dưỡng cho hội viên.',
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
                                  else
                                    for (final guide in _guides)
                                      MetaGymGlassCard(
                                        solid: widget.useSolidGlassFallback,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        borderColor: guide.status == 'ACTIVE'
                                            ? colors.success.withValues(
                                                alpha: 0.40,
                                              )
                                            : null,
                                        onTap: () => _open(guide),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _guideAccent(
                                                  colors,
                                                  guide.status,
                                                ).withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                border: Border.all(
                                                  color: _guideAccent(
                                                    colors,
                                                    guide.status,
                                                  ).withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Icon(
                                                _guideIcon(guide.status),
                                                color: _guideAccent(
                                                  colors,
                                                  guide.status,
                                                ),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CoachingPill(
                                                    label:
                                                        '${guide.statusLabel} · Phiên bản ${guide.version}',
                                                    tone: _guideTone(
                                                      guide.status,
                                                    ),
                                                    icon: _guideIcon(
                                                      guide.status,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    guide.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: colors.textPrimary,
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    guide.publicationLabel,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Icon(
                                                Icons.chevron_right_rounded,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
}
