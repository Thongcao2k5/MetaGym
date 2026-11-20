import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:provider/provider.dart';

enum _SessionsTab { all, upcoming, history }

class MemberSessionsPage extends StatefulWidget {
  const MemberSessionsPage({this.service, this.coachBooking, super.key});

  final MemberSessionsService? service;
  final Widget? coachBooking;

  @override
  State<MemberSessionsPage> createState() => _MemberSessionsPageState();
}

class _MemberSessionsPageState extends State<MemberSessionsPage> {
  MemberSessionsService? _service;
  List<TrainingSession> _sessions = const [];
  bool _loading = true;
  String? _error;
  _SessionsTab _currentTab = _SessionsTab.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberSessionsService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _sessions = const [];
      _error = null;
    });
    try {
      final sessions = await _service!.getMine();
      if (mounted) setState(() => _sessions = sessions);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch buổi tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCoachBooking() {
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => widget.coachBooking ?? const CoachBookingPage(),
      ),
    );
  }

  void _openDetail(TrainingSession session) {
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => _SessionDetailPage(service: _service!, id: session.id),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            Tooltip(
              message: 'Back',
              child: MetaGymCircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Quay lại',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch buổi tập',
                  style: TextStyle(
                    color: Color(0xFFF6F3F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lịch tự tập & buổi tập với Coach',
                  style: TextStyle(color: Color(0xFFBCB5AE), fontSize: 11.5),
                ),
              ],
            ),
          ),
          MetaGymCircleIconButton(
            icon: Icons.event_available_outlined,
            tooltip: 'Lịch Coach',
            onTap: _openCoachBooking,
          ),
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xDA26221F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x938C7B6C)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTabButton(
              label: 'Tất cả',
              active: _currentTab == _SessionsTab.all,
              onTap: () => setState(() => _currentTab = _SessionsTab.all),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentTabButton(
              label: 'Sắp tới',
              active: _currentTab == _SessionsTab.upcoming,
              onTap: () => setState(() => _currentTab = _SessionsTab.upcoming),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentTabButton(
              label: 'Lịch sử',
              active: _currentTab == _SessionsTab.history,
              onTap: () => setState(() => _currentTab = _SessionsTab.history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MetaGymTheme.brandOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC6BBB3),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8C7B6C), fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filteredSessions = _sessions.where((session) {
      if (_currentTab == _SessionsTab.all) return true;
      final start = DateTime.tryParse(session.scheduledStartAt)?.toLocal();
      final isUpcoming =
          session.status == 'SCHEDULED' &&
          (start == null || start.isAfter(now));
      if (_currentTab == _SessionsTab.upcoming) return isUpcoming;
      return !isUpcoming;
    }).toList();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildSegmentedTabs(),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: const Color(0xFF2B2622),
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                            children: [
                              // Hero Card: Lịch tập với Coach
                              MetaGymGlassCard(
                                featured: true,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: MetaGymTheme.brandOrange
                                                .withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.calendar_month_rounded,
                                            color: MetaGymTheme.brandOrange,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Lịch tập với Coach',
                                                style: TextStyle(
                                                  color: Color(0xFFF6F3F0),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Đặt & quản lý buổi tập 1:1 với PT',
                                                style: TextStyle(
                                                  color: Color(0xFFBCB5AE),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            MetaGymTheme.brandOrange,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: _openCoachBooking,
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Đặt lịch tập với Coach',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Section: Lịch tự tập cá nhân
                              _buildSectionHeader(
                                title: 'Lịch tự tập cá nhân',
                                subtitle: '${filteredSessions.length} buổi',
                                icon: Icons.fitness_center_rounded,
                              ),
                              const SizedBox(height: 8),

                              if (_error != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FF453A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x66FF453A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFFF6961),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFFF857D),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  style: TextButton.styleFrom(
                                    foregroundColor: MetaGymTheme.brandOrange,
                                  ),
                                  child: const Text('Thử lại'),
                                ),
                              ] else if (_sessions.isEmpty)
                                const MetaGymGlassCard(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 32,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event_busy_rounded,
                                        color: Color(0xFF8C7B6C),
                                        size: 36,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Bạn chưa có buổi tập nào.',
                                        style: TextStyle(
                                          color: Color(0xFFF6F3F0),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Bạn có thể đặt buổi tập riêng với Huấn luyện viên ở phía trên.',
                                        style: TextStyle(
                                          color: Color(0xFFBCB5AE),
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              else if (filteredSessions.isEmpty)
                                const MetaGymGlassCard(
                                  padding: EdgeInsets.all(22),
                                  child: Center(
                                    child: Text(
                                      'Không có buổi tập nào trong mục này.',
                                      style: TextStyle(
                                        color: Color(0xFFBCB5AE),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                for (final session in filteredSessions)
                                  MetaGymGlassCard(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(16),
                                    child: MetaGymTap(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _openDetail(session),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: MetaGymTheme.brandOrange
                                                  .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.fitness_center_rounded,
                                              color: MetaGymTheme.brandOrange,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  session.title,
                                                  style: const TextStyle(
                                                    color: Color(0xFFF6F3F0),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${formatSessionLocalTime(session.scheduledStartAt)} · ${session.statusLabel}',
                                                  style: const TextStyle(
                                                    color: Color(0xFFBCB5AE),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFFBCB5AE),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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

class _SegmentTabButton extends StatelessWidget {
  const _SegmentTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MetaGymTap(
    borderRadius: BorderRadius.circular(11),
    onTap: onTap,
    child: AnimatedContainer(
      duration: MetaGymTheme.stateDurationOf(context),
      curve: Curves.easeOutCubic,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF544037) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFFF6F3F0) : const Color(0xFFBCB5AE),
          fontSize: 13,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ),
  );
}

class _SessionDetailPage extends StatefulWidget {
  const _SessionDetailPage({required this.service, required this.id});

  final MemberSessionsService service;
  final String id;

  @override
  State<_SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<_SessionDetailPage> {
  TrainingSession? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _session = null;
      _error = null;
    });
    try {
      final session = await widget.service.getDetail(widget.id);
      if (mounted) setState(() => _session = session);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được buổi tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    appBar: AppBar(
      leading: const BackButton(),
      title: const Text(
        'Chi tiết buổi tập',
        style: TextStyle(
          color: Color(0xFFF6F3F0),
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFFF6F3F0)),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const MetaGymBackground(),
        SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: MetaGymTheme.brandOrange,
                  ),
                )
              : RefreshIndicator(
                  color: MetaGymTheme.brandOrange,
                  backgroundColor: const Color(0xFF2B2622),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF453A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x66FF453A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFFF6961),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF857D),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: MetaGymTheme.brandOrange,
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ] else if (_session case final session?) ...[
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.fitness_center_rounded,
                                      color: MetaGymTheme.brandOrange,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      session.title,
                                      style: const TextStyle(
                                        color: Color(0xFFF6F3F0),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Divider(color: Color(0x808C7766)),
                              const SizedBox(height: 8),
                              _detailRow(
                                icon: Icons.info_outline_rounded,
                                iconColor: MetaGymTheme.progressGreen,
                                label: 'Trạng thái',
                                value: session.statusLabel,
                              ),
                              _detailRow(
                                icon: Icons.schedule_rounded,
                                iconColor: MetaGymTheme.reflectionBlue,
                                label: 'Bắt đầu · Giờ địa phương',
                                value: formatSessionLocalTime(
                                  session.scheduledStartAt,
                                ),
                              ),
                              if (session.scheduledEndAt case final end?)
                                _detailRow(
                                  icon: Icons.timer_off_outlined,
                                  iconColor: const Color(0xFFBCB5AE),
                                  label: 'Kết thúc · Giờ địa phương',
                                  value: formatSessionLocalTime(end),
                                ),
                              if (session.notes?.isNotEmpty ?? false)
                                _detailRow(
                                  icon: Icons.notes_rounded,
                                  iconColor: MetaGymTheme.brandOrange,
                                  label: 'Ghi chú',
                                  value: session.notes!,
                                ),
                              if (session.cancellationReason?.isNotEmpty ??
                                  false)
                                _detailRow(
                                  icon: Icons.cancel_outlined,
                                  iconColor: const Color(0xFFFF6961),
                                  label: 'Lý do hủy',
                                  value: session.cancellationReason!,
                                  valueColor: const Color(0xFFFF857D),
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
  );

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFBCB5AE),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? const Color(0xFFF6F3F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
