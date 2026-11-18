import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

const _meals = {
  'BREAKFAST': 'Bữa sáng',
  'LUNCH': 'Bữa trưa',
  'DINNER': 'Bữa tối',
};
const _shortDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _day(int day) => day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}';

class MealPlansPage extends StatefulWidget {
  const MealPlansPage({this.memberId, this.editable = false, super.key});

  final String? memberId;
  final bool editable;

  @override
  State<MealPlansPage> createState() => _MealPlansPageState();
}

class _MealPlansPageState extends State<MealPlansPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  final _title = TextEditingController();
  List<CoachRecord> _plans = [];
  List<CoachRecord> _foods = [];
  List<CoachRecord> _items = [];
  int _selectedDay = 1;
  int _selectedPlanIndex = 0;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  String get _path => '/coach/meal-plans/${widget.memberId}';

  @override
  void initState() {
    super.initState();
    final gymNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    _selectedDay = gymNow.weekday.clamp(1, 7);
    _run(_load);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xử lý được thực đơn.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final memberId = widget.memberId;
    final plans = memberId == null
        ? await _api.list('/meal-plans/me')
        : [await _api.get(_path)];
    final foods = widget.editable
        ? await _api.list('/nutrition-foods')
        : <CoachRecord>[];
    if (!mounted) return;
    setState(() {
      _plans = plans.where((plan) => plan['id'] != null).toList();
      if (_selectedPlanIndex >= _plans.length) _selectedPlanIndex = 0;
      _foods = foods;
      if (widget.editable) {
        _title.text = plans.first['title'] as String? ?? '';
        _items = (plans.first['items'] as List).cast<CoachRecord>().toList();
      }
      _loaded = true;
    });
  }

  Future<void> _add({String initialMeal = 'BREAKFAST'}) async {
    var day = _selectedDay;
    var meal = initialMeal;
    CoachRecord? food = _foods.isNotEmpty ? _foods.first : null;
    int? grams;
    final item = await showModalBottomSheet<CoachRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          final validGrams = grams != null && grams! >= 1 && grams! <= 10000;
          final previewKcal = (food != null && validGrams)
              ? (grams! * ((food!['kcalPer100g'] as num?) ?? 0) / 100).round()
              : null;

          return CoachingOverlaySheet(
            title: 'Thêm món vào thực đơn',
            subtitle: 'Chọn ngày, bữa ăn, thực phẩm và khối lượng (gam)',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: day,
                        isExpanded: true,
                        dropdownColor: MetaGymTheme.elevatedSurface,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: coachingInputDecoration(label: 'Ngày'),
                        items: [
                          for (var i = 1; i <= 7; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                _day(i),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) update(() => day = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: meal,
                        isExpanded: true,
                        dropdownColor: MetaGymTheme.elevatedSurface,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: coachingInputDecoration(label: 'Bữa ăn'),
                        items: [
                          for (final entry in _meals.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) update(() => meal = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: food?['id'] as String?,
                  isExpanded: true,
                  dropdownColor: MetaGymTheme.elevatedSurface,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: coachingInputDecoration(
                    label: 'Thực phẩm',
                    prefixIcon: Icons.restaurant_outlined,
                  ),
                  items: [
                    for (final entry in _foods)
                      DropdownMenuItem(
                        value: entry['id'] as String,
                        child: Text(
                          '${entry['name']} (${entry['kcalPer100g']} kcal/100g)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => update(
                    () => food = _foods.firstWhere((row) => row['id'] == value),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autofocus: true,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 14,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                  decoration: coachingInputDecoration(
                    label: 'Khối lượng (g)',
                    hint: 'VD: 150',
                    prefixIcon: Icons.scale_outlined,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      update(() => grams = int.tryParse(value.trim())),
                ),
                if (previewKcal != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CoachingPill(
                        label: 'Ước tính ~$previewKcal kcal',
                        tone: CoachingPillTone.green,
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CoachingSecondaryButton(
                        label: 'Đóng',
                        expand: true,
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CoachingPrimaryButton(
                        label: 'Thêm món',
                        onPressed: food == null || !validGrams
                            ? null
                            : () =>
                                  Navigator.pop(sheetContext, <String, dynamic>{
                                    'day': day,
                                    'meal': meal,
                                    'foodId': food!['id'],
                                    'foodName': food!['name'],
                                    'kcalPer100g': food!['kcalPer100g'],
                                    'grams': grams,
                                  }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted && item != null) {
      setState(() {
        _items.add(item);
        _selectedDay = item['day'] as int;
      });
    }
  }

  Future<void> _save() => _run(() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nhập tên thực đơn.');
      return;
    }
    await _api.put(_path, {
      'title': title,
      'items': [
        for (final item in _items)
          {
            for (final key in ['day', 'meal', 'foodId', 'grams'])
              key: item[key],
          },
      ],
    });
    await _load();
    if (mounted) {
      showCoachingSnackBar(context, 'Đã lưu thực đơn.');
    }
  });

  double _itemKcal(CoachRecord item) {
    final grams = (item['grams'] as num?) ?? 0;
    final per100 = (item['kcalPer100g'] as num?) ?? 0;
    return grams * per100 / 100.0;
  }

  String _details(CoachRecord item) =>
      '${item['grams']} g · ${_itemKcal(item).toStringAsFixed(0)} kcal';

  double _dayKcal(List<CoachRecord> items, int day) {
    var total = 0.0;
    for (final item in items) {
      if (item['day'] == day) total += _itemKcal(item);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final activePlan = _plans.isNotEmpty ? _plans[_selectedPlanIndex] : null;
    final viewItems = widget.editable
        ? _items
        : ((activePlan?['items'] as List?)?.cast<CoachRecord>() ??
              const <CoachRecord>[]);
    final dayTotalKcal = _dayKcal(viewItems, _selectedDay);
    final selectedDayCount = viewItems
        .where((item) => item['day'] == _selectedDay)
        .length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leadingWidth: canPop ? 68 : null,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: Tooltip(
                      message: 'Back',
                      child: MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: _busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                )
              : null,
          title: Text(
            widget.editable ? 'Thiết kế thực đơn' : 'Thực đơn 7 ngày',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: MetaGymCircleIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Tải lại',
                  onTap: _busy ? null : () => _run(_load),
                ),
              ),
            ),
          ],
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: MetaGymTheme.textPrimary),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              child: !_loaded && _busy
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            color: MetaGymTheme.brandOrange,
                            backgroundColor: MetaGymTheme.cardSurface,
                            onRefresh: () => _run(_load),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                24,
                              ),
                              children: [
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: LinearProgressIndicator(
                                      color: MetaGymTheme.brandOrange,
                                      backgroundColor: MetaGymTheme.cardSurface,
                                    ),
                                  ),
                                if (_error != null) ...[
                                  CoachingErrorBanner(message: _error!),
                                  if (!_loaded) ...[
                                    CoachingSecondaryButton(
                                      label: 'Thử lại',
                                      expand: true,
                                      onPressed: () => _run(_load),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                                if (_loaded &&
                                    !widget.editable &&
                                    _plans.isEmpty)
                                  const MetaGymHeroGlassCard(
                                    padding: EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.restaurant_menu_rounded,
                                          color: MetaGymTheme.success,
                                          size: 26,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Chưa có thực đơn từ Coach.',
                                                style: TextStyle(
                                                  color:
                                                      MetaGymTheme.textPrimary,
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Khi Coach hoàn thiện thực đơn 7 ngày, chi tiết từng bữa sẽ hiển thị tại đây.',
                                                style: TextStyle(
                                                  color: Color(0xFFBEC3CB),
                                                  fontSize: 12.5,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_loaded) ...[
                                  if (!widget.editable &&
                                      _plans.length > 1) ...[
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < _plans.length;
                                            i++
                                          )
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                                bottom: 12,
                                              ),
                                              child: ChoiceChip(
                                                label: Text(
                                                  '${_plans[i]['title']} (${_plans[i]['status'] == 'ACTIVE' ? 'Hiện tại' : 'Lịch sử'})',
                                                ),
                                                selected:
                                                    i == _selectedPlanIndex,
                                                selectedColor: const Color(
                                                  0xFF33201B,
                                                ),
                                                surfaceTintColor:
                                                    Colors.transparent,
                                                checkmarkColor:
                                                    MetaGymTheme.brandOrange,
                                                backgroundColor:
                                                    MetaGymTheme.cardSurface,
                                                side: BorderSide(
                                                  color: i == _selectedPlanIndex
                                                      ? MetaGymTheme.brandOrange
                                                      : MetaGymTheme.cardBorder,
                                                ),
                                                labelStyle: TextStyle(
                                                  color: i == _selectedPlanIndex
                                                      ? MetaGymTheme.textPrimary
                                                      : MetaGymTheme
                                                            .textSecondary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                onSelected: (_) => setState(
                                                  () => _selectedPlanIndex = i,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  _MealSummaryHeroCard(
                                    title: widget.editable
                                        ? (_title.text.trim().isNotEmpty
                                              ? _title.text.trim()
                                              : 'Thực đơn 7 ngày')
                                        : (activePlan?['title'] as String? ??
                                              'Thực đơn 7 ngày'),
                                    statusLabel: widget.editable
                                        ? 'Chế độ Coach'
                                        : (activePlan?['status'] == 'ACTIVE'
                                              ? 'Đang áp dụng'
                                              : 'Lịch sử'),
                                    statusTone:
                                        widget.editable ||
                                            activePlan?['status'] == 'ACTIVE'
                                        ? CoachingPillTone.green
                                        : CoachingPillTone.neutral,
                                    dayLabel: _day(_selectedDay),
                                    dayKcal: dayTotalKcal.round(),
                                    dayItemCount: selectedDayCount,
                                    totalItemCount: viewItems.length,
                                  ),
                                  if (widget.editable) ...[
                                    CoachingGraphiteCard(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TextField(
                                            controller: _title,
                                            enabled: !_busy,
                                            maxLength: 150,
                                            onChanged: (_) => setState(() {}),
                                            style: const TextStyle(
                                              color: MetaGymTheme.textPrimary,
                                              fontSize: 14.5,
                                            ),
                                            decoration: coachingInputDecoration(
                                              label: 'Tên thực đơn',
                                              hint: 'VD: Thực đơn tăng cơ 2.400 kcal',
                                              prefixIcon:
                                                  Icons.edit_note_rounded,
                                            ),
                                          ),
                                          if (_foods.isEmpty) ...[
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Danh mục chưa có thực phẩm đang sử dụng.',
                                              style: TextStyle(
                                                color: MetaGymTheme.warning,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          CoachingCompactAccentButton(
                                            label:
                                                'Thêm món (${_day(_selectedDay)})',
                                            icon: Icons.add_rounded,
                                            expand: true,
                                            onPressed:
                                                _busy ||
                                                    _foods.isEmpty ||
                                                    _items.length >= 210
                                                ? null
                                                : () => _add(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Row(
                                    children: [
                                      for (var d = 1; d <= 7; d++) ...[
                                        if (d > 1) const SizedBox(width: 6),
                                        Expanded(
                                          child: _DayChip(
                                            label: _shortDays[d - 1],
                                            selected: _selectedDay == d,
                                            hasItems: viewItems.any(
                                              (item) => item['day'] == d,
                                            ),
                                            onTap: () => setState(
                                              () => _selectedDay = d,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (!widget.editable && viewItems.isEmpty)
                                    CoachingGraphiteCard(
                                      child: Text(
                                        activePlan?['content'] as String? ??
                                            'Chưa có món nào trong thực đơn.',
                                        style: const TextStyle(
                                          color: MetaGymTheme.textSecondary,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    )
                                  else
                                    for (final meal in _meals.entries)
                                      _MealSlotCard(
                                        mealKey: meal.key,
                                        mealLabel: meal.value,
                                        items: viewItems
                                            .asMap()
                                            .entries
                                            .where(
                                              (e) =>
                                                  e.value['day'] ==
                                                      _selectedDay &&
                                                  e.value['meal'] == meal.key,
                                            )
                                            .toList(),
                                        editable: widget.editable,
                                        busy: _busy,
                                        detailsBuilder: _details,
                                        kcalBuilder: _itemKcal,
                                        onAddMeal:
                                            widget.editable &&
                                                !_busy &&
                                                _foods.isNotEmpty &&
                                                _items.length < 210
                                            ? () => _add(initialMeal: meal.key)
                                            : null,
                                        onRemoveAt: (index) => setState(
                                          () => _items.removeAt(index),
                                        ),
                                      ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_loaded && widget.editable)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            decoration: const BoxDecoration(
                              color: MetaGymTheme.scaffoldBackground,
                              border: Border(
                                top: BorderSide(color: MetaGymTheme.cardBorder),
                              ),
                            ),
                            child: CoachingPrimaryButton(
                              label: _busy ? 'Đang lưu…' : 'Lưu thực đơn',
                              icon: Icons.check_rounded,
                              loading: _busy,
                              onPressed: _busy ? null : _save,
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
}

class _MealSummaryHeroCard extends StatelessWidget {
  const _MealSummaryHeroCard({
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    required this.dayLabel,
    required this.dayKcal,
    required this.dayItemCount,
    required this.totalItemCount,
  });

  final String title;
  final String statusLabel;
  final CoachingPillTone statusTone;
  final String dayLabel;
  final int dayKcal;
  final int dayItemCount;
  final int totalItemCount;

  @override
  Widget build(BuildContext context) {
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CoachingPill(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Năng lượng ($dayLabel)',
                          style: const TextStyle(
                            color: Color(0xFFB7B2AF),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dayKcal kcal',
                          style: const TextStyle(
                            color: MetaGymTheme.success,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetaGymMetricPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Số món trong ngày',
                          style: TextStyle(
                            color: Color(0xFFB7B2AF),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dayItemCount / $totalItemCount món',
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.hasItems,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool hasItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.2)
          : MetaGymTheme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : MetaGymTheme.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? MetaGymTheme.textPrimary
                      : MetaGymTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasItems
                      ? (selected
                            ? MetaGymTheme.brandOrange
                            : MetaGymTheme.success)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.mealKey,
    required this.mealLabel,
    required this.items,
    required this.editable,
    required this.busy,
    required this.detailsBuilder,
    required this.kcalBuilder,
    required this.onRemoveAt,
    this.onAddMeal,
  });

  final String mealKey;
  final String mealLabel;
  final List<MapEntry<int, CoachRecord>> items;
  final bool editable;
  final bool busy;
  final String Function(CoachRecord item) detailsBuilder;
  final double Function(CoachRecord item) kcalBuilder;
  final ValueChanged<int> onRemoveAt;
  final VoidCallback? onAddMeal;

  @override
  Widget build(BuildContext context) {
    final mealKcal = items.fold<double>(
      0,
      (sum, entry) => sum + kcalBuilder(entry.value),
    );
    final mealIcon = switch (mealKey) {
      'BREAKFAST' => Icons.wb_sunny_outlined,
      'LUNCH' => Icons.lunch_dining_outlined,
      _ => Icons.nights_stay_outlined,
    };

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mealIcon, color: MetaGymTheme.success, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mealLabel,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CoachingPill(
                label: '${mealKcal.round()} kcal',
                tone: items.isEmpty
                    ? CoachingPillTone.neutral
                    : CoachingPillTone.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'Chưa có món cho bữa này.',
              style: TextStyle(color: MetaGymTheme.textSecondary, fontSize: 13),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(height: 16, color: MetaGymTheme.cardBorder),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].value['foodName'] as String? ?? 'Thực phẩm',
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detailsBuilder(items[i].value),
                          style: const TextStyle(
                            color: MetaGymTheme.textSecondary,
                            fontSize: 12.5,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (editable)
                    IconButton(
                      tooltip: 'Bỏ món',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: MetaGymTheme.dangerCoral,
                        size: 20,
                      ),
                      onPressed: busy ? null : () => onRemoveAt(items[i].key),
                    ),
                ],
              ),
            ],
          if (onAddMeal != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddMeal,
                style: TextButton.styleFrom(
                  foregroundColor: MetaGymTheme.brandOrange,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Thêm vào $mealLabel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
