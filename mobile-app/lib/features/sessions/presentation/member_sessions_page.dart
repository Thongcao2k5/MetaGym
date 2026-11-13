import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:provider/provider.dart';

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
    appBar: AppBar(
      title: const Text('Lịch buổi tập'),
      actions: [
        if (widget.coachBooking != null)
          IconButton(
            tooltip: 'Lịch Coach',
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => widget.coachBooking!),
            ),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else if (_sessions.isEmpty)
                  const ListTile(title: Text('Bạn chưa có buổi tập nào.'))
                else
                  for (final session in _sessions)
                    Card(
                      child: ListTile(
                        title: Text(session.title),
                        subtitle: Text(
                          '${formatSessionLocalTime(session.scheduledStartAt)} · ${session.statusLabel}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
    appBar: AppBar(title: const Text('Chi tiết buổi tập')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else if (_session case final session?) ...[
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Trạng thái'),
                    subtitle: Text(session.statusLabel),
                  ),
                  ListTile(
                    title: const Text('Bắt đầu · Giờ địa phương'),
                    subtitle: Text(
                      formatSessionLocalTime(session.scheduledStartAt),
                    ),
                  ),
                  if (session.scheduledEndAt case final end?)
                    ListTile(
                      title: const Text('Kết thúc · Giờ địa phương'),
                      subtitle: Text(formatSessionLocalTime(end)),
                    ),
                  if (session.notes?.isNotEmpty ?? false)
                    ListTile(
                      title: const Text('Ghi chú'),
                      subtitle: Text(session.notes!),
                    ),
                  if (session.cancellationReason?.isNotEmpty ?? false)
                    ListTile(
                      title: const Text('Lý do hủy'),
                      subtitle: Text(session.cancellationReason!),
                    ),
                ],
              ],
            ),
          ),
  );
}
