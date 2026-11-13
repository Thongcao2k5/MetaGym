import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/training_plan_content.dart';

class CoachPlanFormPage extends StatefulWidget {
  const CoachPlanFormPage({
    required this.memberId,
    required this.service,
    this.plan,
    super.key,
  });

  final String memberId;
  final CoachTrainingService service;
  final TrainingPlan? plan;

  @override
  State<CoachPlanFormPage> createState() => _CoachPlanFormPageState();
}

class _CoachPlanFormPageState extends State<CoachPlanFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _goal;
  late final List<_DayDraft> _days;
  List<CatalogItem> _catalog = const [];
  Set<String> _activeExerciseIds = const {};
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plan?.title);
    _goal = TextEditingController(text: widget.plan?.goal);
    _days = widget.plan == null
        ? [_DayDraft()]
        : widget.plan!.days.map(_DayDraft.fromPlan).toList();
    _loadExercises();
  }

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    for (final day in _days) {
      day.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final catalog = await widget.service.getExercises();
      final missing = <CatalogItem>[];
      for (final day in widget.plan?.days ?? const <TrainingDay>[]) {
        for (final exercise in day.exercises) {
          if (!catalog.any((item) => item.id == exercise.exerciseId) &&
              !missing.any((item) => item.id == exercise.exerciseId)) {
            missing.add(
              CatalogItem(
                id: exercise.exerciseId,
                name: '${exercise.exerciseName} (không còn trong danh mục)',
              ),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _catalog = [...catalog, ...missing];
          _activeExerciseIds = catalog.map((item) => item.id).toSet();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được danh mục bài tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Vui lòng nhập tiêu đề.';
    if (_days.isEmpty) return 'Cần ít nhất một ngày tập.';
    if (_catalog.isEmpty) return 'Chưa có bài tập để chọn.';
    for (final day in _days) {
      if (day.title.text.trim().isEmpty) return 'Vui lòng nhập tên ngày tập.';
      if (day.exercises.isEmpty) return 'Mỗi ngày cần ít nhất một bài tập.';
      for (final exercise in day.exercises) {
        if (exercise.exerciseId == null) return 'Vui lòng chọn bài tập.';
        if (!_activeExerciseIds.contains(exercise.exerciseId)) {
          return 'Bài tập không còn trong danh mục.';
        }
        final reps = exercise.reps.text.trim();
        final duration = int.tryParse(exercise.duration.text.trim());
        if (reps.isEmpty && duration == null) {
          return 'Cần số lần lặp hoặc thời lượng.';
        }
        if (exercise.duration.text.trim().isNotEmpty &&
            (duration == null || duration <= 0)) {
          return 'Thời lượng phải là số dương.';
        }
        if (exercise.sets.text.trim().isNotEmpty &&
            (int.tryParse(exercise.sets.text.trim()) ?? 0) <= 0) {
          return 'Số hiệp phải là số dương.';
        }
      }
    }
    return null;
  }

  Map<String, Object?> _payload() => {
    'title': _title.text.trim(),
    'goal': _goal.text.trim().isEmpty ? null : _goal.text.trim(),
    'days': [
      for (var dayIndex = 0; dayIndex < _days.length; dayIndex++)
        {
          'dayNumber': dayIndex + 1,
          'title': _days[dayIndex].title.text.trim(),
          'notes': _days[dayIndex].notes.text.trim().isEmpty
              ? null
              : _days[dayIndex].notes.text.trim(),
          'exercises': [
            for (
              var exerciseIndex = 0;
              exerciseIndex < _days[dayIndex].exercises.length;
              exerciseIndex++
            )
              {
                'exerciseId':
                    _days[dayIndex].exercises[exerciseIndex].exerciseId,
                'displayOrder': exerciseIndex + 1,
                'sets': int.tryParse(
                  _days[dayIndex].exercises[exerciseIndex].sets.text.trim(),
                ),
                'reps':
                    _days[dayIndex].exercises[exerciseIndex].reps.text
                        .trim()
                        .isEmpty
                    ? null
                    : _days[dayIndex].exercises[exerciseIndex].reps.text.trim(),
                'durationSeconds': int.tryParse(
                  _days[dayIndex].exercises[exerciseIndex].duration.text.trim(),
                ),
                'restSeconds':
                    _days[dayIndex].exercises[exerciseIndex].restSeconds,
                'weightGuidance':
                    _days[dayIndex].exercises[exerciseIndex].weightGuidance,
                'notes': _days[dayIndex].exercises[exerciseIndex].notes,
              },
          ],
        },
    ],
  };

  Future<void> _save() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = _payload();
      final service = widget.service;
      final saved = service is CoachTrainingApi
          ? await service.saveCurrent(widget.memberId, payload)
          : widget.plan == null
          ? await widget.service.create(widget.memberId, payload)
          : await widget.service.update(widget.plan!.id, payload);
      if (mounted) Navigator.pop(context, saved.id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được giáo trình.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() => _error = null);
    final plan = TrainingPlan(
      id: widget.plan?.id ?? 'preview',
      title: _title.text.trim(),
      goal: _goal.text.trim(),
      status: 'DRAFT',
      version: widget.plan?.version ?? 1,
      days: [
        for (var dayIndex = 0; dayIndex < _days.length; dayIndex++)
          TrainingDay(
            dayNumber: dayIndex + 1,
            title: _days[dayIndex].title.text.trim(),
            notes: _days[dayIndex].notes.text.trim(),
            exercises: [
              for (
                var exerciseIndex = 0;
                exerciseIndex < _days[dayIndex].exercises.length;
                exerciseIndex++
              )
                TrainingExercise(
                  exerciseId:
                      _days[dayIndex].exercises[exerciseIndex].exerciseId!,
                  exerciseName: _catalog
                      .firstWhere(
                        (item) =>
                            item.id ==
                            _days[dayIndex].exercises[exerciseIndex].exerciseId,
                      )
                      .name,
                  displayOrder: exerciseIndex + 1,
                  sets: int.tryParse(
                    _days[dayIndex].exercises[exerciseIndex].sets.text.trim(),
                  ),
                  reps: _days[dayIndex].exercises[exerciseIndex].reps.text
                      .trim(),
                  durationSeconds: int.tryParse(
                    _days[dayIndex].exercises[exerciseIndex].duration.text
                        .trim(),
                  ),
                ),
            ],
          ),
      ],
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xem trước giáo trình'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(child: TrainingPlanContent(plan: plan)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.plan == null ? 'Tạo giáo trình' : 'Sửa bản nháp'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            key: const Key('coach-plan-form-list'),
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextField(
                key: const Key('plan-title'),
                controller: _title,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              TextField(
                key: const Key('plan-goal'),
                controller: _goal,
                maxLength: 5000,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mục tiêu'),
              ),
              for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) ...[
                const SizedBox(height: 16),
                Text(
                  'Ngày ${dayIndex + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextField(
                  key: Key('day-title-$dayIndex'),
                  controller: _days[dayIndex].title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Tên ngày tập'),
                ),
                TextField(
                  controller: _days[dayIndex].notes,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú ngày tập',
                  ),
                ),
                for (
                  var exerciseIndex = 0;
                  exerciseIndex < _days[dayIndex].exercises.length;
                  exerciseIndex++
                )
                  _exerciseFields(dayIndex, exerciseIndex),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _days[dayIndex].exercises.add(_ExerciseDraft());
                        }),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm bài tập'),
                ),
              ],
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _days.add(_DayDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm ngày tập'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy ? null : _preview,
                child: const Text('Xem trước'),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  widget.service is CoachTrainingApi
                      ? 'Lưu giáo trình'
                      : 'Lưu bản nháp',
                ),
              ),
            ],
          ),
  );

  Widget _exerciseFields(int dayIndex, int exerciseIndex) {
    final draft = _days[dayIndex].exercises[exerciseIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bài tập ${exerciseIndex + 1}'),
        DropdownButtonFormField<String>(
          key: Key('exercise-choice-$dayIndex-$exerciseIndex'),
          initialValue: draft.exerciseId,
          decoration: const InputDecoration(labelText: 'Bài tập'),
          items: [
            for (final item in _catalog)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => draft.exerciseId = value),
        ),
        TextField(
          controller: draft.sets,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Số hiệp'),
        ),
        TextField(
          key: Key('exercise-reps-$dayIndex-$exerciseIndex'),
          controller: draft.reps,
          decoration: const InputDecoration(labelText: 'Số lần lặp'),
        ),
        TextField(
          controller: draft.duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Thời lượng (giây)'),
        ),
      ],
    );
  }
}

