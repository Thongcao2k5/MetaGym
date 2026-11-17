import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
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
      if (day.scheduledDate == null) return 'Vui lòng chọn ngày trong lịch.';
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
      if (day.meals.isEmpty) return 'Mỗi ngày cần ít nhất một bữa ăn.';
      for (final meal in day.meals) {
        if (meal.title.text.trim().isEmpty) return 'Vui lòng nhập tên bữa ăn.';
        final time = meal.time.text.trim();
        if (time.isNotEmpty &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
          return 'Giờ ăn phải có dạng HH:mm.';
        }
      }
    }
    final dates = _days.map((day) => _formatDate(day.scheduledDate!)).toSet();
    if (dates.length != _days.length) {
      return 'Mỗi ngày phải có ngày lịch riêng.';
    }
    return null;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _selectDayDate(int dayIndex) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _days[dayIndex].scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) =>
          Theme(data: MetaGymTheme.dark, child: child!),
    );
    if (picked != null && mounted) {
      setState(() => _days[dayIndex].scheduledDate = picked);
    }
  }

  Map<String, Object?> _payload() => {
    'title': _title.text.trim(),
    'goal': _goal.text.trim().isEmpty ? null : _goal.text.trim(),
    'days': [
      for (var dayIndex = 0; dayIndex < _days.length; dayIndex++)
        {
          'dayNumber': dayIndex + 1,
          'scheduledDate': _formatDate(_days[dayIndex].scheduledDate!),
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
          'meals': [
            for (
              var mealIndex = 0;
              mealIndex < _days[dayIndex].meals.length;
              mealIndex++
            )
              {
                'displayOrder': mealIndex + 1,
                'mealType': _days[dayIndex].meals[mealIndex].mealType,
                'scheduledTime':
                    _days[dayIndex].meals[mealIndex].time.text.trim().isEmpty
                    ? null
                    : _days[dayIndex].meals[mealIndex].time.text.trim(),
                'title': _days[dayIndex].meals[mealIndex].title.text.trim(),
                'notes':
                    _days[dayIndex].meals[mealIndex].notes.text.trim().isEmpty
                    ? null
                    : _days[dayIndex].meals[mealIndex].notes.text.trim(),
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
            scheduledDate: _formatDate(_days[dayIndex].scheduledDate!),
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
            meals: [
              for (
                var mealIndex = 0;
                mealIndex < _days[dayIndex].meals.length;
                mealIndex++
              )
                PlannedMeal(
                  displayOrder: mealIndex + 1,
                  mealType: _days[dayIndex].meals[mealIndex].mealType,
                  scheduledTime:
                      _days[dayIndex].meals[mealIndex].time.text.trim().isEmpty
                      ? null
                      : _days[dayIndex].meals[mealIndex].time.text.trim(),
                  title: _days[dayIndex].meals[mealIndex].title.text.trim(),
                  notes: _days[dayIndex].meals[mealIndex].notes.text.trim(),
                ),
            ],
          ),
      ],
    );
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB8040609),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MetaGymTheme.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: const BorderSide(color: MetaGymTheme.cardBorder),
        ),
        title: const Text(
          'Xem trước giáo trình',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(child: TrainingPlanContent(plan: plan)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.elevatedSurface,
              foregroundColor: MetaGymTheme.textPrimary,
              minimumSize: const Size(48, 44),
              side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Set<MuscleFocus> _resolveDayFocuses(_DayDraft day) {
    final selected = day.exercises
        .map(
          (draft) =>
              _catalog.where((item) => item.id == draft.exerciseId).firstOrNull,
        )
        .whereType<CatalogItem>()
        .toList();
    return resolveMuscleFocusSet(
      day.title.text,
      exerciseNames: selected.map((item) => item.name).toList(),
      targetMuscles: selected.expand((item) => item.targetMuscles).toList(),
    );
  }

  InputDecoration _darkInputDecoration({
    required String labelText,
    String? hintText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.darkBorderStrong),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: MetaGymTheme.elevatedSurface,
      labelStyle: const TextStyle(
        color: MetaGymTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: MetaGymTheme.reflectionBlue,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: MetaGymTheme.textSecondary.withValues(alpha: 0.65),
        fontSize: 13.5,
      ),
      counterStyle: const TextStyle(
        color: MetaGymTheme.textSecondary,
        fontSize: 11,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.focusBlue, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
      ),
    );
  }

  static const TextStyle _fieldTextStyle = TextStyle(
    color: MetaGymTheme.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    final canPop = Navigator.of(context).canPop();
    final pageTitle = widget.plan == null
        ? 'Tạo giáo trình'
        : (widget.service is CoachTrainingApi
              ? 'Sửa giáo trình'
              : 'Sửa bản nháp');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 72,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null,
          titleSpacing: canPop ? 8 : 16,
          title: Text(
            pageTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: MetaGymTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : ListView(
                    key: const Key('coach-plan-form-list'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      media.top + kToolbarHeight + 12,
                      16,
                      media.bottom + 32,
                    ),
                    children: [
                      if (_error != null) CoachingErrorBanner(message: _error!),
                      CoachingGraphiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FormSectionHeader(
                              icon: Icons.description_outlined,
                              title: 'Thông tin giáo trình',
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('plan-title'),
                              controller: _title,
                              maxLength: 150,
                              style: _fieldTextStyle,
                              decoration: _darkInputDecoration(
                                labelText: 'Tiêu đề',
                                hintText: 'VD: Sức mạnh cơ bản 4 buổi/tuần',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const Key('plan-goal'),
                              controller: _goal,
                              maxLength: 5000,
                              maxLines: 2,
                              style: _fieldTextStyle,
                              decoration: _darkInputDecoration(
                                labelText: 'Mục tiêu',
                                hintText: 'VD: Tăng cơ và ổn định kỹ thuật',
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (
                        var dayIndex = 0;
                        dayIndex < _days.length;
                        dayIndex++
                      )
                        _buildDayCard(dayIndex),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _days.add(_DayDraft())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MetaGymTheme.textPrimary,
                            backgroundColor: MetaGymTheme.cardSurface,
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(
                              color: MetaGymTheme.darkBorderStrong,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Thêm ngày tập'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: CoachingSecondaryButton(
                              label: 'Xem trước',
                              onPressed: _busy ? null : _preview,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CoachingPrimaryButton(
                              label: widget.service is CoachTrainingApi
                                  ? 'Lưu giáo trình'
                                  : 'Lưu bản nháp',
                              loading: _busy,
                              onPressed: _busy ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final day = _days[dayIndex];
    final dayFocuses = _resolveDayFocuses(day);
    final focusSummary = dayFocuses.isEmpty
        ? 'Nhóm cơ tự động theo tên & bài tập'
        : '${summarizeMuscleFocuses(dayFocuses)} · ${isPosteriorMuscleView(dayFocuses) ? 'Mặt sau' : 'Mặt trước'}';

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MuscleAnatomyTile(
                focuses: dayFocuses,
                width: 48,
                height: 58,
                selected: dayFocuses.isNotEmpty,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoachingPill(
                      label: 'Ngày ${dayIndex + 1}',
                      tone: CoachingPillTone.coral,
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      focusSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dayFocuses.isNotEmpty
                            ? MetaGymTheme.reflectionBlue
                            : MetaGymTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_days.length > 1)
                IconButton(
                  tooltip: 'Xóa ngày tập',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _days.removeAt(dayIndex).dispose()),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: MetaGymTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('day-date-$dayIndex'),
              onPressed: _busy ? null : () => _selectDayDate(dayIndex),
              style: OutlinedButton.styleFrom(
                foregroundColor: MetaGymTheme.textPrimary,
                backgroundColor: MetaGymTheme.elevatedSurface,
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              icon: const Icon(
                Icons.event_outlined,
                color: MetaGymTheme.brandOrange,
                size: 20,
              ),
              label: Text(
                day.scheduledDate == null
                    ? 'Chọn ngày theo lịch'
                    : 'Ngày ${_displayDate(day.scheduledDate!)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: Key('day-title-$dayIndex'),
            controller: day.title,
            maxLength: 120,
            style: _fieldTextStyle,
            onChanged: (_) => setState(() {}),
            decoration: _darkInputDecoration(
              labelText: 'Tên ngày tập',
              hintText: 'VD: Thân trên · Ngực & Vai',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: day.notes,
            maxLength: 2000,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Ghi chú ngày tập'),
          ),
          const SizedBox(height: 14),
          _FormSectionHeader(
            icon: Icons.sports_gymnastics_rounded,
            title: 'Bài tập (${day.exercises.length})',
          ),
          const SizedBox(height: 10),
          for (
            var exerciseIndex = 0;
            exerciseIndex < day.exercises.length;
            exerciseIndex++
          )
            _exerciseFields(dayIndex, exerciseIndex),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() => day.exercises.add(_ExerciseDraft())),
            style: OutlinedButton.styleFrom(
              foregroundColor: MetaGymTheme.reflectionBlue,
              backgroundColor: MetaGymTheme.elevatedSurface,
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: MetaGymTheme.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm bài tập'),
          ),
          const SizedBox(height: 16),
          const Divider(color: MetaGymTheme.cardBorder, height: 1),
          const SizedBox(height: 14),
          const _FormSectionHeader(
            icon: Icons.restaurant_menu_rounded,
            iconColor: MetaGymTheme.success,
            title: 'Lịch ăn trong ngày',
          ),
          const SizedBox(height: 10),
          for (var mealIndex = 0; mealIndex < day.meals.length; mealIndex++)
            _mealFields(dayIndex, mealIndex),
          OutlinedButton.icon(
            onPressed: _busy || day.meals.length >= 12
                ? null
                : () => setState(() => day.meals.add(_MealDraft())),
            style: OutlinedButton.styleFrom(
              foregroundColor: MetaGymTheme.success,
              backgroundColor: MetaGymTheme.elevatedSurface,
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: MetaGymTheme.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm bữa ăn'),
          ),
        ],
      ),
    );
  }

  Widget _exerciseFields(int dayIndex, int exerciseIndex) {
    final day = _days[dayIndex];
    final draft = day.exercises[exerciseIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaGymTheme.elevatedSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaGymTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bài tập ${exerciseIndex + 1}',
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (day.exercises.length > 1)
                IconButton(
                  tooltip: 'Xóa bài tập',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          day.exercises.removeAt(exerciseIndex).dispose();
                        }),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: MetaGymTheme.textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: Key('exercise-choice-$dayIndex-$exerciseIndex'),
            initialValue: draft.exerciseId,
            isExpanded: true,
            dropdownColor: MetaGymTheme.elevatedSurface,
            iconEnabledColor: MetaGymTheme.textSecondary,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Bài tập'),
            items: [
              for (final item in _catalog)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => draft.exerciseId = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  style: _fieldTextStyle,
                  decoration: _darkInputDecoration(labelText: 'Số hiệp'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: Key('exercise-reps-$dayIndex-$exerciseIndex'),
                  controller: draft.reps,
                  style: _fieldTextStyle,
                  decoration: _darkInputDecoration(labelText: 'Số lần lặp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.duration,
            keyboardType: TextInputType.number,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Thời lượng (giây)'),
          ),
        ],
      ),
    );
  }

  Widget _mealFields(int dayIndex, int mealIndex) {
    final draft = _days[dayIndex].meals[mealIndex];
    return Container(
      key: Key('day-meal-$dayIndex-$mealIndex'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaGymTheme.elevatedSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaGymTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bữa ăn ${mealIndex + 1}',
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xóa bữa ăn',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _days[dayIndex].meals.removeAt(mealIndex).dispose();
                      }),
                icon: const Icon(
                  Icons.close_rounded,
                  color: MetaGymTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.mealType,
            isExpanded: true,
            dropdownColor: MetaGymTheme.elevatedSurface,
            iconEnabledColor: MetaGymTheme.textSecondary,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Loại bữa'),
            items: const [
              DropdownMenuItem(value: 'BREAKFAST', child: Text('Bữa sáng')),
              DropdownMenuItem(value: 'LUNCH', child: Text('Bữa trưa')),
              DropdownMenuItem(value: 'DINNER', child: Text('Bữa tối')),
              DropdownMenuItem(value: 'SNACK', child: Text('Bữa phụ')),
              DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => draft.mealType = value ?? 'OTHER'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.time,
            keyboardType: TextInputType.datetime,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(
              labelText: 'Giờ ăn (HH:mm, tùy chọn)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.title,
            maxLength: 120,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Món ăn / thực đơn'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.notes,
            maxLength: 2000,
            maxLines: 2,
            style: _fieldTextStyle,
            decoration: _darkInputDecoration(labelText: 'Hướng dẫn ăn uống'),
          ),
        ],
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.icon,
    required this.title,
    this.iconColor = MetaGymTheme.brandOrange,
  });

  final IconData icon;
  final String title;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayDraft {
  _DayDraft()
    : title = TextEditingController(),
      notes = TextEditingController(),
      exercises = [_ExerciseDraft()],
      meals = [_MealDraft()];

  _DayDraft.fromPlan(TrainingDay day)
    : title = TextEditingController(text: day.title),
      notes = TextEditingController(text: day.notes),
      scheduledDate = day.scheduledDate == null
          ? null
          : DateTime.tryParse(day.scheduledDate!),
      exercises = day.exercises.map(_ExerciseDraft.fromPlan).toList(),
      meals = day.meals.map(_MealDraft.fromPlan).toList();

  DateTime? scheduledDate;
  final TextEditingController title;
  final TextEditingController notes;
  final List<_ExerciseDraft> exercises;
  final List<_MealDraft> meals;

  void dispose() {
    title.dispose();
    notes.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
    for (final meal in meals) {
      meal.dispose();
    }
  }
}

class _MealDraft {
  _MealDraft()
    : title = TextEditingController(),
      time = TextEditingController(),
      notes = TextEditingController();

  _MealDraft.fromPlan(PlannedMeal meal)
    : mealType = meal.mealType,
      title = TextEditingController(text: meal.title),
      time = TextEditingController(text: meal.scheduledTime),
      notes = TextEditingController(text: meal.notes);

  String mealType = 'BREAKFAST';
  final TextEditingController title;
  final TextEditingController time;
  final TextEditingController notes;

  void dispose() {
    title.dispose();
    time.dispose();
    notes.dispose();
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
