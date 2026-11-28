import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

enum MetaGymCalendarMode { week, month }

class MetaGymCalendarStat {
  const MetaGymCalendarStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;
}

DateTime metaGymDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String metaGymIsoDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

List<DateTime> metaGymVisibleCalendarDays(
  DateTime selectedDate,
  MetaGymCalendarMode mode,
) {
  final date = metaGymDateOnly(selectedDate);
  if (mode == MetaGymCalendarMode.week) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }
  final first = DateTime(date.year, date.month, 1);
  final start = first.subtract(Duration(days: first.weekday - 1));
  final last = DateTime(date.year, date.month + 1, 0);
  final end = last.add(Duration(days: DateTime.daysPerWeek - last.weekday));
  final days = <DateTime>[];
  for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
    days.add(day);
  }
  return days;
}

DateTime metaGymShiftCalendarPeriod(
  DateTime selectedDate,
  MetaGymCalendarMode mode,
  int delta, {
  DateTime? maxDate,
}) {
  final date = metaGymDateOnly(selectedDate);
  DateTime next;
  if (mode == MetaGymCalendarMode.week) {
    next = date.add(Duration(days: delta * 7));
  } else {
    final targetMonthStart = DateTime(date.year, date.month + delta, 1);
    final daysInTargetMonth =
        DateTime(targetMonthStart.year, targetMonthStart.month + 1, 0).day;
    next = DateTime(
      targetMonthStart.year,
      targetMonthStart.month,
      date.day.clamp(1, daysInTargetMonth),
    );
  }
  if (maxDate != null) {
    final maxOnly = metaGymDateOnly(maxDate);
    if (next.isAfter(maxOnly)) return maxOnly;
  }
  return next;
}

const List<String> _kCalendarWeekdays = [
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN',
];

/// Compact Hero Week/Month calendar shared across Self Training, Curriculum,
/// Nutrition, and Coach views.
class MetaGymScheduleCalendar extends StatelessWidget {
  const MetaGymScheduleCalendar({
    required this.selectedDate,
    required this.mode,
    required this.onSelectDate,
    required this.onModeChanged,
    this.today,
    this.maxDate,
    this.badgeCountForDay,
    this.badgeColorForDay,
    this.dotColorsForDay,
    this.legend,
    this.stats = const [],
    this.footer,
    this.wrapInHeroCard = true,
    this.selectorKey,
    this.weekEyebrow = 'TUẦN HIỆN TẠI',
    this.monthEyebrow = 'THEO THÁNG',
    super.key,
  });

  final DateTime selectedDate;
  final MetaGymCalendarMode mode;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<MetaGymCalendarMode> onModeChanged;
  final DateTime? today;
  final DateTime? maxDate;
  final int Function(DateTime day)? badgeCountForDay;
  final Color Function(DateTime day)? badgeColorForDay;
  final List<Color> Function(DateTime day)? dotColorsForDay;
  final Widget? legend;
  final List<MetaGymCalendarStat> stats;
  final Widget? footer;
  final bool wrapInHeroCard;
  final Key? selectorKey;
  final String weekEyebrow;
  final String monthEyebrow;

