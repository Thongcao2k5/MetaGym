import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/progress/data/coach_progress_service.dart';
import 'package:meta_gym_app/features/progress/presentation/coach_progress_page.dart';
import 'package:provider/provider.dart';

class CoachMemberDetailPage extends StatefulWidget {
  const CoachMemberDetailPage({
    required this.memberId,
    required this.service,
    super.key,
  });

  final String memberId;
  final CoachMembersService service;

  @override
  State<CoachMemberDetailPage> createState() => _CoachMemberDetailPageState();
}

class _CoachMemberDetailPageState extends State<CoachMemberDetailPage> {
  CoachMemberDetail? _member;
  List<CoachTerminationRequest> _requests = const [];
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _member = null;
      _requests = const [];
      _error = null;
      _actionError = null;
    });
    try {
      final member = await widget.service.getMember(widget.memberId);
      final requests = await widget.service.getTerminationRequests();
      if (!mounted) return;
      setState(() {
        _member = member;
        _requests = requests;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hồ sơ hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestTermination() async {
    final member = _member;
    if (_busy || member == null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _TerminationRequestDialog(),
    );
    if (reason == null ||
        !mounted ||
        _member?.relationshipId != member.relationshipId) {
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.requestTermination(member.relationshipId, reason);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.statusCode == 404 || error.statusCode == 403) {
            _member = null;
            _requests = const [];
            _error = error.message;
          } else {
            _actionError = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không gửi được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = _member;
    final pending = _requests.any(
      (request) =>
          request.relationshipId == member?.relationshipId &&
          request.status == 'PENDING',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ hội viên')),
      body: _loading && member == null
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
                  ],
                  if (member != null) ...[
                    Text(
                      member.memberFullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('Trạng thái: ${member.statusLabel}'),
                    Text('Email: ${member.email}'),
                    if (member.fitnessGoal?.isNotEmpty == true)
                      Text('Mục tiêu: ${member.fitnessGoal}'),
                    if (member.healthNotes?.isNotEmpty == true)
                      Text('Ghi chú sức khỏe: ${member.healthNotes}'),
                    if (member.injuryNotes?.isNotEmpty == true)
                      Text('Chấn thương: ${member.injuryNotes}'),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CoachProgressPage(
                            memberId: member.memberId,
                            memberName: member.memberFullName,
                            service: context.read<CoachProgressService>(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('Xem tiến độ'),
                    ),
                    if (pending)
                      const Text('Yêu cầu đang chờ duyệt')
                    else
                      FilledButton(
                        onPressed: _busy ? null : _requestTermination,
                        child: const Text('Xin ngừng phụ trách'),
                      ),
                    if (_actionError != null)
                      Text(
                        _actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TerminationRequestDialog extends StatefulWidget {
  const _TerminationRequestDialog();

  @override
  State<_TerminationRequestDialog> createState() =>
      _TerminationRequestDialogState();
}

class _TerminationRequestDialogState extends State<_TerminationRequestDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xin ngừng phụ trách?'),
    content: TextField(
      key: const Key('termination-request-reason'),
      controller: _reason,
      maxLength: 1000,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Lý do',
        errorText: _invalid ? 'Vui lòng nhập lý do.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: () {
          final reason = _reason.text.trim();
          if (reason.isEmpty) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, reason);
        },
        child: const Text('Gửi yêu cầu'),
      ),
    ],
  );
}
