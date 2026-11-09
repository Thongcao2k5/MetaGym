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
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _from ?? now.subtract(const Duration(days: 30)),
        end: _to ?? now,
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Tiến độ của tôi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    )
                  : RefreshIndicator(
                      color: MetaGymTheme.brandOrange,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF453A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x66FF453A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFFF6961),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF857D),
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
                                foregroundColor: MetaGymTheme.brandOrange,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ] else ...[
                            if (_summary case final summary?) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text(
                                  'Tổng quan',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.fitness_center,
                                          color: MetaGymTheme.brandOrange,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Buổi tập: ${summary.workoutCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.restaurant,
                                          color: Color(0xFF34C759),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bữa ăn: ${summary.mealCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.photo_camera,
                                          color: Color(0xFF8EB9E5),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ảnh tiến trình: ${summary.progressPhotoCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.monitor_weight,
                                          color: Color(0xFFFF9F0A),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            summary.latestMeasurement == null
                                                ? 'Chưa có số đo.'
                                                : 'Cân nặng mới nhất: ${summary.latestMeasurement!.weightKg} kg',
                                            style: const TextStyle(
                                              color: Colors.white,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final label in const [
                                  'Toàn bộ',
                                  '7 ngày',
                                  '30 ngày',
                                ])
                                  ChoiceChip(
                                    label: Text(label),
                                    selected: _period == label,
                                    selectedColor: MetaGymTheme.brandOrange,
                                    backgroundColor: const Color(0x33162232),
                                    labelStyle: TextStyle(
                                      color: _period == label
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: BorderSide(
                                      color: _period == label
                                          ? MetaGymTheme.brandOrange
                                          : const Color(0x38D4E4FF),
                                    ),
                                    onSelected: (_) => _selectPeriod(label),
                                  ),
                                ActionChip(
                                  label: const Text('Chọn khoảng ngày'),
                                  backgroundColor: const Color(0x33162232),
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0x38D4E4FF),
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
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (_points.isEmpty)
                              const MetaGymGlassCard(
                                padding: EdgeInsets.all(16),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.query_stats,
                                    color: Colors.white38,
                                  ),
                                  title: Text(
                                    'Chưa có số đo để vẽ biểu đồ.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              )
                            else ...[
                              MetaGymGlassCard(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  16,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 180,
                                      child: LineChart(
                                        LineChartData(
                                          minX: 0,
                                          maxX:
                                              (_points.length - 1).toDouble(),
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            getDrawingHorizontalLine: (value) =>
                                                const FlLine(
                                              color: Color(0x26FFFFFF),
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
                                                for (var i = 0;
                                                    i < _points.length;
                                                    i++)
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
                                                getDotPainter: (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) =>
                                                    FlDotCirclePainter(
                                                  radius: 4,
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                  strokeColor: MetaGymTheme
                                                      .brandOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(color: Color(0x26FFFFFF)),
                                    for (final point in _points)
                                      ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        leading: const Icon(
                                          Icons.scale,
                                          color: MetaGymTheme.brandOrange,
                                          size: 18,
                                        ),
                                        title: Text(
                                          '${point.weightKg} kg',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Text(
                                          DateFormat('dd/MM/yyyy').format(
                                            DateTime.parse(
                                              point.measuredAt,
                                            ).toLocal(),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
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
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  iconColor: MetaGymTheme.brandOrange,
                                  collapsedIconColor: Colors.white54,
                                  leading: const Icon(
                                    Icons.comment,
                                    color: MetaGymTheme.brandOrange,
                                  ),
                                  title: const Text(
                                    'Nhận xét của Coach',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  children: _comments.isEmpty
                                      ? [
                                          const ListTile(
                                            title: Text(
                                              'Chưa có nhận xét.',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ),
                                        ]
                                      : [
                                          for (final comment in _comments)
                                            ListTile(
                                              title: Text(
                                                comment.content,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              subtitle: Text(
                                                DateFormat('dd/MM/yyyy')
                                                    .format(
                                                  DateTime.parse(
                                                    comment.createdAt,
                                                  ).toLocal(),
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
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
            ),
          ],
        ),
      );
}
