import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/early_termination_widgets.dart';
import 'package:provider/provider.dart';

const int _coachMemberHardCap = 8;

enum _CoachMembersFilter { all, active, paused, pending }

class CoachMembersPage extends StatefulWidget {
  const CoachMembersPage({this.service, super.key});

  final CoachMembersService? service;

  @override
  State<CoachMembersPage> createState() => _CoachMembersPageState();
}

class _CoachMembersPageState extends State<CoachMembersPage> {
  CoachMembersService? _service;
  List<CoachMemberSummary> _members = const [];
  List<CoachTerminationRequest> _requests = const [];
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;
  _CoachMembersFilter _filter = _CoachMembersFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachMembersService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _actionError = null;
      _members = const [];
      _requests = const [];
    });
    try {
      final members = await _service!.getMembers();
      final requests = await _service!.getTerminationRequests();
      if (!mounted) return;
      setState(() {
        _members = members;
        _requests = requests;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được Member.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respondTermination(
    CoachTerminationRequest request,
    String decision,
    String? reason,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await _service!.respondTermination(
        request.id,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final message = switch (decision) {
        'ACCEPT' => 'Đã chấp nhận kết thúc sớm quan hệ.',
        'REJECT' => 'Đã từ chối và chuyển yêu cầu sang Admin phân xử.',
        _ => 'Đã rút yêu cầu ngừng phụ trách.',
      };
      showCoachingSnackBar(context, message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không xử lý được phản hồi yêu cầu.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMember(CoachMemberSummary member) async {
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachMemberDetailPage(
          memberId: member.memberId,
          service: _service!,
        ),
      ),
    );
    if (mounted) await _load();
  }

  List<CoachMemberSummary> _filteredMembers() {
    return switch (_filter) {
      _CoachMembersFilter.all => _members,
      _CoachMembersFilter.active =>
        _members.where((m) => m.status == 'ACTIVE').toList(),
      _CoachMembersFilter.paused =>
        _members.where((m) => m.status != 'ACTIVE').toList(),
      _CoachMembersFilter.pending => const [],
    };
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
            _MembersCircleButton(
              svgAsset: MetaGymIcons.commonBack,
              testIcon: Icons.arrow_back_rounded,
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
                  'META GYM · COACH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hội viên của tôi',
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
                const SizedBox(height: 1),
                Text(
                  'Quản lý phụ trách 1:1 & yêu cầu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
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

  Widget _buildFilterRow(
    MetaGymColors colors, {
    required int totalCount,
    required int activeCount,
    required int pausedCount,
    required int pendingCount,
  }) {
    final filters = <(_CoachMembersFilter, String, Key)>[
      (
        _CoachMembersFilter.all,
        'Tất cả ($totalCount)',
        const Key('members-filter-all'),
      ),
      (
        _CoachMembersFilter.active,
        'Hiệu lực ($activeCount)',
        const Key('members-filter-active'),
      ),
      if (pausedCount > 0)
        (
          _CoachMembersFilter.paused,
          'Tạm dừng ($pausedCount)',
          const Key('members-filter-paused'),
        ),
      (
        _CoachMembersFilter.pending,
        'Chờ xử lý ($pendingCount)',
        const Key('members-filter-pending'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in filters)
            _MembersFilterPill(
              key: item.$3,
              label: item.$2,
              selected: _filter == item.$1,
              onTap: () => setState(() => _filter = item.$1),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final activeCount = _members.where((m) => m.status == 'ACTIVE').length;
    final pausedCount = _members.length - activeCount;
    final pendingTerminations = _requests.where((item) => item.isOpen).length;
    final filteredMembers = _filteredMembers();
    final showMembersSection = _filter != _CoachMembersFilter.pending;
    final showRequestsSection =
        _filter == _CoachMembersFilter.all ||
        _filter == _CoachMembersFilter.pending;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors),
                Expanded(
                  child: _loading && _members.isEmpty && _requests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Đang tải danh sách học viên...',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            children: [
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                CoachingSecondaryButton(
                                  label: 'Thử lại',
                                  expand: true,
                                  onPressed: _load,
                                ),
                              ] else ...[
                                if (_actionError != null)
                                  CoachingErrorBanner(message: _actionError!),
                                _MembersOverviewHero(
                                  activeCount: activeCount,
                                  totalCount: _members.length,
                                  pendingTerminationCount: pendingTerminations,
                                ),
                                _buildFilterRow(
                                  colors,
                                  totalCount: _members.length,
                                  activeCount: activeCount,
                                  pausedCount: pausedCount,
                                  pendingCount: pendingTerminations,
                                ),
                                if (showMembersSection) ...[
                                  _SectionHeader(
                                    title: 'Đang phụ trách',
                                    count: filteredMembers.length,
                                    highlight: filteredMembers.isNotEmpty,
                                  ),
                                  if (_members.isEmpty)
                                    const _EmptySectionCard(
                                      svgAsset: MetaGymIcons.emptyCoach,
                                      fallbackIcon:
                                          Icons.people_outline_rounded,
                                      title: 'Chưa có hội viên đang phụ trách.',
                                      subtitle: 'Khi học viên mua gói Coach, hồ sơ sẽ hiển thị tại đây.',
                                    )
                                  else if (filteredMembers.isEmpty)
                                    _EmptySectionCard(
                                      svgAsset: MetaGymIcons.emptyCoach,
                                      fallbackIcon:
                                          Icons.filter_list_off_rounded,
                                      title: 'Không có hội viên trong mục đã chọn.',
                                      actionLabel: 'Xem tất cả',
                                      onAction: () => setState(
                                        () => _filter = _CoachMembersFilter.all,
                                      ),
                                    )
                                  else
                                    for (
                                      var i = 0;
                                      i < filteredMembers.length;
                                      i++
                                    )
                                      _MemberRowCard(
                                        member: filteredMembers[i],
                                        paletteIndex: i,
                                        onTap: () =>
                                            _openMember(filteredMembers[i]),
                                      ),
                                  const SizedBox(height: 10),
                                ],
                                if (showRequestsSection) ...[
                                  _SectionHeader(
                                    title: 'Yêu cầu ngừng phụ trách',
                                    count: _requests.length,
                                    warning: pendingTerminations > 0,
                                  ),
                                  if (_requests.isEmpty)
                                    const _EmptySectionCard(
                                      svgAsset:
                                          MetaGymIcons.coachingTermination,
                                      fallbackIcon: Icons.assignment_outlined,
                                      title: 'Chưa có yêu cầu nào.',
                                    )
                                  else
                                    for (final request in _requests)
                                      EarlyTerminationCard(
                                        request: request,
                                        viewerRole: 'COACH',
                                        title: request.memberName,
                                        busy: _busy,
                                        onRespond: (decision, reason) =>
                                            _respondTermination(
                                              request,
                                              decision,
                                              reason,
                                            ),
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
    );
  }
}

class _MembersOverviewHero extends StatelessWidget {
  const _MembersOverviewHero({
    required this.activeCount,
    required this.totalCount,
    required this.pendingTerminationCount,
  });

  final int activeCount;
  final int totalCount;
  final int pendingTerminationCount;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final usedSlots = totalCount.clamp(0, _coachMemberHardCap);
    final freeSlots = (_coachMemberHardCap - usedSlots).clamp(
      0,
      _coachMemberHardCap,
    );
    final ratio = (usedSlots / _coachMemberHardCap).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();

    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.actionMembers,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Công suất phụ trách 1:1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: CoachingPill(
                  label: '$totalCount / $_coachMemberHardCap suất',
                  tone: freeSlots > 0
                      ? CoachingPillTone.green
                      : CoachingPillTone.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    child: _MetricColumn(
                      label: 'Hiệu lực',
                      value: '$activeCount',
                      color: activeCount > 0
                          ? colors.success
                          : colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    child: _MetricColumn(
                      label: 'Chờ xử lý',
                      value: '$pendingTerminationCount',
                      color: pendingTerminationCount > 0
                          ? colors.warning
                          : colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 9,
                    ),
                    child: _MetricColumn(
                      label: 'Suất trống',
                      value: '$freeSlots',
                      color: freeSlots > 0
                          ? colors.primaryText
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Giới hạn chất lượng Meta Gym',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: colors.metricPanelBg,
              valueColor: const AlwaysStoppedAnimation<Color>(
                MetaGymTheme.brandOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.15,
            fontFeatures: MetaGymTheme.tabularFigures,
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.highlight = false,
    this.warning = false,
  });

  final String title;
  final int count;
  final bool highlight;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CoachingPill(
            label: '$count',
            tone: warning
                ? CoachingPillTone.amber
                : highlight
                ? CoachingPillTone.green
                : CoachingPillTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _MemberRowCard extends StatelessWidget {
  const _MemberRowCard({
    required this.member,
    required this.paletteIndex,
    required this.onTap,
  });

  final CoachMemberSummary member;
  final int paletteIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isActive = member.status == 'ACTIVE';
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          CoachingAvatar(
            fullName: member.memberFullName,
            size: 44,
            round: true,
            paletteIndex: paletteIndex,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.memberFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CoachingPill(
                      label: member.statusLabel,
                      tone: isActive
                          ? CoachingPillTone.green
                          : CoachingPillTone.amber,
                    ),
                    Text(
                      'Chạm để xem hồ sơ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textWarmMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.metricPanelBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.metricPanelBorder),
                ),
                alignment: Alignment.center,
                child: MetaGymIcon(
                  svgAsset,
                  size: MetaGymIconSize.sm,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            CoachingSecondaryButton(
              label: actionLabel!,
              expand: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersCircleButton extends StatelessWidget {
  const _MembersCircleButton({
    required this.svgAsset,
    required this.testIcon,
    required this.tooltip,
    required this.onTap,
  });

  final String svgAsset;
  final IconData testIcon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: MetaGymTap(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
              highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.10),
              focusColor: colors.focus.withValues(alpha: 0.22),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.circleButtonBg,
                    gradient: isLight
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE5ECF5)],
                          )
                        : null,
                    border: Border.all(
                      color: colors.circleButtonBorder,
                      width: 1,
                    ),
                    boxShadow: isLight
                        ? const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MetaGymIcon(
                        svgAsset,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          testIcon,
                          size: 20,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembersFilterPill extends StatelessWidget {
  const _MembersFilterPill({
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
    final bg = selected
        ? colors.chipActiveBg
        : (isLight ? colors.surface : colors.liquidGlass);
    final border = selected
        ? MetaGymTheme.brandOrange
        : (isLight ? colors.borderStrong : colors.liquidGlassBorder);
    final fg = selected
        ? (isLight ? colors.chipActiveText : colors.textPrimary)
        : colors.textWarmMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          side: BorderSide(color: border, width: selected ? 1.2 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
          highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                height: 1.2,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
