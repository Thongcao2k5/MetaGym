import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/progress/presentation/member_photo_page.dart';
import 'package:provider/provider.dart';

class MemberWorkoutPage extends StatefulWidget {
  const MemberWorkoutPage({this.service, super.key});
  final MemberWorkoutService? service;
  @override
  State<MemberWorkoutPage> createState() => _MemberWorkoutPageState();
}

class _MemberWorkoutPageState extends State<MemberWorkoutPage> {
  MemberWorkoutService? _service;
  List<WorkoutLog> _logs = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberWorkoutService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loading)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _logs = const [];
        _page = 0;
      }
    });
    try {
      final next = await _service!.getPage(_page + 1);
      if (mounted) {
        setState(() {
          _logs = [..._logs, ...next];
          _page++;
          _hasMore = next.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được nhật ký tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(builder: (_) => _WorkoutFormPage(service: _service!)),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _open(WorkoutLog log) async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(
        builder: (_) => _WorkoutDetailPage(log: log, service: _service!),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nhật ký tập luyện'),
      actions: [
        IconButton(
          tooltip: 'Ảnh thành quả',
          onPressed: () => MetaGymNavigation.pushOnce(
            context,
            MetaGymPageRoute<void>(builder: (_) => const MemberPhotoPage()),
          ),
          icon: const Icon(Icons.photo_library_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Thêm nhật ký tập'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loading && _logs.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _load(more: _logs.isNotEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _logs.isEmpty)
            const ListTile(title: Text('Bạn chưa có nhật ký tập.')),
          for (final log in _logs)
            Card(
              child: ListTile(
                title: Text(
                  '${log.durationMinutes ?? 0} phút · ${formatProgressTime(log.performedAt)}',
                ),
                subtitle: Text('${log.exercises.length} bài tập'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(log),
              ),
            ),
          if (_loading && _logs.isNotEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_hasMore && !_loading)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    ),
  );
}

class _WorkoutDetailPage extends StatelessWidget {
  const _WorkoutDetailPage({required this.log, required this.service});
  final WorkoutLog log;
  final MemberWorkoutService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết nhật ký tập')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          formatProgressTime(log.performedAt),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Thời lượng: ${log.durationMinutes ?? 0} phút'),
        if (log.completionLevel != null)
          Text('Mức hoàn thành: ${log.completionLevel}%'),
        if (log.notes?.isNotEmpty ?? false) Text('Ghi chú: ${log.notes}'),
        const SizedBox(height: 16),
        Text('Bài tập', style: Theme.of(context).textTheme.titleMedium),
        if (log.exercises.isEmpty) const Text('Chưa ghi bài tập.'),
        for (final exercise in log.exercises)
          ListTile(
            title: Text(exercise.name),
            subtitle: exercise.setsCompleted == null
                ? null
                : Text('${exercise.setsCompleted} hiệp'),
          ),
        FilledButton(
          onPressed: () async {
            final saved = await MetaGymNavigation.pushOnce<bool>(
              context,
              MetaGymPageRoute(
                builder: (_) => _WorkoutFormPage(service: service, log: log),
              ),
            );
            if (saved == true && context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Sửa'),
        ),
      ],
    ),
  );
}

class _WorkoutFormPage extends StatefulWidget {
  const _WorkoutFormPage({required this.service, this.log});
  final MemberWorkoutService service;
  final WorkoutLog? log;
  @override
  State<_WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends State<_WorkoutFormPage> {
  final _date = TextEditingController();
  final _duration = TextEditingController();
  final _exercises = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    if (log != null) {
      _date.text = formatProgressTime(log.performedAt);
      _duration.text = log.durationMinutes?.toString() ?? '';
      _exercises.text = log.exercises.map((e) => e.name).join('\n');
      _notes.text = log.notes ?? '';
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _duration.dispose();
    _exercises.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final date = parseProgressTime(_date.text);
    final minutes = int.tryParse(_duration.text.trim());
    final names = _exercises.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    String? validation;
    if (date == null) {
      validation = 'Nhập ngày giờ hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (minutes == null || minutes < 1 || minutes > 32767) {
      validation = 'Thời lượng phải lớn hơn 0 phút.';
    } else if (names.length > 100 || names.any((name) => name.length > 120)) {
      validation = 'Tối đa 100 bài tập, mỗi tên không quá 120 ký tự.';
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
      'performedAt': date!.toUtc().toIso8601String(),
      'durationMinutes': minutes,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'exercises': [
        for (var i = 0; i < names.length; i++)
          {'exerciseName': names[i], 'displayOrder': i + 1},
      ],
    };
    try {
      if (widget.log case final log?) {
        await widget.service.update(log.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được nhật ký tập.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.log == null ? 'Thêm nhật ký tập' : 'Sửa nhật ký tập'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('workout-date'),
          controller: _date,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Ngày tập (dd/MM/yyyy HH:mm)',
          ),
        ),
        TextField(
          key: const Key('workout-duration'),
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
        ),
        TextField(
          key: const Key('workout-exercises'),
          controller: _exercises,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Bài tập (mỗi dòng một bài)',
            alignLabelWithHint: true,
          ),
        ),
        TextField(
          controller: _notes,
          maxLength: 5000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú thành quả',
            hintText: 'Ví dụ: kéo lưng 40 kg, tập đúng kỹ thuật hơn',
          ),
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
