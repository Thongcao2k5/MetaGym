import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:meta_gym_app/features/training/presentation/training_plan_content.dart';

class CoachPlanDetailPage extends StatefulWidget {
  const CoachPlanDetailPage({
    required this.id,
    required this.service,
    super.key,
  });

  final String id;
  final CoachTrainingService service;

  @override
  State<CoachPlanDetailPage> createState() => _CoachPlanDetailPageState();
}

class _CoachPlanDetailPageState extends State<CoachPlanDetailPage> {
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
      if (mounted) setState(() => _plan = plan);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    }
  }

  Future<void> _edit() async {
    final plan = _plan;
    if (plan == null || plan.status != 'DRAFT') return;
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: '',
          plan: plan,
          service: widget.service,
        ),
      ),
    );
    if (saved != null && mounted) await _load();
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
                if (_plan != null) ...[
                  TrainingPlanContent(plan: _plan!),
                  if (_plan!.status == 'DRAFT')
                    FilledButton(
                      onPressed: _edit,
                      child: const Text('Sửa bản nháp'),
                    ),
                ],
              ],
            ),
          ),
  );
}
