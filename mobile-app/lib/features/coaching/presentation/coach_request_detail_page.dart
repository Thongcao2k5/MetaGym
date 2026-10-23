import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';

class CoachRequestDetailPage extends StatefulWidget {
  const CoachRequestDetailPage({
    required this.requestId,
    required this.service,
    super.key,
  });

  final String requestId;
  final CoachRequestsService service;

  @override
  State<CoachRequestDetailPage> createState() => _CoachRequestDetailPageState();
}

class _CoachRequestDetailPageState extends State<CoachRequestDetailPage> {
  final _reason = TextEditingController();
  CoachIncomingRequest? _request;
  String? _loadError;
  String? _decisionError;
  bool _reasonRequired = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _request = null;
      _loadError = null;
    });
    try {
      final request = await widget.service.getRequest(widget.requestId);
      if (mounted) setState(() => _request = request);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được chi tiết yêu cầu.');
      }
    }
  }

  Future<void> _decide(String decision) async {
    if (_busy || _request?.status != 'PENDING') return;
    final reason = _reason.text.trim();
    if (decision == 'REJECTED' && reason.isEmpty) {
      setState(() => _reasonRequired = true);
      return;
    }
    setState(() {
      _busy = true;
      _decisionError = null;
      _reasonRequired = false;
    });
    try {
      await widget.service.decide(
        widget.requestId,
        decision,
        reason: decision == 'REJECTED' ? reason : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _decisionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _decisionError = 'Không xử lý được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết yêu cầu')),
      body: request == null && _loadError == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (request != null) ...[
                  Text(
                    'Hội viên ${request.memberId}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Trạng thái: ${request.statusLabel}'),
                  if (request.message?.isNotEmpty == true)
                    Text('Lời nhắn: ${request.message}'),
                  if (request.rejectionReason?.isNotEmpty == true)
                    Text('Lý do từ chối: ${request.rejectionReason}'),
                  if (request.status == 'PENDING') ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('rejection-reason'),
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 1000,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Lý do từ chối',
                        errorText: _reasonRequired
                            ? 'Vui lòng nhập lý do.'
                            : null,
                      ),
                    ),
                    if (_decisionError != null)
                      Text(
                        _decisionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy ? null : () => _decide('ACCEPTED'),
                          child: const Text('Chấp nhận'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : () => _decide('REJECTED'),
                          child: const Text('Từ chối'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
