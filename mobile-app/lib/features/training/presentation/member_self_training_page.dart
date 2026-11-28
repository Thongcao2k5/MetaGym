import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:provider/provider.dart';

enum _CalendarMode { week, month }

class _ExerciseDraft {
  _ExerciseDraft({
    required this.id,
    String name = '',
    int? sets,
    String? reps,
  }) : nameController = TextEditingController(text: name),
       setsController = TextEditingController(
         text: sets != null ? '$sets' : '',
       ),
       repsController = TextEditingController(text: reps ?? '');

  final String id;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;

  bool get isCompletelyEmpty =>
      nameController.text.trim().isEmpty &&
      setsController.text.trim().isEmpty &&
      repsController.text.trim().isEmpty;

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
  }
}

class MemberSelfTrainingPage extends StatefulWidget {
  const MemberSelfTrainingPage({
    this.api,
    this.catalog,
    this.iconStore,
    super.key,
  });

  final MemberSelfTrainingApi? api;
  final CatalogService? catalog;
  final SelfTrainingIconStore? iconStore;

  @override
  State<MemberSelfTrainingPage> createState() => _MemberSelfTrainingPageState();
}

class _MemberSelfTrainingPageState extends State<MemberSelfTrainingPage> {
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  late final MemberSelfTrainingApi _api;
  late final SelfTrainingIconStore _iconStore;
  late DateTime _selected = _today;
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, MemberSelfTrainingDay> _plans = {};
  final Map<String, String> _iconKeys = {};
  final List<_ExerciseDraft> _exerciseDrafts = [];
  String? _time;
  String? _selectedIconKey;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _expandedDetails = false;
  bool _ready = false;
  _CalendarMode _mode = _CalendarMode.week;

  DateTime get _today {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(vn.year, vn.month, vn.day);
  }

  bool get _canEdit => !_selected.isBefore(_today);
  String get _selectedKey => _key(_selected);
  MemberSelfTrainingDay? get _plan => _plans[_selectedKey];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _api = widget.api ?? MemberSelfTrainingApi(context.read<ApiClient>());
    _iconStore = widget.iconStore ?? SelfTrainingIconStore();
    _title.addListener(_onDraftTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _onDraftTitleChanged() {
    if (_editing && _selectedIconKey == null && mounted) {
      setState(() {});
    }
  }

  void _clearExerciseDrafts() {
    for (final draft in _exerciseDrafts) {
      draft.nameController.removeListener(_onDraftTitleChanged);
      draft.dispose();
    }
    _exerciseDrafts.clear();
  }

  void _appendExerciseDraft({String? id, String name = '', int? sets, String? reps}) {
    final draft = _ExerciseDraft(
      id: (id != null && id.isNotEmpty)
          ? id
          : 'custom-${DateTime.now().microsecondsSinceEpoch}-${_exerciseDrafts.length}',
      name: name,
      sets: sets,
      reps: reps,
    );
    draft.nameController.addListener(_onDraftTitleChanged);
    _exerciseDrafts.add(draft);
  }

  @override
  void dispose() {
    _title.removeListener(_onDraftTitleChanged);
    _clearExerciseDrafts();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - DateTime.monday));

