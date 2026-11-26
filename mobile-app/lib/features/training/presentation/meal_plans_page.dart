import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';

const Map<String, String> _kMealLabels = <String, String>{
  'BREAKFAST': 'Bữa sáng',
  'LUNCH': 'Bữa trưa',
  'DINNER': 'Bữa tối',
  'SNACK': 'Bữa phụ',
};

const List<String> _kMainMealOrder = <String>[
  'BREAKFAST',
  'LUNCH',
  'DINNER',
  'SNACK',
];

String _dayFull(int day) => day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}';

String _dayShort(int day) => day == 7 ? 'CN' : 'T${day + 1}';

String _mealAsset(String mealType) => switch (mealType) {
  'BREAKFAST' => MetaGymIcons.mealBreakfast,
  'LUNCH' => MetaGymIcons.mealLunch,
  'DINNER' => MetaGymIcons.mealDinner,
  _ => MetaGymIcons.mealSnack,
};

num _itemCalories(CoachRecord item) {
  final grams = (item['grams'] as num?) ?? 0;
  final kcalPer100 = (item['kcalPer100g'] as num?) ?? 0;
  return grams * kcalPer100 / 100;
}

class MealPlansPage extends StatefulWidget {
  const MealPlansPage({
    this.memberId,
    this.memberName,
    this.editable = false,
    this.apiClient,
    this.previewMode = false,
    this.initialPlans,
    this.initialFoods,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final String? memberId;
  final String? memberName;
  final bool editable;
  final ApiClient? apiClient;
  final bool previewMode;
  final List<CoachRecord>? initialPlans;
  final List<CoachRecord>? initialFoods;
  final bool useSolidGlassFallback;

  @override
  State<MealPlansPage> createState() => _MealPlansPageState();
}

class _MealPlansPageState extends State<MealPlansPage> {
  final TextEditingController _title = TextEditingController();
  ApiClient? _client;
  CoachV2Api? _api;
  bool _initialized = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _client = widget.apiClient ?? optionalProvider<ApiClient>(context);
    if (_client != null) {
      _api = CoachV2Api(_client!);
    }

    if (widget.initialPlans != null) {
      _applyPlans(widget.initialPlans!, widget.initialFoods ?? const []);
      return;
    }

    if (widget.previewMode || _api == null) {
      if (widget.previewMode) {
        _applyPlans(_demoPlans(), _demoFoods());
      } else {
        setState(() {
          _loaded = true;
          _error = 'Chế độ xem cần kết nối máy chủ.';
        });
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run(_load);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<CoachRecord> _demoFoods() => const [
    {'id': 'f-1', 'name': 'Yến mạch nguyên hạt + Sữa', 'kcalPer100g': 100},
    {'id': 'f-2', 'name': 'Ức gà áp chảo', 'kcalPer100g': 165},
    {'id': 'f-3', 'name': 'Cá hồi phi lê + Khoai lang', 'kcalPer100g': 224},
    {'id': 'f-4', 'name': 'Sữa chua Hy Lạp không đường', 'kcalPer100g': 90},
  ];

  List<CoachRecord> _demoPlans() => [
    {
      'id': 'mp-demo-1',
      'title': 'Thực đơn Tăng cơ giảm mỡ · Tuần 4',
      'status': 'ACTIVE',
      'items': [
        {
          'day': 1,
          'meal': 'BREAKFAST',
          'foodId': 'f-1',
          'foodName': 'Yến mạch nguyên hạt + Sữa tách béo',
          'kcalPer100g': 160,
          'grams': 200,
        },
        {
          'day': 1,
          'meal': 'LUNCH',
          'foodId': 'f-2',
          'foodName': 'Ức gà áp chảo',
          'kcalPer100g': 165,
          'grams': 200,
        },
        {
          'day': 1,
          'meal': 'DINNER',
          'foodId': 'f-3',
          'foodName': 'Cá hồi phi lê nướng + Khoai lang',
          'kcalPer100g': 224,
          'grams': 380,
        },
        {
          'day': 2,
          'meal': 'BREAKFAST',
          'foodId': 'f-4',
          'foodName': 'Bánh mì nguyên cám + Trứng ốp la',
          'kcalPer100g': 230,
          'grams': 220,
        },
      ],
    },
  ];

  void _applyPlans(List<CoachRecord> plans, List<CoachRecord> foods) {
    final validPlans = plans.where((plan) => plan['id'] != null).toList();
    setState(() {
      _plans = validPlans;
      _foods = foods;
      _selectedPlanIndex = 0;
      if (widget.editable && plans.isNotEmpty) {
        _title.text = plans.first['title'] as String? ?? '';
        _items = (plans.first['items'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (!widget.editable && validPlans.isNotEmpty) {
        final activeIdx = validPlans.indexWhere((p) => p['status'] == 'ACTIVE');
        _selectedPlanIndex = activeIdx >= 0 ? activeIdx : 0;
      }
      _loaded = true;
    });
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
    if (_api == null) return;
    final memberId = widget.memberId;
    final plans = memberId == null
        ? await _api!.list('/meal-plans/me')
        : [await _api!.get(_path)];
    final foods = widget.editable
        ? await _api!.list('/nutrition-foods')
        : <CoachRecord>[];
    if (!mounted) return;
    _applyPlans(plans, foods);
  }

  Future<void> _add() async {
    var day = _selectedDay;
    var meal = 'LUNCH';
    CoachRecord? food = _foods.isNotEmpty ? _foods.first : null;
    int? grams;
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final item = await showModalBottomSheet<CoachRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? colors.surface : colors.overlayGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MetaGymTheme.radiusGlassDock),
        ),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          final kcalPer100 = (food?['kcalPer100g'] as num?) ?? 0;
          final estimatedKcal = grams == null
              ? null
              : (grams! * kcalPer100 / 100).round();

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thêm món vào thực đơn',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      MetaGymCircleIconButton(
                        svgAsset: MetaGymIcons.commonClose,
                        icon: Icons.close_rounded,
                        tooltip: 'Đóng',
                        onTap: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: day,
                          isExpanded: true,
                          dropdownColor: isLight
                              ? colors.surface
                              : colors.overlayGlass,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: _fieldDecoration(colors, 'Ngày'),
                          items: [
                            for (var i = 1; i <= 7; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  _dayFull(i),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              update(() => day = value ?? day),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: meal,
                          isExpanded: true,
                          dropdownColor: isLight
                              ? colors.surface
                              : colors.overlayGlass,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: _fieldDecoration(colors, 'Bữa ăn'),
                          items: [
                            for (final entry in _kMealLabels.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              update(() => meal = value ?? meal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: food?['id'] as String?,
                    isExpanded: true,
                    dropdownColor: isLight
                        ? colors.surface
                        : colors.overlayGlass,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: _fieldDecoration(colors, 'Thực phẩm (Catalog)'),
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
                      () =>
                          food = _foods.firstWhere((row) => row['id'] == value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _fieldDecoration(
                      colors,
                      'Khối lượng (gram)',
                      suffixText: estimatedKcal == null
                          ? null
                          : '~$estimatedKcal kcal',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        update(() => grams = int.tryParse(value.trim())),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CoachingSecondaryButton(
                          label: 'Đóng',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.primary,
                            foregroundColor: MetaGymTheme.onPrimary,
                            minimumSize: const Size(88, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                          ),
                          onPressed:
                              food == null ||
                                  grams == null ||
                                  grams! < 1 ||
                                  grams! > 10000
                              ? null
                              : () => Navigator.pop(
                                  sheetContext,
                                  <String, dynamic>{
                                    'day': day,
                                    'meal': meal,
                                    'foodId': food!['id'],
                                    'foodName': food!['name'],
                                    'kcalPer100g': food!['kcalPer100g'],
                                    'grams': grams,
                                  },
                                ),
                          child: const Text(
                            'Thêm món',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted && item != null) {
      setState(() {
        _items.add(item);
        final itemDay = item['day'] as int?;
        if (itemDay != null && itemDay >= 1 && itemDay <= 7) {
          _selectedDay = itemDay;
        }
      });
    }
  }

  InputDecoration _fieldDecoration(
    MetaGymColors colors,
    String label, {
    String? suffixText,
  }) => InputDecoration(
    labelText: label,
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      color: MetaGymTheme.brandOrange,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
    filled: true,
    fillColor: colors.metricPanelBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.metricPanelBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.metricPanelBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.5),
    ),
  );

  Future<void> _save() => _run(() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nhập tên thực đơn.');
      return;
    }
    if (widget.previewMode || _api == null) {
      if (mounted) {
        showCoachingSnackBar(
          context,
          'Đã lưu Thực đơn 7 ngày (bản xem trước).',
        );
      }
      return;
    }
    await _api!.put(_path, {
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

  String _details(CoachRecord item) {
    final kcalPer100 = (item['kcalPer100g'] as num?) ?? 0;
    final calories = _itemCalories(item).round();
    return '${item['grams']} g · $kcalPer100 kcal/100g · $calories kcal';
  }

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final memberTag = widget.memberName?.trim();
    final eyebrow = widget.editable
        ? (memberTag != null && memberTag.isNotEmpty
              ? '${memberTag.toUpperCase()} · MEAL PLAN'
              : 'MEAL PLAN · COACH')
        : 'DINH DƯỠNG HÀNG TUẦN';

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
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
                  widget.editable ? 'Thiết kế thực đơn' : 'Thực đơn 7 ngày',
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
          if (widget.editable) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              key: const Key('meal-plan-header-add'),
              svgAsset: MetaGymIcons.commonAdd,
              icon: Icons.add_rounded,
              tooltip: 'Thêm món ăn',
              onTap: _busy || _foods.isEmpty || _items.length >= 210
                  ? null
                  : _add,
            ),
          ],
          if (widget.memberId == null) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonRefresh,
              icon: Icons.refresh_rounded,
              tooltip: 'Tải lại',
              onTap: _busy || widget.previewMode || _api == null
                  ? null
                  : () => _run(_load),
            ),
          ],
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
    final hasDock = _loaded && widget.editable;

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
                  _buildHeader(context, colors),
                  Expanded(
                    child: RefreshIndicator(
                      color: MetaGymTheme.primary,
                      backgroundColor: colors.overlayGlass,
                      onRefresh: widget.previewMode || _api == null
                          ? () async {}
                          : () => _run(_load),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          4,
                          gutter,
                          hasDock ? 118 + media.bottom : media.bottom + 36,
                        ),
                        children: [
                          if (_busy)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(
                                color: MetaGymTheme.primary,
                                backgroundColor: colors.metricPanelBg,
                              ),
                            ),
                          if (_error != null)
                            CoachingErrorBanner(message: _error!),
                          if (_loaded && widget.editable)
                            ..._buildCoachEditableBody(colors, isLight)
                          else if (_loaded)
                            ..._buildMemberViewBody(colors, isLight),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasDock)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    12,
                    gutter,
                    media.bottom + 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.canvas.withValues(alpha: 0.0),
                        colors.canvas.withValues(alpha: 0.90),
                        colors.canvas,
                      ],
                      stops: const [0.0, 0.30, 1.0],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CoachingSecondaryButton(
                          label: '+ Chọn món',
                          onPressed:
                              _busy || _foods.isEmpty || _items.length >= 210
                              ? null
                              : _add,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: CoachingPrimaryButton(
                          label: 'Lưu thực đơn',
                          icon: Icons.check_rounded,
                          loading: _busy,
                          onPressed: _busy ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCoachEditableBody(MetaGymColors colors, bool isLight) {
    final activeDaysCount = {for (final item in _items) item['day'] as int?}
        .whereType<int>()
        .length;
    final totalKcal = _items.fold<num>(0, (s, item) => s + _itemCalories(item));
    final avgKcal = activeDaysCount == 0
        ? 0
        : (totalKcal / activeDaysCount).round();
    final mealSlotCount = {
      for (final item in _items) '${item['day']}-${item['meal']}',
    }.length;

    return [
      MetaGymHeroGlassCard(
        useSolidFallback: widget.useSolidGlassFallback,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MetaGymIcon(
                  MetaGymIcons.nutritionCoachPlan,
                  size: 18,
                  color: colors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thực đơn tuần',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const CoachingPill(
                  label: 'Chế độ Coach',
                  tone: CoachingPillTone.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_busy,
              maxLength: 150,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration(colors, 'Tên thực đơn'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MealHeroMetric(
                    value: avgKcal == 0 ? '0' : '~$avgKcal',
                    label: 'TB kcal/ngày',
                    valueColor: MetaGymTheme.brandOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealHeroMetric(
                    value: '$mealSlotCount bữa',
                    label: 'Sáng · Trưa · Tối',
                    valueColor: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealHeroMetric(
                    value: '$activeDaysCount/7',
                    label: 'Ngày T2 – CN',
                    valueColor: colors.success,
                  ),
                ),
              ],
            ),
            if (_foods.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Danh mục chưa có thực phẩm đang sử dụng.',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      ..._buildDaySelectorAndMeals(
        colors: colors,
        isLight: isLight,
        items: _items,
        editable: true,
      ),
    ];
  }

  List<Widget> _buildMemberViewBody(MetaGymColors colors, bool isLight) {
    if (_plans.isEmpty) {
      return [
        MetaGymGlassCard(
          solid: widget.useSolidGlassFallback,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetaGymIcon(
                MetaGymIcons.emptyNutrition,
                size: 28,
                color: colors.reflection,
              ),
              const SizedBox(height: 10),
              Text(
                'Chưa có thực đơn từ Coach.',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Khi Coach thiết kế thực đơn 7 ngày cho bạn, chi tiết từng bữa ăn và lượng calo sẽ hiển thị tại đây.',
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final safeIdx = _selectedPlanIndex.clamp(0, _plans.length - 1);
    final selectedPlan = _plans[safeIdx];
    final isCurrent = selectedPlan['status'] == 'ACTIVE';
    final planItems = (selectedPlan['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final activeDaysCount = {for (final item in planItems) item['day'] as int?}
        .whereType<int>()
        .length;
    final totalKcal = planItems.fold<num>(
      0,
      (s, item) => s + _itemCalories(item),
    );
    final avgKcal = activeDaysCount == 0
        ? 0
        : (totalKcal / activeDaysCount).round();
    final mealSlotCount = {
      for (final item in planItems) '${item['day']}-${item['meal']}',
    }.length;

    return [
      if (_plans.length > 1) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _plans.length; i++)
              _MealDayChip(
                label: _plans[i]['title'] as String? ?? 'Thực đơn ${i + 1}',
                selected: safeIdx == i,
                onTap: () => setState(() => _selectedPlanIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      MetaGymHeroGlassCard(
        useSolidFallback: widget.useSolidGlassFallback,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetaGymIcon(
                        MetaGymIcons.nutritionCoachPlan,
                        size: 18,
                        color: colors.success,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: CoachingPill(
                          label: isCurrent ? 'Đang áp dụng' : 'Lịch sử',
                          tone: isCurrent
                              ? CoachingPillTone.green
                              : CoachingPillTone.info,
                          icon: isCurrent
                              ? Icons.verified_outlined
                              : Icons.history_rounded,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${planItems.length} món',
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              selectedPlan['title'] as String? ?? 'Thực đơn 7 ngày',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MealHeroMetric(
                    value: avgKcal == 0 ? '0' : '~$avgKcal',
                    label: 'TB kcal/ngày',
                    valueColor: MetaGymTheme.brandOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealHeroMetric(
                    value: '$mealSlotCount bữa',
                    label: 'Sáng · Trưa · Tối',
                    valueColor: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealHeroMetric(
                    value: '$activeDaysCount/7',
                    label: 'Ngày T2 – CN',
                    valueColor: colors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (planItems.isEmpty)
        MetaGymGlassCard(
          solid: widget.useSolidGlassFallback,
          padding: const EdgeInsets.all(14),
          child: Text(
            selectedPlan['content'] as String? ?? 'Chưa có món ăn chi tiết.',
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        )
      else
        ..._buildDaySelectorAndMeals(
          colors: colors,
          isLight: isLight,
          items: planItems,
          editable: false,
        ),
    ];
  }

  List<Widget> _buildDaySelectorAndMeals({
    required MetaGymColors colors,
    required bool isLight,
    required List<CoachRecord> items,
    required bool editable,
  }) {
    final dayItems = items
        .where((item) => item['day'] == _selectedDay)
        .toList();
    final dayKcal = dayItems
        .fold<num>(0, (s, item) => s + _itemCalories(item))
        .round();

    final visibleMealKeys = [
      for (final mealKey in _kMainMealOrder)
        if (mealKey != 'SNACK' ||
            dayItems.any((item) => item['meal'] == 'SNACK'))
          mealKey,
    ];

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var d = 1; d <= 7; d++)
            _MealDayChip(
              key: Key('meal-day-tab-$d'),
              label: _dayShort(d),
              selected: _selectedDay == d,
              hasDot: items.any((item) => item['day'] == d),
              onTap: () => setState(() => _selectedDay = d),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              '${_dayFull(_selectedDay)} · $dayKcal kcal',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          if (editable)
            Semantics(
              button: true,
              child: MetaGymTap(
                onTap: _busy || _foods.isEmpty || _items.length >= 210
                    ? null
                    : _add,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    'Thêm món (${_dayShort(_selectedDay)})',
                    style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final mealKey in visibleMealKeys)
        Builder(
          builder: (context) {
            final entries = <({int originalIndex, CoachRecord record})>[];
            for (var i = 0; i < items.length; i++) {
              final row = items[i];
              if (row['day'] == _selectedDay && row['meal'] == mealKey) {
                entries.add((originalIndex: i, record: row));
              }
            }
            final mealKcal = entries
                .fold<num>(0, (s, e) => s + _itemCalories(e.record))
                .round();

            return MetaGymGlassCard(
              solid: widget.useSolidGlassFallback,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MetaGymIcon(_mealAsset(mealKey), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _kMealLabels[mealKey] ?? mealKey,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CoachingPill(
                        label: '$mealKcal kcal',
                        tone: entries.isEmpty
                            ? CoachingPillTone.neutral
                            : CoachingPillTone.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (entries.isEmpty)
                    Text(
                      'Chưa có món ăn cho bữa này.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    )
                  else
                    for (var idx = 0; idx < entries.length; idx++)
                      Container(
                        margin: EdgeInsets.only(
                          bottom: idx == entries.length - 1 ? 0 : 8,
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: colors.metricPanelBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.metricPanelBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entries[idx].record['foodName']
                                            as String? ??
                                        '',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _details(entries[idx].record),
                                    style: TextStyle(
                                      color: colors.textWarmMuted,
                                      fontSize: 12,
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
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _items.removeAt(
                                          entries[idx].originalIndex,
                                        ),
                                      ),
                                icon: MetaGymIcon(
                                  MetaGymIcons.commonDelete,
                                  size: 18,
                                  color: colors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            );
          },
        ),
    ];
  }
}

class _MealHeroMetric extends StatelessWidget {
  const _MealHeroMetric({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymMetricPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealDayChip extends StatelessWidget {
  const _MealDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hasDot = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool hasDot;

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
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (hasDot && !selected) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
