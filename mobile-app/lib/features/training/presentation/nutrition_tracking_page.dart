import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

import '../data/nutrition_tracking_api.dart';
import 'meal_plans_page.dart';

const _meals = {
  'BREAKFAST': 'Bữa sáng',
  'LUNCH': 'Bữa trưa',
  'DINNER': 'Bữa tối',
  'SNACK': 'Bữa phụ',
};

const _quickMealLabels = [
  'Bữa sáng',
  'Bữa trưa',
  'Bữa tối',
  'Meal trước tập',
  'Meal sau tập',
];

const _customMealPrefix = '[Bữa: ';

({String? mealLabel, String notes}) _parseEntryNotes(String? rawNotes) {
  final text = (rawNotes ?? '').trim();
  if (!text.startsWith(_customMealPrefix)) {
    return (mealLabel: null, notes: text);
  }
  final end = text.indexOf(']');
  if (end <= _customMealPrefix.length) {
    return (mealLabel: null, notes: text);
  }
  final label = text.substring(_customMealPrefix.length, end).trim();
  final rest = text.substring(end + 1).trim();
  return (mealLabel: label.isEmpty ? null : label, notes: rest);
}

String _encodeEntryNotes(String? customMealLabel, String notes) {
  final cleanLabel = (customMealLabel ?? '').trim();
  final cleanNotes = notes.trim();
  if (cleanLabel.isEmpty) return cleanNotes;
  if (cleanNotes.isEmpty) return '$_customMealPrefix$cleanLabel]';
  return '$_customMealPrefix$cleanLabel]\n$cleanNotes';
}

const Map<String, ({double per100g, double perServing})>
_kVietnameseFoodKcal = <String, ({double per100g, double perServing})>{
  'com gao lut': (per100g: 112, perServing: 180),
  'gao lut': (per100g: 112, perServing: 180),
  'com trang': (per100g: 130, perServing: 200),
  'com tam': (per100g: 165, perServing: 550),
  'com ga': (per100g: 170, perServing: 520),
  'com': (per100g: 130, perServing: 200),
  'uc ga': (per100g: 165, perServing: 250),
  'dui ga': (per100g: 195, perServing: 240),
  'thit ga': (per100g: 180, perServing: 250),
  'thit bo': (per100g: 250, perServing: 300),
  'thit heo': (per100g: 242, perServing: 290),
  'thit lon': (per100g: 242, perServing: 290),
  'suon nuong': (per100g: 260, perServing: 320),
  'ca hoi': (per100g: 208, perServing: 280),
  'ca ngu': (per100g: 132, perServing: 180),
  'ca basa': (per100g: 120, perServing: 180),
  'ca thu': (per100g: 205, perServing: 260),
  'tom': (per100g: 99, perServing: 140),
  'muc': (per100g: 92, perServing: 140),
  'trung ga': (per100g: 155, perServing: 78),
  'trung vit': (per100g: 185, perServing: 130),
  'trung': (per100g: 155, perServing: 78),
  'pho bo': (per100g: 115, perServing: 450),
  'pho ga': (per100g: 105, perServing: 400),
  'pho': (per100g: 110, perServing: 430),
  'bun bo': (per100g: 125, perServing: 520),
  'bun cha': (per100g: 145, perServing: 500),
  'bun rieu': (per100g: 105, perServing: 420),
  'bun thit nuong': (per100g: 140, perServing: 480),
  'bun': (per100g: 110, perServing: 220),
  'hu tieu': (per100g: 115, perServing: 420),
  'mien ga': (per100g: 95, perServing: 350),
  'mi tom': (per100g: 450, perServing: 350),
  'banh mi': (per100g: 265, perServing: 350),
  'banh cuon': (per100g: 140, perServing: 320),
  'xoi': (per100g: 210, perServing: 380),
  'chao': (per100g: 70, perServing: 260),
  'khoai lang': (per100g: 86, perServing: 130),
  'yen mach': (per100g: 389, perServing: 155),
  'chuoi': (per100g: 89, perServing: 105),
  'tao': (per100g: 52, perServing: 95),
  'qua bo': (per100g: 160, perServing: 240),
  'trai bo': (per100g: 160, perServing: 240),
  'sua tuoi': (per100g: 62, perServing: 150),
  'sua dau nanh': (per100g: 54, perServing: 130),
  'sua chua': (per100g: 65, perServing: 100),
  'whey': (per100g: 400, perServing: 120),
  'dau phu': (per100g: 76, perServing: 115),
  'dau hu': (per100g: 76, perServing: 115),
  'bong cai xanh': (per100g: 34, perServing: 50),
  'salad': (per100g: 40, perServing: 120),
  'rau xanh': (per100g: 25, perServing: 50),
  'rau': (per100g: 25, perServing: 50),
  'dau phong': (per100g: 567, perServing: 170),
  'hanh nhan': (per100g: 579, perServing: 175),
  'ca phe sua': (per100g: 110, perServing: 180),
  'tra sua': (per100g: 95, perServing: 320),
  'nuoc cam': (per100g: 45, perServing: 110),
};

const Set<String> _kServingUnits = <String>{
  'phần',
  'cái',
  'quả',
  'bát',
  'tô',
  'ly',
  'muỗng',
  'miếng',
  'hộp',
  'gói',
  'chai',
  'lon',
  'ổ',
  'dĩa',
  'đĩa',
  'chén',
};

