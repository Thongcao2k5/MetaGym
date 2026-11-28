import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_schedule_calendar.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/nutrition_tracking_page.dart';
import 'package:provider/provider.dart';

/// Dedicated read-only Member page for Coach's 7-day Nutrition & Meal Plan,
/// reusing the shared Week/Month Hero Calendar from `Lịch tập của tôi`.
class MemberCoachNutritionPage extends StatefulWidget {
  const MemberCoachNutritionPage({
    this.apiClient,
    this.coachingService,
    this.nutritionService,
    this.relationshipId,
    super.key,
  });

  final ApiClient? apiClient;
  final MemberCoachingService? coachingService;
  final MemberNutritionService? nutritionService;
  final String? relationshipId;

  @override
  State<MemberCoachNutritionPage> createState() =>
      _MemberCoachNutritionPageState();
}

class _MemberCoachNutritionPageState extends State<MemberCoachNutritionPage> {
  static const _mealGroups = [
    ('BREAKFAST', 'Bữa sáng', MetaGymIcons.mealBreakfast, Icons.wb_sunny_outlined),
    ('LUNCH', 'Bữa trưa', MetaGymIcons.mealLunch, Icons.light_mode_outlined),
    ('DINNER', 'Bữa tối', MetaGymIcons.mealDinner, Icons.nightlight_outlined),
    ('SNACK', 'Bữa phụ', MetaGymIcons.mealSnack, Icons.local_cafe_outlined),
  ];

  bool _initialized = false;
  bool _loading = true;
  bool _paused = false;
  String? _error;
  String? _coachName;
  CoachRecord? _mealPlan;
  List<CoachRecord> _archivedPlans = const [];
  NutritionGuide? _fallbackGuide;

  DateTime _selectedDate = metaGymDateOnly(DateTime.now());
  MetaGymCalendarMode _calendarMode = MetaGymCalendarMode.week;

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  MetaGymColors get _colors => MetaGymColors.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  T? _optional<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final apiClient = widget.apiClient ?? _optional<ApiClient>();
    final coachingService =
        widget.coachingService ?? _optional<MemberCoachingService>();
    final nutritionService =
        widget.nutritionService ?? _optional<MemberNutritionService>();

