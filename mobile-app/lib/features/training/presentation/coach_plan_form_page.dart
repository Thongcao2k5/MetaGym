import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
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
    this.memberName,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final String memberId;
  final CoachTrainingService service;
  final TrainingPlan? plan;
  final String? memberName;
  final bool useSolidGlassFallback;

  @override
  State<CoachPlanFormPage> createState() => _CoachPlanFormPageState();
}

class _CoachPlanFormPageState extends State<CoachPlanFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _goal;
  late final List<_DayDraft> _days;
  int _selectedDayIndex = 0;
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
    _days = widget.plan == null || widget.plan!.days.isEmpty
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

  (int? dayIndex, String? message) _validateWithDay() {
    if (_title.text.trim().isEmpty) return (null, 'Vui lòng nhập tiêu đề.');
    if (_days.isEmpty) return (null, 'Cần ít nhất một ngày tập.');
    if (_catalog.isEmpty) return (null, 'Chưa có bài tập để chọn.');
    for (var i = 0; i < _days.length; i++) {
      final day = _days[i];
      if (day.scheduledDate == null)
        return (i, 'Vui lòng chọn ngày trong lịch.');
      if (day.title.text.trim().isEmpty)
        return (i, 'Vui lòng nhập tên ngày tập.');
      if (day.exercises.isEmpty)
        return (i, 'Mỗi ngày cần ít nhất một bài tập.');
      for (final exercise in day.exercises) {
        if (exercise.exerciseId == null) return (i, 'Vui lòng chọn bài tập.');
        if (!_activeExerciseIds.contains(exercise.exerciseId)) {
          return (i, 'Bài tập không còn trong danh mục.');
        }
        final reps = exercise.reps.text.trim();
        final duration = int.tryParse(exercise.duration.text.trim());
        if (reps.isEmpty && duration == null) {
          return (i, 'Cần số lần lặp hoặc thời lượng.');
        }
        if (exercise.duration.text.trim().isNotEmpty &&
            (duration == null || duration <= 0)) {
          return (i, 'Thời lượng phải là số dương.');
        }
        if (exercise.sets.text.trim().isNotEmpty &&
            (int.tryParse(exercise.sets.text.trim()) ?? 0) <= 0) {
          return (i, 'Số hiệp phải là số dương.');
        }
      }
      if (day.meals.isEmpty) return (i, 'Mỗi ngày cần ít nhất một bữa ăn.');
      for (final meal in day.meals) {
        if (meal.title.text.trim().isEmpty)
          return (i, 'Vui lòng nhập tên bữa ăn.');
        final time = meal.time.text.trim();
        if (time.isNotEmpty &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
          return (i, 'Giờ ăn phải có dạng HH:mm.');
        }
      }
    }
    final dates = _days.map((day) => _formatDate(day.scheduledDate!)).toSet();
    if (dates.length != _days.length) {
      return (null, 'Mỗi ngày phải có ngày lịch riêng.');
    }
    return (null, null);
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _selectDayDate(int dayIndex) async {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final picked = await showDatePicker(
      context: context,
      initialDate: _days[dayIndex].scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final baseTheme = isLight ? MetaGymTheme.light : MetaGymTheme.dark;
        final c = MetaGymColors.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              surface: isLight ? c.surface : const Color(0xFF241F1B),
              surfaceContainerHigh: isLight
                  ? c.surfaceRaised
                  : const Color(0xFF2B2622),
            ),
            dialogTheme: baseTheme.dialogTheme.copyWith(
              backgroundColor: isLight ? c.surface : const Color(0xFF241F1B),
            ),
          ),
          child: child!,
        );
      },
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
    if (_busy) return;
    final (errorDay, validation) = _validateWithDay();
    if (validation != null) {
      setState(() {
        _error = validation;
        if (errorDay != null) _selectedDayIndex = errorDay;
      });
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
    final (errorDay, validation) = _validateWithDay();
    if (validation != null) {
      setState(() {
        _error = validation;
        if (errorDay != null) _selectedDayIndex = errorDay;
      });
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

    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    await MetaGymNavigation.showDialogOnce<void>(
      context: context,
      barrierColor: colors.scrim,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? colors.surface : colors.overlayGlass,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
        ),
        title: Text(
          'Xem trước giáo trình',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: TrainingPlanContent(
              plan: plan,
              useSolidGlassFallback: widget.useSolidGlassFallback,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: colors.metricPanelBg,
              foregroundColor: colors.textPrimary,
              minimumSize: const Size(48, 48),
              side: BorderSide(color: colors.metricPanelBorder),
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

  Future<void> _openCatalogPickerSheet(int dayIndex) async {
    final activeCatalog = _catalog
        .where((item) => _activeExerciseIds.contains(item.id))
        .toList();
    if (activeCatalog.isEmpty) return;

    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    var query = '';
    var defaultSets = '3';
    var defaultReps = '10–12';

    final picked = await showModalBottomSheet<CatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? colors.surface : colors.overlayGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MetaGymTheme.radiusGlassDock),
        ),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, update) {
          final q = query.trim().toLowerCase();
          final matches = q.isEmpty
              ? activeCatalog
              : activeCatalog
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(q) ||
                          (item.category?.toLowerCase().contains(q) ?? false) ||
                          item.targetMuscles.any(
                            (m) => m.toLowerCase().contains(q),
                          ),
                    )
                    .toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thêm bài tập · Ngày ${dayIndex + 1}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        MetaGymCircleIconButton(
                          svgAsset: MetaGymIcons.commonClose,
                          icon: Icons.close_rounded,
                          tooltip: 'Đóng',
                          onTap: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _inputDecoration(
                        colors,
                        labelText: 'Tìm bài tập',
                        hintText: 'VD: Squat, Bench Press, Row...',
                      ),
                      style: _fieldTextStyle(colors),
                      onChanged: (val) => update(() => query = val),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: defaultSets,
                            keyboardType: TextInputType.number,
                            style: _fieldTextStyle(colors),
                            decoration: _inputDecoration(
                              colors,
                              labelText: 'Số hiệp mặc định',
                            ),
                            onChanged: (v) => defaultSets = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: defaultReps,
                            style: _fieldTextStyle(colors),
                            decoration: _inputDecoration(
                              colors,
                              labelText: 'Số lần (Reps)',
                            ),
                            onChanged: (v) => defaultReps = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: matches.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy bài tập phù hợp.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: matches.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final item = matches[idx];
                                return MetaGymMetricPanel(
                                  onTap: () => Navigator.pop(sheetCtx, item),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (item.category != null ||
                                                item
                                                    .targetMuscles
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (item.category != null)
                                                    item.category!,
                                                  if (item
                                                      .targetMuscles
                                                      .isNotEmpty)
                                                    item.targetMuscles.join(
                                                      ', ',
                                                    ),
                                                ].join(' · '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textWarmMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const CoachingPill(
                                        label: '+ Chọn',
                                        tone: CoachingPillTone.coral,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        final day = _days[dayIndex];
        final emptyIndex = day.exercises.indexWhere(
          (e) => e.exerciseId == null,
        );
        if (emptyIndex >= 0) {
          final draft = day.exercises[emptyIndex];
          draft.exerciseId = picked.id;
          if (draft.sets.text.trim().isEmpty) {
            draft.sets.text = defaultSets.trim();
          }
          if (draft.reps.text.trim().isEmpty) {
            draft.reps.text = defaultReps.trim();
          }
        } else {
          final draft = _ExerciseDraft()
            ..exerciseId = picked.id
            ..sets.text = defaultSets.trim()
            ..reps.text = defaultReps.trim();
          day.exercises.add(draft);
        }
      });
    }
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

  InputDecoration _inputDecoration(
    MetaGymColors colors, {
    required String labelText,
    String? hintText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.metricPanelBorder),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: colors.metricPanelBg,
      labelStyle: TextStyle(
        color: colors.textSecondary,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: MetaGymTheme.brandOrange,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
      counterStyle: TextStyle(color: colors.textSecondary, fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: BorderSide(color: colors.error),
      ),
    );
  }

  TextStyle _fieldTextStyle(MetaGymColors colors) => TextStyle(
    color: colors.textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
  );

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors,
    String title,
  ) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final memberTag = widget.memberName?.trim();
    final eyebrow = memberTag != null && memberTag.isNotEmpty
        ? '${memberTag.toUpperCase()} · GIÁO TRÌNH TẬP'
        : 'GIÁO TRÌNH TẬP LUYỆN';

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 4),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final pageTitle = widget.plan == null
        ? 'Tạo giáo trình'
        : (widget.service is CoachTrainingApi
              ? 'Cập nhật giáo trình tập'
              : 'Sửa bản nháp');

    final activeDayIndex = _selectedDayIndex.clamp(0, _days.length - 1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, colors, pageTitle),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          )
                        : ListView(
                            key: const Key('coach-plan-form-list'),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              media.bottom + 40,
                            ),
                            children: [
                              if (_error != null)
                                CoachingErrorBanner(message: _error!),
                              MetaGymGlassCard(
                                solid: widget.useSolidGlassFallback,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FormSectionHeader(
                                      svgAsset: MetaGymIcons.mediaDocument,
                                      icon: Icons.description_outlined,
                                      title: 'Thông tin giáo trình',
                                      textColor: colors.textPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      key: const Key('plan-title'),
                                      controller: _title,
                                      maxLength: 150,
                                      style: _fieldTextStyle(colors),
                                      decoration: _inputDecoration(
                                        colors,
                                        labelText: 'Tiêu đề',
                                        hintText:
                                            'VD: Sức mạnh cơ bản 4 buổi/tuần',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      key: const Key('plan-goal'),
                                      controller: _goal,
                                      maxLength: 5000,
                                      maxLines: 2,
                                      style: _fieldTextStyle(colors),
                                      decoration: _inputDecoration(
                                        colors,
                                        labelText: 'Mục tiêu',
                                        hintText:
                                            'VD: Tăng cơ và ổn định kỹ thuật',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Cấu trúc ngày & bài tập',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (_days.length == 1) ...[
                                    _FormDayChip(
                                      key: const Key('plan-form-add-day-chip'),
                                      label: '+ Thêm ngày',
                                      selected: false,
                                      onTap: _busy
                                          ? null
                                          : () => setState(() {
                                              _days.add(_DayDraft());
                                              _selectedDayIndex =
                                                  _days.length - 1;
                                            }),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    '${_days.length} ngày',
                                    style: TextStyle(
                                      color: colors.textWarmMuted,
                                      fontSize: 12,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ],
                              ),
                              if (_days.length > 1) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (var i = 0; i < _days.length; i++)
                                      _FormDayChip(
                                        key: Key('plan-form-day-tab-$i'),
                                        label:
                                            _days[i].title.text.trim().isEmpty
                                            ? 'Ngày ${i + 1}'
                                            : 'Ngày ${i + 1} · ${_days[i].title.text.trim()}',
                                        selected: activeDayIndex == i,
                                        onTap: () => setState(
                                          () => _selectedDayIndex = i,
                                        ),
                                      ),
                                    _FormDayChip(
                                      key: const Key('plan-form-add-day-chip'),
                                      label: '+ Thêm ngày',
                                      selected: false,
                                      onTap: _busy
                                          ? null
                                          : () => setState(() {
                                              _days.add(_DayDraft());
                                              _selectedDayIndex =
                                                  _days.length - 1;
                                            }),
                                    ),
                                  ],
                                ),
                              ],
                              _buildDayCard(colors, isLight, activeDayIndex),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _days.add(_DayDraft());
                                          _selectedDayIndex = _days.length - 1;
                                        }),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.textPrimary,
                                    backgroundColor: colors.metricPanelBg,
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                    side: BorderSide(
                                      color: colors.metricPanelBorder,
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
                              const SizedBox(height: 12),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(MetaGymColors colors, bool isLight, int dayIndex) {
    final day = _days[dayIndex];
    final dayFocuses = _resolveDayFocuses(day);
    final focusSummary = dayFocuses.isEmpty
        ? 'Nhóm cơ tự động theo tên & bài tập'
        : '${summarizeMuscleFocuses(dayFocuses)} · ${isPosteriorMuscleView(dayFocuses) ? 'Mặt sau' : 'Mặt trước'}';

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
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
                            ? colors.reflection
                            : colors.textSecondary,
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
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _days.removeAt(dayIndex).dispose();
                          if (_selectedDayIndex >= _days.length) {
                            _selectedDayIndex = _days.length - 1;
                          }
                        }),
                  icon: MetaGymIcon(
                    MetaGymIcons.commonDelete,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('day-date-$dayIndex'),
              onPressed: _busy ? null : () => _selectDayDate(dayIndex),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                backgroundColor: colors.metricPanelBg,
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                side: BorderSide(color: colors.metricPanelBorder),
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
            style: _fieldTextStyle(colors),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(
              colors,
              labelText: 'Tên ngày tập',
              hintText: 'VD: Thân trên · Ngực & Vai',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: day.notes,
            maxLength: 2000,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(colors, labelText: 'Ghi chú ngày tập'),
          ),
          const SizedBox(height: 14),
          _FormSectionHeader(
            icon: Icons.sports_gymnastics_rounded,
            title: 'Bài tập (${day.exercises.length})',
            textColor: colors.textPrimary,
          ),
          const SizedBox(height: 10),
          for (
            var exerciseIndex = 0;
            exerciseIndex < day.exercises.length;
            exerciseIndex++
          )
            _exerciseFields(colors, isLight, dayIndex, exerciseIndex),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => day.exercises.add(_ExerciseDraft())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.reflection,
                    backgroundColor: colors.metricPanelBg,
                    minimumSize: const Size(48, 48),
                    side: BorderSide(color: colors.metricPanelBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm bài tập'),
                ),
              ),
              if (_activeExerciseIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: Key('plan-open-catalog-picker-$dayIndex'),
                  onPressed: _busy
                      ? null
                      : () => _openCatalogPickerSheet(dayIndex),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetaGymTheme.brandOrange,
                    backgroundColor: colors.metricPanelBg,
                    minimumSize: const Size(48, 48),
                    side: BorderSide(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                  ),
                  icon: const MetaGymIcon(
                    MetaGymIcons.workoutAddExercise,
                    size: 16,
                    color: MetaGymTheme.brandOrange,
                  ),
                  label: const Text('Thư viện'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.border.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 14),
          _FormSectionHeader(
            icon: Icons.restaurant_menu_rounded,
            iconColor: colors.success,
            title: 'Lịch ăn trong ngày',
            textColor: colors.textPrimary,
          ),
          const SizedBox(height: 10),
          for (var mealIndex = 0; mealIndex < day.meals.length; mealIndex++)
            _mealFields(colors, isLight, dayIndex, mealIndex),
          OutlinedButton.icon(
            onPressed: _busy || day.meals.length >= 12
                ? null
                : () => setState(() => day.meals.add(_MealDraft())),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.success,
              backgroundColor: colors.metricPanelBg,
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: colors.metricPanelBorder),
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

  Widget _exerciseFields(
    MetaGymColors colors,
    bool isLight,
    int dayIndex,
    int exerciseIndex,
  ) {
    final day = _days[dayIndex];
    final draft = day.exercises[exerciseIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.metricPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bài tập ${exerciseIndex + 1}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (day.exercises.length > 1)
                IconButton(
                  tooltip: 'Xóa bài tập',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          day.exercises.removeAt(exerciseIndex).dispose();
                        }),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
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
            dropdownColor: isLight ? colors.surface : colors.overlayGlass,
            iconEnabledColor: colors.textSecondary,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(colors, labelText: 'Bài tập'),
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
                  style: _fieldTextStyle(colors),
                  decoration: _inputDecoration(colors, labelText: 'Số hiệp'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: Key('exercise-reps-$dayIndex-$exerciseIndex'),
                  controller: draft.reps,
                  style: _fieldTextStyle(colors),
                  decoration: _inputDecoration(colors, labelText: 'Số lần lặp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.duration,
            keyboardType: TextInputType.number,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(
              colors,
              labelText: 'Thời lượng (giây)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealFields(
    MetaGymColors colors,
    bool isLight,
    int dayIndex,
    int mealIndex,
  ) {
    final draft = _days[dayIndex].meals[mealIndex];
    return Container(
      key: Key('day-meal-$dayIndex-$mealIndex'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.metricPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bữa ăn ${mealIndex + 1}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xóa bữa ăn',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _days[dayIndex].meals.removeAt(mealIndex).dispose();
                      }),
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: draft.mealType,
            isExpanded: true,
            dropdownColor: isLight ? colors.surface : colors.overlayGlass,
            iconEnabledColor: colors.textSecondary,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(colors, labelText: 'Loại bữa'),
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
          // Keep TextField order (0: time, 1: title, 2: notes) for test selectors
          TextField(
            controller: draft.time,
            keyboardType: TextInputType.datetime,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(
              colors,
              labelText: 'Giờ ăn (HH:mm, tùy chọn)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.title,
            maxLength: 120,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(
              colors,
              labelText: 'Món ăn / thực đơn',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.notes,
            maxLength: 2000,
            maxLines: 2,
            style: _fieldTextStyle(colors),
            decoration: _inputDecoration(
              colors,
              labelText: 'Hướng dẫn ăn uống',
            ),
          ),
        ],
      ),
    );
  }
}

class _FormDayChip extends StatelessWidget {
  const _FormDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(999);

    return Material(
      color: selected
          ? (isLight
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.14)
                : colors.chipActiveBg)
          : colors.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : colors.metricPanelBorder,
          width: selected ? 1.2 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? (isLight ? colors.primaryText : colors.chipActiveText)
                    : colors.textSecondary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.icon,
    required this.title,
    required this.textColor,
    this.svgAsset,
    this.iconColor = MetaGymTheme.brandOrange,
  });

  final IconData icon;
  final String title;
  final Color textColor;
  final String? svgAsset;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (svgAsset != null)
          MetaGymIcon(svgAsset!, size: 18, color: iconColor)
        else
          Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
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
