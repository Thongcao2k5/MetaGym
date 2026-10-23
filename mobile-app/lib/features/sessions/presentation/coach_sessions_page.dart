import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:provider/provider.dart';

class CoachSessionsPage extends StatefulWidget {
  const CoachSessionsPage({this.service, this.membersService, super.key});
  final CoachSessionsService? service;
  final CoachMembersService? membersService;

  @override
  State<CoachSessionsPage> createState() => _CoachSessionsPageState();
}

class _CoachSessionsPageState extends State<CoachSessionsPage> {
  CoachSessionsService? _service;
  CoachMembersService? _membersService;
  List<CoachMemberSummary> _members = const [];
  List<TrainingSession> _sessions = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachSessionsService>();
    _membersService =
        widget.membersService ?? context.read<CoachMembersService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessions = const [];
    });
    try {
      final members = await _membersService!.getMembers();
      final sessions = await _service!.getAll();
      if (mounted) {
        setState(() {
          _members = members;
          _sessions = sessions;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch buổi tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([TrainingSession? session]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SessionFormPage(
          service: _service!,
          session: session,
          members: _members.where((m) => m.status == 'ACTIVE').toList(),
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _changeStatus(TrainingSession session, String status) async {
    String? reason;
    if (status == 'CANCELLED') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _CancellationDialog(),
      );
      if (reason == null || !mounted) return;
    } else {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đổi trạng thái'),
          content: Text(
            status == 'COMPLETED'
                ? 'Đánh dấu hoàn thành?'
                : 'Đánh dấu hội viên vắng?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (submitted != true || !mounted) return;
    }
    try {
      await _service!.update(session.id, {
        'status': status,
        if (status == 'CANCELLED') 'cancellationReason': reason,
      });
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không cập nhật được buổi tập.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý buổi tập')),
    floatingActionButton: _loading || !_members.any((m) => m.status == 'ACTIVE')
        ? null
        : FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Tạo buổi tập'),
          ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
                  const ListTile(title: Text('Chưa có buổi tập nào.')),
                if (_error == null)
                  for (final session in _sessions)
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(session.title),
                            subtitle: Text(
                              '${_memberName(session.memberId)} · ${formatSessionLocalTime(session.scheduledStartAt)} · ${session.statusLabel}',
                            ),
                            onTap: session.status == 'SCHEDULED'
                                ? () => _edit(session)
                                : null,
                          ),
                          if (session.status == 'SCHEDULED')
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _changeStatus(session, 'COMPLETED'),
                                  child: const Text('Hoàn thành'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _changeStatus(session, 'MEMBER_ABSENT'),
                                  child: const Text('Vắng mặt'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _changeStatus(session, 'CANCELLED'),
                                  child: const Text('Hủy buổi'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
  );

  String _memberName(String? id) {
    for (final member in _members) {
      if (member.memberId == id) return member.memberFullName;
    }
    return 'Hội viên';
  }
}

class _SessionFormPage extends StatefulWidget {
  const _SessionFormPage({
    required this.service,
    required this.members,
    this.session,
  });
  final CoachSessionsService service;
  final List<CoachMemberSummary> members;
  final TrainingSession? session;
  @override
  State<_SessionFormPage> createState() => _SessionFormPageState();
}

class _CancellationDialog extends StatefulWidget {
  const _CancellationDialog();
  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hủy buổi tập'),
    content: TextField(
      controller: _reason,
      key: const Key('session-cancellation-reason'),
      maxLength: 2000,
      decoration: InputDecoration(
        labelText: 'Lý do hủy',
        errorText: _invalid ? 'Vui lòng nhập lý do hủy.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
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
        child: const Text('Xác nhận hủy'),
      ),
    ],
  );
}

class _SessionFormPageState extends State<_SessionFormPage> {
  final _title = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _notes = TextEditingController();
  String? _memberId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _memberId =
        session?.memberId ??
        (widget.members.isEmpty ? null : widget.members.first.memberId);
    if (session != null) {
      _title.text = session.title;
      _start.text = formatSessionLocalTime(session.scheduledStartAt);
      _end.text = session.scheduledEndAt == null
          ? ''
          : formatSessionLocalTime(session.scheduledEndAt!);
      _notes.text = session.notes ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _start.dispose();
    _end.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final start = parseSessionLocalTime(_start.text);
    final end = _end.text.trim().isEmpty
        ? null
        : parseSessionLocalTime(_end.text);
    String? validation;
    if (_memberId == null ||
        _title.text.trim().isEmpty ||
        start == null ||
        (_end.text.trim().isNotEmpty && end == null)) {
      validation = 'Nhập tên và thời gian hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (end != null && !end.isAfter(start)) {
      validation = 'Giờ kết thúc phải sau giờ bắt đầu.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, Object?>{
      if (widget.session == null) 'memberId': _memberId,
      'title': _title.text.trim(),
      'scheduledStartAt': start!.toUtc().toIso8601String(),
      'scheduledEndAt': end?.toUtc().toIso8601String(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.session case final session?) {
        await widget.service.update(session.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được buổi tập.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.session == null ? 'Tạo buổi tập' : 'Sửa buổi tập'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.session == null)
          DropdownButtonFormField<String>(
            initialValue: _memberId,
            decoration: const InputDecoration(labelText: 'Hội viên'),
            items: widget.members
                .map(
                  (m) => DropdownMenuItem(
                    value: m.memberId,
                    child: Text(m.memberFullName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _memberId = value),
          ),
        TextField(
          key: const Key('session-title'),
          controller: _title,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Tên buổi tập'),
        ),
        TextField(
          key: const Key('session-start'),
          controller: _start,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Bắt đầu (dd/MM/yyyy HH:mm)',
          ),
        ),
        TextField(
          key: const Key('session-end'),
          controller: _end,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: 'Kết thúc (tùy chọn)'),
        ),
        TextField(
          controller: _notes,
          maxLength: 5000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ghi chú'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}

DateTime? parseSessionLocalTime(String input) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$')
      .firstMatch(input.trim());
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final time = DateTime(year, month, day, hour, minute);
  if (time.year != year ||
      time.month != month ||
      time.day != day ||
      time.hour != hour ||
      time.minute != minute) {
    return null;
  }
  return time;
}
