import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/early_termination_widgets.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final pendingTerminations = _requests.where((item) => item.isOpen).length;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
        title: const Text(
          'Hội viên của tôi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFF7F9FC),
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
                onTap: _loading ? null : _load,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: MetaGymTheme.textPrimary),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: _loading && _members.isEmpty && _requests.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: const Color(0xFF282320),
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
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
                            memberCount: _members.length,
                            pendingTerminationCount: pendingTerminations,
                          ),
                          _SectionHeader(
                            title: 'Đang phụ trách',
                            count: _members.length,
                            highlight: _members.isNotEmpty,
                          ),
                          if (_members.isEmpty)
                            const _EmptySectionCard(
                              icon: Icons.people_outline_rounded,
                              title: 'Chưa có hội viên đang phụ trách.',
                              subtitle: 'Khi học viên mua gói Coach, hồ sơ sẽ hiển thị tại đây.',
                            ),
                          for (final member in _members)
                            _MemberRowCard(
                              member: member,
                              onTap: () => _openMember(member),
                            ),
                          const SizedBox(height: 12),
                          _SectionHeader(
                            title: 'Yêu cầu ngừng phụ trách',
                            count: _requests.length,
                          ),
                          if (_requests.isEmpty)
                            const _EmptySectionCard(
                              icon: Icons.assignment_outlined,
                              title: 'Chưa có yêu cầu nào.',
                            ),
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MembersOverviewHero extends StatelessWidget {
  const _MembersOverviewHero({
    required this.memberCount,
    required this.pendingTerminationCount,
  });

  final int memberCount;
  final int pendingTerminationCount;

  @override
  Widget build(BuildContext context) {
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _MetricColumn(
              label: 'Đang phụ trách',
              value: '$memberCount',
              accent: memberCount > 0,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0x26FFF5E9),
          ),
          Expanded(
            child: _MetricColumn(
              label: 'Chờ ngừng phụ trách',
              value: '$pendingTerminationCount',
              warning: pendingTerminationCount > 0,
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
    this.accent = false,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool accent;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? MetaGymTheme.warning
        : accent
        ? MetaGymTheme.primary
        : MetaGymTheme.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFC8C2BC), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
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
  });

  final String title;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CoachingPill(
            label: '$count',
            tone: highlight ? CoachingPillTone.green : CoachingPillTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _MemberRowCard extends StatelessWidget {
  const _MemberRowCard({required this.member, required this.onTap});

  final CoachMemberSummary member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = member.status == 'ACTIVE';
    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          CoachingAvatar(
            fullName: member.memberFullName,
            size: 44,
            round: true,
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
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                CoachingPill(
                  label: member.statusLabel,
                  tone: isActive
                      ? CoachingPillTone.green
                      : CoachingPillTone.amber,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFC8C2BC),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x80211E1C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x9A8C8176)),
            ),
            child: Icon(icon, color: const Color(0xFFC8C2BC), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0xFFC8C2BC),
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
    );
  }
}