String _normalizeFoodKey(String input) {
  const accented =
      'àáạảãâầấậẩẫăằắặẳẵ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ'
      'èéẹẻẽêềếệểễ'
      'ÈÉẸẺẼÊỀẾỆỂỄ'
      'ìíịỉĩÌÍỊỈĨ'
      'òóọỏõôồốộổỗơờớợởỡ'
      'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ'
      'ùúụủũưừứựửữ'
      'ÙÚỤỦŨƯỪỨỰỬỮ'
      'ỳýỵỷỹỲÝỴỶỸ'
      'đĐ';
  const plain =
      'aaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'eeeeeeeeeee'
      'iiiiiiiiii'
      'ooooooooooooooooo'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'uuuuuuuuuuu'
      'yyyyyyyyyy'
      'dd';
  final buffer = StringBuffer();
  for (final rune in input.trim().runes) {
    final ch = String.fromCharCode(rune);
    final idx = accented.indexOf(ch);
    buffer.write(idx >= 0 ? plain[idx] : ch.toLowerCase());
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Ước tính lượng calo (kcal) cho món ăn người dùng tự nhập dựa trên danh mục
/// hiện có và bảng thực phẩm phổ biến. Trả về `null` nếu chưa đủ dữ liệu khớp.
double? estimateCustomFoodKcal({
  required String name,
  required double quantity,
  required String unit,
  List<NutritionRecord> catalogFoods = const [],
}) {
  if (!quantity.isFinite || quantity < 0.01 || quantity > 10000) return null;
  final normName = _normalizeFoodKey(name);
  if (normName.isEmpty) return null;
  final normUnit = unit.trim().toLowerCase();

  if (normUnit == 'g' || normUnit == 'ml') {
    String? bestCatalogKey;
    double? bestPer100g;
    for (final food in catalogFoods) {
      final rawFoodName = (food['name'] ?? '').toString();
      final normFood = _normalizeFoodKey(rawFoodName);
      final per100g = food['kcalPer100g'];
      if (normFood.isEmpty || per100g is! num || per100g <= 0) continue;
      final matches =
          normName == normFood ||
          ' $normName '.contains(' $normFood ') ||
          (normName.length >= 4 && normFood.contains(normName));
      if (matches &&
          (bestCatalogKey == null || normFood.length > bestCatalogKey.length)) {
        bestCatalogKey = normFood;
        bestPer100g = per100g.toDouble();
      }
    }
    if (bestPer100g != null) {
      return (bestPer100g * quantity) / 100.0;
    }
  }

  String? bestKey;
  ({double per100g, double perServing})? bestMatch;
  final padded = ' $normName ';
  for (final entry in _kVietnameseFoodKcal.entries) {
    final kw = entry.key;
    final matches =
        normName == kw ||
        padded.contains(' $kw ') ||
        (kw.length >= 4 && normName.contains(kw));
    if (matches && (bestKey == null || kw.length > bestKey.length)) {
      bestKey = kw;
      bestMatch = entry.value;
    }
  }
  if (bestMatch == null) return null;

  if (normUnit == 'g' || normUnit == 'ml') {
    return (bestMatch.per100g * quantity) / 100.0;
  }
  if (_kServingUnits.contains(normUnit)) {
    return bestMatch.perServing * quantity;
  }
  return null;
}

/// Lọc danh sách món từ danh mục theo từ khóa nhập (không phân biệt dấu),
/// ưu tiên khớp tiền tố trước khi khớp giữa chuỗi.
List<NutritionRecord> filterCatalogFoods(
  String query,
  List<NutritionRecord> catalogFoods, {
  int limit = 5,
}) {
  final normQuery = _normalizeFoodKey(query);
  if (normQuery.isEmpty || catalogFoods.isEmpty) return const [];
  final prefixMatches = <NutritionRecord>[];
  final containsMatches = <NutritionRecord>[];
  for (final food in catalogFoods) {
    final normName = _normalizeFoodKey((food['name'] ?? '').toString());
    if (normName.isEmpty || !normName.contains(normQuery)) continue;
    if (normName.startsWith(normQuery)) {
      prefixMatches.add(food);
    } else {
      containsMatches.add(food);
    }
  }
  int byName(NutritionRecord a, NutritionRecord b) =>
      (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
  prefixMatches.sort(byName);
  containsMatches.sort(byName);
  return [...prefixMatches, ...containsMatches].take(limit).toList();
}

({String mealType, String? customLabel}) _resolveMealType(String rawInput) {
  final trimmed = rawInput.trim();
  final normalized = trimmed.toLowerCase();
  if (normalized == 'sáng' ||
      normalized == 'bữa sáng' ||
      normalized == 'breakfast') {
    return (mealType: 'BREAKFAST', customLabel: null);
  }
  if (normalized == 'trưa' ||
      normalized == 'bữa trưa' ||
      normalized == 'lunch') {
    return (mealType: 'LUNCH', customLabel: null);
  }
  if (normalized == 'tối' ||
      normalized == 'bữa tối' ||
      normalized == 'dinner') {
    return (mealType: 'DINNER', customLabel: null);
  }
  if (normalized == 'bữa phụ' || normalized == 'snack') {
    return (mealType: 'SNACK', customLabel: null);
  }
  return (mealType: 'SNACK', customLabel: trimmed);
}

class _NutritionTokens {
  const _NutritionTokens({
    required this.isLight,
    required this.palette,
    required this.colors,
  });

  factory _NutritionTokens.of(BuildContext context) => _NutritionTokens(
    isLight: MetaGymTheme.isLightPalette(context),
    palette: MetaGymTheme.paletteOf(context),
    colors: MetaGymColors.of(context),
  );

  final bool isLight;
  final MetaGymPalette palette;
  final MetaGymColors colors;

  Color get glassBorder => colors.overlayGlassBorder;
  Color get cardBorder => colors.liquidGlassBorder;
  Color get recessedFill => palette.metricPanelBg;
  Color get recessedFocusedFill =>
      isLight ? const Color(0xFFE3EAF4) : const Color(0x9E28231F);
  Color get recessedBorder => palette.metricPanelBorder;
  Color get divider => palette.borderSolid.withValues(alpha: 0.7);
  Color get dropdownSurface => colors.surface;
  Color get dialogSurface => colors.overlayGlass;
  Color get dockSurface => isLight ? colors.overlayGlass : const Color(0xE01A1715);
  Color get dockBorder => isLight ? palette.borderSolid : const Color(0x3DFFF6EA);
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get labelText => isLight ? palette.textSecondary : const Color(0xFFD5CCBF);
  Color get hintText =>
      isLight ? palette.textSecondary.withValues(alpha: 0.7) : const Color(0xA6C4BAAE);
  Color get orangeText => isLight ? palette.primaryText : const Color(0xFFFF7852);
  Color get success => palette.success;
  Color get warning => palette.warning;
  Color get error => palette.error;
  Color get reflection => palette.reflection;
}

DateTime _vietnamToday() {
  final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}

TimeOfDay _vietnamNowTime() {
  final vn = DateTime.now().toUtc().add(const Duration(hours: 7));
  return TimeOfDay(hour: vn.hour, minute: vn.minute);
}

ThemeData _warmPickerTheme(BuildContext context) {
  final t = _NutritionTokens.of(context);
  return Theme.of(context).copyWith(
    colorScheme: t.isLight
        ? ColorScheme.light(
            primary: MetaGymTheme.brandOrange,
            onPrimary: Colors.white,
            surface: t.dropdownSurface,
            onSurface: t.textPrimary,
            secondary: t.reflection,
            onSecondary: Colors.white,
          )
        : ColorScheme.dark(
            primary: MetaGymTheme.brandOrange,
            onPrimary: Colors.white,
            surface: const Color(0xFF28231F),
            onSurface: t.textPrimary,
            secondary: MetaGymTheme.reflectionBlue,
            onSecondary: const Color(0xFF071A2C),
          ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.dialogSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.glassBorder, width: 1.1),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: t.dialogSurface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: t.isLight
          ? t.palette.surfaceRaised
          : const Color(0xFF302924),
      headerForegroundColor: t.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.glassBorder, width: 1.1),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: t.dialogSurface,
      dialBackgroundColor: t.isLight
          ? t.palette.surfaceRaised
          : const Color(0xFF302924),
      hourMinuteColor: t.recessedFill,
      hourMinuteTextColor: t.textPrimary,
      dayPeriodColor: t.palette.chipActiveBg,
      dayPeriodTextColor: t.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.glassBorder, width: 1.1),
      ),
    ),
  );
}

class NutritionTrackingPage extends StatefulWidget {
  const NutritionTrackingPage({this.api, super.key});

  final NutritionTrackingApi? api;

  @override
  State<NutritionTrackingPage> createState() => _NutritionTrackingPageState();
}