  String _periodLabel(List<DateTime> days, DateTime selected) {
    if (mode == MetaGymCalendarMode.month) {
      return 'Tháng ${selected.month}/${selected.year}';
    }
    final first = days.first;
    final last = days.last;
    final d1 = first.day.toString().padLeft(2, '0');
    final m1 = first.month.toString().padLeft(2, '0');
    final d2 = last.day.toString().padLeft(2, '0');
    final m2 = last.month.toString().padLeft(2, '0');
    if (first.month == last.month) {
      return '$d1–$d2/$m2';
    }
    return '$d1/$m1–$d2/$m2';
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final selected = metaGymDateOnly(selectedDate);
    final todayOnly = metaGymDateOnly(today ?? DateTime.now());
    final maxOnly = maxDate == null ? null : metaGymDateOnly(maxDate!);
    final days = metaGymVisibleCalendarDays(selected, mode);
    final period = _periodLabel(days, selected);

    final canShiftNext = maxOnly == null
        ? true
        : mode == MetaGymCalendarMode.week
        ? days.last.isBefore(maxOnly)
        : !DateTime(selected.year, selected.month + 1, 1).isAfter(maxOnly);

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    final calendarSelector = Column(
      key: selectorKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final inlineMode = constraints.maxWidth >= 295 && textScale <= 1.15;
            final prevBtn = _navButton(
              context,
              palette: palette,
              tooltip: 'Kỳ trước',
              svgAsset: MetaGymIcons.commonChevronLeft,
              fallbackIcon: Icons.chevron_left_rounded,
              onTap: () => onSelectDate(
                metaGymShiftCalendarPeriod(selected, mode, -1, maxDate: maxOnly),
              ),
            );
            final nextBtn = _navButton(
              context,
              palette: palette,
              tooltip: 'Kỳ sau',
              svgAsset: MetaGymIcons.commonChevronRight,
              fallbackIcon: Icons.chevron_right_rounded,
              onTap: canShiftNext
                  ? () => onSelectDate(
                      metaGymShiftCalendarPeriod(
                        selected,
                        mode,
                        1,
                        maxDate: maxOnly,
                      ),
                    )
                  : null,
            );
            final titleBlock = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: inlineMode
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  mode == MetaGymCalendarMode.week ? weekEyebrow : monthEyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: inlineMode
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: Text(
                    period,
                    maxLines: 1,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: MetaGymTheme.tabularFigures,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            );

            Widget modeToggle({bool expand = false}) => Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: palette.metricPanelBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: palette.metricPanelBorder),
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  _modeButton(
                    context,
                    palette: palette,
                    label: 'Tuần',
                    value: MetaGymCalendarMode.week,
                    expand: expand,
                  ),
                  const SizedBox(width: 2),
                  _modeButton(
                    context,
                    palette: palette,
                    label: 'Tháng',
                    value: MetaGymCalendarMode.month,
                    expand: expand,
                  ),
                ],
              ),
            );

            if (inlineMode) {
              return Row(
                children: [
                  prevBtn,
                  const SizedBox(width: 4),
                  Expanded(child: titleBlock),
                  nextBtn,
                  const SizedBox(width: 4),
                  modeToggle(),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    prevBtn,
                    Expanded(child: titleBlock),
                    nextBtn,
                  ],
                ),
                const SizedBox(height: 8),
                modeToggle(expand: true),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        if (mode == MetaGymCalendarMode.month) ...[
          Row(
            children: [
              for (final day in _kCalendarWeekdays)
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        if (mode == MetaGymCalendarMode.week)
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 46),
                    child: _dayCell(
                      context,
                      palette: palette,
                      day: day,
                      selected: selected,
                      today: todayOnly,
                      maxOnly: maxOnly,
                      showNumber: false,
                    ),
                  ),
                ),
            ],
          )
        else
          Builder(
            builder: (context) {
              final cellExtent = (44 * textScale.clamp(1.0, 1.5))
                  .ceilToDouble()
                  .clamp(44.0, 76.0)
                  .toDouble();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  mainAxisExtent: cellExtent,
                ),
                itemCount: days.length,
                itemBuilder: (_, index) => _dayCell(
                  context,
                  palette: palette,
                  day: days[index],
                  selected: selected,
                  today: todayOnly,
                  maxOnly: maxOnly,
                  showNumber: true,
                ),
              );
            },
          ),
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        calendarSelector,
        if (legend != null) ...[
          const SizedBox(height: 8),
          legend!,
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 8),
          MetaGymMetricPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 10,
                        thickness: 1,
                        color: palette.borderSolid,
                      ),
                    Expanded(child: _statCell(palette, stats[i])),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: 8),
          footer!,
        ],
      ],
    );

    if (!wrapInHeroCard) return content;
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(12),
      child: content,
    );
  }

  Widget _navButton(
    BuildContext context, {
    required MetaGymPalette palette,
    required String tooltip,
    required String svgAsset,
    required IconData fallbackIcon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.38,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.metricPanelBg,
                      border: Border.all(color: palette.metricPanelBorder),
                    ),
                    child: Center(
                      child: MetaGymSvgIcon(
                        svgAsset,
                        size: 16,
                        fallbackIcon: fallbackIcon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required MetaGymPalette palette,
    required String label,
    required MetaGymCalendarMode value,
    required bool expand,
  }) {
    final active = mode == value;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!active) onModeChanged(value);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: MetaGymTheme.stateDurationOf(context),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minWidth: expand ? 0 : 48,
            minHeight: 30,
          ),
          padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 10, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? MetaGymTheme.brandOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : palette.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }

  Widget _dayCell(
    BuildContext context, {
    required MetaGymPalette palette,
    required DateTime day,
    required DateTime selected,
    required DateTime today,
    required DateTime? maxOnly,
    required bool showNumber,
  }) {
    final dayIso = metaGymIsoDate(day);
    final isSelected = dayIso == metaGymIsoDate(selected);
    final isToday = dayIso == metaGymIsoDate(today);
    final isDisabled = maxOnly != null && day.isAfter(maxOnly);
    final outside = showNumber && day.month != selected.month;

    List<Color> dots;
    if (isDisabled) {
      dots = const [];
    } else if (dotColorsForDay != null) {
      final raw = dotColorsForDay!(day);
      dots = raw
          .take(3)
          .map((c) => isSelected ? Colors.white : c)
          .toList();
    } else {
      final badgeCount = (badgeCountForDay?.call(day) ?? 0).clamp(0, 3);
      final badgeColor = isSelected
          ? Colors.white
          : (badgeColorForDay?.call(day) ?? palette.success);
      dots = List.filled(badgeCount, badgeColor);
    }

    return MetaGymTap(
      onTap: isDisabled ? null : () => onSelectDate(day),
      borderRadius: BorderRadius.circular(11),
      child: Opacity(
        opacity: isDisabled ? 0.36 : 1.0,
        child: AnimatedContainer(
          duration: MetaGymTheme.stateDurationOf(context),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(1.5),
          padding: EdgeInsets.symmetric(vertical: showNumber ? 3 : 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6E48), MetaGymTheme.brandOrange],
                  )
                : null,
            color: isSelected ? null : palette.metricPanelBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              width: isToday && !isSelected ? 1.25 : 1,
              color: isSelected
                  ? MetaGymTheme.brandOrange
                  : isToday
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.65)
                  : palette.metricPanelBorder,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!showNumber)
                    Text(
                      _kCalendarWeekdays[day.weekday - 1],
                      style: TextStyle(
                        color: isSelected ? Colors.white : palette.textPrimary,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : outside
                            ? palette.textSecondary.withValues(alpha: 0.55)
                            : palette.textPrimary,
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  if (dots.isNotEmpty) ...[
                    const SizedBox(height: 2.5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var d = 0; d < dots.length; d++) ...[
                          if (d > 0) const SizedBox(width: 2.5),
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dots[d],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCell(MetaGymPalette palette, MetaGymCalendarStat stat) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            stat.value,
            maxLines: 1,
            style: TextStyle(
              color: stat.accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: MetaGymTheme.tabularFigures,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
