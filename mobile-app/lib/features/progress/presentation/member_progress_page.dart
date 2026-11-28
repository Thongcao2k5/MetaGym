import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class MemberProgressPage extends StatefulWidget {
  const MemberProgressPage({this.service, super.key});
  final MemberProgressService? service;
  @override
  State<MemberProgressPage> createState() => _MemberProgressPageState();
}

class _MemberProgressPageState extends State<MemberProgressPage> {
  MemberProgressService? _service;
  ProgressSummary? _summary;
  List<WeightPoint> _points = const [];
  List<ProgressComment> _comments = const [];
  DateTime? _from;
  DateTime? _to;
  String _period = 'Toàn bộ';
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberProgressService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
      _points = const [];
      _comments = const [];
    });
    try {
      final summary = await _service!.getSummary();
      final points = await _service!.getCharts(from: _from, to: _to);
      final comments = await _service!.getComments();
      if (mounted) {
        setState(() {
          _summary = summary;
          _points = points;
          _comments = comments;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được tiến độ.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectPeriod(String label) {
    final now = DateTime.now();
    setState(() {
      _period = label;
      _to = label == 'Toàn bộ' ? null : DateTime(now.year, now.month, now.day);
      _from = label == '7 ngày'
          ? _to!.subtract(const Duration(days: 6))
          : label == '30 ngày'
          ? _to!.subtract(const Duration(days: 29))
          : null;
    });
    _load();
  }

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final isLight = MetaGymTheme.isLightPalette(context);
    final colors = MetaGymColors.of(context);
    final palette = MetaGymTheme.paletteOf(context);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _from ?? now.subtract(const Duration(days: 30)),
        end: _to ?? now,
      ),
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
    if (range == null || !mounted) return;
    setState(() {
      _period = 'Tùy chọn';
      _from = range.start;
      _to = range.end;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final canPop = Navigator.of(context).canPop();
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
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
          'Tiến độ của tôi',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: MetaGymTheme.primary),
                )
              : RefreshIndicator(
                  color: MetaGymTheme.brandOrange,
                  backgroundColor: colors.surface,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topInset,
                      16,
                      MediaQuery.paddingOf(context).bottom + 28,
                    ),
                    children: [
                      if (_error != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.error.withValues(alpha: 0.42),
                            ),
                          ),
                          child: Row(
                            children: [
                              MetaGymSvgIcon(MetaGymIcons.stateError, size: 20, fallbackIcon: Icons.error_outline_rounded),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: palette.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ] else ...[
                        if (_summary case final summary?) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Text(
                              'Tổng quan',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          MetaGymGlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 18, fallbackIcon: Icons.fitness_center),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buổi tập: ${summary.workoutCount}',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 18, fallbackIcon: Icons.restaurant),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Bữa ăn: ${summary.mealCount}',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    MetaGymSvgIcon(MetaGymIcons.commonCamera, size: 18, fallbackIcon: Icons.photo_camera),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ảnh tiến trình: ${summary.progressPhotoCount}',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    MetaGymSvgIcon(MetaGymIcons.bodyWeightScale, size: 18, fallbackIcon: Icons.monitor_weight),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        summary.latestMeasurement == null
                                            ? 'Chưa có số đo.'
                                            : 'Cân nặng mới nhất: ${summary.latestMeasurement!.weightKg} kg',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Biểu đồ cân nặng',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in const [
                              'Toàn bộ',
                              '7 ngày',
                              '30 ngày',
                            ])
                              ChoiceChip(
                                label: Text(label),
                                selected: _period == label,
                                selectedColor: isLight
                                    ? palette.chipActiveBg
                                    : const Color(0xFF493025),
                                backgroundColor: colors.liquidGlass,
                                surfaceTintColor: Colors.transparent,
                                checkmarkColor: palette.primaryText,
                                labelStyle: TextStyle(
                                  color: _period == label
                                      ? palette.chipActiveText
                                      : palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: _period == label
                                      ? MetaGymTheme.brandOrange
                                      : colors.liquidGlassBorder,
                                  width: 1.1,
                                ),
                                onSelected: (_) => _selectPeriod(label),
                              ),
                            ActionChip(
                              label: const Text('Chọn khoảng ngày'),
                              backgroundColor: colors.liquidGlass,
                              surfaceTintColor: Colors.transparent,
                              labelStyle: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: colors.liquidGlassBorder,
                                width: 1.1,
                              ),
                              onPressed: _chooseRange,
                            ),
                          ],
                        ),
                        if (_period == 'Tùy chọn' &&
                            _from != null &&
                            _to != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${DateFormat('dd/MM/yyyy').format(_from!)} – ${DateFormat('dd/MM/yyyy').format(_to!)}',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 13,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (_points.isEmpty)
                          MetaGymGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: ListTile(
                              leading: MetaGymSvgIcon(MetaGymIcons.statsChartLine, fallbackIcon: Icons.query_stats),
                              title: Text(
                                'Chưa có số đo để vẽ biểu đồ.',
                                style: TextStyle(color: palette.textSecondary),
                              ),
                            ),
                          )
                        else ...[
                          MetaGymGlassCard(
                            padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 180,
                                  child: LineChart(
                                    LineChartData(
                                      minX: 0,
                                      maxX: (_points.length - 1).toDouble(),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                              color: palette.borderSolid
                                                  .withValues(alpha: 0.7),
                                              strokeWidth: 1,
                                            ),
                                      ),
                                      titlesData: const FlTitlesData(
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: [
                                            for (
                                              var i = 0;
                                              i < _points.length;
                                              i++
                                            )
                                              FlSpot(
                                                i.toDouble(),
                                                _points[i].weightKg,
                                              ),
                                          ],
                                          isCurved: false,
                                          barWidth: 3,
                                          color: MetaGymTheme.brandOrange,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter:
                                                (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) => FlDotCirclePainter(
                                                  radius: 4,
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                  strokeColor:
                                                      MetaGymTheme.brandOrange,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Divider(
                                  color: palette.borderSolid.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                for (final point in _points)
                                  ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    leading: MetaGymSvgIcon(MetaGymIcons.bodyWeightScale, size: 18, fallbackIcon: Icons.scale),
                                    title: Text(
                                      '${point.weightKg} kg',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                    subtitle: Text(
                                      DateFormat('dd/MM/yyyy').format(
                                        DateTime.parse(point.measuredAt)
                                            .toLocal(),
                                      ),
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: palette.primaryText,
                              collapsedIconColor: palette.textSecondary,
                              leading: MetaGymSvgIcon(MetaGymIcons.commChat, fallbackIcon: Icons.comment),
                              title: Text(
                                'Nhận xét của Coach',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              children: _comments.isEmpty
                                  ? [
                                      ListTile(
                                        title: Text(
                                          'Chưa có nhận xét.',
                                          style: TextStyle(
                                            color: palette.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : [
                                      for (final comment in _comments)
                                        ListTile(
                                          title: Text(
                                            comment.content,
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          subtitle: Text(
                                            DateFormat('dd/MM/yyyy').format(
                                              DateTime.parse(comment.createdAt)
                                                  .toLocal(),
                                            ),
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 12,
                                              fontFeatures:
                                                  MetaGymTheme.tabularFigures,
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
                ),
        ],
      ),
    );
  }
}
