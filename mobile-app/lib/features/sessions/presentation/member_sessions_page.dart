import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:provider/provider.dart';

class MemberSessionsPage extends StatefulWidget {
  const MemberSessionsPage({this.service, super.key});

  final MemberSessionsService? service;

  @override
  State<MemberSessionsPage> createState() => _MemberSessionsPageState();
}

class _MemberSessionsPageState extends State<MemberSessionsPage> {
  MemberSessionsService? _service;
  List<TrainingSession> _sessions = const [];
  bool _loading = true;
  String? _error;

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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Lịch buổi tập',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
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
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF453A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x66FF453A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
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
                              padding: EdgeInsets.all(16),
                              child: ListTile(
                                leading: Icon(
                                  Icons.event_busy,
                                  color: Colors.white38,
                                ),
                                title: Text(
                                  'Bạn chưa có buổi tập nào.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            )
                          else
                            for (final session in _sessions)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.fitness_center,
                                      color: MetaGymTheme.brandOrange,
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    session.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${formatSessionLocalTime(session.scheduledStartAt)} · ${session.statusLabel}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white54,
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => _SessionDetailPage(
                                        service: _service!,
                                        id: session.id,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
            ),
          ],
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Chi tiết buổi tập',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
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
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF453A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x66FF453A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: MetaGymTheme.brandOrange
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.fitness_center,
                                          color: MetaGymTheme.brandOrange,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          session.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  const Divider(color: Color(0x26FFFFFF)),
                                  const SizedBox(height: 6),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF34C759),
                                      size: 22,
                                    ),
                                    title: const Text(
                                      'Trạng thái',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      session.statusLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.schedule,
                                      color: Color(0xFF8EB9E5),
                                      size: 22,
                                    ),
                                    title: const Text(
                                      'Bắt đầu · Giờ địa phương',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      formatSessionLocalTime(
                                        session.scheduledStartAt,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (session.scheduledEndAt case final end?)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.timer_off_outlined,
                                        color: Colors.white60,
                                        size: 22,
                                      ),
                                      title: const Text(
                                        'Kết thúc · Giờ địa phương',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        formatSessionLocalTime(end),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  if (session.notes?.isNotEmpty ?? false)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.notes_rounded,
                                        color: MetaGymTheme.brandOrange,
                                        size: 22,
                                      ),
                                      title: const Text(
                                        'Ghi chú',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        session.notes!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  if (session.cancellationReason?.isNotEmpty ??
                                      false)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.cancel_outlined,
                                        color: Color(0xFFFF6961),
                                        size: 22,
                                      ),
                                      title: const Text(
                                        'Lý do hủy',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        session.cancellationReason!,
                                        style: const TextStyle(
                                          color: Color(0xFFFF6961),
                                          fontSize: 14,
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
            ),
          ],
        ),
      );
}