class _DayDraft {
  _DayDraft()
    : title = TextEditingController(),
      notes = TextEditingController(),
      exercises = [_ExerciseDraft()];

  _DayDraft.fromPlan(TrainingDay day)
    : title = TextEditingController(text: day.title),
      notes = TextEditingController(text: day.notes),
      exercises = day.exercises.map(_ExerciseDraft.fromPlan).toList();

  final TextEditingController title;
  final TextEditingController notes;
  final List<_ExerciseDraft> exercises;

  void dispose() {
    title.dispose();
    notes.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
  }
}

class _ExerciseDraft {
  _ExerciseDraft()
    : sets = TextEditingController(),
      reps = TextEditingController(),
      duration = TextEditingController();

  _ExerciseDraft.fromPlan(TrainingExercise exercise)
    : exerciseId = exercise.exerciseId,
      restSeconds = exercise.restSeconds,
      weightGuidance = exercise.weightGuidance,
      notes = exercise.notes,
      sets = TextEditingController(text: exercise.sets?.toString()),
      reps = TextEditingController(text: exercise.reps),
      duration = TextEditingController(
        text: exercise.durationSeconds?.toString(),
      );

  String? exerciseId;
  int? restSeconds;
  String? weightGuidance;
  String? notes;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController duration;

  void dispose() {
    sets.dispose();
    reps.dispose();
    duration.dispose();
  }
}
