import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_request_detail_page.dart';
import 'package:provider/provider.dart';

class CoachRequestsPage extends StatefulWidget {
  const CoachRequestsPage({required this.coachId, this.service, super.key});

  final String coachId;
  final CoachRequestsService? service;

  @override
  State<CoachRequestsPage> createState() => _CoachRequestsPageState();
}

class _CoachRequestsPageState extends State<CoachRequestsPage> {
  CoachRequestsService? _service;
  List<CoachIncomingRequest> _requests = const [];
  CoachProfile? _coach;
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
    final pending = _requests.where((item) => item.status == 'PENDING');
    final decided = _requests.where((item) => item.status != 'PENDING');
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu chọn Coach')),
      body: _loading && _requests.isEmpty && _coach == null
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
                  ] else ...[
                    if (_coach != null)
                      Text(
                        _coach!.availableSlots > 0
                            ? 'Còn ${_coach!.availableSlots} suất'
                            : 'Đã hết suất',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Đang chờ xử lý',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (pending.isEmpty)
                      const ListTile(title: Text('Chưa có yêu cầu đang chờ.')),
                    for (final request in pending)
                      ListTile(
                        title: Text('Hội viên ${request.memberId}'),
                        subtitle: Text(request.message ?? request.statusLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openRequest(request),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Lịch sử yêu cầu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (decided.isEmpty && pending.isEmpty)
                      const ListTile(title: Text('Chưa có yêu cầu nào.')),
                    for (final request in decided)
                      ListTile(
                        title: Text('Hội viên ${request.memberId}'),
                        subtitle: Text(request.statusLabel),
                        onTap: () => _openRequest(request),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
