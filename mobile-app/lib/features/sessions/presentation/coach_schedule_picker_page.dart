import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';

enum _PickerCalMode { week, month }

class _PickedShift {
  const _PickedShift({
    required this.dateKey,
    required this.startsAt,
    required this.startLabel,
    required this.endLabel,
  });

  final String dateKey;
  final String startsAt;
  final String startLabel;
  final String endLabel;
}

class _ShiftDisplayItem {
  const _ShiftDisplayItem({
    required this.startLabel,
    required this.endLabel,
    required this.statusLabel,
    required this.isOpen,
    required this.isMine,
    this.startsAt,
  });

  final String startLabel;
  final String endLabel;
  final String statusLabel;
  final bool isOpen;
  final bool isMine;
  final String? startsAt;
}

/// Full-page schedule picker reusing Meta Gym's week/month calendar and Coach shifts.
class CoachSchedulePickerPage extends StatefulWidget {
  const CoachSchedulePickerPage({
    required this.api,
    required this.pack,
    required this.existingBookings,
    required this.availableToBook,
    this.bookingId,
    super.key,
  });

  final CoachV2Api api;
  final CoachRecord pack;
  final List<CoachRecord> existingBookings;
  final int availableToBook;
  final String? bookingId;

  @override
  State<CoachSchedulePickerPage> createState() =>
      _CoachSchedulePickerPageState();
}

class _CoachSchedulePickerPageState extends State<CoachSchedulePickerPage> {
  static const _weekdaysShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _weekdaysFull = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  bool get _isReschedule => widget.bookingId != null;

  late DateTime _todayGym;
  late DateTime _minDate;
  late DateTime _maxDate;
  late DateTime _selectedDate;
  _PickerCalMode _calMode = _PickerCalMode.week;

  final Map<String, List<CoachRecord>> _availableByDate = {};
  final Map<int, List<String>> _weeklyWorkStarts = {};
  final Map<String, _PickedShift> _pickedByDate = {};

