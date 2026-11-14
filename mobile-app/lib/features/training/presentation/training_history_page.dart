import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:provider/provider.dart';

/// Gym attendance history. Check-in will be added to this flow later.
class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({this.api, super.key});

  final GymVisitsApi? api;

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  GymVisitsApi? _api;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  GymVisitMonth? _data;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api ?? GymVisitsApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api!.getMonth(_month);
      if (mounted) setState(() => _data = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử đến gym.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMonth(int offset) {
    final next = DateTime(_month.year, _month.month + offset);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoForward = _month.isBefore(DateTime(now.year, now.month));
    final data = _data;

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Lịch sử tập luyện'),
        backgroundColor: MetaGymTheme.scaffoldBackground,
        foregroundColor: MetaGymTheme.textPrimary,
      ),
      body: RefreshIndicator(
        color: MetaGymTheme.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _HistorySurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lịch đến gym',
                          style: TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _moveMonth(-1),
                        tooltip: 'Tháng trước',
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: MetaGymTheme.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('MM/yyyy').format(_month),
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: canGoForward ? () => _moveMonth(1) : null,
                        tooltip: 'Tháng sau',
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: MetaGymTheme.textPrimary,
                        disabledColor: MetaGymTheme.textSecondary,
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.primary,
                        ),
                      ),
                    )
                  else if (_error != null)
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('$_error Thử lại'),
                    )
                  else if (data != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _HistoryStat(
                            label: 'Đã đến gym',
                            value: data.visitedDays,
                            color: MetaGymTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HistoryStat(
                            label: 'Ngày chưa đến',
                            value: (data.eligibleDays - data.visitedDays).clamp(
                              0,
                              31,
                            ),
                            color: MetaGymTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _HistoryCalendar(month: _month, visits: data.visits),
                    const SizedBox(height: 10),
                    const Text(
                      'Ngày chưa đến chỉ tính khi gói tập có hiệu lực.',
                      style: TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Các lần đến gym',
              style: TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (data != null && !_loading && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${data.entryCount} lượt trong tháng · Một ngày có thể vào nhiều lần',
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (!_loading && _error == null && data != null)
              if (data.visits.isEmpty)
                const _HistorySurface(
                  child: Text(
                    'Chưa có lượt đến gym trong tháng này.',
                    style: TextStyle(color: MetaGymTheme.textSecondary),
                  ),
                )
              else
                ...data.visits.map(
                  (visit) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistorySurface(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: MetaGymTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(visit.day),
                                  style: const TextStyle(
                                    color: MetaGymTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('HH:mm').format(visit.checkedInAt.toLocal())} · ${visit.gymName}',
                                  style: const TextStyle(
                                    color: MetaGymTheme.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  visit.gymAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _HistorySurface extends StatelessWidget {
  const _HistorySurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MetaGymTheme.cardSurface,
      border: Border.all(color: MetaGymTheme.cardBorder),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MetaGymTheme.elevatedSurface,
      border: Border.all(color: MetaGymTheme.cardBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MetaGymTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({required this.month, required this.visits});

  final DateTime month;
  final List<GymVisit> visits;

  @override
  Widget build(BuildContext context) {
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final visited = visits.map((visit) => visit.day.day).toSet();
    final now = DateTime.now();
    final currentMonth = month.year == now.year && month.month == now.month;

    return Column(
      children: [
        Row(
          children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(((leading + days) / 7).ceil(), (week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(7, (weekday) {
                final day = week * 7 + weekday - leading + 1;
                if (day < 1 || day > days) {
                  return const Expanded(child: SizedBox(height: 44));
                }
                final hasVisit = visited.contains(day);
                final future = currentMonth && day > now.day;
                final today = currentMonth && day == now.day;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: hasVisit
                            ? MetaGymTheme.primary
                            : future
                            ? MetaGymTheme.darkCanvasElevated
                            : MetaGymTheme.elevatedSurface,
                        border: Border.all(
                          color: today
                              ? MetaGymTheme.reflectionBlue
                              : MetaGymTheme.cardBorder,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: future
                              ? MetaGymTheme.textSecondary
                              : MetaGymTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: hasVisit || today
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}
