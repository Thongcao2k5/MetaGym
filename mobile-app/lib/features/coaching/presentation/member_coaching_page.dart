import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/termination_reason_dialog.dart';
import 'package:provider/provider.dart';

class MemberCoachingPage extends StatefulWidget {
  const MemberCoachingPage({this.service, super.key});

  final MemberCoachingService? service;

  @override
  State<MemberCoachingPage> createState() => _MemberCoachingPageState();
}

class _MemberCoachingPageState extends State<MemberCoachingPage> {
  MemberCoachingService? _service;
  List<MemberCoachRequest> _requests = const [];
  List<MemberCoachRelationship> _history = const [];
  Map<String, String> _coachNames = const {};
  MemberCoachRelationship? _current;
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? MemberCoachingApi(context.read<ApiClient>());
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
      final current = await _service!.getCurrentRelationship();
      final history = await _service!.getRelationshipHistory();
      Map<String, String> coachNames;
      try {
        coachNames = await _service!.getCoachNames();
      } catch (_) {
        coachNames = const {};
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _current = current;
        _history = history;
        _coachNames = coachNames;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được quan hệ Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _coachLabel(String coachId) =>
      _coachNames[coachId] ?? 'Coach: $coachId';

  Future<void> _cancel(MemberCoachRequest request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await _service!.cancelRequest(request.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không hủy được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _terminate() async {
    if (_busy || _current == null) return;
    final relationshipId = _current!.id;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const TerminationReasonDialog(),
    );
    if (reason == null || !mounted || _current?.id != relationshipId) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await _service!.terminateRelationship(relationshipId, reason);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không kết thúc được quan hệ.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((item) => item.status == 'PENDING');
    final previousRequests = _requests.where(
      (item) => item.status != 'PENDING',
    );
    final previousRelationships = _history.where(
      (item) => item.id != _current?.id,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach của tôi'),
        actions: [
          if (_current != null && context.read<ApiClient?>() != null)
            IconButton(
              tooltip: 'Xem gói Coach',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
                final coachId = _current!.coachId;
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CoachOffersPage(coachId: coachId),
                  ),
                );
              },
            ),
        ],
      ),
      body:
          _loading && _requests.isEmpty && _history.isEmpty && _current == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
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
                    if (_actionError != null)
                      Text(
                        _actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Text(
                      'Yêu cầu đang chờ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (pending.isEmpty)
                      const ListTile(title: Text('Không có yêu cầu đang chờ.')),
                    for (final request in pending)
                      ListTile(
                        title: Text(_coachLabel(request.coachId)),
                        subtitle: Text(request.message ?? request.statusLabel),
                        trailing: TextButton(
                          onPressed: _busy ? null : () => _cancel(request),
                          child: const Text('Hủy yêu cầu'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Coach hiện tại',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_current == null)
                      const ListTile(title: Text('Chưa có Coach hiện tại.'))
                    else
                      ListTile(
                        title: Text(_coachLabel(_current!.coachId)),
                        subtitle: Text(_current!.statusLabel),
                        trailing: TextButton(
                          onPressed: _busy ? null : _terminate,
                          child: const Text('Kết thúc quan hệ'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Lịch sử yêu cầu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (previousRequests.isEmpty)
                      const ListTile(title: Text('Chưa có lịch sử yêu cầu.')),
                    for (final request in previousRequests)
                      ListTile(
                        title: Text(_coachLabel(request.coachId)),
                        subtitle: Text(request.statusLabel),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Lịch sử quan hệ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (previousRelationships.isEmpty)
                      const ListTile(title: Text('Chưa có lịch sử quan hệ.')),
                    for (final item in previousRelationships)
                      ListTile(
                        title: Text(_coachLabel(item.coachId)),
                        subtitle: Text(item.statusLabel),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