  bool _loadingDay = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final gymNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    _todayGym = DateTime.utc(gymNow.year, gymNow.month, gymNow.day);
    final startsOn = DateTime.tryParse(
      '${widget.pack['startsOn'] as String? ?? ''}T00:00:00Z',
    );
    final endsOn = DateTime.parse(
      '${widget.pack['endsOn'] as String}T00:00:00Z',
    );
    _minDate = (startsOn != null && startsOn.isAfter(_todayGym))
        ? startsOn
        : _todayGym;
    _maxDate = endsOn.isBefore(_minDate) ? _minDate : endsOn;
    _selectedDate = _minDate;
    _loadInitialData();
  }

  String _ymd(DateTime dt) => dt.toIso8601String().substring(0, 10);

  String _hhmm(DateTime gymTime) => gymTime.toIso8601String().substring(11, 16);

  DateTime _gymTime(DateTime time) =>
      time.toUtc().add(const Duration(hours: 7));

  DateTime _weekMonday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  bool _isOutOfBounds(DateTime date) =>
      date.isBefore(_minDate) || date.isAfter(_maxDate);

  bool _hasExistingBookingOnDate(String dateKey) {
    return widget.existingBookings.any((b) {
      if (_isReschedule && b['id'] == widget.bookingId) return false;
      final status = b['status'] as String?;
      final charged = b['chargedAt'] != null;
      if (status != 'BOOKED' && status != 'COMPLETED' && !charged) {
        return false;
      }
      final start = DateTime.tryParse(b['startsAt'] as String? ?? '');
      if (start == null) return false;
      return _ymd(_gymTime(start)) == dateKey;
    });
  }

  Set<String> _myBookedTimesOnDate(String dateKey) {
    final result = <String>{};
    for (final b in widget.existingBookings) {
      if (b['status'] != 'BOOKED') continue;
      final start = DateTime.tryParse(b['startsAt'] as String? ?? '');
      if (start == null) continue;
      final gym = _gymTime(start);
      if (_ymd(gym) == dateKey) result.add(_hhmm(gym));
    }
    return result;
  }

  Future<void> _loadInitialData() async {
    final coachId = widget.pack['coachId'] as String?;
    await Future.wait([
      _loadSlotsForDate(_selectedDate),
      if (coachId != null && coachId.isNotEmpty) _loadWorkSlots(coachId),
    ]);
  }

  Future<void> _loadWorkSlots(String coachId) async {
    try {
      final data = await widget.api.get('/coaches/$coachId/work-slots');
      final days = (data['days'] as List? ?? const []).cast<CoachRecord>();
      if (!mounted) return;
      setState(() {
        _weeklyWorkStarts.clear();
        for (final day in days) {
          final weekday = (day['weekday'] as num?)?.toInt();
          final starts = (day['starts'] as List? ?? const []).cast<String>();
          if (weekday != null) _weeklyWorkStarts[weekday] = starts;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    final key = _ymd(date);
    if (_availableByDate.containsKey(key) || _isOutOfBounds(date)) return;
    setState(() {
      _loadingDay = true;
      _error = null;
    });
    try {
      final rows = await widget.api.list(
        '/coach-bookings/available-slots',
        query: {
          'entitlementId': widget.pack['id'],
          'date': key,
          'bookingId': ?widget.bookingId,
        },
      );
      if (mounted) {
        setState(() => _availableByDate[key] = rows);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được khung giờ trong ngày này.');
      }
    } finally {
      if (mounted) setState(() => _loadingDay = false);
    }
  }

  void _selectDate(DateTime date) {
    if (_isOutOfBounds(date)) return;
    setState(() {
      _selectedDate = date;
      _error = null;
    });
    _loadSlotsForDate(date);
  }

  void _movePeriod(int direction) {
    final next = _calMode == _PickerCalMode.week
        ? _selectedDate.add(Duration(days: direction * 7))
        : DateTime.utc(_selectedDate.year, _selectedDate.month + direction, 1);
    final clamped = next.isBefore(_minDate)
        ? _minDate
        : (next.isAfter(_maxDate) ? _maxDate : next);
    _selectDate(clamped);
  }

  String _calendarTitleText() {
    if (_calMode == _PickerCalMode.week) {
      final mon = _weekMonday(_selectedDate);
      final sun = mon.add(const Duration(days: 6));
      if (mon.month == sun.month) {
        return '${mon.day} – ${sun.day} tháng ${sun.month}';
      }
      return '${mon.day}/${mon.month} – ${sun.day}/${sun.month}';
    }
    return 'Tháng ${_selectedDate.month}, ${_selectedDate.year}';
  }

  String _selectedDayHeading() {
    final diff = _selectedDate.difference(_todayGym).inDays;
    final dd = _selectedDate.day.toString().padLeft(2, '0');
    final mm = _selectedDate.month.toString().padLeft(2, '0');
    if (diff == 0) return 'Hôm nay · $dd/$mm';
    if (diff == 1) return 'Ngày mai · $dd/$mm';
    return '${_weekdaysFull[_selectedDate.weekday - 1]} · $dd/$mm';
  }

  List<_ShiftDisplayItem> _buildDayShifts(String dateKey) {
    final available = _availableByDate[dateKey] ?? const <CoachRecord>[];
    final availByStart = <String, CoachRecord>{};
    for (final item in available) {
      final startsAt = item['startsAt'] as String?;
      if (startsAt == null) continue;
      final gymStart = _gymTime(DateTime.parse(startsAt));
      availByStart[_hhmm(gymStart)] = item;
    }

    final weeklyStarts = _weeklyWorkStarts[_selectedDate.weekday];
    final myTimes = _myBookedTimesOnDate(dateKey);
    final gymNow = _gymTime(DateTime.now());
    final allStarts = <String>{...?weeklyStarts, ...availByStart.keys}.toList()
      ..sort();

    return allStarts.map((startLabel) {
      final match = availByStart[startLabel];
      final parts = startLabel.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final endTotal = hour * 60 + minute + 90;
      final endLabel =
          '${((endTotal ~/ 60) % 24).toString().padLeft(2, '0')}:${(endTotal % 60).toString().padLeft(2, '0')}';

      if (match != null) {
        return _ShiftDisplayItem(
          startLabel: startLabel,
          endLabel: endLabel,
          statusLabel: 'Còn trống',
          isOpen: true,
          isMine: false,
          startsAt: match['startsAt'] as String,
        );
      }

      if (myTimes.contains(startLabel)) {
        return _ShiftDisplayItem(
          startLabel: startLabel,
          endLabel: endLabel,
          statusLabel: 'Bạn đã đặt',
          isOpen: false,
          isMine: true,
        );
      }

      final slotGymDt = DateTime.utc(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );
      final isPast = !slotGymDt.isAfter(gymNow);
      return _ShiftDisplayItem(
        startLabel: startLabel,
        endLabel: endLabel,
        statusLabel: isPast ? 'Đã qua giờ' : 'Đã có lịch',
        isOpen: false,
        isMine: false,
      );
    }).toList();
  }

  void _toggleShift(String dateKey, _ShiftDisplayItem item) {
    final startsAt = item.startsAt;
    if (!item.isOpen || startsAt == null || _submitting) return;
    final currentPick = _pickedByDate[dateKey];
    setState(() {
      _error = null;
      if (currentPick != null && currentPick.startsAt == startsAt) {
        _pickedByDate.remove(dateKey);
        return;
      }
      if (_isReschedule) {
        _pickedByDate
          ..clear()
          ..[dateKey] = _PickedShift(
            dateKey: dateKey,
            startsAt: startsAt,
            startLabel: item.startLabel,
            endLabel: item.endLabel,
          );
        return;
      }
      final maxAllowed = widget.availableToBook;
      if (currentPick == null &&
          maxAllowed > 0 &&
          _pickedByDate.length >= maxAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gói hiện chỉ còn đặt thêm tối đa $maxAllowed buổi.'),
          ),
        );
        return;
      }
      _pickedByDate[dateKey] = _PickedShift(
        dateKey: dateKey,
        startsAt: startsAt,
        startLabel: item.startLabel,
        endLabel: item.endLabel,
      );
    });
  }

  Future<void> _submit() async {
    if (_pickedByDate.isEmpty || _submitting) return;
    final picks = _pickedByDate.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isReschedule) {
        await widget.api.patch('/coach-bookings/${widget.bookingId}', {
          'action': 'RESCHEDULE',
          'startsAt': picks.first.startsAt,
        });
      } else {
        for (final pick in picks) {
          await widget.api.post(
            '/coach-bookings',
            body: {
              'entitlementId': widget.pack['id'],
              'startsAt': pick.startsAt,
            },
          );
        }
      }
      if (mounted) Navigator.of(context).pop<int>(picks.length);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không xử lý được lịch. Hãy thử lại.';
          _submitting = false;
        });
      }
    }
  }

  Widget _buildCalendarCard() {
    final monthStart = DateTime.utc(_selectedDate.year, _selectedDate.month, 1);
    final gridStart = _calMode == _PickerCalMode.week
        ? _weekMonday(_selectedDate)
        : _weekMonday(monthStart);
    final daysInMonth = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final cellCount = _calMode == _PickerCalMode.week
        ? 7
        : ((((monthStart.weekday - 1) + daysInMonth) / 7).ceil() * 7);

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarArrowButton(
                icon: Icons.chevron_left_rounded,
                tooltip: _calMode == _PickerCalMode.week
                    ? 'Tuần trước'
                    : 'Tháng trước',
                onTap: () => _movePeriod(-1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _calendarTitleText(),
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CalendarArrowButton(
                icon: Icons.chevron_right_rounded,
                tooltip: _calMode == _PickerCalMode.week
                    ? 'Tuần sau'
                    : 'Tháng sau',
                onTap: () => _movePeriod(1),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF211E1C),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0x808C7766)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CalModeChip(
                      label: 'Tuần',
                      active: _calMode == _PickerCalMode.week,
                      onTap: () =>
                          setState(() => _calMode = _PickerCalMode.week),
                    ),
                    const SizedBox(width: 2),
                    _CalModeChip(
                      label: 'Tháng',
                      active: _calMode == _PickerCalMode.month,
                      onTap: () =>
                          setState(() => _calMode = _PickerCalMode.month),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_calMode == _PickerCalMode.month) ...[
            const SizedBox(height: 8),
            Row(
              children: _weekdaysShort
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFFA99F98),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 6),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              final ymd = _ymd(date);
              final selected = ymd == _ymd(_selectedDate);
              final isToday = ymd == _ymd(_todayGym);
              final isPickedDay = _pickedByDate.containsKey(ymd);
              final outsideMonth =
                  _calMode == _PickerCalMode.month &&
                  date.month != _selectedDate.month;
              final disabled = _isOutOfBounds(date);
              final hasWork =
                  !disabled &&
                  (_weeklyWorkStarts.isEmpty ||
                      (_weeklyWorkStarts[date.weekday]?.isNotEmpty ?? false));

              return InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: disabled ? null : () => _selectDate(date),
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: selected
                        ? MetaGymTheme.brandOrange
                        : isPickedDay
                        ? MetaGymTheme.progressGreen.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: !selected && isPickedDay
                        ? Border.all(
                            color: MetaGymTheme.progressGreen.withValues(
                              alpha: 0.65,
                            ),
                          )
                        : (!selected && isToday
                              ? Border.all(
                                  color: MetaGymTheme.brandOrange.withValues(
                                    alpha: 0.6,
                                  ),
                                )
                              : null),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_calMode == _PickerCalMode.week)
                            Text(
                              _weekdaysShort[index],
                              style: TextStyle(
                                color: selected
                                    ? MetaGymTheme.onPrimary
                                    : disabled
                                    ? const Color(0xFF5E6472)
                                    : const Color(0xFFA99F98),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: selected
                                  ? MetaGymTheme.onPrimary
                                  : disabled
                                  ? const Color(0xFF5E6472)
                                  : outsideMonth
                                  ? const Color(0xFF8D827B)
                                  : const Color(0xFFDED7D1),
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                      if (isPickedDay || hasWork)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : isPickedDay
                                  ? const Color(0xFF59E59A)
                                  : MetaGymTheme.brandOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShiftGroups(
    String dateKey,
    List<_ShiftDisplayItem> shifts,
    bool alreadyHasDayBooking,
  ) {
    final morning = shifts
        .where((s) => int.parse(s.startLabel.substring(0, 2)) < 12)
        .toList();
    final afternoon = shifts.where((s) {
      final h = int.parse(s.startLabel.substring(0, 2));
      return h >= 12 && h < 18;
    }).toList();
    final evening = shifts
        .where((s) => int.parse(s.startLabel.substring(0, 2)) >= 18)
        .toList();

    final groups = [
      if (morning.isNotEmpty) ('Buổi sáng', morning),
      if (afternoon.isNotEmpty) ('Buổi chiều', afternoon),
      if (evening.isNotEmpty) ('Buổi tối', evening),
    ];

    if (_loadingDay && shifts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: CircularProgressIndicator(color: MetaGymTheme.brandOrange),
        ),
      );
    }

    if (groups.isEmpty) {
      return const CoachingGraphiteCard(
        padding: EdgeInsets.all(18),
        child: Center(
          child: Text(
            'Coach không có ca trống trong ngày này. Hãy chọn ngày khác trên lịch.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MetaGymTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (alreadyHasDayBooking) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: MetaGymTheme.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: MetaGymTheme.warningAmber,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Bạn đã có 1 buổi tập trong ngày này. Mỗi ngày chỉ được đặt tối đa 1 buổi.',
                    style: TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        for (final (label, items) in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 7),
            child: Text(
              label,
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 58,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final picked =
                  _pickedByDate[dateKey]?.startsAt == item.startsAt &&
                  item.startsAt != null;
              final blockedByDay = alreadyHasDayBooking && item.isOpen;
              final enabled = item.isOpen && !blockedByDay;

              final bgColor = picked
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.20)
                  : item.isMine
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.08)
                  : enabled
                  ? MetaGymTheme.elevatedSurface
                  : MetaGymTheme.cardSurface.withValues(alpha: 0.72);
              final borderColor = picked
                  ? MetaGymTheme.brandOrange
                  : item.isMine
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.35)
                  : enabled
                  ? MetaGymTheme.darkBorderStrong
                  : MetaGymTheme.cardBorder;
              final metaColor = picked
                  ? const Color(0xFFFF987E)
                  : item.isMine
                  ? MetaGymTheme.brandOrange
                  : enabled
                  ? const Color(0xFF59E59A)
                  : MetaGymTheme.textSecondary;
              final metaText = picked
                  ? 'Đang chọn'
                  : blockedByDay
                  ? 'Đã đủ 1 buổi/ngày'
                  : item.statusLabel;

              return Material(
                color: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => _toggleShift(dateKey, item) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.startLabel} – ${item.endLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled || picked
                                ? MetaGymTheme.textPrimary
                                : MetaGymTheme.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPickedTray() {
    final sorted = _pickedByDate.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaGymTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MetaGymTheme.brandOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isReschedule
                      ? 'Ca tập mới đã chọn'
                      : 'Đã chọn ${sorted.length}/${widget.availableToBook} buổi tập',
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _submitting
                    ? null
                    : () => setState(() => _pickedByDate.clear()),
                child: const Text(
                  'Xóa hết',
                  style: TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sorted.map((pick) {
              final ddmm =
                  '${pick.dateKey.substring(8, 10)}/${pick.dateKey.substring(5, 7)}';
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _submitting
                    ? null
                    : () => setState(() => _pickedByDate.remove(pick.dateKey)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$ddmm · ${pick.startLabel}–${pick.endLabel}',
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '×',
                        style: TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _ymd(_selectedDate);
    final shifts = _buildDayShifts(dateKey);
    final alreadyHasDayBooking =
        !_isReschedule && _hasExistingBookingOnDate(dateKey);
    final openCount = alreadyHasDayBooking
        ? 0
        : shifts.where((s) => s.isOpen).length;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isReschedule
                                  ? 'Đổi khung giờ tập'
                                  : 'Đặt lịch với Coach',
                              style: const TextStyle(
                                color: Color(0xFFF6F3F0),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isReschedule
                                  ? 'Chọn 1 ca mới khả dụng'
                                  : 'Chọn nhiều ngày, tối đa 1 buổi/ngày',
                              style: const TextStyle(
                                color: Color(0xFFBCB5AE),
                                fontSize: 11.5,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                    children: [
                      if (_error != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF453A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x66FF453A)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFFF857D),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      _buildCalendarCard(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDayHeading(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            alreadyHasDayBooking
                                ? 'Đã có lịch ngày này'
                                : openCount > 0
                                ? '$openCount ca trống · 1h30/ca'
                                : 'Nghỉ / Kín lịch',
                            style: const TextStyle(
                              color: MetaGymTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildShiftGroups(dateKey, shifts, alreadyHasDayBooking),
                      if (_pickedByDate.isNotEmpty) ...[
                        _buildPickedTray(),
                        const SizedBox(height: 14),
                        CoachingPrimaryButton(
                          label: _submitting
                              ? 'Đang xử lý...'
                              : (_isReschedule ? 'Đổi giờ' : 'Đặt lịch'),
                          icon: _isReschedule
                              ? Icons.schedule_rounded
                              : Icons.add_circle_outline_rounded,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ],
                      const SizedBox(height: 14),
                      CoachingGraphiteCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: MetaGymTheme.warningAmber,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Lưu ý: Có thể chọn nhiều ngày để đặt cùng lúc (tối đa 1 buổi/ngày). Hủy hoặc đổi giờ dưới 12 giờ sẽ bị trừ 1 lượt.',
                                style: TextStyle(
                                  color: MetaGymTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _CalendarArrowButton extends StatelessWidget {
  const _CalendarArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF211E1C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x738C7766)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFF6F3F0)),
        ),
      ),
    );
  }
}

class _CalModeChip extends StatelessWidget {
  const _CalModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? MetaGymTheme.brandOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? MetaGymTheme.onPrimary : MetaGymTheme.textSecondary,
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
