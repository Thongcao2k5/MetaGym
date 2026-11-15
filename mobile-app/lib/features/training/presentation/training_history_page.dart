import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text(
          'Lịch sử tập luyện',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
        backgroundColor: Colors.transparent,
        foregroundColor: MetaGymTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.primary,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                _HistorySurface(
                  dense: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: MetaGymTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
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
                            visualDensity: VisualDensity.compact,
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
                            onPressed: canGoForward
                                ? () => _moveMonth(1)
                                : null,
                            tooltip: 'Tháng sau',
                            visualDensity: VisualDensity.compact,
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xD423211F),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _HistoryStat(
                                  label: 'Đã đến gym',
                                  value: data.visitedDays,
                                  color: MetaGymTheme.primary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 46,
                                color: const Color(0x667E7064),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _HistoryStat(
                                  label: 'Ngày chưa đến',
                                  value: (data.eligibleDays - data.visitedDays)
                                      .clamp(0, 31),
                                  color: MetaGymTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _HistoryCalendar(month: _month, visits: data.visits),
                        const SizedBox(height: 8),
                        const Text(
                          'Ngày chưa đến chỉ tính khi gói tập còn hiệu lực.',
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Các lần đến gym',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (data != null && !_loading && _error == null)
                      Text(
                        '${data.entryCount} lượt · ${data.visitedDays} ngày',
                        style: const TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
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
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HistorySurface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.place_outlined,
                                  size: 20,
                                  color: MetaGymTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd/MM/yyyy')
                                                .format(visit.day),
                                            style: const TextStyle(
                                              color: MetaGymTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(visit.checkedInAt.toLocal()),
                                          style: const TextStyle(
                                            color: Color(0xFFF5C5A3),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      visit.gymName,
                                      style: const TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      visit.gymAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFB8B0A8),
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
        ],
      ),
    );
  }
}

class _HistorySurface extends StatelessWidget {
  const _HistorySurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.dense = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) => MetaGymGlassCard(
    padding: dense ? EdgeInsets.zero : padding,
    child: dense
        ? ColoredBox(
            color: const Color(0xA0211E1C),
            child: Padding(padding: padding, child: child),
          )
        : child,
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: 2),
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
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
        const SizedBox(height: 6),
        ...List.generate(((leading + days) / 7).ceil(), (week) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (weekday) {
                final day = week * 7 + weekday - leading + 1;
                if (day < 1 || day > days) {
                  return const Expanded(child: SizedBox(height: 38));
                }
                final hasVisit = visited.contains(day);
                final future = currentMonth && day > now.day;
                final today = currentMonth && day == now.day;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: hasVisit
                            ? MetaGymTheme.primary
                            : future
                            ? const Color(0xA01F1D1B)
                            : const Color(0xDA292522),
                        border: Border.all(
                          color: today
                              ? const Color(0xFFE0B99A)
                              : const Color(0x677D7065),
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