  List<DateTime> get _visibleDays {
    if (_mode == _CalendarMode.week) {
      final first = _weekStart(_selected);
      return List.generate(7, (index) => first.add(Duration(days: index)));
    }
    final first = _weekStart(DateTime(_selected.year, _selected.month));
    final last = DateTime(_selected.year, _selected.month + 1, 0);
    final count = last.difference(first).inDays + (7 - last.weekday) + 1;
    return List.generate(count, (index) => first.add(Duration(days: index)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final days = _visibleDays;
    try {
      final results = await Future.wait([
        _api.getRange(_key(days.first), _key(days.last)),
        _iconStore.loadAll(),
      ]);
      final plans = results[0] as List<MemberSelfTrainingDay>;
      final storedIcons = results[1] as Map<String, String>;
      if (!mounted) return;
      setState(() {
        _plans
          ..clear()
          ..addEntries(plans.map((plan) => MapEntry(plan.planDate, plan)));
        _iconKeys
          ..clear()
          ..addAll(storedIcons);
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changePeriod(int delta) {
    setState(() {
      _selected = _mode == _CalendarMode.week
          ? _selected.add(Duration(days: 7 * delta))
          : DateTime(_selected.year, _selected.month + delta);
      _editing = false;
      _expandedDetails = false;
    });
    _load();
  }

  void _switchMode(_CalendarMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _editing = false;
      _expandedDetails = false;
    });
    _load();
  }

  void _startEditing() {
    final plan = _plan;
    _title.text = plan?.title ?? '';
    _notes.text = plan?.notes ?? '';
    _time = plan?.startTime;
    _selectedIconKey = _iconKeys[_selectedKey] ?? plan?.iconKey;
    _clearExerciseDrafts();
    if (plan != null && plan.exercises.isNotEmpty) {
      for (final exercise in plan.exercises) {
        _appendExerciseDraft(
          id: exercise.id,
          name: exercise.name,
          sets: exercise.sets,
          reps: exercise.reps,
        );
      }
    } else {
      _appendExerciseDraft();
    }
    setState(() {
      _editing = true;
      _expandedDetails = false;
    });
  }

  void _showWarmSnackBar(String message) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xF0241F1B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            side: BorderSide(
              color: isLight
                  ? palette.borderSolid
                  : MetaGymWarmGlassTokens.cardBorder,
              width: 1.1,
            ),
          ),
        ),
      );
  }

