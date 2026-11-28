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
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

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
  final Map<String, List<MemberSelfTrainingDay>> _plans = {};
  final Map<String, String> _iconKeys = {};
  final List<_ExerciseDraft> _exerciseDrafts = [];
  final Set<String> _expandedSessionIds = {};
  String? _time;
  String? _selectedIconKey;
  String? _editingSessionId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _ready = false;
  _CalendarMode _mode = _CalendarMode.week;

  DateTime get _today {
    final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(vn.year, vn.month, vn.day);
  }

  bool get _canEdit => !_selected.isBefore(_today);
  String get _selectedKey => _key(_selected);
  List<MemberSelfTrainingDay> get _dayPlans => _plans[_selectedKey] ?? const [];

  void _sortDayPlans(List<MemberSelfTrainingDay> items) {
    items.sort((a, b) {
      final timeCmp = (a.startTime ?? '99:99').compareTo(b.startTime ?? '99:99');
      if (timeCmp != 0) return timeCmp;
      return a.id.compareTo(b.id);
    });
  }

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
      final grouped = <String, List<MemberSelfTrainingDay>>{};
      for (final plan in plans) {
        grouped.putIfAbsent(plan.planDate, () => []).add(plan);
      }
      for (final entry in grouped.values) {
        _sortDayPlans(entry);
      }
      setState(() {
        _plans
          ..clear()
          ..addAll(grouped);
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
      _editingSessionId = null;
      _expandedSessionIds.clear();
    });
    _load();
  }

  void _switchMode(_CalendarMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _editing = false;
      _editingSessionId = null;
      _expandedSessionIds.clear();
    });
    _load();
  }

  void _startEditing([MemberSelfTrainingDay? plan]) {
    _title.text = plan?.title ?? '';
    _notes.text = plan?.notes ?? '';
    _time = plan?.startTime;
    _editingSessionId = plan?.id;
    _selectedIconKey = plan == null
        ? null
        : (_iconKeys[plan.id] ?? _iconKeys[plan.planDate] ?? plan.iconKey);
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
    });
  }

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  bool get _isLight => MetaGymTheme.isLightPalette(context);

  void _showWarmSnackBar(String message) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
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
          backgroundColor: colors.overlayGlass,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
          ),
        ),
      );
  }

  Future<void> _chooseTime() async {
    final parts = _time?.split(':');
    final isLight = MetaGymTheme.isLightPalette(context);
    final colors = MetaGymColors.of(context);
    final palette = MetaGymTheme.paletteOf(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isLight
              ? ColorScheme.light(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: Colors.white,
                  surface: colors.surface,
                  onSurface: palette.textPrimary,
                )
              : ColorScheme.dark(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: Colors.white,
                  surface: const Color(0xFF2B2622),
                  onSurface: palette.textPrimary,
                ),
          dialogTheme: DialogThemeData(
            backgroundColor: colors.overlayGlass,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
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
      final saved = _editingSessionId == null
          ? await _api.createSession(
              day: _selectedKey,
              title: _title.text.trim(),
              startTime: _time,
              notes: _notes.text.trim(),
              exercises: builtExercises,
            )
          : await _api.updateSession(
              id: _editingSessionId!,
              title: _title.text.trim(),
              startTime: _time,
              notes: _notes.text.trim(),
              exercises: builtExercises,
            );
      await _iconStore.setIcon(saved.id, _selectedIconKey);
      if (!mounted) return;
      final normalized = MemberSelfTrainingDay(
        id: saved.id,
        planDate: saved.planDate,
        title: saved.title,
        startTime: saved.startTime,
        notes: saved.notes,
        iconKey: _selectedIconKey ?? saved.iconKey,
        exercises: saved.exercises,
      );
      setState(() {
        final dayList = List<MemberSelfTrainingDay>.from(
          _plans[_selectedKey] ?? const [],
        );
        final existingIdx = dayList.indexWhere((item) => item.id == saved.id);
        if (existingIdx >= 0) {
          dayList[existingIdx] = normalized;
        } else {
          dayList.add(normalized);
        }
        _sortDayPlans(dayList);
        _plans[_selectedKey] = dayList;
        if (_selectedIconKey == null || _selectedIconKey!.isEmpty) {
          _iconKeys.remove(saved.id);
        } else {
          _iconKeys[saved.id] = _selectedIconKey!;
        }
        _editing = false;
        _editingSessionId = null;
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

  Future<void> _delete(MemberSelfTrainingDay plan) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _api.deleteSession(plan.id);
      await _iconStore.removeIcon(plan.id);
      if (!mounted) return;
      setState(() {
        final dayList = List<MemberSelfTrainingDay>.from(
          _plans[plan.planDate] ?? const [],
        )..removeWhere((item) => item.id == plan.id);
        if (dayList.isEmpty) {
          _plans.remove(plan.planDate);
        } else {
          _plans[plan.planDate] = dayList;
        }
        _iconKeys.remove(plan.id);
        _expandedSessionIds.remove(plan.id);
        _editing = false;
        _editingSessionId = null;
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
    final palette = _palette;
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
        title: Text(
          'Lịch tập của tôi',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: _bottomActionDock(),
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
                MediaQuery.paddingOf(context).bottom + (_bottomActionDock() != null ? 104 : 24),
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
                                color: palette.error.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.error.withValues(alpha: 0.40),
                                ),
                              ),
                              child: MetaGymSvgIcon(MetaGymIcons.stateOffline, size: 20, fallbackIcon: Icons.cloud_off_rounded),
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
                          icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _displayDate(_selected),
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!_editing && _dayPlans.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.chipActiveBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: MetaGymTheme.brandOrange.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: Text(
                            '${_dayPlans.length} buổi tập',
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                    ],
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
    final palette = _palette;
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
                icon: const MetaGymSvgIcon(MetaGymIcons.commonChevronLeft, fallbackIcon: Icons.chevron_left_rounded),
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
                icon: const MetaGymSvgIcon(MetaGymIcons.commonChevronRight, fallbackIcon: Icons.chevron_right_rounded),
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
                        color: palette.textSecondary,
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
    final palette = _palette;
    final active = _mode == mode;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _switchMode(mode),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: active
              ? (_isLight ? MetaGymTheme.primary : const Color(0xFF493025))
              : palette.metricPanelBg,
          foregroundColor: active ? Colors.white : palette.textSecondary,
          side: BorderSide(
            color: active ? MetaGymTheme.primary : palette.metricPanelBorder,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool showNumber}) {
    final palette = _palette;
    final key = _key(day);
    final selected = key == _selectedKey;
    final hasPlan = _plans[key]?.isNotEmpty ?? false;
    final outside = showNumber && day.month != _selected.month;
    return MetaGymTap(
      onTap: () {
        final monthChanged =
            day.month != _selected.month || day.year != _selected.year;
        setState(() {
          _selected = day;
          _editing = false;
          _editingSessionId = null;
          _expandedSessionIds.clear();
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
                    ? palette.textSecondary.withValues(alpha: 0.6)
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

  Widget? _bottomActionDock() {
    if (_loading || _error != null || !_canEdit || _editing) return null;
    final palette = _palette;
    final colors = MetaGymColors.of(context);
    final hasPlans = _dayPlans.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _isLight
            ? colors.surface.withValues(alpha: 0.96)
            : const Color(0xEC161920),
        border: Border(
          top: BorderSide(color: palette.borderSolid, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          key: const Key('self-training-bottom-add-session'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: _saving ? null : () => _startEditing(),
          icon: const MetaGymSvgIcon(
            MetaGymIcons.commonAdd,
            size: 19,
            color: Colors.white,
            adaptForLightMode: false,
            fallbackIcon: Icons.add_rounded,
          ),
          label: Text(hasPlans ? 'Thêm buổi tập mới' : 'Lên lịch tập'),
        ),
      ),
    );
  }

  Widget _summaryPanel() {
    final palette = _palette;
    final dayPlans = _dayPlans;
    if (dayPlans.isEmpty) {
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
              _canEdit
                  ? 'Nhấn nút Lên lịch tập bên dưới để tạo buổi tập cho ngày này.'
                  : 'Không có lịch tập cho ngày này.',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < dayPlans.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _sessionSummaryCard(dayPlans[i]),
        ],
      ],
    );
  }

  Widget _sessionSummaryCard(MemberSelfTrainingDay plan) {
    final palette = _palette;
    final expanded = _expandedSessionIds.contains(plan.id);
    final focuses = resolveMuscleFocusSet(
      plan.title,
      exerciseNames: plan.exercises.map((e) => e.name).toList(),
      explicitKey: _iconKeys[plan.id] ?? _iconKeys[plan.planDate] ?? plan.iconKey,
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

    return CoachingGraphiteCard(
      key: Key('self-training-session-card-${plan.id}'),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetaGymTap(
            onTap: () => setState(() {
              if (expanded) {
                _expandedSessionIds.remove(plan.id);
              } else {
                _expandedSessionIds.add(plan.id);
              }
            }),
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
                                  color: palette.metricPanelBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: palette.metricPanelBorder,
                                  ),
                                ),
                                child: Text(
                                  summarizeMuscleFocuses(focuses),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          MetaGymResolvedIcon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            fallbackColor: palette.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            if (plan.exercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                color: palette.borderSolid.withValues(alpha: 0.7),
                height: 1,
              ),
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
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],
          if (_canEdit) ...[
            const SizedBox(height: 12),
            Divider(
              color: palette.borderSolid.withValues(alpha: 0.7),
              height: 1,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('self-training-edit-${plan.id}'),
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
                    onPressed: () => _startEditing(plan),
                    icon: MetaGymSvgIcon(
                      MetaGymIcons.commonEdit,
                      size: 16,
                      fallbackIcon: Icons.edit_outlined,
                    ),
                    label: const Text('Sửa lịch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: Key('self-training-delete-${plan.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: palette.metricPanelBg,
                      foregroundColor: palette.error,
                      side: BorderSide(color: palette.metricPanelBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _saving ? null : () => _delete(plan),
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
    final palette = _palette;
    final volume = exercise.volumeLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.metricPanelBorder, width: 0.9),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.chipActiveBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
              ),
            ),
            child: Text(
              '$order',
              style: TextStyle(
                color: palette.primaryText,
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
                color: palette.chipActiveBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: MetaGymTheme.primary.withValues(alpha: 0.36),
                  width: 0.9,
                ),
              ),
              child: Text(
                volume,
                style: TextStyle(
                  color: palette.primaryText,
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
    final palette = _palette;
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
      labelStyle: TextStyle(color: palette.textSecondary),
      hintStyle: TextStyle(
        color: palette.textSecondary.withValues(alpha: 0.7),
        fontSize: 13.5,
      ),
      floatingLabelStyle: TextStyle(
        color: palette.primaryText,
        fontWeight: FontWeight.w600,
      ),
      counterStyle: TextStyle(color: palette.textSecondary, fontSize: 11),
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
    final palette = _palette;
    return Container(
      key: ValueKey(draft.id),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.metricPanelBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
                  ),
                ),
                child: Text(
                  'Bài #${index + 1}',
                  style: TextStyle(
                    color: palette.primaryText,
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
                icon: MetaGymSvgIcon(MetaGymIcons.commonDelete, size: 19, fallbackIcon: Icons.delete_outline_rounded),
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
    final palette = _palette;
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
              icon: MetaGymSvgIcon(MetaGymIcons.timeClock, fallbackIcon: Icons.schedule_rounded),
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
            icon: MetaGymSvgIcon(MetaGymIcons.commonAdd, fallbackIcon: Icons.add_rounded),
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
                  foregroundColor: palette.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _editing = false;
                        _editingSessionId = null;
                      }),
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
