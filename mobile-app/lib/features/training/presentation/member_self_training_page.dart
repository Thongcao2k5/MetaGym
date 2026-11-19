import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_library_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:provider/provider.dart';

enum _CalendarMode { week, month }

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
  late final CatalogService _catalog;
  late final SelfTrainingIconStore _iconStore;
  late DateTime _selected = _today;
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, MemberSelfTrainingDay> _plans = {};
  final Map<String, String> _iconKeys = {};
  List<CatalogItem> _exercises = [];
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
    _catalog = widget.catalog ?? context.read<CatalogService>();
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

  @override
  void dispose() {
    _title.removeListener(_onDraftTitleChanged);
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
    _exercises =
        plan?.exercises
            .map(
              (exercise) => CatalogItem(id: exercise.id, name: exercise.name),
            )
            .toList() ??
        [];
    setState(() {
      _editing = true;
      _expandedDetails = false;
    });
  }

  Future<void> _chooseTime() async {
    final parts = _time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked != null && mounted) {
      setState(
        () => _time =
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _pickExercises() async {
    List<CatalogItem> items;
    try {
      items = await _catalog.getExercises();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được Thư viện bài tập.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final selected = _exercises.map((item) => item.id).toSet();
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0241F1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xA3A79D92), width: 1.1),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chọn bài tập',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                            'Thư viện chưa có bài tập.',
                            style: TextStyle(color: Color(0xFFC8C2BC)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return CheckboxListTile(
                              value: selected.contains(item.id),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: item.targetMuscles.isEmpty
                                  ? null
                                  : Text(
                                      item.targetMuscles.join(' · '),
                                      style: const TextStyle(
                                        color: Color(0xFFB8B0A8),
                                        fontSize: 12.5,
                                      ),
                                    ),
                              activeColor: MetaGymTheme.primary,
                              checkColor: Colors.white,
                              onChanged: (checked) => update(() {
                                if (checked == true) {
                                  if (selected.length < 20) {
                                    selected.add(item.id);
                                  }
                                } else {
                                  selected.remove(item.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
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
                      onPressed: () =>
                          Navigator.pop(context, selected.toList()),
                      child: const Text('Xong'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      final byId = {
        for (final item in [..._exercises, ...items]) item.id: item,
      };
      setState(() => _exercises = picked.map((id) => byId[id]!).toList());
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập tên buổi tập.')));
      return;
    }
    if (_time == null || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn giờ và ít nhất một bài tập.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _api.save(
        day: _selectedKey,
        title: _title.text.trim(),
        startTime: _time,
        notes: _notes.text.trim(),
        exerciseIds: _exercises.map((item) => item.id).toList(),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu lịch tập.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được lịch tập.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xóa được kế hoạch.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openExercise(SelfTrainingExercise exercise) async {
    try {
      final matches = await _catalog.getExercises(search: exercise.name);
      final item = matches.where((item) => item.id == exercise.id).firstOrNull;
      if (!mounted) return;
      if (item == null) throw StateError('missing exercise');
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ExerciseDetailPage(item: item)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bài tập này không còn trong thư viện.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
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
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            _calendar(),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: MetaGymTheme.primary),
              )
            else if (_error != null)
              _panel(
                Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                _displayDate(_selected),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (_editing) _editPanel() else _summaryPanel(),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _calendar() {
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
                color: const Color(0xFFF7F9FC),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Kỳ trước',
              ),
              Expanded(
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changePeriod(1),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: const Color(0xFFF7F9FC),
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
                      style: const TextStyle(
                        color: Color(0xFFB8B0A8),
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

  Widget _modeButton(String label, _CalendarMode mode) => Expanded(
    child: OutlinedButton(
      onPressed: () => _switchMode(mode),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: _mode == mode
            ? const Color(0xFF493025)
            : const Color(0x80211E1C),
        foregroundColor: _mode == mode ? Colors.white : const Color(0xFFC8C2BC),
        side: BorderSide(
          color: _mode == mode ? MetaGymTheme.primary : const Color(0x9A8C8176),
        ),
      ),
      child: Text(label),
    ),
  );

  Widget _dayCell(DateTime day, {required bool showNumber}) {
    final key = _key(day);
    final selected = key == _selectedKey;
    final hasPlan = _plans.containsKey(key);
    final outside = showNumber && day.month != _selected.month;
    return InkWell(
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
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? MetaGymTheme.primary : const Color(0x80211E1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? MetaGymTheme.primary : const Color(0x9A8C8176),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              showNumber ? '${day.day}' : _weekdays[day.weekday - 1],
              style: TextStyle(
                color: outside ? const Color(0xFF8E95A5) : Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasPlan) ...[
              if (showNumber) const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : const Color(0xFF2ECC71),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryPanel() {
    final plan = _plan;
    if (plan == null) {
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chưa có kế hoạch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn bài tập và thời gian cho ngày này.',
              style: TextStyle(color: Color(0xFFB8B0A8)),
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
    final metaParts = [
      if (plan.startTime != null) 'Bắt đầu ${plan.startTime}',
      '${plan.exercises.length} bài tập',
    ];

    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
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
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  summarizeMuscleFocuses(focuses),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFC9D0DB),
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
                            color: MetaGymTheme.textSecondary,
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
              const Divider(color: Color(0x14FFFFFF), height: 1),
              const SizedBox(height: 6),
              for (final exercise in plan.exercises)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: MetaGymTheme.textSecondary,
                    ),
                    onTap: () => _openExercise(exercise),
                  ),
                ),
            ],
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.notes,
                style: const TextStyle(
                  color: Color(0xFFE4DAD1),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ],
          if (_canEdit) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0x14FFFFFF), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: const Color(0x80211E1C),
                      foregroundColor: MetaGymTheme.textPrimary,
                      side: BorderSide(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _startEditing,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: MetaGymTheme.brandOrange,
                    ),
                    label: const Text('Sửa lịch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: const Color(0x80211E1C),
                      foregroundColor: const Color(0xFFE08C87),
                      side: const BorderSide(color: Color(0x9A8C8176)),
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

  Set<MuscleFocus> get _draftInferredFocuses => resolveMuscleFocusSet(
    _title.text,
    exerciseNames: _exercises.map((item) => item.name).toList(),
    targetMuscles: _exercises.expand((item) => item.targetMuscles).toList(),
  );

  InputDecoration _warmInputDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: Color(0x9A8C8176)),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0x80211E1C),
      labelStyle: const TextStyle(color: Color(0xFFC8C2BC)),
      floatingLabelStyle: const TextStyle(
        color: MetaGymTheme.brandOrange,
        fontWeight: FontWeight.w600,
      ),
      counterStyle: const TextStyle(color: Color(0xFFB8B0A8), fontSize: 11),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.5),
      ),
    );
  }

  Widget _editPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _title,
          maxLength: 120,
          style: const TextStyle(color: Color(0xFFF7F9FC)),
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
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: const Color(0x80211E1C),
            foregroundColor: const Color(0xFFF7F9FC),
            side: const BorderSide(color: Color(0x9A8C8176)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: _chooseTime,
          icon: const Icon(Icons.schedule_rounded, color: MetaGymTheme.brandOrange),
          label: Text(_time == null ? 'Chọn giờ tập' : 'Bắt đầu $_time'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: const Color(0x80211E1C),
            foregroundColor: const Color(0xFFF7F9FC),
            side: const BorderSide(color: Color(0x9A8C8176)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: _pickExercises,
          icon: const Icon(Icons.add_rounded, color: MetaGymTheme.brandOrange),
          label: Text('Chọn bài tập (${_exercises.length})'),
        ),
        if (_exercises.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final exercise in _exercises)
            Text(
              '• ${exercise.name}',
              style: const TextStyle(color: Colors.white),
            ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          maxLength: 2000,
          style: const TextStyle(color: Color(0xFFF7F9FC)),
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
                foregroundColor: const Color(0xFFC8C2BC),
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

  Widget _panel(Widget child) =>
      MetaGymGlassCard(padding: const EdgeInsets.all(16), child: child);

  String _displayDate(DateTime date) {
    final weekday = date.weekday == 7 ? 'Chủ Nhật' : 'Thứ ${date.weekday + 1}';
    return '$weekday, ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
