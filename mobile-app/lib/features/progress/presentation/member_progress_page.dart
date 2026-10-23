import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
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
    });
    try {
      final summary = await _service!.getSummary();
      final points = await _service!.getCharts(from: _from, to: _to);
      if (mounted) {
        setState(() {
          _summary = summary;
          _points = points;
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
    appBar: AppBar(title: const Text('Tiến độ của tôi')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else ...[
                  if (_summary case final summary?) ...[
                    Text(
                      'Tổng quan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Buổi tập: ${summary.workoutCount}'),
                    Text('Bữa ăn: ${summary.mealCount}'),
                    Text('Ảnh tiến trình: ${summary.progressPhotoCount}'),
                    Text(
                      summary.latestMeasurement == null
                          ? 'Chưa có số đo.'
                          : 'Cân nặng mới nhất: ${summary.latestMeasurement!.weightKg} kg',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Biểu đồ cân nặng',
                    style: Theme.of(context).textTheme.titleLarge,
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
                          onSelected: (_) => _selectPeriod(label),
                        ),
                      ActionChip(
                        label: const Text('Chọn khoảng ngày'),
                        onPressed: _chooseRange,
                      ),
                    ],
                  ),
                  if (_period == 'Tùy chọn' && _from != null && _to != null)
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(_from!)} – ${DateFormat('dd/MM/yyyy').format(_to!)}',
                    ),
                  const SizedBox(height: 16),
                  if (_points.isEmpty)
                    const ListTile(title: Text('Chưa có số đo để vẽ biểu đồ.'))
                  else ...[
                    SizedBox(
                      height: 240,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: (_points.length - 1).toDouble(),
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < _points.length; i++)
                                    FlSpot(i.toDouble(), _points[i].weightKg),
                                ],
                                isCurved: false,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final point in _points)
                      ListTile(
                        title: Text('${point.weightKg} kg'),
                        subtitle: Text(
                          DateFormat(
                            'dd/MM/yyyy',
                          ).format(DateTime.parse(point.measuredAt).toLocal()),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
  );
}
