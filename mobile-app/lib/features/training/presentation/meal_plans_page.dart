import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

const _meals = {'BREAKFAST': 'Sáng', 'LUNCH': 'Trưa', 'DINNER': 'Tối'};

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
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  String get _path => '/coach/meal-plans/${widget.memberId}';

  @override
  void initState() {
    super.initState();
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
      _foods = foods;
      if (widget.editable && plans.isNotEmpty) {
        _title.text = plans.first['title'] as String? ?? '';
        _items =
            (plans.first['items'] as List? ?? const []).cast<CoachRecord>().toList();
      }
      _loaded = true;
    });
  }

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  MetaGymColors get _colors => MetaGymColors.of(context);

  Future<void> _add() async {
    var day = 1;
    var meal = 'BREAKFAST';
    CoachRecord? food;
    int? grams;
    final item = await MetaGymNavigation.showDialogOnce<CoachRecord>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) {
          final palette = MetaGymTheme.paletteOf(context);
          final colors = MetaGymColors.of(context);
          return AlertDialog(
            backgroundColor: colors.overlayGlass,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.overlayGlassBorder),
            ),
            title: Text(
              'Thêm món',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    dropdownColor: colors.surface,
                    style: TextStyle(color: palette.textPrimary),
                    decoration: _dialogInputDecoration('Ngày'),
                    items: [
                      for (var i = 1; i <= 7; i++)
                        DropdownMenuItem(value: i, child: Text(_day(i))),
                    ],
                    onChanged: (value) => update(() => day = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: meal,
                    dropdownColor: colors.surface,
                    style: TextStyle(color: palette.textPrimary),
                    decoration: _dialogInputDecoration('Bữa'),
                    items: [
                      for (final entry in _meals.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => update(() => meal = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    dropdownColor: colors.surface,
                    style: TextStyle(color: palette.textPrimary),
                    decoration: _dialogInputDecoration('Thực phẩm'),
                    items: [
                      for (final entry in _foods)
                        DropdownMenuItem(
                          value: entry['id'] as String,
                          child: Text(
                            entry['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(
                      () => food =
                          _foods.firstWhere((row) => row['id'] == value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _dialogInputDecoration('Khối lượng (g)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        update(() => grams = int.tryParse(value)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                  minimumSize: const Size(64, 48),
                ),
                child: const Text('Đóng'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.primary,
                  foregroundColor: MetaGymTheme.onPrimary,
                  minimumSize: const Size(88, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed:
                    food == null || grams == null || grams! < 1 || grams! > 10000
                    ? null
                    : () => Navigator.pop(dialog, <String, dynamic>{
                        'day': day,
                        'meal': meal,
                        'foodId': food!['id'],
                        'foodName': food!['name'],
                        'kcalPer100g': food!['kcalPer100g'],
                        'grams': grams,
                      }),
                child: const Text(
                  'Thêm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (mounted && item != null) setState(() => _items.add(item));
  }

  InputDecoration _dialogInputDecoration(String label) {
    final palette = _palette;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
      filled: true,
      fillColor: palette.metricPanelBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.metricPanelBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MetaGymTheme.primary, width: 1.4),
      ),
    );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu thực đơn.')));
    }
  });

  String _details(CoachRecord item) {
    final calories =
        (item['grams'] as num) * (item['kcalPer100g'] as num) / 100;
    return '${item['grams']} g · ${calories.toStringAsFixed(0)} kcal';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final colors = _colors;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? 72 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? 8 : 16,
        title: Text(
          'Thực đơn',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
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
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.primary,
            backgroundColor: colors.surface,
            onRefresh: () => _run(_load),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                16,
                MediaQuery.paddingOf(context).bottom + 32,
              ),
              children: [
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      color: MetaGymTheme.primary,
                      backgroundColor: palette.surfaceRaised,
                    ),
                  ),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.error.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      children: [
                        MetaGymSvgIcon(MetaGymIcons.stateError, size: 20, fallbackIcon: Icons.error_outline_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: palette.error,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_loaded && widget.editable) ...[
                  _level1Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 19, fallbackIcon: Icons.restaurant_menu_rounded),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Thiết lập thực đơn 7 ngày',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _title,
                          enabled: !_busy,
                          maxLength: 150,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _dialogInputDecoration('Tên thực đơn'),
                        ),
                        if (_foods.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              'Danh mục chưa có thực phẩm đang sử dụng.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        for (final (index, item) in _items.indexed) ...[
                          Divider(
                            color: palette.borderSolid.withValues(alpha: 0.7),
                            height: 14,
                          ),
                          Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['foodName'] as String,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: Text(
                                '${_day(item['day'] as int)} · ${_meals[item['meal']]} · ${_details(item)}',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12.5,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Bỏ món',
                                icon: MetaGymSvgIcon(
                                  MetaGymIcons.commonDelete,
                                  fallbackIcon: Icons.delete_outline_rounded,
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _items.removeAt(index)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _busy || _foods.isEmpty || _items.length >= 210
                              ? null
                              : _add,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            backgroundColor: palette.metricPanelBg,
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(color: palette.metricPanelBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: MetaGymSvgIcon(MetaGymIcons.commonAdd, fallbackIcon: Icons.add_rounded),
                          label: const Text(
                            'Thêm món',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.primary,
                            foregroundColor: MetaGymTheme.onPrimary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const MetaGymSvgIcon(MetaGymIcons.stateSuccess, size: 19, fallbackIcon: Icons.check_rounded),
                          label: const Text(
                            'Lưu thực đơn',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_loaded) ...[
                  if (_plans.isEmpty)
                    _level1Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 26, fallbackIcon: Icons.restaurant_menu_outlined),
                          const SizedBox(height: 10),
                          Text(
                            'Chưa có thực đơn từ Coach.',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Khi Coach thiết kế thực đơn 7 ngày cho bạn, chi tiết từng bữa ăn và lượng calo sẽ hiển thị tại đây.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final plan in _plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: plan['status'] == 'ACTIVE'
                          ? MetaGymHeroGlassCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: _buildPlanTile(plan, isCurrent: true),
                            )
                          : _level1Card(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: _buildPlanTile(plan, isCurrent: false),
                            ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(CoachRecord plan, {required bool isCurrent}) {
    final palette = _palette;
    final badgeColor = isCurrent ? palette.success : palette.reflection;
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 6, bottom: 6),
          initiallyExpanded: isCurrent,
          iconColor: palette.textPrimary,
          collapsedIconColor: palette.textSecondary,
          title: Text(
            plan['title'] as String,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    isCurrent ? 'Hiện tại' : 'Lịch sử',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: _planContent(plan),
        ),
      ),
    );
  }

  List<Widget> _planContent(CoachRecord plan) {
    final palette = _palette;
    final items = (plan['items'] as List? ?? const []).cast<CoachRecord>();
    if (items.isEmpty) {
      return [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.metricPanelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.metricPanelBorder),
          ),
          child: Text(
            plan['content'] as String? ?? 'Chưa có món',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ),
      ];
    }
    return [
      for (var day = 1; day <= 7; day++)
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: palette.metricPanelBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: palette.metricPanelBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                iconColor: palette.success,
                collapsedIconColor: palette.textSecondary,
                title: Text(
                  _day(day),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                for (final meal in _meals.entries) ...[
                  Divider(
                    color: palette.borderSolid.withValues(alpha: 0.7),
                    height: 14,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      meal.value,
                      style: TextStyle(
                        color: palette.success,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!items.any(
                    (item) => item['day'] == day && item['meal'] == meal.key,
                  ))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Chưa có món',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  for (final item in items.where(
                    (item) => item['day'] == day && item['meal'] == meal.key,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['foodName'] as String,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _details(item),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12.5,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _level1Card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final colors = _colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.liquidGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.liquidGlassBorder, width: 1.1),
      ),
      child: child,
    );
  }
}
