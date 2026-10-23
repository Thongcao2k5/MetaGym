import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:provider/provider.dart';

class CallsPage extends StatefulWidget {
  const CallsPage({this.service, required this.currentUserId, super.key});
  final CallsService? service;
  final String currentUserId;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  CallsService? _service;
  List<CallLog> _calls = const [];
  List<Conversation> _relationships = const [];
  String? _selectedRelationship;
  String _callType = 'VOICE';
  bool _loading = true;
  bool _saving = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CallsService>();
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
      final calls = await _service!.getCalls(1);
      final relationships = await _service!.getActiveRelationships();
      if (mounted) {
        setState(() {
          _calls = calls;
          _relationships = relationships;
          _selectedRelationship =
              relationships.any(
                (item) => item.relationshipId == _selectedRelationship,
              )
              ? _selectedRelationship
              : relationships.firstOrNull?.relationshipId;
          _page = 1;
          _hasMore = calls.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử gọi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final calls = await _service!.getCalls(_page + 1);
      if (mounted) {
        setState(() {
          _calls = [..._calls, ...calls];
          _page++;
          _hasMore = calls.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải thêm được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _create() async {
    final relationshipId = _selectedRelationship;
    if (_saving || relationshipId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final call = await _service!.create(relationshipId, _callType);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallDetailPage(
            service: _service!,
            call: call,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tạo được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử cuộc gọi')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Đây chỉ là bản ghi thử API. Ứng dụng chưa tích hợp RTC, '
                  'nên không thể kết nối cuộc gọi thoại/video thật.',
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _calls.isEmpty ? _load : _loadMore,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (_relationships.isEmpty)
                  const ListTile(
                    title: Text('Chưa có quan hệ hoạt động để tạo cuộc gọi.'),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRelationship,
                    decoration: const InputDecoration(labelText: 'Quan hệ'),
                    items: [
                      for (final item in _relationships)
                        DropdownMenuItem(
                          value: item.relationshipId,
                          child: Text('Quan hệ ${item.relationshipId}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedRelationship = value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _callType,
                    decoration: const InputDecoration(
                      labelText: 'Loại cuộc gọi',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VOICE', child: Text('Thoại')),
                      DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                    ],
                    onChanged: (value) =>
                        setState(() => _callType = value ?? 'VOICE'),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _create,
                    child: Text(_saving ? 'Đang tạo…' : 'Tạo bản ghi cuộc gọi'),
                  ),
                ],
                const SizedBox(height: 16),
                if (_calls.isEmpty && _error == null)
                  const ListTile(title: Text('Chưa có cuộc gọi nào.')),
                for (final call in _calls)
                  Card(
                    child: ListTile(
                      title: Text('${call.typeLabel} · ${call.statusLabel}'),
                      subtitle: Text(call.initiatedAt),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CallDetailPage(
                              service: _service!,
                              call: call,
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        );
                        if (mounted) _load();
                      },
                    ),
                  ),
                if (_hasMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm'),
                  ),
              ],
            ),
          ),
  );
}

class CallDetailPage extends StatefulWidget {
  const CallDetailPage({
    required this.service,
    required this.call,
    required this.currentUserId,
    super.key,
  });
  final CallsService service;
  final CallLog call;
  final String currentUserId;
  @override
  State<CallDetailPage> createState() => _CallDetailPageState();
}

class _CallDetailPageState extends State<CallDetailPage> {
  late CallLog _call = widget.call;
  bool _saving = false;
  String? _error;

  Future<void> _update(String status, {String? failureReason}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.service.updateStatus(
        _call.id,
        status,
        failureReason: failureReason,
      );
      if (mounted) setState(() => _call = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không cập nhật được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiver = _call.receiverId == widget.currentUserId;
    return Scaffold(
      appBar: AppBar(title: const Text('Trạng thái cuộc gọi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Chỉ hiển thị metadata. Chưa có RTC để kết nối âm thanh/video.',
          ),
          ListTile(
            title: Text(_call.typeLabel),
            subtitle: Text(_call.statusLabel),
          ),
          ListTile(
            title: const Text('Quan hệ'),
            subtitle: Text(_call.relationshipId),
          ),
          ListTile(
            title: const Text('Thời điểm tạo'),
            subtitle: Text(_call.initiatedAt),
          ),
          if (_call.endedAt != null)
            ListTile(
              title: const Text('Kết thúc'),
              subtitle: Text(_call.endedAt!),
            ),
          if (_call.failureReason != null) Text(_call.failureReason!),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_call.status == 'CREATED' || _call.status == 'RINGING') ...[
            if (_call.status == 'CREATED')
              OutlinedButton(
                onPressed: _saving ? null : () => _update('RINGING'),
                child: const Text('Đánh dấu đổ chuông'),
              ),
            if (receiver)
              OutlinedButton(
                onPressed: _saving ? null : () => _update('REJECTED'),
                child: const Text('Đánh dấu từ chối'),
              ),
            if (receiver && _call.status == 'RINGING')
              OutlinedButton(
                onPressed: _saving ? null : () => _update('ANSWERED'),
                child: const Text('Đánh dấu bắt máy'),
              ),
            OutlinedButton(
              onPressed: _saving ? null : () => _update('MISSED'),
              child: const Text('Đánh dấu nhỡ'),
            ),
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => _update(
                      'FAILED',
                      failureReason: 'Ứng dụng chưa tích hợp RTC',
                    ),
              child: const Text('Đánh dấu lỗi kết nối'),
            ),
          ],
          if (_call.status == 'ANSWERED')
            FilledButton(
              onPressed: _saving ? null : () => _update('ENDED'),
              child: const Text('Đánh dấu kết thúc'),
            ),
        ],
      ),
    );
  }
}
