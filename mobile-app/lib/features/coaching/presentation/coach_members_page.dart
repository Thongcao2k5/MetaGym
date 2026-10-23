import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/progress/presentation/coach_progress_page.dart';
import 'package:provider/provider.dart';

class CoachMembersPage extends StatefulWidget {
  const CoachMembersPage({this.service, this.progressOnly = false, super.key});

  final CoachMembersService? service;
  final bool progressOnly;

  @override
  State<CoachMembersPage> createState() => _CoachMembersPageState();
}

class _CoachMembersPageState extends State<CoachMembersPage> {
  CoachMembersService? _service;
  List<CoachMemberSummary> _members = const [];
  List<CoachTerminationRequest> _requests = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachMembersService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _members = const [];
      _requests = const [];
    });
    try {
      final members = await _service!.getMembers();
      final requests = widget.progressOnly
          ? <CoachTerminationRequest>[]
          : await _service!.getTerminationRequests();
      if (!mounted) return;
      setState(() {
        _members = members;
        _requests = requests;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được Member.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMember(CoachMemberSummary member) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => widget.progressOnly
            ? CoachProgressPage(
                memberId: member.memberId,
                memberName: member.memberFullName,
              )
            : CoachMemberDetailPage(
                memberId: member.memberId,
                service: _service!,
              ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.progressOnly ? 'Tiến độ hội viên' : 'Hội viên của tôi',
      ),
    ),
    body: _loading && _members.isEmpty && _requests.isEmpty
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
                  Text(
                    'Đang phụ trách',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_members.isEmpty)
                    const ListTile(
                      title: Text('Chưa có hội viên đang phụ trách.'),
                    ),
                  for (final member in _members)
                    ListTile(
                      title: Text(member.memberFullName),
                      subtitle: Text(member.statusLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openMember(member),
                    ),
                  const SizedBox(height: 16),
                  if (!widget.progressOnly) ...[
                    Text(
                      'Yêu cầu ngừng phụ trách',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_requests.isEmpty)
                      const ListTile(title: Text('Chưa có yêu cầu nào.')),
                    for (final request in _requests)
                      ListTile(
                        title: Text(request.reason),
                        subtitle: Text(request.statusLabel),
                      ),
                  ],
                ],
              ],
            ),
          ),
  );
}
