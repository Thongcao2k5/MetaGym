import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_request_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class CoachRequestsPage extends StatefulWidget {
  const CoachRequestsPage({required this.coachId, this.service, super.key});

  final String coachId;
  final CoachRequestsService? service;

  @override
  State<CoachRequestsPage> createState() => _CoachRequestsPageState();
}

enum _RequestFilter { all, pending, decided }

class _CoachRequestsPageState extends State<CoachRequestsPage> {
  CoachRequestsService? _service;
  List<CoachIncomingRequest> _requests = const [];
  CoachProfile? _coach;
  _RequestFilter _filter = _RequestFilter.all;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachRequestsService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _service!.getRequests();
      final coach = await _service!.getCoach(widget.coachId);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _coach = coach;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được yêu cầu Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequest(CoachIncomingRequest request) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CoachRequestDetailPage(requestId: request.id, service: _service!),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final pending = _requests
        .where((item) => item.status == 'PENDING')
        .toList();
    final decided = _requests
        .where((item) => item.status != 'PENDING')
        .toList();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: canPop ? 68 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: Tooltip(
                    message: 'Back',
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text(
          'Yêu cầu chọn Coach',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
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
            child: _loading && _requests.isEmpty && _coach == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.cardSurface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            expand: true,
                            onPressed: _load,
                          ),
                        ] else ...[
                          if (_coach != null)
                            _SlotCapacityHero(
                              coach: _coach!,
                              pendingCount: pending.length,
                            ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in const [
                                (_RequestFilter.all, 'Tất cả'),
                                (_RequestFilter.pending, 'Chờ duyệt'),
                                (_RequestFilter.decided, 'Đã xử lý'),
                              ])
                                ChoiceChip(
                                  label: Text(entry.$2),
                                  selected: _filter == entry.$1,
                                  selectedColor: const Color(0xFF33201B),
                                  surfaceTintColor: Colors.transparent,
                                  checkmarkColor: MetaGymTheme.brandOrange,
                                  backgroundColor: MetaGymTheme.cardSurface,
                                  side: BorderSide(
                                    color: _filter == entry.$1
                                        ? MetaGymTheme.brandOrange
                                        : MetaGymTheme.cardBorder,
                                  ),
                                  labelStyle: TextStyle(
                                    color: _filter == entry.$1
                                        ? MetaGymTheme.textPrimary
                                        : MetaGymTheme.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.$1),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_filter != _RequestFilter.decided) ...[
                            _SectionHeader(
                              title: 'Đang chờ xử lý',
                              count: pending.length,
                              highlight: pending.isNotEmpty,
                            ),
                            if (pending.isEmpty)
                              const _EmptyStateCard(
                                icon: Icons.mark_email_read_outlined,
                                title: 'Chưa có yêu cầu đang chờ.',
                                subtitle: 'Yêu cầu mới từ học viên sẽ hiển thị ở đây để bạn duyệt.',
                              ),
                            for (final request in pending)
                              _RequestCard(
                                request: request,
                                onTap: () => _openRequest(request),
                              ),
                            if (_filter == _RequestFilter.all)
                              const SizedBox(height: 12),
                          ],
                          if (_filter != _RequestFilter.pending) ...[
                            _SectionHeader(
                              title: 'Lịch sử yêu cầu',
                              count: decided.length,
                            ),
                            if (decided.isEmpty && pending.isEmpty)
                              const _EmptyStateCard(
                                icon: Icons.inbox_outlined,
                                title: 'Chưa có yêu cầu nào.',
                                subtitle: 'Kéo xuống để làm mới khi có học viên gửi yêu cầu chọn Coach.',
                              )
                            else if (decided.isEmpty)
                              const _EmptyStateCard(
                                icon: Icons.history_rounded,
                                title: 'Chưa có yêu cầu đã xử lý.',
                              ),
                            for (final request in decided)
                              _RequestCard(
                                request: request,
                                onTap: () => _openRequest(request),
                              ),
                          ],
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

class _SlotCapacityHero extends StatelessWidget {
  const _SlotCapacityHero({required this.coach, required this.pendingCount});

  final CoachProfile coach;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final hasSlots = coach.availableSlots > 0;
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hạn mức học viên',
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CoachingPill(
                label: hasSlots
                    ? 'Còn ${coach.availableSlots} suất'
                    : 'Đã hết suất',
                tone: hasSlots
                    ? CoachingPillTone.green
                    : CoachingPillTone.amber,
                icon: hasSlots
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetricColumn(
                    label: 'Đang phụ trách',
                    value: '${coach.usedSlots}/${coach.memberLimit}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0x26FFFFFF),
                ),
                Expanded(
                  child: _HeroMetricColumn(
                    label: 'Chờ duyệt',
                    value: '$pendingCount',
                    accent: pendingCount > 0,
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

class _HeroMetricColumn extends StatelessWidget {
  const _HeroMetricColumn({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBEC3CB), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: accent ? MetaGymTheme.primary : MetaGymTheme.textPrimary,
            fontSize: 20,
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
            tone: highlight ? CoachingPillTone.coral : CoachingPillTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final CoachIncomingRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'PENDING';
    final tone = switch (request.status) {
      'PENDING' => CoachingPillTone.amber,
      'ACCEPTED' => CoachingPillTone.green,
      'REJECTED' => CoachingPillTone.coral,
      _ => CoachingPillTone.neutral,
    };

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderColor: isPending
          ? MetaGymTheme.primary.withValues(alpha: 0.4)
          : MetaGymTheme.cardBorder,
      onTap: onTap,
      child: Row(
        children: [
          CoachingAvatar(fullName: request.memberId, size: 46, round: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hội viên ${request.memberId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CoachingPill(label: request.statusLabel, tone: tone),
                  ],
                ),
                if (request.message?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    request.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD2D6DE),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (request.requestedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Gửi lúc ${formatVietnamTime(request.requestedAt)}',
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 12,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: MetaGymTheme.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MetaGymTheme.elevatedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetaGymTheme.cardBorder),
            ),
            child: Icon(icon, color: MetaGymTheme.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
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