    try {
      String? coachName;
      bool paused = false;
      String? activeRelId = widget.relationshipId;

      if (coachingService != null) {
        try {
          final rel = await coachingService.getCurrentRelationship();
          final names = await coachingService.getCoachNames();
          if (rel != null) {
            activeRelId ??= rel.id;
            paused = rel.status == 'PAUSED';
            coachName = rel.coachName?.isNotEmpty == true
                ? rel.coachName
                : names[rel.coachId];
          }
        } catch (_) {
          // Keep meal plan readable if coaching metadata is unavailable.
        }
      }

      List<CoachRecord> plans = const [];
      if (apiClient != null) {
        plans = await CoachV2Api(apiClient).list('/meal-plans/me');
      }

      CoachRecord? selectedPlan;
      if (plans.isNotEmpty) {
        selectedPlan = plans.where((p) {
          final relMatch =
              activeRelId == null || p['relationshipId'] == activeRelId;
          return relMatch && p['status'] == 'ACTIVE';
        }).firstOrNull;
        selectedPlan ??=
            plans.where((p) => p['status'] == 'ACTIVE').firstOrNull;
        selectedPlan ??= plans.first;
      }

      NutritionGuide? fallbackGuide;
      if (selectedPlan == null && nutritionService != null) {
        try {
          final active = await nutritionService.getActive();
          if (active?.status == 'ACTIVE') fallbackGuide = active;
        } catch (_) {}
      }

      if (!mounted) return;
      final archived = plans
          .where(
            (p) =>
                p['id'] != selectedPlan?['id'] && p['status'] == 'ARCHIVED',
          )
          .toList();

      setState(() {
        _coachName = coachName;
        _paused = paused;
        _mealPlan = selectedPlan;
        _archivedPlans = archived;
        _fallbackGuide = fallbackGuide;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được thực đơn.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CoachRecord> _itemsFor(CoachRecord? plan) {
    final raw = plan?['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => CoachRecord.from(e)).toList();
  }

  List<CoachRecord> _itemsForWeekday(CoachRecord? plan, int weekday) =>
      _itemsFor(plan).where((item) => item['day'] == weekday).toList();

  double _kcalForItem(CoachRecord food) {
    final direct = food['kcal'];
    if (direct is num) return direct.toDouble();
    final grams = food['grams'];
    final per100 = food['kcalPer100g'];
    return grams is num && per100 is num ? grams * per100 / 100.0 : 0;
  }

  String _formatNumber(double value) {
    final raw = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final rev = raw.length - i;
      buffer.write(raw[i]);
      if (rev > 1 && rev % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }

  String _weekdayLabel(DateTime date) {
    final weekdayName =
        date.weekday == 7 ? 'Chủ nhật' : 'Thứ ${date.weekday + 1}';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$weekdayName, $d/$m/${date.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PT';
    return parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  void _openTracking() {
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(builder: (_) => const NutritionTrackingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palette;
    final plan = _mealPlan;
    final allItems = _itemsFor(plan);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.brandOrange,
                backgroundColor: _colors.surface,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.paddingOf(context).bottom + 36,
                  ),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 14),
                    if (_loading && plan == null && _fallbackGuide == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 64),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        ),
                      )
                    else if (_error != null)
                      _buildErrorCard()
                    else if (plan == null && _fallbackGuide == null)
                      _buildEmptyCard()
                    else ...[
                      if (_paused) ...[
                        _buildPausedCard(),
                        const SizedBox(height: 12),
                      ],
                      if (plan != null) ...[
                        _buildHeroCard(plan),
                        const SizedBox(height: 12),
                        _buildCalendar(plan, allItems),
                        const SizedBox(height: 16),
                        if (!_paused) ...[
                          _buildSelectedDaySection(plan),
                          const SizedBox(height: 12),
                        ],
                      ] else if (_fallbackGuide != null) ...[
                        _buildLegacyGuideCard(_fallbackGuide!),
                        const SizedBox(height: 12),
                      ],
                      if (_archivedPlans.isNotEmpty) ...[
                        _buildArchivedSection(),
                        const SizedBox(height: 12),
                      ],
                      _buildQuickTrackingCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = _palette;
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.commonBack,
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DINH DƯỠNG COACH',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Thực đơn & Dinh dưỡng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        MetaGymCircleIconButton(
          svgAsset: MetaGymIcons.foodLogAdd,
          icon: Icons.edit_note_rounded,
          tooltip: 'Nhật ký dinh dưỡng',
          onTap: _openTracking,
        ),
      ],
    );
  }

  Widget _buildHeroCard(CoachRecord plan) {
    final palette = _palette;
    final status = _paused
        ? 'Tạm khóa'
        : plan['status'] == 'ARCHIVED'
        ? 'Đã lưu trữ'
        : 'Đang áp dụng';
    final statusColor = _paused
        ? palette.warning
        : plan['status'] == 'ARCHIVED'
        ? palette.reflection
        : palette.success;
    final note = (plan['content'] as String? ?? '').trim();

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: palette.success.withValues(alpha: 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(
                  MetaGymIcons.nutritionCoachPlan,
                  size: 20,
                  fallbackIcon: Icons.restaurant_menu_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['title'] as String? ?? 'Thực đơn của Coach',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (_coachName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: MetaGymTheme.coachAvatarBackground,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _initials(_coachName!),
                              style: const TextStyle(
                                color: MetaGymTheme.coachAvatarForeground,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _coachName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(status, statusColor),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.metricPanelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.metricPanelBorder),
              ),
              child: Text(
                note,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar(CoachRecord plan, List<CoachRecord> allItems) {
    final palette = _palette;
    final dayItems = _itemsForWeekday(plan, _selectedDate.weekday);
    final dayKcal =
        dayItems.fold<double>(0, (sum, item) => sum + _kcalForItem(item));
    final activeMealTypes =
        dayItems.map((e) => e['meal']).whereType<String>().toSet().length;
    final configuredWeekdays =
        allItems.map((e) => e['day']).whereType<int>().toSet().length;

    return MetaGymScheduleCalendar(
      selectedDate: _selectedDate,
      mode: _calendarMode,
      onSelectDate: (date) => setState(() => _selectedDate = date),
      onModeChanged: (mode) => setState(() => _calendarMode = mode),
      badgeCountForDay: (day) {
        final items = _itemsForWeekday(plan, day.weekday);
        return items.map((e) => e['meal']).toSet().length.clamp(0, 3);
      },
      badgeColorForDay: (_) => palette.success,
      stats: [
        MetaGymCalendarStat(
          label: 'Calo ngày',
          value: dayKcal > 0 ? '${_formatNumber(dayKcal)} kcal' : '—',
          accent: palette.primaryText,
        ),
        MetaGymCalendarStat(
          label: 'Số bữa',
          value: '$activeMealTypes bữa',
          accent: palette.success,
        ),
        MetaGymCalendarStat(
          label: 'Lịch tuần',
          value: '$configuredWeekdays/7',
          accent: palette.reflection,
        ),
      ],
    );
  }

  Widget _buildSelectedDaySection(CoachRecord plan) {
    final palette = _palette;
    final dayItems = _itemsForWeekday(plan, _selectedDate.weekday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _weekdayLabel(_selectedDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _statusPill(
              '${dayItems.length} món · Lặp hằng tuần',
              palette.success,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dayItems.isEmpty)
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 22,
                  color: palette.reflection,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa có món cho ngày này',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coach chưa thêm món ăn vào thực đơn ${_selectedDate.weekday == 7 ? 'Chủ nhật' : 'Thứ ${_selectedDate.weekday + 1}'}.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (final group in _mealGroups)
            ..._buildMealCardIfRelevant(group, dayItems),
      ],
    );
  }

  List<Widget> _buildMealCardIfRelevant(
    (String, String, String, IconData) group,
    List<CoachRecord> dayItems,
  ) {
    final foods = dayItems.where((item) => item['meal'] == group.$1).toList();
    // Always show 3 main meals; show SNACK only when Coach added items for it.
    if (group.$1 == 'SNACK' && foods.isEmpty) return const [];
    return [
      _buildMealGroupCard(group.$2, group.$3, group.$4, foods),
      const SizedBox(height: 10),
    ];
  }

  Widget _buildMealGroupCard(
    String title,
    String svgAsset,
    IconData fallbackIcon,
    List<CoachRecord> foods,
  ) {
    final palette = _palette;
    final total =
        foods.fold<double>(0, (sum, item) => sum + _kcalForItem(item));
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.success.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(
                  svgAsset,
                  size: 18,
                  fallbackIcon: fallbackIcon,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (foods.isNotEmpty && total > 0)
                _statusPill('${_formatNumber(total)} kcal', palette.success),
            ],
          ),
          const SizedBox(height: 10),
          if (foods.isEmpty)
            Text(
              'Chưa có món trong bữa này',
              style: TextStyle(color: palette.textWarmMuted, fontSize: 13),
            )
          else
            for (var i = 0; i < foods.length; i++) ...[
              if (i > 0)
                Divider(
                  color: palette.borderSolid.withValues(alpha: 0.7),
                  height: 16,
                ),
              _buildFoodRow(foods[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildFoodRow(CoachRecord food) {
    final palette = _palette;
    final name = food['foodName'] as String? ?? 'Thực phẩm';
    final grams = food['grams'];
    final kcal = _kcalForItem(food);
    final notes = (food['notes'] as String? ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              [
                if (grams != null) '$grams g',
                if (kcal > 0) '${_formatNumber(kcal)} kcal',
              ].join(' · '),
              style: TextStyle(
                color: palette.textWarmMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            notes,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLegacyGuideCard(NutritionGuide guide) {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymSvgIcon(
                MetaGymIcons.nutritionCoachPlan,
                size: 20,
                fallbackIcon: Icons.restaurant_menu_rounded,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusPill('Hướng dẫn', palette.success),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            guide.content,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedCard() {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      borderColor: palette.warning.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymSvgIcon(
                MetaGymIcons.settingPrivacyLock,
                size: 20,
                fallbackIcon: Icons.lock_clock_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thực đơn đang tạm khóa',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thực đơn Coach đã thiết kế được giữ lại. Gia hạn gói Gym để tiếp tục áp dụng cùng Coach.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => MetaGymNavigation.pushOnce<void>(
              context,
              MetaGymPageRoute(builder: (_) => const MembershipPage()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(150, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Gia hạn gói tập',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedSection() {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymSvgIcon(
                MetaGymIcons.workoutHistory,
                size: 18,
                fallbackIcon: Icons.history_rounded,
              ),
              const SizedBox(width: 8),
              Text(
                'Thực đơn đã lưu trữ',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final old in _archivedPlans)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                old['title'] as String? ?? 'Thực đơn cũ',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickTrackingCard() {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ghi nhận & đối chiếu bữa ăn',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Theo dõi calo hằng ngày và đối chiếu khẩu phần thực tế với thực đơn từ Coach.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openTracking,
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const MetaGymSvgIcon(
              MetaGymIcons.foodLogAdd,
              size: 18,
              fallbackIcon: Icons.edit_note_rounded,
            ),
            label: const Text(
              'Mở nhật ký dinh dưỡng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu_outlined,
                size: 26,
                color: palette.reflection,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chưa có thực đơn từ Coach',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thực đơn 7 ngày sẽ xuất hiện khi Coach công bố kế hoạch dinh dưỡng dành riêng cho bạn.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _openTracking,
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const MetaGymSvgIcon(
              MetaGymIcons.foodLogAdd,
              size: 18,
              fallbackIcon: Icons.edit_note_rounded,
            ),
            label: const Text(
              'Mở nhật ký dinh dưỡng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 24, color: palette.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const MetaGymSvgIcon(
              MetaGymIcons.commonRefresh,
              size: 18,
              fallbackIcon: Icons.refresh_rounded,
            ),
            label: const Text(
              'Thử lại',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: MetaGymTheme.tabularFigures,
      ),
    ),
  );
}
