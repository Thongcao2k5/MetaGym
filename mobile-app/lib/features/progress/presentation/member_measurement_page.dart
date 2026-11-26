import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/body_metric_pickers.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình **5.5 Nhật ký & Số đo** đồng bộ `tab5-profile.js` (`member-measurement`)
/// và chuẩn Warm Smoked Liquid Glass:
/// - Header với `common_back.svg`, eyebrow `TIẾN ĐỘ & SỐ ĐO`, nút thêm nhanh `common_add.svg`
/// - Thẻ Hero Warm Glass `Chỉ số mới nhất` (`body_weight_scale.svg`) gồm 3 ô: Cân nặng (mở Cân Đĩa Tạ), Mỡ cơ thể, BMI
/// - Danh sách `Lịch sử số đo vòng` dạng Warm Smoked Glass kèm lưới 3 vòng (`Ngực · Eo · Hông`)
/// - Thanh CTA đáy `.bottom-cta-dock` có `SafeArea(top: false)`.
class MemberMeasurementPage extends StatefulWidget {
  const MemberMeasurementPage({this.service, super.key});

  final MemberMeasurementService? service;

  @override
  State<MemberMeasurementPage> createState() => _MemberMeasurementPageState();
}

class _MemberMeasurementPageState extends State<MemberMeasurementPage> {
  MemberMeasurementService? _service;
  List<BodyMeasurement> _items = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberMeasurementService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  double get _memberHeightCm {
    final user = optionalProvider<SessionController>(context)?.user;
    final raw = user?.profile['heightCm'];
    if (raw is num && raw >= 80 && raw <= 300) return raw.toDouble();
    return 174.0;
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loading)) return;
    final targetPage = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await _service!.getPage(targetPage);
      if (mounted) {
        setState(() {
          _items = more ? [..._items, ...next] : next;
          _page = targetPage;
          _hasMore = next.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được số đo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([
    BodyMeasurement? measurement,
    double? initialWeightKg,
  ]) async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(
        builder: (_) => _MeasurementFormPage(
          service: _service!,
          measurement: measurement,
          initialWeightKg: initialWeightKg,
          referenceHeightCm: _memberHeightCm,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _quickPickWeight() async {
    final currentWeight = _items.isNotEmpty ? _items.first.weightKg : 72.4;
    final picked = await showWeightBarbellDialPicker(
      context,
      initialWeightKg: currentWeight,
      referenceHeightCm: _memberHeightCm,
    );
    if (picked != null && mounted) {
      await _edit(null, picked);
    }
  }

  String _formatDateOnly(String iso) {
    final full = formatProgressTime(iso);
    final spaceIdx = full.indexOf(' ');
    return spaceIdx > 0 ? full.substring(0, spaceIdx) : full;
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TIẾN ĐỘ & SỐ ĐO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nhật ký & Số đo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.commonAdd,
            tooltip: 'Thêm chỉ số mới',
            onTap: () => _edit(),
          ),
        ],
      ),
    );
  }

  String _shortBmiLabel(BmiInfo bmi) => switch (bmi.zone) {
    BmiZone.underweight => 'Thiếu cân',
    BmiZone.normal => 'Chuẩn',
    BmiZone.overweight => 'Thừa cân',
    BmiZone.obese => 'Béo phì',
  };

  Widget _buildLatestHeroCard(MetaGymColors colors) {
    final latest = _items.first;
    final previous = _items.length > 1 ? _items[1] : null;
    final weightDelta = previous == null
        ? null
        : latest.weightKg - previous.weightKg;
    final fatDelta =
        (previous?.bodyFatPercent != null && latest.bodyFatPercent != null)
        ? latest.bodyFatPercent! - previous!.bodyFatPercent!
        : null;
    final bmi = calculateBmiInfo(_memberHeightCm, latest.weightKg);
    final bmiColor = bmi.colorFor(colors);

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.bodyWeightScale,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Chỉ số mới nhất',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CoachingPill(
                label: _formatDateOnly(latest.measuredAt),
                tone: CoachingPillTone.green,
              ),
            ],
          ),
          const SizedBox(height: 11),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    onTap: _quickPickWeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Cân nặng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatNumber(latest.weightKg)} kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 2),
                        weightDelta == null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Cân tạ',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.primaryText,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 11, fallbackIcon: Icons.north_east_rounded),
                                ],
                              )
                            : Text(
                                '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: weightDelta <= 0
                                      ? colors.success
                                      : colors.warning,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Mỡ cơ thể',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest.bodyFatPercent != null
                              ? '${_formatNumber(latest.bodyFatPercent!)}%'
                              : '--',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fatDelta == null
                              ? '--'
                              : '${fatDelta >= 0 ? '+' : ''}${fatDelta.toStringAsFixed(1)}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fatDelta == null
                                ? colors.textSecondary
                                : (fatDelta <= 0
                                      ? colors.success
                                      : colors.warning),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'BMI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bmi.bmi.toStringAsFixed(1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shortBmiLabel(bmi),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: bmiColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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

  Widget _buildHistoryCard(
    MetaGymColors colors,
    BodyMeasurement item,
    bool isLatest,
  ) {
    final pillText = item.bodyFatPercent != null
        ? '${_formatNumber(item.weightKg)} kg · ${_formatNumber(item.bodyFatPercent!)}%'
        : '${_formatNumber(item.weightKg)} kg';

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.zero,
      onTap: () => _edit(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDateOnly(item.measuredAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CoachingPill(
                  label: pillText,
                  tone: isLatest
                      ? CoachingPillTone.coral
                      : CoachingPillTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _CircumferenceStat(
                    label: 'Ngực',
                    valueCm: item.chestCm,
                  ),
                ),
                Expanded(
                  child: _CircumferenceStat(label: 'Eo', valueCm: item.waistCm),
                ),
                Expanded(
                  child: _CircumferenceStat(
                    label: 'Hông',
                    valueCm: item.hipsCm,
                  ),
                ),
              ],
            ),
            if (item.armCm != null ||
                item.thighCm != null ||
                (item.notes?.trim().isNotEmpty == true)) ...[
              const SizedBox(height: 7),
              Text(
                [
                  if (item.armCm != null)
                    'Tay ${_formatNumber(item.armCm!)} cm',
                  if (item.thighCm != null)
                    'Đùi ${_formatNumber(item.thighCm!)} cm',
                  if (item.notes?.trim().isNotEmpty == true) item.notes!.trim(),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 11.5,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors),
                Expanded(
                  child: RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: colors.surface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      children: [
                        if (_loading && _items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                              ),
                            ),
                          ),
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: colors.primaryText,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () => _load(more: false),
                              icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (!_loading && _error == null && _items.isEmpty)
                          MetaGymHeroGlassCard(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: MetaGymTheme.brandOrange.withValues(
                                      alpha: 0.16,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.42),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const MetaGymIcon(
                                    MetaGymIcons.bodyWeightScale,
                                    size: MetaGymIconSize.lg,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bạn chưa có số đo nào.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ghi nhận cân nặng, tỷ lệ mỡ và số đo 3 vòng để theo dõi thay đổi hình thể theo từng tuần.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textWarmMuted,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_items.isNotEmpty) ...[
                          _buildLatestHeroCard(colors),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Lịch sử số đo vòng',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_items.length} bản ghi',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < _items.length; i++)
                            _buildHistoryCard(colors, _items[i], i == 0),
                        ],
                        if (_loading && _items.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                              ),
                            ),
                          ),
                        if (_hasMore && !_loading)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: colors.primaryText,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _load(more: true),
                            child: const Text('Tải thêm'),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isLight
                        ? colors.overlayGlass
                        : const Color(0xF0181513),
                    border: Border(
                      top: BorderSide(
                        color: colors.metricPanelBorder.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                          ),
                          onPressed: () => _edit(),
                          child: const Text(
                            '+ Ghi nhận số đo mới',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
    );
  }
}

class _CircumferenceStat extends StatelessWidget {
  const _CircumferenceStat({required this.label, required this.valueCm});

  final String label;
  final double? valueCm;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final formatted = valueCm == null
        ? '--'
        : '${valueCm == valueCm!.roundToDouble() ? valueCm!.toStringAsFixed(0) : valueCm} cm';
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          formatted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _MeasurementFormPage extends StatefulWidget {
  const _MeasurementFormPage({
    required this.service,
    required this.referenceHeightCm,
    this.measurement,
    this.initialWeightKg,
  });

  final MemberMeasurementService service;
  final double referenceHeightCm;
  final BodyMeasurement? measurement;
  final double? initialWeightKg;

  @override
  State<_MeasurementFormPage> createState() => _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<_MeasurementFormPage> {
  final _date = TextEditingController();
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _arm = TextEditingController();
  final _thigh = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.measurement;
    if (m != null) {
      _date.text = formatProgressTime(m.measuredAt);
      _weight.text = m.weightKg.toString();
      _fat.text = m.bodyFatPercent?.toString() ?? '';
      _chest.text = m.chestCm?.toString() ?? '';
      _waist.text = m.waistCm?.toString() ?? '';
      _hips.text = m.hipsCm?.toString() ?? '';
      _arm.text = m.armCm?.toString() ?? '';
      _thigh.text = m.thighCm?.toString() ?? '';
      _notes.text = m.notes ?? '';
    } else {
      _date.text = formatProgressTime(DateTime.now().toUtc().toIso8601String());
      if (widget.initialWeightKg != null) {
        _weight.text = widget.initialWeightKg!.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _date,
      _weight,
      _fat,
      _chest,
      _waist,
      _hips,
      _arm,
      _thigh,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  double? _optionalNumber(TextEditingController c) =>
      c.text.trim().isEmpty ? null : _parseNumber(c.text);

  Future<void> _pickDateTime() async {
    final current = parseProgressTime(_date.text) ?? DateTime.now();
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    Widget pickerTheme(BuildContext ctx, Widget? child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: isLight
            ? ColorScheme.light(
                primary: MetaGymTheme.brandOrange,
                onPrimary: MetaGymTheme.onPrimary,
                surface: colors.overlayGlass,
                onSurface: colors.textPrimary,
              )
            : ColorScheme.dark(
                primary: MetaGymTheme.brandOrange,
                onPrimary: MetaGymTheme.onPrimary,
                surface: colors.overlayGlass,
                onSurface: colors.textPrimary,
              ),
      ),
      child: child!,
    );
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: pickerTheme,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: pickerTheme,
    );
    if (!mounted) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? current.hour,
      pickedTime?.minute ?? current.minute,
    );
    setState(() {
      _date.text = formatProgressTime(combined.toUtc().toIso8601String());
    });
  }

  Future<void> _openWeightDial() async {
    final currentW = _parseNumber(_weight.text) ?? 72.4;
    final picked = await showWeightBarbellDialPicker(
      context,
      initialWeightKg: currentW,
      referenceHeightCm: widget.referenceHeightCm,
    );
    if (picked != null && mounted) {
      setState(() => _weight.text = picked.toStringAsFixed(1));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final date = parseProgressTime(_date.text);
    final weight = _parseNumber(_weight.text);
    final fat = _optionalNumber(_fat);
    final lengths = [_chest, _waist, _hips, _arm, _thigh];
    String? validation;
    if (date == null) {
      validation = 'Nhập ngày giờ hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (weight == null ||
        !weight.isFinite ||
        weight <= 0 ||
        weight > 999.99) {
      validation = 'Cân nặng phải lớn hơn 0 và không quá 999.99 kg.';
    } else if (_fat.text.trim().isNotEmpty &&
        (fat == null || !fat.isFinite || fat < 0 || fat > 100)) {
      validation = 'Mỡ cơ thể phải trong khoảng 0–100%.';
    } else if (lengths.any(
      (c) =>
          c.text.trim().isNotEmpty &&
          (_optionalNumber(c) == null ||
              !_optionalNumber(c)!.isFinite ||
              _optionalNumber(c)! <= 0 ||
              _optionalNumber(c)! > 999.99),
    )) {
      validation = 'Số đo vòng phải lớn hơn 0 và không quá 999.99 cm.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, Object?>{
      'measuredAt': date!.toUtc().toIso8601String(),
      'weightKg': weight,
      'bodyFatPercent': fat,
      'chestCm': _optionalNumber(_chest),
      'waistCm': _optionalNumber(_waist),
      'hipsCm': _optionalNumber(_hips),
      'armCm': _optionalNumber(_arm),
      'thighCm': _optionalNumber(_thigh),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.measurement case final m?) {
        await widget.service.update(m.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được số đo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(
    MetaGymColors colors,
    String label, {
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textWarmMuted),
    counterStyle: TextStyle(color: colors.textSecondary),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.metricPanelBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      borderSide: BorderSide(color: colors.focus, width: 1.5),
    ),
  );

  Widget _numberField(
    MetaGymColors colors,
    String label,
    TextEditingController controller, {
    Key? key,
    Widget? suffixIcon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      cursorColor: MetaGymTheme.brandOrange,
      style: TextStyle(
        color: colors.textPrimary,
        fontFeatures: MetaGymTheme.tabularFigures,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(colors, label, suffixIcon: suffixIcon),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        svgAsset: MetaGymIcons.commonBack,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIẾN ĐỘ & SỐ ĐO',
                              style: TextStyle(
                                color: colors.primaryText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.measurement == null
                                  ? 'Thêm số đo'
                                  : 'Sửa số đo',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      MetaGymGlassCard(
                        solid: false,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                key: const Key('measurement-date'),
                                controller: _date,
                                cursorColor: MetaGymTheme.brandOrange,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                                keyboardType: TextInputType.datetime,
                                decoration: _inputDecoration(
                                  colors,
                                  'Ngày đo (dd/MM/yyyy HH:mm)',
                                  suffixIcon: IconButton(
                                    tooltip: 'Chọn ngày giờ',
                                    onPressed: _pickDateTime,
                                    icon: const MetaGymIcon(
                                      MetaGymIcons.workoutPlanCalendar,
                                      size: MetaGymIconSize.sm,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _numberField(
                              colors,
                              'Cân nặng (kg)',
                              _weight,
                              key: const Key('measurement-weight'),
                              suffixIcon: MetaGymTap(
                                onTap: _openWeightDial,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Cân tạ',
                                          style: TextStyle(
                                            color: colors.primaryText,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 12, fallbackIcon: Icons.north_east_rounded),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _numberField(
                              colors,
                              'Mỡ cơ thể (%)',
                              _fat,
                              key: const Key('measurement-fat'),
                            ),
                            _numberField(colors, 'Vòng ngực (cm)', _chest),
                            _numberField(
                              colors,
                              'Vòng eo (cm)',
                              _waist,
                              key: const Key('measurement-waist'),
                            ),
                            _numberField(colors, 'Vòng hông (cm)', _hips),
                            _numberField(colors, 'Vòng tay (cm)', _arm),
                            _numberField(colors, 'Vòng đùi (cm)', _thigh),
                            TextField(
                              controller: _notes,
                              cursorColor: MetaGymTheme.brandOrange,
                              maxLength: 5000,
                              maxLines: 3,
                              style: TextStyle(color: colors.textPrimary),
                              decoration: _inputDecoration(colors, 'Ghi chú'),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              CoachingErrorBanner(message: _error!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isLight
                        ? colors.overlayGlass
                        : const Color(0xF0181513),
                    border: Border(
                      top: BorderSide(
                        color: colors.metricPanelBorder.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                          ),
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? 'Đang lưu…' : 'Lưu',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
    );
  }
}