  Future<void> _chooseTime() async {
    final isLight = MetaGymTheme.isLightPalette(context);
    final parts = _time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) => Theme(
        data: isLight
            ? MetaGymTheme.light
            : Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: Colors.white,
                  surface: Color(0xFF2B2622),
                  onSurface: Color(0xFFF7F9FC),
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: const Color(0xF0241F1B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(
                      color: Color(0xA3A79D92),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _time =
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  void _addExerciseDraftRow() {
    if (_exerciseDrafts.length >= 20) {
      _showWarmSnackBar('Tối đa 20 bài tập trong một buổi.');
      return;
    }
    setState(() => _appendExerciseDraft());
  }

  void _removeExerciseDraftRow(int index) {
    if (index < 0 || index >= _exerciseDrafts.length) return;
    setState(() {
      if (_exerciseDrafts.length == 1) {
        _exerciseDrafts.first.nameController.clear();
        _exerciseDrafts.first.setsController.clear();
        _exerciseDrafts.first.repsController.clear();
      } else {
        final removed = _exerciseDrafts.removeAt(index);
        removed.nameController.removeListener(_onDraftTitleChanged);
        removed.dispose();
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      _showWarmSnackBar('Nhập tên buổi tập.');
      return;
    }
    if (_time == null) {
      _showWarmSnackBar('Chọn giờ tập.');
      return;
    }
    final activeDrafts =
        _exerciseDrafts.where((draft) => !draft.isCompletelyEmpty).toList();
    if (activeDrafts.isEmpty) {
      _showWarmSnackBar('Nhập ít nhất một bài tập.');
      return;
    }
    final builtExercises = <SelfTrainingExercise>[];
    for (final draft in activeDrafts) {
      final name = draft.nameController.text.trim();
      final sets = int.tryParse(draft.setsController.text.trim());
      final reps = draft.repsController.text.trim();
      if (name.isEmpty ||
          sets == null ||
          sets < 1 ||
          sets > 99 ||
          reps.isEmpty) {
        _showWarmSnackBar(
          'Nhập đầy đủ tên bài tập, số set (1–99) và số rep.',
        );
        return;
      }
      builtExercises.add(
        SelfTrainingExercise(
          id: draft.id,
          name: name,
          sets: sets,
          reps: reps,
        ),
      );
    }
    setState(() => _saving = true);
    try {
      final saved = await _api.save(
        day: _selectedKey,
        title: _title.text.trim(),
        startTime: _time,
        notes: _notes.text.trim(),
        exercises: builtExercises,
      );
      await _iconStore.setIcon(_selectedKey, _selectedIconKey);
      if (!mounted) return;
      setState(() {
        _plans[_selectedKey] = MemberSelfTrainingDay(
          id: saved.id,
          planDate: saved.planDate,
          title: saved.title,
          startTime: saved.startTime,
          notes: saved.notes,
          iconKey: _selectedIconKey ?? saved.iconKey,
          exercises: saved.exercises,
        );
        if (_selectedIconKey == null || _selectedIconKey!.isEmpty) {
          _iconKeys.remove(_selectedKey);
        } else {
          _iconKeys[_selectedKey] = _selectedIconKey!;
        }
        _editing = false;
        _expandedDetails = false;
      });
      _showWarmSnackBar('Đã lưu lịch tập.');
    } on ApiException catch (error) {
      if (mounted) {
        _showWarmSnackBar(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showWarmSnackBar('Không lưu được lịch tập.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _api.delete(_selectedKey);
      await _iconStore.removeIcon(_selectedKey);
      if (!mounted) return;
      setState(() {
        _plans.remove(_selectedKey);
        _iconKeys.remove(_selectedKey);
        _editing = false;
        _expandedDetails = false;
      });
    } catch (_) {
      if (mounted) {
        _showWarmSnackBar('Không xóa được kế hoạch.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: palette.textPrimary,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MetaGymCircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        titleSpacing: 8,
        title: const Text(
          'Lịch tập của tôi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                _calendar(),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                else if (_error != null)
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palette.error.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.error.withValues(alpha: 0.42),
                                ),
                              ),
                              child: Icon(
                                Icons.cloud_off_rounded,
                                size: 20,
                                color: palette.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                          ),
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    _displayDate(_selected),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_editing) _editPanel() else _summaryPanel(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final days = _visibleDays;
    final period = _mode == _CalendarMode.week
        ? '${days.first.day.toString().padLeft(2, '0')}–'
              '${days.last.day.toString().padLeft(2, '0')}/'
              '${days.last.month.toString().padLeft(2, '0')}/${days.last.year}'
        : 'Tháng ${_selected.month}/${_selected.year}';
    return _panel(
      Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changePeriod(-1),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: palette.textPrimary,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Kỳ trước',
              ),
              Expanded(
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changePeriod(1),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: palette.textPrimary,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Kỳ sau',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _modeButton('Tuần', _CalendarMode.week),
              const SizedBox(width: 8),
              _modeButton('Tháng', _CalendarMode.month),
            ],
          ),
          const SizedBox(height: 14),
          if (_mode == _CalendarMode.month) ...[
            Row(
              children: [
                for (final day in _weekdays)
                  Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isLight
                            ? palette.textSecondary
                            : MetaGymWarmGlassTokens.subtitleMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (_mode == _CalendarMode.week)
            Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 54),
                      child: _dayCell(day, showNumber: false),
                    ),
                  ),
              ],
            )
          else
            Builder(
              builder: (context) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final cellExtent = (48 * textScale.clamp(1.0, 1.5))
                    .ceilToDouble()
                    .clamp(48.0, 84.0)
                    .toDouble();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: cellExtent,
                  ),
                  itemCount: days.length,
                  itemBuilder: (_, index) =>
                      _dayCell(days[index], showNumber: true),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _modeButton(String label, _CalendarMode mode) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _switchMode(mode),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: _mode == mode
              ? (isLight ? palette.chipActiveBg : const Color(0xFF493025))
              : palette.metricPanelBg,
          foregroundColor: _mode == mode
              ? (isLight ? palette.primaryText : Colors.white)
              : palette.textWarmMuted,
          side: BorderSide(
            color: _mode == mode
                ? MetaGymTheme.primary
                : palette.metricPanelBorder,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool showNumber}) {
    final palette = MetaGymTheme.paletteOf(context);
    final key = _key(day);
    final selected = key == _selectedKey;
    final hasPlan = _plans.containsKey(key);
    final outside = showNumber && day.month != _selected.month;
    return MetaGymTap(
      onTap: () {
        final monthChanged =
            day.month != _selected.month || day.year != _selected.year;
        setState(() {
          _selected = day;
          _editing = false;
          _expandedDetails = false;
        });
        if (_mode == _CalendarMode.month && monthChanged) _load();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: MetaGymTheme.stateDurationOf(context),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? MetaGymTheme.primary : palette.metricPanelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? MetaGymTheme.primary : palette.metricPanelBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              showNumber ? '${day.day}' : _weekdays[day.weekday - 1],
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : outside
                    ? palette.textSecondary.withValues(alpha: 0.65)
                    : palette.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasPlan) ...[
              if (showNumber) const SizedBox(height: 4),
              AnimatedContainer(
                duration: MetaGymTheme.stateDurationOf(context),
                curve: Curves.easeOutCubic,
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : palette.success,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryPanel() {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final subtleMuted = isLight
        ? palette.textSecondary
        : MetaGymWarmGlassTokens.subtitleMuted;
    final plan = _plan;
    if (plan == null) {
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chưa có kế hoạch',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chọn bài tập và thời gian cho ngày này.',
              style: TextStyle(color: subtleMuted),
            ),
            if (_canEdit) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                  ),
                ),
                onPressed: _startEditing,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Lên lịch tập'),
              ),
            ],
          ],
        ),
      );
    }

    final focuses = resolveMuscleFocusSet(
      plan.title,
      exerciseNames: plan.exercises.map((e) => e.name).toList(),
      explicitKey: _iconKeys[plan.planDate] ?? plan.iconKey,
    );
    final totalSets = plan.exercises.fold<int>(
      0,
      (sum, item) => sum + (item.sets ?? 0),
    );
    final metaParts = [
      if (plan.startTime != null) 'Bắt đầu ${plan.startTime}',
      '${plan.exercises.length} bài tập',
      if (totalSets > 0) '$totalSets set',
    ];
    final dividerColor = isLight ? palette.borderSolid : const Color(0x14FFFFFF);

    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetaGymTap(
            onTap: () => setState(() => _expandedDetails = !_expandedDetails),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MuscleAnatomyTile(focuses: focuses, width: 58, height: 68),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metaParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (focuses.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? palette.surfaceRaised
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isLight
                                        ? palette.borderSolid
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  summarizeMuscleFocuses(focuses),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLight
                                        ? palette.textSecondary
                                        : const Color(0xFFC9D0DB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Icon(
                            _expandedDetails
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: palette.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_expandedDetails) ...[
            if (plan.exercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: dividerColor, height: 1),
              const SizedBox(height: 10),
              for (var index = 0; index < plan.exercises.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _exerciseSummaryRow(index + 1, plan.exercises[index]),
              ],
            ],
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.notes,
                style: TextStyle(
                  color: isLight
                      ? palette.textSecondary
                      : const Color(0xFFE4DAD1),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],
          if (_canEdit) ...[
            const SizedBox(height: 12),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: palette.metricPanelBg,
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _startEditing,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: palette.primaryText,
                    ),
                    label: const Text('Sửa lịch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: palette.metricPanelBg,
                      foregroundColor: isLight
                          ? palette.error
                          : const Color(0xFFE08C87),
                      side: BorderSide(color: palette.metricPanelBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _saving ? null : _delete,
                    child: const Text('Xóa lịch'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _exerciseSummaryRow(int order, SelfTrainingExercise exercise) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final volume = exercise.volumeLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isLight ? palette.metricPanelBg : const Color(0x5A211E1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight ? palette.metricPanelBorder : const Color(0x45A79D92),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
              ),
            ),
            child: Text(
              '$order',
              style: TextStyle(
                color: isLight ? palette.primaryText : const Color(0xFFFF9676),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (volume != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x20FF5E36),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x52FF5E36), width: 0.9),
              ),
              child: Text(
                volume,
                style: TextStyle(
                  color: isLight
                      ? palette.primaryText
                      : const Color(0xFFFFB29B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Set<MuscleFocus> get _draftInferredFocuses => resolveMuscleFocusSet(
    _title.text,
    exerciseNames: _exerciseDrafts
        .map((item) => item.nameController.text.trim())
        .where((name) => name.isNotEmpty)
        .toList(),
  );

  InputDecoration _warmInputDecoration(
    String label, {
    String? hintText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.metricPanelBorder),
    );
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: palette.metricPanelBg,
      contentPadding: contentPadding,
      labelStyle: TextStyle(color: palette.textWarmMuted),
      hintStyle: TextStyle(
        color: isLight
            ? palette.textSecondary.withValues(alpha: 0.72)
            : const Color(0x8AC8C2BC),
        fontSize: 13.5,
      ),
      floatingLabelStyle: TextStyle(
        color: palette.primaryText,
        fontWeight: FontWeight.w600,
      ),
      counterStyle: TextStyle(
        color: isLight
            ? palette.textSecondary
            : MetaGymWarmGlassTokens.subtitleMuted,
        fontSize: 11,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _exerciseDraftCard(int index, _ExerciseDraft draft) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Container(
      key: ValueKey(draft.id),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isLight ? palette.metricPanelBg : const Color(0x66211E1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight ? palette.metricPanelBorder : const Color(0x55A79D92),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
                  ),
                ),
                child: Text(
                  'Bài #${index + 1}',
                  style: TextStyle(
                    color: isLight
                        ? palette.primaryText
                        : const Color(0xFFFF9676),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('self-training-remove-exercise-$index'),
                tooltip: 'Xóa bài tập',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _saving
                    ? null
                    : () => _removeExerciseDraftRow(index),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: isLight ? palette.error : const Color(0xFFE08C87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            key: Key('self-training-exercise-name-$index'),
            controller: draft.nameController,
            enabled: !_saving,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            decoration: _warmInputDecoration(
              'Tên bài tập',
              hintText: 'VD: Đẩy ngực ngang, Squat...',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('self-training-exercise-sets-$index'),
                  controller: draft.setsController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                  decoration: _warmInputDecoration(
                    'Số set',
                    hintText: 'VD: 4',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: Key('self-training-exercise-reps-$index'),
                  controller: draft.repsController,
                  enabled: !_saving,
                  maxLength: 20,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
                  decoration: _warmInputDecoration(
                    'Số rep',
                    hintText: 'VD: 10 hoặc 8-12',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editPanel() {
    final palette = MetaGymTheme.paletteOf(context);
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            enabled: !_saving,
            maxLength: 120,
            style: TextStyle(color: palette.textPrimary),
            decoration: _warmInputDecoration('Tên buổi tập'),
          ),
          const SizedBox(height: 10),
          CoachingGraphiteCard(
            padding: const EdgeInsets.all(12),
            child: MuscleFocusPicker(
              selectedKey: _selectedIconKey,
              inferredTargets: _draftInferredFocuses,
              onSelected: (value) => setState(() => _selectedIconKey = value),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: palette.metricPanelBg,
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.metricPanelBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              onPressed: _chooseTime,
              icon: Icon(
                Icons.schedule_rounded,
                color: palette.primaryText,
              ),
              label: Text(_time == null ? 'Chọn giờ tập' : 'Bắt đầu $_time'),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bài tập (${_exerciseDrafts.length})',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _exerciseDrafts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _exerciseDraftCard(i, _exerciseDrafts[i]),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('self-training-add-exercise'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: palette.metricPanelBg,
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.metricPanelBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            onPressed: _saving ? null : _addExerciseDraftRow,
            icon: Icon(Icons.add_rounded, color: palette.primaryText),
            label: const Text(
              'Thêm bài tập',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            enabled: !_saving,
            maxLines: 3,
            maxLength: 2000,
            style: TextStyle(color: palette.textPrimary),
            decoration: _warmInputDecoration('Ghi chú (tùy chọn)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Đang lưu…' : 'Lưu kế hoạch'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: palette.textWarmMuted,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _editing = false),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: child,
  );

  String _displayDate(DateTime date) {
    final weekday = date.weekday == 7 ? 'Chủ Nhật' : 'Thứ ${date.weekday + 1}';
    return '$weekday, ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
