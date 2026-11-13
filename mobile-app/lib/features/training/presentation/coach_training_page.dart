import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:provider/provider.dart';

class CoachTrainingPage extends StatefulWidget {
  const CoachTrainingPage({this.service, super.key});

  final CoachTrainingService? service;

  @override
  State<CoachTrainingPage> createState() => _CoachTrainingPageState();
}

class _CoachTrainingPageState extends State<CoachTrainingPage> {
  CoachTrainingService? _service;
  List<CoachMemberSummary> _members = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachTrainingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _members = const [];
      _error = null;
    });
    try {
      final members = await _service!.getMembers();
      if (mounted) setState(() => _members = members);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giáo trình của Coach')),
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
                ] else ...[
                  Text(
                    'Chọn hội viên',
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
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => _MemberPlansPage(
                              member: member,
                              service: _service!,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                    ),
                ],
              ],
            ),
          ),
  );
}

class _MemberPlansPage extends StatefulWidget {
  const _MemberPlansPage({required this.member, required this.service});

  final CoachMemberSummary member;
  final CoachTrainingService service;

  @override
  State<_MemberPlansPage> createState() => _MemberPlansPageState();
}

class _MemberPlansPageState extends State<_MemberPlansPage> {
  List<TrainingPlan> _plans = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _plans = const [];
      _error = null;
    });
    try {
      final plans = await widget.service.getPlans(widget.member.memberId);
      if (mounted) setState(() => _plans = plans);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlan(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachPlanDetailPage(
          id: id,
          service: widget.service,
          memberId: widget.member.memberId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: widget.member.memberId,
          service: widget.service,
        ),
      ),
    );
    if (!mounted || id == null) return;
    await _load();
    if (mounted) await _openPlan(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Giáo trình · ${widget.member.memberFullName}')),
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
                ] else ...[
                  if (widget.service is! CoachTrainingApi ||
                      !_plans.any((plan) => plan.status == 'ACTIVE'))
                    FilledButton(
                      onPressed: _create,
                      child: const Text('Tạo giáo trình'),
                    ),
                  if (_plans.isEmpty)
                    const ListTile(title: Text('Chưa có giáo trình nào.')),
                  for (final plan in _plans.where(
                    (plan) =>
                        widget.service is! CoachTrainingApi ||
                        plan.status != 'DRAFT',
                  ))
                    ListTile(
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.statusLabel} · Phiên bản ${plan.version}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPlan(plan.id),
                    ),
                ],
              ],
            ),
          ),
  );
}
