import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:provider/provider.dart';

class CoachSelectionPage extends StatefulWidget {
  const CoachSelectionPage({this.service, super.key});

  final CoachSelectionService? service;

  @override
  State<CoachSelectionPage> createState() => _CoachSelectionPageState();
}

class _CoachSelectionPageState extends State<CoachSelectionPage> {
  CoachSelectionService? _service;
  List<CoachProfile> _coaches = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachSelectionService>();
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
      final coaches = await _service!.getCoaches();
      if (mounted) setState(() => _coaches = coaches);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn Coach')),
    body: _loading && _coaches.isEmpty
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
                ] else if (_coaches.isEmpty)
                  const ListTile(title: Text('Chưa có Coach để lựa chọn.')),
                if (_error == null)
                  for (final coach in _coaches)
                    ListTile(
                      title: Text(coach.fullName),
                      subtitle: Text(coach.specialties.join(', ')),
                      trailing: Text(
                        coach.availableSlots > 0
                            ? 'Còn ${coach.availableSlots} suất'
                            : 'Đã hết suất',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CoachDetailPage(
                            coachId: coach.id,
                            service: _service!,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
  );
}
