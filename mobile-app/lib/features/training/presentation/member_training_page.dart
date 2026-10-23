import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/training_plan_content.dart';
import 'package:provider/provider.dart';

class MemberTrainingPage extends StatefulWidget {
  const MemberTrainingPage({this.service, super.key});

  final MemberTrainingService? service;

  @override
  State<MemberTrainingPage> createState() => _MemberTrainingPageState();
}

class _MemberTrainingPageState extends State<MemberTrainingPage> {
  MemberTrainingService? _service;
  TrainingPlan? _active;
  List<TrainingPlan> _history = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberTrainingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _active = null;
      _history = const [];
    });
    try {
      final active = await _service!.getActive();
      final history = await _service!.getHistory();
      if (!mounted) return;
      setState(() {
        _active = active?.status == 'ACTIVE' ? active : null;
        _history = history
            .where((plan) => plan.status == 'ARCHIVED' && plan.id != active?.id)
            .toList();
      });
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
        builder: (_) => _MemberTrainingDetailPage(id: id, service: _service!),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giáo trình')),
    body: _loading && _active == null && _history.isEmpty
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
                    'Hiện hành',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_active == null)
                    const ListTile(
                      title: Text('Bạn chưa được giao giáo trình.'),
                    )
                  else
                    ListTile(
                      title: Text(_active!.title),
                      subtitle: Text('Phiên bản ${_active!.version}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPlan(_active!.id),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Lịch sử',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_history.isEmpty)
                    const ListTile(title: Text('Chưa có giáo trình cũ.')),
                  for (final plan in _history)
                    ListTile(
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.statusLabel} · Phiên bản ${plan.version}',
                      ),
                      onTap: () => _openPlan(plan.id),
                    ),
                ],
              ],
            ),
          ),
  );
}

class _MemberTrainingDetailPage extends StatefulWidget {
  const _MemberTrainingDetailPage({required this.id, required this.service});

  final String id;
  final MemberTrainingService service;

  @override
  State<_MemberTrainingDetailPage> createState() =>
      _MemberTrainingDetailPageState();
}

class _MemberTrainingDetailPageState extends State<_MemberTrainingDetailPage> {
  TrainingPlan? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _plan = null;
      _error = null;
    });
    try {
      final plan = await widget.service.getPlan(widget.id);
      if (!mounted) return;
      setState(() {
        if (plan.status == 'ACTIVE' || plan.status == 'ARCHIVED') {
          _plan = plan;
        } else {
          _error = 'Không tìm thấy giáo trình đã công bố.';
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được chi tiết giáo trình.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết giáo trình')),
    body: _plan == null && _error == null
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
                if (_plan != null) TrainingPlanContent(plan: _plan!),
              ],
            ),
          ),
  );
}