class _NutritionTrackingPageState extends State<NutritionTrackingPage> {
  late final NutritionTrackingApi _api;
  DateTime _date = _vietnamToday();
  NutritionRecord? _data;
  String? _error;
  bool _loading = true;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  bool get _isToday =>
      _dateKey == DateFormat('yyyy-MM-dd').format(_vietnamToday());

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? NutritionTrackingApi(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    final date = _dateKey;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.day(date);
      if (mounted && date == _dateKey) setState(() => _data = data);
    } catch (error) {
      if (mounted && date == _dateKey) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được nhật ký ăn.',
        );
      }
    } finally {
      if (mounted && date == _dateKey) setState(() => _loading = false);
    }
  }

  Future<void> _shiftDate(int deltaDays) async {
    final today = _vietnamToday();
    final next = DateTime(_date.year, _date.month, _date.day + deltaDays);
    if (next.isAfter(today)) return;
    setState(() {
      _date = next;
      _data = null;
    });
    await _load();
  }

  Future<void> _pickDate() async {
    final today = _vietnamToday();
    final initial = _date.isAfter(today) ? today : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: today,
      builder: (context, child) =>
          Theme(data: _warmPickerTheme(context), child: child!),
    );
    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _date = normalized;
        _data = null;
      });
      await _load();
    }
  }

  Future<void> _openForm({
    String? meal,
    String? initialMealLabel,
    NutritionRecord? entry,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EntryForm(
          api: _api,
          date: _dateKey,
          meal: meal,
          initialMealLabel: initialMealLabel,
          entry: entry,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Widget _surface({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    VoidCallback? onTap,
  }) => MetaGymGlassCard(
    key: key,
    solid: false,
    padding: padding,
    onTap: onTap,
    child: child,
  );

  String _formatKcal(double value) {
    final raw = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final rev = raw.length - i;
      buffer.write(raw[i]);
      if (rev > 1 && rev % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }

  String _dayLabel() {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    final label = DateFormat('dd/MM/yyyy').format(_date);
    return _isToday
        ? 'Hôm nay · $label'
        : '${weekdays[_date.weekday - 1]} · $label';
  }

  _NutritionTokens get _t => _NutritionTokens.of(context);

  Widget _dateArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final t = _t;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: enabled ? t.recessedFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: enabled
                      ? Border.all(color: t.recessedBorder, width: 1)
                      : null,
                ),
                child: MetaGymResolvedIcon(icon, size: 20, fallbackColor: enabled
                      ? t.textPrimary
                      : t.textSecondary.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateSelector() => MetaGymGlassCard(
    solid: false,
    borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: _dateNavigation(),
  );

  Widget _dateNavigation() {
    final t = _t;
    return Row(
      key: const Key('nutrition-date-selector'),
      children: [
        _dateArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Ngày trước',
          onTap: _loading ? null : () => _shiftDate(-1),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            onTap: _loading ? null : _pickDate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MetaGymSvgIcon(MetaGymIcons.workoutPlanCalendar, size: 16, fallbackIcon: Icons.calendar_today_rounded),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          _dayLabel(),
                          maxLines: 1,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    MetaGymSvgIcon(MetaGymIcons.commonChevronDown, size: 18, fallbackIcon: Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
        _dateArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Ngày sau',
          onTap: (_loading || _isToday) ? null : () => _shiftDate(1),
        ),
      ],
    );
  }

  Widget _summary(
    List<NutritionRecord> entries,
    List<NutritionRecord> known,
    double kcal,
    bool canWrite,
  ) {
    final t = _t;
    final isExpired = _data?['hasActiveMembership'] == false;
    final showNotice = isExpired || !canWrite;
    return MetaGymHeroGlassCard(
      key: const Key('nutrition-day-summary'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dateNavigation(),
          const SizedBox(height: 6),
          Container(
            key: const Key('nutrition-day-metrics'),
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _metricPanel(
                      label: 'Tổng calo',
                      value: known.isEmpty ? '—' : '${_formatKcal(kcal)} kcal',
                      icon: Icons.bolt_rounded,
                      color: t.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricPanel(
                      label: 'Món đã ghi',
                      value: '${entries.length} món',
                      icon: Icons.restaurant_rounded,
                      color: t.reflection,
                      valueColor: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showNotice) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Divider(height: 1, thickness: 1, color: t.divider),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: t.recessedFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExpired
                      ? t.warning.withValues(alpha: 0.42)
                      : t.recessedBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  MetaGymResolvedIcon(isExpired
                        ? Icons.lock_outline_rounded
                        : Icons.history_toggle_off_rounded, size: 16, fallbackColor: isExpired ? t.warning : t.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isExpired
                          ? 'Gói Gym không còn hiệu lực · chỉ xem lịch sử.'
                          : 'Ngày đã qua · chỉ xem, không sửa hoặc xóa.',
                      style: TextStyle(
                        color: t.labelText,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricPanel({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    Color? valueColor,
  }) {
    final t = _t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.recessedFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.recessedBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              MetaGymResolvedIcon(icon, size: 13.5, fallbackColor: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: value == '—' ? t.textSecondary : (valueColor ?? color),
                fontSize: 19,
                height: 1.15,
                fontWeight: FontWeight.w800,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMealPlans() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MealPlansPage()));
  }

  Widget _coachSummary(Map? plan) {
    final t = _t;
    final relationship = _data?['relationshipStatus'];
    final title = plan?['title'] as String?;
    final canOpenPlan = relationship != 'NONE' && !_loading;
    final titleLine = title == null
        ? 'Chưa có thực đơn từ Coach'
        : 'Thực đơn từ Coach';
    final detail = relationship == 'PAUSED'
        ? 'Coach đang tạm ngưng.'
        : (title ?? 'Thực đơn sẽ hiện khi Coach công bố.');
    if (relationship == 'NONE' && plan == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          'Bạn có thể tự ghi món, không cần thực đơn.',
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      );
    }
    final isActivePlan = title != null && relationship != 'PAUSED';
    final statusColor = isActivePlan ? t.success : t.warning;
    final statusLabel = isActivePlan
        ? 'Đang áp dụng'
        : relationship == 'PAUSED'
        ? 'Tạm ngưng'
        : 'Chưa có';

    return _surface(
      key: const Key('nutrition-coach-source'),
      padding: EdgeInsets.fromLTRB(14, 10, canOpenPlan ? 4 : 14, 10),
      onTap: canOpenPlan ? _openMealPlans : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: t.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: t.warning.withValues(alpha: 0.38),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(
                  MetaGymIcons.nutritionCoachPlan,
                  size: 18,
                  fallbackIcon: Icons.restaurant_menu_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            titleLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.42),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActivePlan ? t.textPrimary : t.labelText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpenPlan)
                IconButton(
                  tooltip: 'Mở thực đơn Coach đầy đủ',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _openMealPlans,
                  icon: MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 22, fallbackIcon: Icons.chevron_right_rounded),
                ),
            ],
          ),
          if (plan != null) _comparisonNote(),
        ],
      ),
    );
  }

  Widget _comparisonNote() {
    final t = _t;
    final comparisons = _data?['comparisons'] as Map?;
    if (comparisons == null || (_data?['entries'] as List? ?? []).isEmpty) {
      return const SizedBox.shrink();
    }
    final incomplete = [
      'BREAKFAST',
      'LUNCH',
      'DINNER',
    ].any((meal) => comparisons[meal]?['status'] == 'INSUFFICIENT');
    if (!incomplete) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: t.divider),
          const SizedBox(height: 7),
          Row(
            children: [
              MetaGymSvgIcon(MetaGymIcons.commonInfo, size: 15, fallbackIcon: Icons.info_outline_rounded),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Đối chiếu cần món danh mục và khẩu phần gram.',
                  style: TextStyle(
                    color: t.labelText,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, IconData, Color) _mealStyle(String meal) {
    final t = _t;
    return switch (meal) {
      'BREAKFAST' => (
        MetaGymIcons.mealBreakfast,
        Icons.wb_twilight_rounded,
        t.warning,
      ),
      'LUNCH' => (
        MetaGymIcons.mealLunch,
        Icons.wb_sunny_rounded,
        t.success,
      ),
      'DINNER' => (
        MetaGymIcons.mealDinner,
        Icons.nights_stay_rounded,
        t.reflection,
      ),
      _ => (
        MetaGymIcons.mealSnack,
        Icons.local_cafe_rounded,
        t.orangeText,
      ),
    };
  }

  Future<void> _onEditMealSection({
    required String mealType,
    required String title,
    required List<NutritionRecord> mealEntries,
  }) async {
    if (mealEntries.isEmpty) {
      await _openForm(meal: mealType, initialMealLabel: title);
      return;
    }
    if (mealEntries.length == 1) {
      await _openForm(
        meal: mealType,
        initialMealLabel: title,
        entry: mealEntries.first,
      );
      return;
    }
    final t = _t;
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: t.dialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: t.cardBorder, width: 1),
      ),
      builder: (sheetContext) {
        final st = _NutritionTokens.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chọn món cần sửa · $title',
                  style: TextStyle(
                    color: st.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in mealEntries)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: MetaGymSvgIcon(MetaGymIcons.commonEdit, size: 18, fallbackIcon: Icons.edit_outlined),
                    title: Text(
                      '${entry['mealName'] ?? entry['foodName'] ?? 'Món ăn'}',
                      style: TextStyle(
                        color: st.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (entry['quantity'] != null)
                          '${_formatAmount(entry['quantity'])} ${entry['unit'] ?? ''}'
                              .trim(),
                        if ((entry['kcal'] ?? entry['calories']) != null)
                          '${_formatAmount(entry['kcal'] ?? entry['calories'])} kcal',
                      ].join(' · '),
                      style: TextStyle(
                        color: st.textSecondary,
                        fontSize: 12,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, entry),
                  ),
                const SizedBox(height: 4),
                Divider(height: 1, thickness: 1, color: st.divider),
                const SizedBox(height: 4),
                ListTile(
                  key: Key('nutrition-sheet-add-$mealType'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 20, fallbackIcon: Icons.add_circle_outline_rounded),
                  title: Text(
                    'Thêm món mới vào $title',
                    style: TextStyle(
                      color: st.orangeText,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'ADD_NEW'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked == 'ADD_NEW') {
      await _openForm(meal: mealType, initialMealLabel: title);
    } else if (picked is NutritionRecord) {
      await _openForm(meal: mealType, initialMealLabel: title, entry: picked);
    }
  }

  Widget _mealSection({
    required String sectionKey,
    required String mealType,
    required String title,
    required List<NutritionRecord> mealEntries,
    required List<NutritionRecord> suggestions,
    required Map? comparison,
    required bool canWrite,
  }) {
    final t = _t;
    final (svgAsset, icon, accentColor) = _mealStyle(mealType);
    final editable = canWrite && !_loading;
    final matchedEntryIds = <String>{};
    final rows = <Widget>[];

    for (final suggestion in suggestions) {
      final id = suggestion['foodId'];
      final index = mealEntries.indexWhere(
        (entry) =>
            entry['foodId'] == id && !matchedEntryIds.contains(entry['id']),
      );
      if (index >= 0) {
        final entry = mealEntries[index];
        matchedEntryIds.add('${entry['id']}');
        rows.add(_mealEntry(entry, comparison: comparison, canWrite: editable));
      } else {
        rows.add(
          _plannedSuggestion(
            suggestion,
            difference: _differenceFor(comparison, {'foodId': id}),
          ),
        );
      }
    }

    for (final entry in mealEntries) {
      if (!matchedEntryIds.contains('${entry['id']}')) {
        rows.add(_mealEntry(entry, comparison: comparison, canWrite: editable));
      }
    }

    return _surface(
      key: Key('nutrition-meal-$sectionKey'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.36),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(svgAsset, size: 19, fallbackIcon: icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (mealEntries.isNotEmpty)
                      Text(
                        '${mealEntries.length} món',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
              ),
              if (editable) ...[
                Tooltip(
                  message: 'Thêm món vào $title',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('nutrition-add-meal-$sectionKey'),
                      onTap: () =>
                          _openForm(meal: mealType, initialMealLabel: title),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.palette.chipActiveBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.45,
                                ),
                                width: 0.9,
                              ),
                            ),
                            child: MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 19, fallbackIcon: Icons.add_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Sửa $title',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('nutrition-edit-meal-$sectionKey'),
                      onTap: () => _onEditMealSection(
                        mealType: mealType,
                        title: title,
                        mealEntries: mealEntries,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.recessedFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: t.recessedBorder,
                                width: 0.9,
                              ),
                            ),
                            child: const MetaGymSvgIcon(
                              MetaGymIcons.commonEdit,
                              size: 16,
                              fallbackIcon: Icons.edit_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (rows.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Divider(height: 1, thickness: 1, color: t.divider),
            ),
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) Divider(height: 1, thickness: 1, color: t.divider),
              rows[index],
            ],
          ],
        ],
      ),
    );
  }

  Widget _emptyMealsCard(bool canWrite) {
    final t = _t;
    return _surface(
      key: const Key('nutrition-empty-meals'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.palette.chipActiveBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: MetaGymTheme.primary.withValues(alpha: 0.35),
              ),
            ),
            alignment: Alignment.center,
            child: const MetaGymSvgIcon(
              MetaGymIcons.emptyNutrition,
              size: 22,
              fallbackIcon: Icons.restaurant_menu_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa có bữa ăn nào',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canWrite
                      ? 'Nhấn "Ghi lại bữa ăn" bên dưới để thêm bữa trưa, meal trước tập hoặc bất kỳ bữa nào.'
                      : 'Không có món ăn nào được ghi trong ngày này.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plannedSuggestion(NutritionRecord item, {Map? difference}) {
    final t = _t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: t.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: t.warning.withValues(alpha: 0.36)),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(
                  MetaGymIcons.nutritionCoachPlan,
                  size: 16,
                  fallbackIcon: Icons.restaurant_menu_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item['foodName']} · ${item['grams']} g',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.labelText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: t.warning.withValues(alpha: 0.38),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Gợi ý',
                  style: TextStyle(
                    color: t.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (difference != null)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 3),
              child: Text(
                'Đã ghi ${_formatAmount(difference['actualGrams'])} g · lệch ${_deltaAmount(difference['deltaGrams'])} g',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mealEntry(
    NutritionRecord entry, {
    required Map? comparison,
    required bool canWrite,
  }) {
    final t = _t;
    final difference = _differenceFor(comparison, entry);
    final mealName = (entry['mealName'] ?? entry['foodName'] ?? 'Món ăn')
        .toString();
    final entryKcal = entry['kcal'] ?? entry['calories'];
    final quantity = entry['quantity'];
    final unit = entry['unit'] as String? ?? '';
    final amount = quantity == null
        ? ''
        : '${_formatAmount(quantity)} $unit'.trim();
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: t.success.withValues(alpha: 0.38)),
            ),
            alignment: Alignment.center,
            child: const MetaGymSvgIcon(
              MetaGymIcons.nutritionDishLogged,
              size: 16,
              fallbackIcon: Icons.restaurant_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amount.isEmpty ? mealName : '$mealName · $amount',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
                const SizedBox(height: 3),
                if (entryKcal != null)
                  Text(
                    '${_formatAmount(entryKcal)} kcal',
                    style: TextStyle(
                      color: t.success,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  )
                else
                  Text(
                    'Nhập thủ công',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (difference != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Gợi ý ${_formatAmount(difference['suggestedGrams'])} g · lệch ${_deltaAmount(difference['deltaGrams'])} g',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canWrite) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.recessedFill,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.recessedBorder, width: 0.8),
              ),
              child: MetaGymSvgIcon(MetaGymIcons.commonEdit, size: 15, fallbackIcon: Icons.edit_outlined),
            ),
          ],
        ],
      ),
    );
    if (!canWrite) return content;
    final parsedNotes = _parseEntryNotes(entry['notes'] as String?);
    return InkWell(
      key: Key('nutrition-entry-${entry['id']}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openForm(
        meal: entry['mealType'] as String?,
        initialMealLabel: parsedNotes.mealLabel,
        entry: entry,
      ),
      child: content,
    );
  }

  Map? _differenceFor(Map? comparison, NutritionRecord entry) {
    final foodId = entry['foodId'];
    if (foodId == null) return null;
    for (final difference in comparison?['differences'] as List? ?? const []) {
      if (difference is Map && difference['foodId'] == foodId) {
        return difference;
      }
    }
    return null;
  }

  String _formatAmount(Object? value) {
    if (value is! num) return '$value';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _deltaAmount(Object? value) {
    if (value is! num) return '$value';
    if (value == 0) return '0';
    final prefix = value > 0 ? '+' : '−';
    return '$prefix${_formatAmount(value.abs())}';
  }

  Widget _errorStateCard() {
    final t = _t;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.error.withValues(alpha: 0.40),
                    ),
                  ),
                  child: MetaGymSvgIcon(MetaGymIcons.stateOffline, size: 20, fallbackIcon: Icons.cloud_off_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kiểm tra kết nối mạng rồi thử tải lại.',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  List<
    ({
      String sectionKey,
      String mealType,
      String title,
      List<NutritionRecord> entries,
      List<NutritionRecord> suggestions,
      Map? comparison,
    })
  >
  _buildMealGroups(
    List<NutritionRecord> entries,
    List<NutritionRecord> planItems,
    Map? plan,
  ) {
    final groups =
        <
          String,
          ({
            String mealType,
            String title,
            List<NutritionRecord> entries,
            List<NutritionRecord> suggestions,
            Map? comparison,
          })
        >{};

    void ensureGroup(String key, String mealType, String title) {
      groups.putIfAbsent(
        key,
        () => (
          mealType: mealType,
          title: title,
          entries: <NutritionRecord>[],
          suggestions: <NutritionRecord>[],
          comparison: mealType == 'SNACK'
              ? null
              : _data?['comparisons']?[mealType] as Map?,
        ),
      );
    }

    if (plan != null) {
      for (final mealKey in const ['BREAKFAST', 'LUNCH', 'DINNER']) {
        final mealSuggestions = planItems
            .where(
              (item) => item['day'] == _date.weekday && item['meal'] == mealKey,
            )
            .toList();
        if (mealSuggestions.isNotEmpty) {
          ensureGroup(mealKey, mealKey, _meals[mealKey]!);
          groups[mealKey]!.suggestions.addAll(mealSuggestions);
        }
      }
    }

    for (final entry in entries) {
      final rawMealType = (entry['mealType'] as String? ?? 'SNACK');
      final parsed = _parseEntryNotes(entry['notes'] as String?);
      if (parsed.mealLabel != null) {
        final customKey = 'CUSTOM:${parsed.mealLabel!.toLowerCase()}';
        ensureGroup(customKey, rawMealType, parsed.mealLabel!);
        groups[customKey]!.entries.add(entry);
      } else {
        final title = _meals[rawMealType] ?? rawMealType;
        ensureGroup(rawMealType, rawMealType, title);
        groups[rawMealType]!.entries.add(entry);
      }
    }

    final orderedKeys = <String>[
      for (final standard in const ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'])
        if (groups.containsKey(standard)) standard,
      for (final key in groups.keys)
        if (!const ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'].contains(key)) key,
    ];

    return [
      for (final key in orderedKeys)
        (
          sectionKey: key,
          mealType: groups[key]!.mealType,
          title: groups[key]!.title,
          entries: groups[key]!.entries,
          suggestions: groups[key]!.suggestions,
          comparison: groups[key]!.comparison,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final entries = (_data?['entries'] as List? ?? []).cast<NutritionRecord>();
    final known = entries
        .where((e) => (e['kcal'] ?? e['calories']) != null)
        .toList();
    final kcal = known.fold<double>(
      0,
      (sum, e) => sum + ((e['kcal'] ?? e['calories']) as num).toDouble(),
    );
    final plan = _data?['plan'] as Map?;
    final items = (plan?['items'] as List? ?? []).cast<NutritionRecord>();
    final canWrite = _data?['canWrite'] == true;
    final mealGroups = _buildMealGroups(entries, items, plan);
    final showLogButton = !_loading && _error == null && canWrite;
    return Scaffold(
      backgroundColor: t.palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: t.textPrimary,
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
        title: const Text('Theo dõi dinh dưỡng'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
      ),
      bottomNavigationBar: showLogButton
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: t.dockSurface,
                border: Border(
                  top: BorderSide(color: t.dockBorder, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton.icon(
                  key: const Key('nutrition-log-meal'),
                  onPressed: () => _openForm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: MetaGymTheme.fontFamily,
                      fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 20, fallbackIcon: Icons.add_rounded),
                  label: const Text('Ghi lại bữa ăn'),
                ),
              ),
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              backgroundColor: t.dropdownSurface,
              color: MetaGymTheme.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  4,
                  MetaGymTheme.pageGutter,
                  24,
                ),
                children: [
                  if (_loading || _error != null) ...[
                    _dateSelector(),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 84, bottom: 84),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: MetaGymTheme.isFlutterTestEnvironment
                              ? 0.55
                              : null,
                          color: MetaGymTheme.primary,
                        ),
                      ),
                    )
                  else if (_error != null)
                    _errorStateCard()
                  else ...[
                    _summary(entries, known, kcal, canWrite),
                    const SizedBox(height: 10),
                    _coachSummary(plan),
                    const SizedBox(height: 14),
                    Text(
                      'Nhật ký bữa ăn',
                      key: const Key('nutrition-meals-heading'),
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (mealGroups.isEmpty)
                      _emptyMealsCard(canWrite)
                    else
                      for (final group in mealGroups) ...[
                        _mealSection(
                          sectionKey: group.sectionKey,
                          mealType: group.mealType,
                          title: group.title,
                          mealEntries: group.entries,
                          suggestions: group.suggestions,
                          comparison: group.comparison,
                          canWrite: canWrite,
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({
    required this.api,
    required this.date,
    this.meal,
    this.initialMealLabel,
    this.entry,
  });

  final NutritionTrackingApi api;
  final String date;
  final String? meal;
  final String? initialMealLabel;
  final NutritionRecord? entry;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _DishDraft {
  _DishDraft({
    String name = '',
    String quantity = '',
    String customKcal = '',
    this.foodId,
    this.unit = 'g',
  }) : name = TextEditingController(text: name),
       quantity = TextEditingController(text: quantity),
       customKcal = TextEditingController(text: customKcal);

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController customKcal;
  String? foodId;
  String unit;
  bool saved = false;

  void dispose() {
    name.dispose();
    quantity.dispose();
    customKcal.dispose();
  }

  double? parsedQuantity() {
    final qty = double.tryParse(quantity.text.trim().replaceAll(',', '.'));
    if (qty == null || !qty.isFinite || qty < 0.01 || qty > 10000) return null;
    return qty;
  }

  double? parsedManualKcal() {
    final raw = customKcal.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final val = double.tryParse(raw);
    if (val == null || !val.isFinite || val < 0 || val > 20000) return null;
    return val;
  }

  double? autoEstimatedKcal(List<NutritionRecord> foods) {
    final qty = parsedQuantity();
    if (qty == null) return null;
    if (foodId != null) {
      if (unit != 'g') return null;
      for (final item in foods) {
        if (item['id'] == foodId) {
          final per100g = item['kcalPer100g'];
          if (per100g is num && per100g > 0) {
            return (per100g.toDouble() * qty) / 100.0;
          }
          break;
        }
      }
      return null;
    }
    return estimateCustomFoodKcal(
      name: name.text,
      quantity: qty,
      unit: unit,
      catalogFoods: foods,
    );
  }

  double? resolvedKcal(List<NutritionRecord> foods) {
    if (foodId != null) return autoEstimatedKcal(foods);
    return parsedManualKcal() ?? autoEstimatedKcal(foods);
  }

  bool isAutoEstimated(List<NutritionRecord> foods) {
    if (foodId != null) return false;
    return parsedManualKcal() == null && autoEstimatedKcal(foods) != null;
  }
}

class _EntryFormState extends State<_EntryForm> {
  final _form = GlobalKey<FormState>();
  final _mealLabel = TextEditingController();
  final _notes = TextEditingController();
  final List<_DishDraft> _dishes = [];
  List<NutritionRecord> _foods = [];
  TimeOfDay _time = _vietnamNowTime();
  bool _saving = false;
  bool _foodError = false;
  SelectedProgressImage? _image;
  String? _uploadedImageId;
  String? _error;

  static String _formatPlainNum(Object? value) {
    if (value is! num) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      final parsedNotes = _parseEntryNotes(entry['notes'] as String?);
      final rawMealType = entry['mealType'] as String? ?? widget.meal ?? '';
      _mealLabel.text =
          parsedNotes.mealLabel ?? (_meals[rawMealType] ?? rawMealType);
      _notes.text = parsedNotes.notes;
      final foodId = entry['foodId'] as String?;
      final rawUnit = (entry['unit'] as String? ?? '').trim();
      final unit = rawUnit.isEmpty ? 'g' : rawUnit;
      final existingKcal = entry['kcal'] ?? entry['calories'];
      _dishes.add(
        _DishDraft(
          name: (entry['mealName'] ?? entry['foodName'] ?? '').toString(),
          quantity: '${entry['quantity'] ?? ''}',
          customKcal: (foodId == null && existingKcal != null)
              ? _formatPlainNum(existingKcal)
              : '',
          foodId: foodId,
          unit: unit,
        ),
      );
      _uploadedImageId = entry['imageMediaId'] as String?;
      final eaten = DateTime.tryParse(entry['eatenAt'] as String? ?? '')
          ?.toUtc()
          .add(const Duration(hours: 7));
      if (eaten != null) {
        _time = TimeOfDay(hour: eaten.hour, minute: eaten.minute);
      }
    } else {
      final label = (widget.initialMealLabel ?? '').trim();
      if (label.isNotEmpty) {
        _mealLabel.text = label;
      } else if (widget.meal != null && widget.meal!.isNotEmpty) {
        _mealLabel.text = _meals[widget.meal!] ?? widget.meal!;
      }
      _dishes.add(_DishDraft());
    }
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    try {
      final foods = await widget.api.foods();
      if (mounted) {
        setState(() {
          _foods = foods;
          _foodError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _foodError = true);
    }
  }

  @override
  void dispose() {
    _mealLabel.dispose();
    _notes.dispose();
    for (final dish in _dishes) {
      dish.dispose();
    }
    super.dispose();
  }

  double? get _totalEstimatedKcal {
    double total = 0;
    var hasAny = false;
    for (final dish in _dishes) {
      final k = dish.resolvedKcal(_foods);
      if (k != null) {
        total += k;
        hasAny = true;
      }
    }
    return hasAny ? total : null;
  }

  void _addAnotherDish() {
    setState(() {
      _dishes.add(_DishDraft());
    });
  }

  void _removeDish(int index) {
    if (_dishes.length <= 1) return;
    setState(() {
      final removed = _dishes.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) =>
          Theme(data: _warmPickerTheme(context), child: child!),
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await DeviceProgressPhotoPicker().pick();
      if (image == null || !mounted) return;
      final error = validateProgressImage(image);
      setState(() {
        _error = error;
        if (error == null) {
          _image = image;
          _uploadedImageId = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không chọn được ảnh. Vui lòng thử lại.');
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_image != null) _uploadedImageId ??= await widget.api.upload(_image!);
      final time =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final resolvedMeal = _resolveMealType(_mealLabel.text);
      final encodedNotes = _encodeEntryNotes(
        resolvedMeal.customLabel,
        _notes.text,
      );

      Map<String, dynamic> buildPayload(_DishDraft dish) {
        final resolvedKcal = dish.resolvedKcal(_foods);
        return <String, dynamic>{
          'eatenAt': '${widget.date}T$time:00+07:00',
          'mealType': resolvedMeal.mealType,
          'mealName': dish.name.text.trim(),
          'foodId': dish.foodId,
          'imageMediaId': _uploadedImageId,
          'quantity': double.parse(dish.quantity.text.replaceAll(',', '.')),
          'unit': dish.unit,
          'notes': encodedNotes,
          if (dish.foodId == null &&
              (resolvedKcal != null || widget.entry != null))
            'estimatedCalories': resolvedKcal?.round(),
        };
      }

      if (widget.entry == null) {
        for (final dish in _dishes) {
          if (dish.saved) continue;
          await widget.api.add(buildPayload(dish));
          dish.saved = true;
        }
      } else {
        await widget.api.update(
          widget.entry!['id'] as String,
          buildPayload(_dishes.first),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không lưu được món. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  _NutritionTokens get _t => _NutritionTokens.of(context);

  Future<void> _deleteEntry() async {
    final entry = widget.entry;
    if (entry == null || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final dt = _NutritionTokens.of(dialog);
        return AlertDialog(
          backgroundColor: dt.dialogSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dt.glassBorder, width: 1.1),
          ),
          title: Text(
            'Xóa món đã ghi?',
            style: TextStyle(
              color: dt.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            (entry['mealName'] ?? entry['foodName'] ?? 'Món ăn').toString(),
            style: TextStyle(
              color: dt.labelText,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: dt.textSecondary,
              ),
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Giữ lại'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dt.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(96, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Xóa món'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.delete(entry['id'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không xóa được món. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _warmInputDecoration({
    required String labelText,
    bool alignLabelWithHint = false,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
  }) {
    final t = _t;
    final radius = BorderRadius.circular(MetaGymTheme.radiusInput);
    return InputDecoration(
      labelText: labelText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: t.recessedFill,
      hoverColor: t.recessedFocusedFill,
      labelStyle: TextStyle(
        color: t.labelText,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return TextStyle(
            color: t.error,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          );
        }
        if (states.contains(WidgetState.focused)) {
          return TextStyle(
            color: t.orangeText,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: t.labelText,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        );
      }),
      hintStyle: TextStyle(color: t.hintText, fontSize: 13.5),
      errorStyle: TextStyle(
        color: t.error,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      errorMaxLines: 2,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.recessedBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.recessedBorder, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: t.recessedBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: t.error, width: 1.6),
      ),
    );
  }

  Widget _sectionHeader(String title, Color accentColor) {
    final t = _t;
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    final t = _t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: t.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.error.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: MetaGymSvgIcon(MetaGymIcons.stateError, size: 17, fallbackIcon: Icons.error_outline_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: t.error,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(int index, _DishDraft dish, _NutritionTokens t) {
    NutritionRecord? selectedCatalogFood;
    if (dish.foodId != null) {
      for (final f in _foods) {
        if (f['id'] == dish.foodId) {
          selectedCatalogFood = f;
          break;
        }
      }
    }
    const defaultUnits = ['g', 'ml', 'phần', 'cái', 'bát', 'ly'];
    final unitOptions = <String>[
      ...defaultUnits,
      if (dish.unit.isNotEmpty && !defaultUnits.contains(dish.unit)) dish.unit,
    ];
    final autoKcal = dish.autoEstimatedKcal(_foods);
    final resolvedKcal = dish.resolvedKcal(_foods);
    final isAuto = dish.isAutoEstimated(_foods);
    final showMultiHeader = widget.entry == null && _dishes.length > 1;
    final suggestions = (dish.foodId == null && !_saving)
        ? filterCatalogFoods(dish.name.text, _foods)
        : const <NutritionRecord>[];

    return MetaGymGlassCard(
      key: Key('nutrition-dish-card-$index'),
      solid: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  showMultiHeader ? 'Món ${index + 1}' : 'Thông tin món ăn',
                  MetaGymTheme.brandOrange,
                ),
              ),
              if (showMultiHeader)
                Tooltip(
                  message: 'Xóa món ${index + 1}',
                  child: IconButton(
                    key: Key('nutrition-remove-dish-$index'),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: _saving ? null : () => _removeDish(index),
                    icon: MetaGymSvgIcon(MetaGymIcons.commonClose, size: 20, fallbackIcon: Icons.close_rounded),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: Key('nutrition-dish-name-$index'),
            controller: dish.name,
            enabled: !_saving,
            maxLength: 150,
            cursorColor: MetaGymTheme.brandOrange,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
            onChanged: (value) {
              setState(() {
                if (dish.foodId != null) {
                  final expectedName =
                      (selectedCatalogFood?['name'] ?? '').toString();
                  if (value.trim() != expectedName.trim()) {
                    dish.foodId = null;
                  }
                }
              });
            },
            decoration: _warmInputDecoration(labelText: 'Tên món').copyWith(
              hintText: 'Tìm trong danh mục hoặc nhập món tự do...',
              prefixIcon: MetaGymSvgIcon(MetaGymIcons.commonSearch, size: 19, fallbackIcon: Icons.search_rounded),
              suffixIcon: dish.name.text.isNotEmpty && !_saving
                  ? IconButton(
                      tooltip: 'Xóa tên món',
                      onPressed: () {
                        setState(() {
                          dish.name.clear();
                          dish.foodId = null;
                        });
                      },
                      icon: MetaGymSvgIcon(MetaGymIcons.commonClose, size: 18, fallbackIcon: Icons.close_rounded),
                    )
                  : null,
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nhập tên món' : null,
          ),
          if (dish.foodId != null) ...[
            const SizedBox(height: 8),
            Container(
              key: Key('nutrition-selected-catalog-$index'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: t.success.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  MetaGymSvgIcon(MetaGymIcons.authVerified, size: 16, fallbackIcon: Icons.verified_rounded),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedCatalogFood?['kcalPer100g'] is num
                          ? 'Món danh mục · ${_formatPlainNum(selectedCatalogFood!['kcalPer100g'])} kcal / 100g'
                          : 'Món danh mục',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _saving
                        ? null
                        : () => setState(() => dish.foodId = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        'Nhập tự do',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              key: Key('nutrition-food-suggestions-$index'),
              decoration: BoxDecoration(
                color: t.dropdownSurface,
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                border: Border.all(color: t.recessedBorder, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var sIdx = 0; sIdx < suggestions.length; sIdx++) ...[
                    if (sIdx > 0)
                      Divider(height: 1, thickness: 1, color: t.divider),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key(
                          'nutrition-food-suggestion-$index-${suggestions[sIdx]['id']}',
                        ),
                        onTap: () {
                          final food = suggestions[sIdx];
                          setState(() {
                            dish.foodId = food['id'] as String;
                            dish.name.text = food['name'] as String;
                            dish.name.selection = TextSelection.collapsed(
                              offset: dish.name.text.length,
                            );
                            dish.unit = 'g';
                            dish.customKcal.clear();
                          });
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 16, fallbackIcon: Icons.restaurant_menu_rounded),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${suggestions[sIdx]['name'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (suggestions[sIdx]['kcalPer100g'] is num) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatPlainNum(suggestions[sIdx]['kcalPer100g'])} kcal / 100g',
                                    style: TextStyle(
                                      color: t.success,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_foodError && index == 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loadFoods,
                style: TextButton.styleFrom(
                  foregroundColor: t.warning,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: const Size(44, 44),
                ),
                icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 17, fallbackIcon: Icons.refresh_rounded),
                label: const Text(
                  'Danh mục tải lỗi · Thử lại; vẫn có thể nhập món tự do',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: Key('nutrition-dish-qty-$index'),
                  controller: dish.quantity,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  cursorColor: MetaGymTheme.brandOrange,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: _warmInputDecoration(
                    labelText: 'Lượng thực tế',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return n == null || !n.isFinite || n < 0.01 || n > 10000
                        ? 'Nhập lượng từ 0,01 đến 10000'
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('unit-$index-${dish.unit}'),
                  initialValue: dish.unit,
                  isExpanded: true,
                  dropdownColor: t.dropdownSurface,
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  icon: const MetaGymSvgIcon(MetaGymIcons.commonChevronDown, fallbackIcon: Icons.keyboard_arrow_down_rounded),
                  iconEnabledColor: t.labelText,
                  iconDisabledColor: t.labelText.withValues(alpha: 0.4),
                  disabledHint: Text(
                    dish.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MetaGymTheme.fontFamily,
                      fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                      color: t.labelText,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: MetaGymTheme.fontFamily,
                    fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                    color: t.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _warmInputDecoration(
                    labelText: 'Đơn vị',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  selectedItemBuilder: (_) => [
                    for (final unit in unitOptions)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MetaGymTheme.fontFamily,
                            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                            color: (dish.foodId != null || _saving)
                                ? t.labelText
                                : t.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  items: [
                    for (final unit in unitOptions)
                      DropdownMenuItem(
                        value: unit,
                        child: Text(
                          unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: dish.foodId != null || _saving
                      ? null
                      : (v) => setState(() => dish.unit = v!),
                ),
              ),
            ],
          ),
          if (dish.foodId == null) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: Key('nutrition-custom-kcal-$index'),
              controller: dish.customKcal,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              cursorColor: MetaGymTheme.brandOrange,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
              onChanged: (_) => setState(() {}),
              decoration:
                  _warmInputDecoration(
                    labelText: 'Calo (kcal) · tùy chọn',
                  ).copyWith(
                    hintText: autoKcal != null
                        ? 'Tự tính: ≈ ${autoKcal.round()} kcal (nhập để ghi đè)'
                        : 'Nhập calo nếu biết (VD: 350)',
                  ),
              validator: (v) {
                final trimmed = (v ?? '').trim();
                if (trimmed.isEmpty) return null;
                final n = double.tryParse(trimmed.replaceAll(',', '.'));
                return n == null || !n.isFinite || n < 0 || n > 20000
                    ? 'Nhập calo từ 0 đến 20000'
                    : null;
              },
            ),
          ],
          if (resolvedKcal != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: index == 0
                    ? const Key('nutrition-estimated-kcal')
                    : Key('nutrition-estimated-kcal-$index'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: t.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: t.success.withValues(alpha: 0.38),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MetaGymSvgIcon(MetaGymIcons.streakFlame, size: 16, fallbackIcon: Icons.bolt_rounded),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        isAuto
                            ? 'Tự tính ≈ ${resolvedKcal.round()} kcal'
                            : '≈ ${resolvedKcal.round()} kcal',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final pageTitle = widget.entry == null ? 'Ghi lại bữa ăn' : 'Sửa món ăn';
    final totalEstimatedKcal = _totalEstimatedKcal;
    final hasPhoto =
        _image != null ||
        (_uploadedImageId != null && _uploadedImageId!.isNotEmpty);
    final saveButtonText = _saving
        ? 'Đang lưu…'
        : (widget.entry == null && _dishes.length > 1)
        ? 'Lưu ${_dishes.length} món'
        : 'Lưu món';

    return Scaffold(
      backgroundColor: t.palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: t.textPrimary,
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
        title: Text(pageTitle),
        titleTextStyle: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
        actions: [
          if (widget.entry != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                key: const Key('nutrition-delete-entry'),
                tooltip: 'Xóa món',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _saving ? null : _deleteEntry,
                icon: MetaGymSvgIcon(MetaGymIcons.commonDelete, fallbackIcon: Icons.delete_outline_rounded),
              ),
            ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: t.dockSurface,
          border: Border(top: BorderSide(color: t.dockBorder, width: 1)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.entry == null && _dishes.length > 1) ...[
                  Row(
                    key: const Key('nutrition-meal-total-banner'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng bữa (${_dishes.length} món)',
                        style: TextStyle(
                          color: t.labelText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        totalEstimatedKcal != null
                            ? '≈ ${totalEstimatedKcal.round()} kcal'
                            : 'Chưa đủ dữ liệu calo',
                        style: TextStyle(
                          color: totalEstimatedKcal != null
                              ? t.success
                              : t.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_error != null) ...[
                  _errorBanner(_error!),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    disabledBackgroundColor: MetaGymTheme.brandOrange
                        .withValues(alpha: 0.48),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: MetaGymTheme.fontFamily,
                      fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(saveButtonText),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Form(
              key: _form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  MetaGymGlassCard(
                    solid: false,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader('Bữa ăn', t.warning),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('nutrition-meal-label-field'),
                          controller: _mealLabel,
                          enabled: !_saving,
                          maxLength: 60,
                          cursorColor: MetaGymTheme.brandOrange,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => null,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              _warmInputDecoration(labelText: 'Tên bữa ăn')
                                  .copyWith(
                                    hintText: 'VD: Bữa trưa, Meal trước tập...',
                                  ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nhập tên bữa ăn (VD: Bữa trưa, Meal trước tập)'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in _quickMealLabels)
                              ChoiceChip(
                                label: Text(preset),
                                selected:
                                    _mealLabel.text.trim().toLowerCase() ==
                                    preset.toLowerCase(),
                                onSelected: _saving
                                    ? null
                                    : (_) => setState(() {
                                        _mealLabel.text = preset;
                                      }),
                                showCheckmark: false,
                                backgroundColor: t.recessedFill,
                                selectedColor: t.palette.chipActiveBg,
                                side: BorderSide(
                                  color:
                                      _mealLabel.text.trim().toLowerCase() ==
                                          preset.toLowerCase()
                                      ? MetaGymTheme.brandOrange
                                      : t.cardBorder,
                                ),
                                labelStyle: TextStyle(
                                  color:
                                      _mealLabel.text.trim().toLowerCase() ==
                                          preset.toLowerCase()
                                      ? t.orangeText
                                      : t.labelText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < _dishes.length; i++) ...[
                    _buildDishCard(i, _dishes[i], t),
                    const SizedBox(height: 12),
                  ],
                  if (widget.entry == null) ...[
                    OutlinedButton.icon(
                      key: const Key('nutrition-add-another-dish'),
                      onPressed: _saving ? null : _addAnotherDish,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.orangeText,
                        backgroundColor: t.recessedFill,
                        side: BorderSide(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.48,
                          ),
                        ),
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusInput,
                          ),
                        ),
                      ),
                      icon: const MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 19, fallbackIcon: Icons.add_rounded),
                      label: const Text(
                        'Thêm món vào bữa này',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 2),
                  MetaGymGlassCard(
                    solid: false,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader('Thời gian & ghi chú', t.success),
                        const SizedBox(height: 14),
                        Material(
                          color: t.recessedFill,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              MetaGymTheme.radiusInput,
                            ),
                            side: BorderSide(
                              color: t.recessedBorder,
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: const Key('nutrition-time-tile'),
                            onTap: _saving ? null : _pickTime,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 52),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: t.palette.chipActiveBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: MetaGymSvgIcon(MetaGymIcons.timeClock, size: 18, fallbackIcon: Icons.schedule_rounded),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Giờ ăn',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: t.textSecondary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _time.format(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: t.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              fontFeatures:
                                                  MetaGymTheme.tabularFigures,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 20, fallbackIcon: Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          enabled: !_saving,
                          maxLines: 3,
                          maxLength: 5000,
                          cursorColor: MetaGymTheme.brandOrange,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            required maxLength,
                          }) => null,
                          decoration: _warmInputDecoration(
                            labelText: 'Ghi chú (tùy chọn)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: t.recessedFill,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              MetaGymTheme.radiusInput,
                            ),
                            side: BorderSide(
                              color: t.recessedBorder,
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: const Key('nutrition-photo-tile'),
                            onTap: _saving ? null : _pickPhoto,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 52),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: t.palette.chipActiveBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: MetaGymSvgIcon(MetaGymIcons.mediaGallery, size: 18, fallbackIcon: Icons.photo_outlined),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        hasPhoto
                                            ? 'Đã chọn ảnh · Đổi ảnh'
                                            : 'Thêm ảnh (tùy chọn)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (_image != null) ...[
                                      const SizedBox(width: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          _image!.bytes,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => MetaGymSvgIcon(MetaGymIcons.mediaGallery, size: 20, fallbackIcon: Icons.image_rounded),
                                        ),
                                      ),
                                    ] else if (hasPhoto) ...[
                                      const SizedBox(width: 8),
                                      MetaGymSvgIcon(MetaGymIcons.stateSuccess, size: 20, fallbackIcon: Icons.check_circle_outline_rounded),
                                    ] else
                                      MetaGymSvgIcon(MetaGymIcons.mediaGallery, size: 20, fallbackIcon: Icons.add_photo_alternate_outlined),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
