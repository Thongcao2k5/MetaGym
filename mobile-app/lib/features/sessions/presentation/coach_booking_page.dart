import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_schedule_calendar.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_card.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_schedule_picker_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_day_plan_page.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

DateTime _gymTime(DateTime time) => time.toUtc().add(const Duration(hours: 7));
String _date(DateTime time) => time.toIso8601String().substring(0, 10);

String _slotLabel(String value) {
  final time = _gymTime(DateTime.parse(value));
  return '${_date(time)} · ${time.toIso8601String().substring(11, 16)}';
}

enum _BookingTab { all, packages, upcoming, history }

class CoachBookingPage extends StatefulWidget {
  const CoachBookingPage({this.coachId, super.key});
  final String? coachId;

  @override
  State<CoachBookingPage> createState() => _CoachBookingPageState();
}

class _CoachBookingPageState extends State<CoachBookingPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  bool get _isCoach => widget.coachId != null;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  List<CoachRecord> _packages = [];
  List<CoachRecord> _bookings = [];
  List<CoachRecord> _blocks = [];
  List<CoachRecord> _days = [];
  TrainingPlan? _activePlan;
  int _unreadNotifications = 0;
  _BookingTab _currentTab = _BookingTab.all;
  DateTime _calendarDate = metaGymDateOnly(_gymTime(DateTime.now()));
  MetaGymCalendarMode _calendarMode = MetaGymCalendarMode.week;
  bool _filterByCalendarDate = false;

  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không xử lý được lịch. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final apiClient = context.read<ApiClient>();
    final bookings = await _api.list('/coach-bookings');
    final packages = _isCoach
        ? <CoachRecord>[]
        : await _api.list('/coach-entitlements');
    final blocks = _isCoach
        ? await _api.list('/coach-bookings/blocks')
        : <CoachRecord>[];
    final schedule = _isCoach
        ? await _api.get('/coaches/${widget.coachId}/work-slots')
        : null;

    int unread = 0;
    if (_isCoach) {
      try {
        final notifs = await _api.list('/coach-notifications');
        unread = notifs.where((item) => item['readAt'] == null).length;
      } catch (_) {}
    }

    TrainingPlan? activePlan;
    if (!_isCoach) {
      try {
        activePlan = await MemberTrainingApi(apiClient).getActive();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _bookings = bookings;
        _packages = packages;
        _blocks = blocks;
        _days = (schedule?['days'] as List? ?? []).cast<CoachRecord>();
        _activePlan = activePlan;
        _unreadNotifications = unread;
        _loaded = true;
      });
    }
  }

  Future<void> _openSchedulePicker(
    CoachRecord pack, {
    String? bookingId,
  }) async {
    if (_busy) return;
    if (bookingId != null) {
      final original = _bookings
          .where((entry) => entry['id'] == bookingId)
          .firstOrNull;
      if (original != null &&
          _willCharge(original) &&
          !await _confirmCharge('Đổi giờ tập')) {
        return;
      }
      if (!mounted) return;
    }

    final remaining = (pack['remainingSessions'] as num?)?.toInt() ?? 0;
    final bookedCount = _bookings
        .where(
          (b) => b['entitlementId'] == pack['id'] && b['status'] == 'BOOKED',
        )
        .length;
    final availableToBook = bookingId != null
        ? 1
        : (remaining - bookedCount).clamp(0, remaining);

    final changedCount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CoachSchedulePickerPage(
          api: _api,
          pack: pack,
          existingBookings: _bookings,
          availableToBook: availableToBook,
          bookingId: bookingId,
          activePlan: _activePlan,
        ),
      ),
    );
    if (changedCount != null && changedCount > 0 && mounted) {
      await _run(_reload);
      if (mounted) {
        showCoachingSnackBar(
          context,
          bookingId != null
              ? 'Đã đổi lịch buổi tập thành công.'
              : 'Đã đặt $changedCount buổi tập thành công.',
        );
      }
    }
  }

  Future<String?> _reason(String heading) async {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = MetaGymTheme.paletteOf(ctx);
        final isLight = MetaGymTheme.isLightPalette(ctx);
        return AlertDialog(
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xF0241F1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
              width: 1.1,
            ),
          ),
          title: Text(
            heading,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextFormField(
            maxLength: 500,
            autofocus: true,
            style: TextStyle(color: palette.textPrimary),
            onChanged: (value) => reason = value.trim(),
            decoration: InputDecoration(
              labelText: 'Lý do',
              labelStyle: TextStyle(color: palette.textWarmMuted),
              filled: true,
              fillColor: palette.metricPanelBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: BorderSide(color: palette.metricPanelBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: BorderSide(color: palette.metricPanelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: const BorderSide(
                  color: MetaGymTheme.brandOrange,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: palette.textWarmMuted,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: MetaGymTheme.onPrimary,
                minimumSize: const Size(96, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (reason.isNotEmpty) Navigator.pop(ctx, reason);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resolve(CoachRecord booking, String action) async {
    if (!_isCoach &&
        action == 'CANCEL' &&
        _willCharge(booking) &&
        !await _confirmCharge('Hủy buổi tập')) {
      return;
    }
    final reason = _isCoach && action == 'CANCEL'
        ? await _reason('Hủy buổi tập')
        : null;
    if (!mounted || (_isCoach && action == 'CANCEL' && reason == null)) return;
    await _run(() async {
      await _api.patch('/coach-bookings/${booking['id']}', {
        'action': action,
        'reason': ?reason,
      });
      await _reload();
    });
  }

  bool _willCharge(CoachRecord booking) =>
      DateTime.parse(booking['startsAt'] as String).difference(DateTime.now()) <
      const Duration(hours: 12);

  Future<bool> _confirmCharge(String title) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) {
            final palette = MetaGymTheme.paletteOf(dialog);
            final isLight = MetaGymTheme.isLightPalette(dialog);
            return AlertDialog(
              backgroundColor: isLight
                  ? palette.surfaceSolid
                  : const Color(0xF0241F1B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
                  width: 1.1,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Còn dưới 12 giờ đến buổi tập. Nếu tiếp tục, gói Coach sẽ bị trừ một lượt.',
                style: TextStyle(color: palette.textPrimary, height: 1.45),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: palette.textWarmMuted,
                  ),
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Quay lại'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    foregroundColor: MetaGymTheme.onPrimary,
                    minimumSize: const Size(96, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Tiếp tục'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _block() async {
    final now = _gymTime(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 190)),
      builder: (context, child) {
        final palette = MetaGymTheme.paletteOf(context);
        final isLight = MetaGymTheme.isLightPalette(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isLight
                ? ColorScheme.light(
                    primary: MetaGymTheme.primary,
                    onPrimary: MetaGymTheme.onPrimary,
                    surface: palette.surfaceSolid,
                    onSurface: palette.textPrimary,
                    surfaceContainerHigh: palette.surfaceRaised,
                  )
                : const ColorScheme.dark(
                    primary: MetaGymTheme.primary,
                    onPrimary: MetaGymTheme.onPrimary,
                    surface: Color(0xF0241F1B),
                    onSurface: Color(0xFFF7F9FC),
                    surfaceContainerHigh: Color(0xFF2B2622),
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isLight
                  ? palette.surfaceSolid
                  : const Color(0xF0241F1B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
                  width: 1.1,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (day == null || !mounted) return;

    final starts =
        (_days
                        .where((row) => row['weekday'] == day.weekday)
                        .firstOrNull?['starts']
                    as List? ??
                const [])
            .map((e) => e.toString())
            .toList();

    final time = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = MetaGymTheme.paletteOf(ctx);
        final isLight = MetaGymTheme.isLightPalette(ctx);
        return SimpleDialog(
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xF0241F1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
              width: 1.1,
            ),
          ),
          title: Text(
            'Chọn giờ cần khóa',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          children: [
            if (starts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  'Ngày này không có lịch làm việc.',
                  style: TextStyle(color: palette.textWarmMuted),
                ),
              ),
            for (final slot in starts)
              SimpleDialogOption(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                onPressed: () => Navigator.pop(ctx, slot),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.metricPanelBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.metricPanelBorder),
                  ),
                  child: Row(
                    children: [
                      MetaGymSvgIcon(MetaGymIcons.timeClock, size: 18, fallbackIcon: Icons.schedule_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                      MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 18, fallbackIcon: Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: palette.textWarmMuted,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (time == null || !mounted) return;

    final reason = await _reason('Khóa khung giờ');
    if (reason == null || !mounted) return;
    await _setBlock('${_date(day)}T$time:00+07:00', reason: reason);
  }

  Future<void> _setBlock(String slot, {String? reason}) => _run(() async {
    await _api.put('/coach-bookings/blocks', {
      'startsAt': slot,
      'blocked': reason != null,
      'reason': ?reason,
    });
    await _reload();
  });

  Future<void> _editSchedule() async {
    final result = await showDialog<List<CoachRecord>>(
      context: context,
      builder: (ctx) => _CoachScheduleBuilderDialog(initialDays: _days),
    );
    if (result == null || !mounted) return;

    await _run(() async {
      await _api.put('/coach/work-slots', {'days': result});
      await _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final now = DateTime.now();
    final gymNow = _date(_gymTime(now));

    final upcomingBookings = _bookings.where((b) {
      if (b['status'] != 'BOOKED') return false;
      final startsAt = DateTime.tryParse(b['startsAt'] as String? ?? '');
      if (startsAt == null || !startsAt.isAfter(now)) return false;
      if (_filterByCalendarDate &&
          _date(_gymTime(startsAt)) != metaGymIsoDate(_calendarDate)) {
        return false;
      }
      return true;
    }).toList();

    final pastBookings = _bookings.where((b) {
      final startsAt = DateTime.tryParse(b['startsAt'] as String? ?? '');
      final isPast =
          b['status'] != 'BOOKED' || startsAt == null || !startsAt.isAfter(now);
      if (!isPast) return false;
      if (_filterByCalendarDate && startsAt != null) {
        return _date(_gymTime(startsAt)) == metaGymIsoDate(_calendarDate);
      }
      return true;
    }).toList();

    final showPackages =
        _currentTab == _BookingTab.all ||
        _currentTab == _BookingTab.packages;
    final showUpcoming =
        _currentTab == _BookingTab.all ||
        _currentTab == _BookingTab.upcoming;
    final showHistory =
        _currentTab == _BookingTab.history ||
        (_currentTab == _BookingTab.all &&
            (_isCoach || pastBookings.isNotEmpty || _filterByCalendarDate));

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, pastBookings),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: _buildSegmentedTabs(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: isLight
                        ? palette.surfaceSolid
                        : const Color(0xFF2B2622),
                    onRefresh: _reload,
                    child: !_loaded && _busy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.brandOrange,
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              MediaQuery.paddingOf(context).bottom + 36,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                              if (_busy)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: LinearProgressIndicator(
                                    color: MetaGymTheme.brandOrange,
                                    backgroundColor: isLight
                                        ? palette.borderSolid
                                        : const Color(0x5426221F),
                                  ),
                                ),
                              if (_error != null)
                                if (_isCoach)
                                  CoachingErrorBanner(message: _error!)
                                else
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? palette.error.withValues(alpha: 0.10)
                                          : const Color(0xD4331E1E),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: palette.error.withValues(
                                          alpha: isLight ? 0.45 : 0.60,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        MetaGymSvgIcon(MetaGymIcons.stateError, size: 20, fallbackIcon: Icons.error_outline_rounded),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: isLight
                                                  ? palette.error
                                                  : const Color(0xFFFFB2B6),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                              if (_isCoach) ...[
                                if (showPackages) ...[
                                  _buildSectionHeader(
                                    title: 'Lịch làm việc hằng tuần',
                                    subtitle:
                                        '${_days.length} ngày đã thiết lập',
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                  const SizedBox(height: 8),
                                  CoachingGraphiteCard(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _days.isEmpty
                                                    ? 'Chưa có lịch làm việc tuần'
                                                    : 'Lịch nhận đặt buổi 1:1',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            CoachingPill(
                                              label: '${_days.length}/7 ngày',
                                              tone: _days.length >= 6
                                                  ? CoachingPillTone.green
                                                  : CoachingPillTone.amber,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (_days.isEmpty)
                                          Text(
                                            'Bạn chưa thiết lập lịch làm việc tuần. Vui lòng cấu hình tối thiểu 6 ngày làm việc.',
                                            style: TextStyle(
                                              color: palette.textWarmMuted,
                                              fontSize: 13,
                                              height: 1.45,
                                            ),
                                          )
                                        else
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              for (final day in _days)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 11,
                                                        vertical: 7,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: palette.metricPanelBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: palette
                                                          .metricPanelBorder,
                                                    ),
                                                  ),
                                                  child: Text.rich(
                                                    TextSpan(
                                                      text: day['weekday'] == 7
                                                          ? 'CN'
                                                          : 'T${(day['weekday'] as int) + 1}',
                                                      style: TextStyle(
                                                        color:
                                                            palette.primaryText,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              ' · ${(day['starts'] as List).length} ca',
                                                          style: TextStyle(
                                                            color: palette
                                                                .textPrimary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontFeatures:
                                                                MetaGymTheme
                                                                    .tabularFigures,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        const SizedBox(height: 14),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final textScale =
                                                MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(1.0);
                                            final stackButtons =
                                                constraints.maxWidth < 290 ||
                                                textScale > 1.1;
                                            final editButton = FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    MetaGymTheme.primary,
                                                foregroundColor:
                                                    MetaGymTheme.onPrimary,
                                                minimumSize: const Size(0, 48),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        MetaGymTheme
                                                            .radiusInput,
                                                      ),
                                                ),
                                              ),
                                              onPressed: _busy
                                                  ? null
                                                  : _editSchedule,
                                              icon: const MetaGymSvgIcon(MetaGymIcons.workoutPlanCalendar, size: 18, fallbackIcon: Icons.edit_calendar_rounded),
                                              label: const Text(
                                                'Cấu hình lịch tuần',
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );
                                            final blockButton = OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor:
                                                    palette.metricPanelBg,
                                                foregroundColor:
                                                    palette.textPrimary,
                                                minimumSize: const Size(48, 48),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10,
                                                    ),
                                                side: BorderSide(
                                                  color:
                                                      palette.metricPanelBorder,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        MetaGymTheme
                                                            .radiusInput,
                                                      ),
                                                ),
                                              ),
                                              onPressed:
                                                  _busy || _days.isEmpty
                                                      ? null
                                                      : _block,
                                              icon: MetaGymSvgIcon(MetaGymIcons.commBlock, size: 18, fallbackIcon: Icons.block_rounded),
                                              label: Text(
                                                'Khóa giờ',
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: palette.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                            if (stackButtons) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  editButton,
                                                  const SizedBox(height: 8),
                                                  blockButton,
                                                ],
                                              );
                                            }
                                            return Row(
                                              children: [
                                                Expanded(child: editButton),
                                                const SizedBox(width: 10),
                                                blockButton,
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (_blocks.isNotEmpty && showPackages) ...[
                                  _buildSectionHeader(
                                    title: 'Khung giờ đã khóa',
                                    subtitle: '${_blocks.length} khung giờ',
                                    icon: Icons.lock_clock_rounded,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final block in _blocks)
                                    CoachingGraphiteCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                        vertical: 12,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: isLight
                                                  ? palette.warning.withValues(
                                                      alpha: 0.14,
                                                    )
                                                  : const Color(0xFF45311D),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              border: Border.all(
                                                color: isLight
                                                    ? palette.warning
                                                          .withValues(
                                                            alpha: 0.40,
                                                          )
                                                    : const Color(0xFF815423),
                                              ),
                                            ),
                                            child: MetaGymSvgIcon(MetaGymIcons.settingPrivacyLock, size: 18, fallbackIcon: Icons.lock_clock_rounded),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _slotLabel(
                                                    block['startsAt'] as String,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: palette.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    fontFeatures: MetaGymTheme
                                                        .tabularFigures,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  block['reason'] as String? ??
                                                      'Khóa lịch',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        palette.textWarmMuted,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(68, 48),
                                              foregroundColor:
                                                  palette.primaryText,
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => _setBlock(
                                                    block['startsAt'] as String,
                                                  ),
                                            child: const Text(
                                              'Mở giờ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                ],
                              ] else ...[
                                // Member: Gói Coach đang hiệu lực
                                if (showPackages) ...[
                                  if (_packages.isNotEmpty) ...[
                                    _buildSectionHeader(
                                      title: 'Gói Coach đang hiệu lực',
                                      subtitle: '${_packages.length} gói',
                                      icon: Icons.workspace_premium_rounded,
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  if (_loaded && _packages.isEmpty)
                                    _buildEmptyPackageHeroCard(context),
                                  for (final pack in _packages) ...[
                                    _buildPackageCard(pack, gymNow, now),
                                    const SizedBox(height: 8),
                                  ],
                                  const SizedBox(height: 4),
                                ],
                              ],

                              if (_loaded &&
                                  (_currentTab == _BookingTab.upcoming ||
                                      _currentTab == _BookingTab.history)) ...[
                                _buildScheduleCalendarSection(now),
                                const SizedBox(height: 16),
                              ],

                              // Section: Lịch sắp tới
                              if (showUpcoming) ...[
                                _buildSectionHeader(
                                  title: _isCoach
                                      ? 'Lịch tập sắp tới'
                                      : 'Buổi tập sắp tới',
                                  subtitle: _isCoach
                                      ? '${upcomingBookings.length} buổi đã đặt'
                                      : '${upcomingBookings.length} lịch hẹn',
                                  icon: Icons.event_available_rounded,
                                ),
                                const SizedBox(height: 6),
                                if (_loaded && upcomingBookings.isEmpty)
                                  _buildEmptyStateCard(
                                    _filterByCalendarDate
                                        ? 'Không có buổi tập nào vào ngày đã chọn.'
                                        : 'Chưa có buổi tập nào sắp tới.',
                                  ),
                                for (final booking in upcomingBookings) ...[
                                  if (_isCoach)
                                    _buildBookingCard(
                                      booking,
                                      isUpcoming: true,
                                      now: now,
                                    )
                                  else
                                    _buildMemberBookingCard(booking, now: now),
                                  const SizedBox(height: 8),
                                ],
                                const SizedBox(height: 10),
                              ],

                              if (!_isCoach && showUpcoming) ...[
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MetaGymSvgIcon(MetaGymIcons.commonInfo, size: 16, fallbackIcon: Icons.info_outline_rounded),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          'Lưu ý: Hủy hoặc đổi giờ trong vòng 12 giờ trước buổi tập sẽ bị trừ 1 lượt trong gói.',
                                          style: TextStyle(
                                            color: palette.textWarmMuted,
                                            fontSize: 12,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (_loaded && _currentTab == _BookingTab.all) ...[
                                _buildScheduleCalendarSection(now),
                                const SizedBox(height: 16),
                              ],

                              // Section: Lịch sử buổi tập
                              if (showHistory) ...[
                                _buildSectionHeader(
                                  title: 'Lịch sử buổi tập',
                                  subtitle: '${pastBookings.length} buổi',
                                  icon: Icons.history_rounded,
                                ),
                                const SizedBox(height: 8),
                                if (_loaded && pastBookings.isEmpty)
                                  _buildEmptyStateCard(
                                    'Chưa có lịch sử buổi tập với Coach.',
                                  ),
                                for (final booking in pastBookings) ...[
                                  if (_isCoach)
                                    _buildBookingCard(
                                      booking,
                                      isUpcoming: false,
                                      now: now,
                                    )
                                  else
                                    _buildMemberBookingCard(booking, now: now),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 20),
                              ],
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

  void _pushOrFallback(
    BuildContext context, {
    required String route,
    required Widget fallbackPage,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(route);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => fallbackPage),
    );
  }

  Widget _buildEmptyPackageHeroCard(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.35),
                  ),
                ),
                child: MetaGymSvgIcon(MetaGymIcons.socialGroup, size: 22, fallbackIcon: Icons.groups_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn chưa có gói Coach.',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Khám phá hồ sơ chuyên môn, lịch làm việc và chọn gói PT 1:1 phù hợp để bắt đầu đặt lịch tập.',
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CoachingPrimaryButton(
            label: 'Khám phá Coach',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _pushOrFallback(
              context,
              route: '/member/features/coaching',
              fallbackPage: const CoachSelectionPage(),
            ),
          ),
          const SizedBox(height: 8),
          CoachingSecondaryButton(
            label: 'Coach của tôi',
            expand: true,
            onPressed: () => _pushOrFallback(
              context,
              route: '/member/features/my-coach',
              fallbackPage: const MemberCoachingPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCalendarSection(DateTime now) {
    final palette = MetaGymTheme.paletteOf(context);
    final countsByDate = <String, int>{};
    var upcomingCount = 0;

    for (final b in _bookings) {
      final startsAt = DateTime.tryParse(b['startsAt'] as String? ?? '');
      if (startsAt == null) continue;
      final iso = _date(_gymTime(startsAt));
      countsByDate[iso] = (countsByDate[iso] ?? 0) + 1;
      if (b['status'] == 'BOOKED' && startsAt.isAfter(now)) {
        upcomingCount++;
      }
    }

    final visibleDays = metaGymVisibleCalendarDays(_calendarDate, _calendarMode);
    var sessionsInPeriod = 0;
    var activeDaysInPeriod = 0;
    for (final day in visibleDays) {
      if (_calendarMode == MetaGymCalendarMode.month &&
          day.month != _calendarDate.month) {
        continue;
      }
      final c = countsByDate[metaGymIsoDate(day)] ?? 0;
      if (c > 0) {
        activeDaysInPeriod++;
        sessionsInPeriod += c;
      }
    }
    final filteredPlanDay = _filterByCalendarDate && !_isCoach
        ? _matchedPlanDayForDate(_calendarDate)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaGymScheduleCalendar(
          selectedDate: _calendarDate,
          today: metaGymDateOnly(_gymTime(now)),
          mode: _calendarMode,
          onModeChanged: (mode) => setState(() => _calendarMode = mode),
          onSelectDate: (picked) {
            final normalized = metaGymDateOnly(picked);
            setState(() {
              if (_filterByCalendarDate &&
                  metaGymIsoDate(_calendarDate) == metaGymIsoDate(normalized)) {
                _filterByCalendarDate = false;
              } else {
                _calendarDate = normalized;
                _filterByCalendarDate = true;
              }
            });
          },
          badgeCountForDay: (day) =>
              (countsByDate[metaGymIsoDate(day)] ?? 0).clamp(0, 3),
          badgeColorForDay: (_) => palette.primaryText,
          stats: [
            MetaGymCalendarStat(
              label: _calendarMode == MetaGymCalendarMode.week
                  ? 'Tuần này'
                  : 'Tháng này',
              value: '$sessionsInPeriod buổi',
              accent: palette.primaryText,
            ),
            MetaGymCalendarStat(
              label: 'Buổi sắp tới',
              value: '$upcomingCount lịch',
              accent: palette.success,
            ),
            MetaGymCalendarStat(
              label: 'Ngày đặt',
              value: '$activeDaysInPeriod ngày',
              accent: palette.reflection,
            ),
          ],
        ),
        if (_filterByCalendarDate) ...[
          const SizedBox(height: 8),
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt_rounded,
                      size: 16,
                      color: palette.primaryText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang lọc ngày ${_formatDmy(metaGymIsoDate(_calendarDate))}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: palette.primaryText,
                      ),
                      onPressed: () =>
                          setState(() => _filterByCalendarDate = false),
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (filteredPlanDay != null) ...[
                  Divider(
                    height: 12,
                    thickness: 1,
                    color: palette.borderSolid.withValues(alpha: 0.55),
                  ),
                  InkWell(
                    onTap: () => _openPlanDay(filteredPlanDay),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            size: 15,
                            color: palette.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Giáo án hôm đó: ${filteredPlanDay.title} · ${filteredPlanDay.exercises.length} bài',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.success,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: palette.success,
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
      ],
    );
  }

  Widget _buildEmptyStateCard(String message) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: CoachingGraphiteCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: palette.textWarmMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<CoachRecord> pastBookings) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
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
                  _isCoach ? 'LỊCH DẠY CÁ NHÂN' : 'HUẤN LUYỆN 1:1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lịch Coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (!_isCoach)
                  Text(
                    'Đặt lịch & quản lý buổi tập 1:1',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isCoach)
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.workoutHistory,
              icon: Icons.history_rounded,
              tooltip: 'Lịch sử buổi tập',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CoachBookingHistoryPage(
                    bookings: pastBookings,
                    matchPlanDay: _matchedPlanDay,
                    onOpenPlanDay: _openPlanDay,
                  ),
                ),
              ),
            )
          else ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                MetaGymCircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Thông báo Coach',
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const CoachNotificationsPage(),
                      ),
                    );
                    if (mounted) _reload();
                  },
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: IgnorePointer(
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: palette.canvas,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _unreadNotifications > 9
                              ? '9+'
                              : '$_unreadNotifications',
                          style: const TextStyle(
                            color: MetaGymTheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Tải lại',
              onTap: _busy ? null : () => _run(_reload),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.metricPanelBorder, width: 1.1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SegmentTabButton(
                label: 'Tất cả',
                active: _currentTab == _BookingTab.all,
                graphiteStyle: true,
                onTap: () => setState(() => _currentTab = _BookingTab.all),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SegmentTabButton(
                label: _isCoach ? 'Lịch tuần' : 'Gói Coach',
                active: _currentTab == _BookingTab.packages,
                graphiteStyle: true,
                onTap: () => setState(() => _currentTab = _BookingTab.packages),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SegmentTabButton(
                label: 'Sắp tới',
                active: _currentTab == _BookingTab.upcoming,
                graphiteStyle: true,
                onTap: () => setState(() => _currentTab = _BookingTab.upcoming),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SegmentTabButton(
                label: 'Lịch sử',
                active: _currentTab == _BookingTab.history,
                graphiteStyle: true,
                onTap: () => setState(() => _currentTab = _BookingTab.history),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textWarmMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDmy(String isoDate) {
    if (isoDate.length < 10) return isoDate;
    return '${isoDate.substring(8, 10)}/${isoDate.substring(5, 7)}/${isoDate.substring(0, 4)}';
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    String? suffix,
    Color? valueColor,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: palette.metricPanelBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: palette.metricPanelBorder, width: 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? palette.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                  children: [
                    if (suffix != null)
                      TextSpan(
                        text: suffix,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textWarmMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(CoachRecord pack, String gymNow, DateTime now) {
    final palette = MetaGymTheme.paletteOf(context);
    final remaining = (pack['remainingSessions'] as num?)?.toInt() ?? 0;
    final total = (pack['totalSessions'] as num?)?.toInt() ?? 0;
    final bookedCount = _bookings
        .where(
          (b) => b['entitlementId'] == pack['id'] && b['status'] == 'BOOKED',
        )
        .length;
    final availableToBook = (remaining - bookedCount).clamp(0, remaining);
    final isPaused = pack['relationshipStatus'] == 'PAUSED';
    final endsOn = pack['endsOn'] as String? ?? '';
    final isExpired =
        endsOn.isNotEmpty &&
        DateTime.parse(endsOn).isBefore(DateTime.parse(gymNow));
    final isActivePack = pack['status'] == 'ACTIVE';
    final canBook =
        isActivePack &&
        pack['relationshipStatus'] == 'ACTIVE' &&
        !isExpired &&
        availableToBook > 0;

    final coachName = (pack['coachName'] as String? ?? '').trim();
    final coachNameParts = coachName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final coachInitials = coachNameParts.isEmpty
        ? null
        : coachNameParts.length >= 2
        ? '${coachNameParts.first[0]}${coachNameParts.last[0]}'.toUpperCase()
        : coachNameParts.first.substring(0, 1).toUpperCase();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coachInitials != null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF8C45E), Color(0xFFE0952B)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF5B041).withValues(alpha: 0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      coachInitials,
                      style: const TextStyle(
                        color: Color(0xFF181B22),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!isPaused && !isExpired)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.surfaceSolid,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          coachName.isNotEmpty
                              ? coachName
                              : (pack['planName'] as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPackageStatusBadge(
                        status: pack['status'] as String,
                        relationshipStatus:
                            pack['relationshipStatus'] as String?,
                        isExpired: isExpired,
                        remaining: remaining,
                      ),
                    ],
                  ),
                  if (coachName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      pack['planName'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (endsOn.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      remaining <= 0 && isActivePack
                          ? 'Đã hết số buổi tập · Hạn ${_formatDmy(endsOn)}'
                          : 'Hạn dùng đến ${_formatDmy(endsOn)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (isActivePack) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCell(
                label: 'Còn lại',
                value: '$remaining',
                suffix: '/$total',
              ),
              const SizedBox(width: 8),
              _buildStatCell(
                label: 'Đã đặt',
                value: '$bookedCount',
                suffix: ' buổi',
              ),
              const SizedBox(width: 8),
              if (isPaused)
                _buildStatCell(
                  label: 'Trạng thái',
                  value: 'Tạm dừng',
                  valueColor: palette.warning,
                )
              else
                _buildStatCell(
                  label: 'Chưa đặt',
                  value: '$availableToBook',
                  suffix: ' lượt',
                  valueColor: availableToBook > 0
                      ? palette.primaryText
                      : palette.textPrimary,
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            pack['status'] == 'QUEUED' ? 'Chờ kích hoạt' : 'Đã kết thúc',
            style: TextStyle(color: palette.textWarmMuted, fontSize: 13),
          ),
        ],
        if (canBook) ...[
          const SizedBox(height: 8),
          CoachingPrimaryButton(
            label: 'Đặt lịch',
            icon: Icons.add_circle_outline_rounded,
            onPressed: _busy ? null : () => _openSchedulePicker(pack),
          ),
        ],
      ],
    );

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: content,
    );
  }

  Widget _buildPackageStatusBadge({
    required String status,
    required String? relationshipStatus,
    required bool isExpired,
    required int remaining,
  }) {
    if (relationshipStatus == 'PAUSED') {
      return const CoachingPill(
        label: 'Tạm ngưng',
        tone: CoachingPillTone.amber,
      );
    }

    if (isExpired) {
      return const CoachingPill(label: 'Hết hạn', tone: CoachingPillTone.amber);
    }
    if (status == 'ACTIVE' && remaining <= 0) {
      return const CoachingPill(
        label: 'Hết lượt',
        tone: CoachingPillTone.neutral,
      );
    }
    return switch (status) {
      'ACTIVE' => const CoachingPill(
        label: 'Đang hoạt động',
        tone: CoachingPillTone.green,
      ),
      'QUEUED' => const CoachingPill(
        label: 'Chờ kích hoạt',
        tone: CoachingPillTone.neutral,
      ),
      _ => const CoachingPill(
        label: 'Đã kết thúc',
        tone: CoachingPillTone.neutral,
      ),
    };
  }

  TrainingDay? _matchedPlanDay(String startsAtStr) {
    final parsed = DateTime.tryParse(startsAtStr);
    if (parsed == null) return null;
    return _matchedPlanDayForDate(_gymTime(parsed));
  }

  TrainingDay? _matchedPlanDayForDate(DateTime date) =>
      _activePlan?.dayForDate(date);

  void _openPlanDay(TrainingDay? day) {
    if (day == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MemberDayPlanPage(day: day, planTitle: _activePlan?.title),
      ),
    );
  }

  Widget _buildMemberBookingCard(CoachRecord booking, {required DateTime now}) {
    final startsAtStr = booking['startsAt'] as String;
    final matchedDay = _matchedPlanDay(startsAtStr);
    final pack = _packages
        .where((row) => row['id'] == booking['entitlementId'])
        .firstOrNull;
    final coachName = booking['coachName'] as String?;
    final primaryTitle =
        matchedDay?.title ??
        (coachName != null && coachName.trim().isNotEmpty
            ? coachName.trim()
            : 'Huấn luyện viên');
    final canReschedule =
        pack != null &&
        pack['status'] == 'ACTIVE' &&
        pack['relationshipStatus'] == 'ACTIVE';

    return CoachMemberBookingCard(
      booking: booking,
      isUpcoming: true,
      now: now,
      primaryTitle: primaryTitle,
      matchedDay: matchedDay,
      canReschedule: canReschedule,
      busy: _busy,
      onOpenCurriculum: matchedDay != null
          ? () => _openPlanDay(matchedDay)
          : null,
      onCancel: () => _resolve(booking, 'CANCEL'),
      onReschedule: canReschedule
          ? () => _openSchedulePicker(pack, bookingId: booking['id'] as String)
          : null,
    );
  }

  Widget _buildBookingCard(
    CoachRecord booking, {
    required bool isUpcoming,
    required DateTime now,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final otherName = booking[_isCoach ? 'memberName' : 'coachName'] as String?;
    final startsAtStr = booking['startsAt'] as String;
    final startsAt = DateTime.tryParse(startsAtStr);
    final status = booking['status'] as String;
    final reason = booking['reason'] as String?;
    final chargedAt = booking['chargedAt'];

    if (_isCoach) {
      final memberName = otherName != null && otherName.trim().isNotEmpty
          ? otherName.trim()
          : 'Hội viên';
      final startGym = startsAt != null ? _gymTime(startsAt) : null;
      final todayGym = _gymTime(now);
      final isToday =
          isUpcoming &&
          startGym != null &&
          startGym.year == todayGym.year &&
          startGym.month == todayGym.month &&
          startGym.day == todayGym.day;

      return CoachingGraphiteCard(
        backgroundColor: isLight
            ? (isToday ? const Color(0xFFFFF5F2) : null)
            : (isToday ? const Color(0xD4382721) : const Color(0xC42B2622)),
        padding: const EdgeInsets.all(15),
        borderColor: isToday
            ? MetaGymTheme.brandOrange.withValues(alpha: 0.65)
            : (isLight ? null : const Color(0xA3A79D92)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isUpcoming)
                  CoachingAvatar(fullName: memberName, size: 42)
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.metricPanelBg,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: palette.metricPanelBorder),
                    ),
                    child: MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 19, fallbackIcon: Icons.fitness_center_rounded),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _slotLabel(startsAtStr),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isToday
                              ? (isLight
                                    ? palette.primaryText
                                    : const Color(0xFFFF9B82))
                              : palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.25,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        memberName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textWarmMuted,
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBookingStatusChip(status, chargedAt),
              ],
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do: $reason',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (status == 'BOOKED') ...[
              const SizedBox(height: 12),
              Divider(
                color: isLight ? palette.borderSolid : const Color(0x26FFF5E9),
                height: 1,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (startsAt != null && startsAt.isAfter(now))
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(88, 48),
                        backgroundColor: isLight
                            ? palette.error.withValues(alpha: 0.08)
                            : const Color(0x80211E1C),
                        foregroundColor: palette.error,
                        side: BorderSide(
                          color: palette.error.withValues(alpha: 0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'CANCEL'),
                      child: const Text(
                        'Hủy buổi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (startsAt != null && !startsAt.isAfter(now)) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(84, 48),
                        backgroundColor: isLight
                            ? palette.warning.withValues(alpha: 0.10)
                            : const Color(0x80211E1C),
                        foregroundColor: palette.warning,
                        side: BorderSide(
                          color: isLight
                              ? palette.warning.withValues(alpha: 0.45)
                              : const Color(0xFF815423),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'NO_SHOW'),
                      child: const Text(
                        'Vắng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(112, 48),
                        backgroundColor: MetaGymTheme.progressGreen,
                        foregroundColor: const Color(0xFF06261D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'COMPLETE'),
                      child: const Text(
                        'Hoàn thành',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUpcoming
                    ? palette.chipActiveBg
                    : palette.metricPanelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUpcoming
                      ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                      : palette.metricPanelBorder,
                ),
              ),
              child: MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 20, fallbackIcon: Icons.fitness_center_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slotLabel(startsAtStr),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    otherName ?? 'Huấn luyện viên',
                    style: TextStyle(
                      color: palette.textWarmMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBookingStatusChip(status, chargedAt),
          ],
        ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Lý do: $reason',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (status == 'BOOKED') ...[
          const SizedBox(height: 12),
          Divider(
            color: isLight ? palette.borderSolid : const Color(0x26FFF5E9),
            height: 1,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (startsAt != null && startsAt.isAfter(now)) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    backgroundColor: isLight
                        ? palette.error.withValues(alpha: 0.08)
                        : const Color(0x80211E1C),
                    side: BorderSide(
                      color: palette.error.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _busy ? null : () => _resolve(booking, 'CANCEL'),
                  child: Text(
                    'Hủy buổi',
                    style: TextStyle(
                      color: isLight ? palette.error : const Color(0xFFFF9A94),
                      fontSize: 13,
                    ),
                  ),
                ),
                for (final pack in _packages.where(
                  (row) =>
                      row['id'] == booking['entitlementId'] &&
                      row['status'] == 'ACTIVE' &&
                      row['relationshipStatus'] == 'ACTIVE',
                ))
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      backgroundColor: palette.metricPanelBg,
                      foregroundColor: palette.primaryText,
                      side: BorderSide(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.65),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _openSchedulePicker(
                            pack,
                            bookingId: booking['id'] as String,
                          ),
                    child: const Text(
                      'Đổi giờ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ],
    );

    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(16),
      child: body,
    );
  }

  Widget _buildBookingStatusChip(String status, Object? chargedAt) {
    if (_isCoach) {
      return switch (status) {
        'BOOKED' => const CoachingPill(
          label: 'Đã đặt',
          tone: CoachingPillTone.coral,
        ),
        'COMPLETED' => const CoachingPill(
          label: 'Đã hoàn thành',
          tone: CoachingPillTone.green,
        ),
        'NO_SHOW' => const CoachingPill(
          label: 'Vắng mặt',
          tone: CoachingPillTone.amber,
        ),
        'CANCELLED' when chargedAt != null => const CoachingPill(
          label: 'Đã hủy · Đã trừ lượt',
          tone: CoachingPillTone.amber,
        ),
        _ => const CoachingPill(
          label: 'Đã hủy',
          tone: CoachingPillTone.neutral,
        ),
      };
    }

    return switch (status) {
      'BOOKED' => const CoachingPill(
        label: 'Đã đặt',
        tone: CoachingPillTone.coral,
      ),
      'COMPLETED' => const CoachingPill(
        label: 'Đã hoàn thành',
        tone: CoachingPillTone.green,
      ),
      _ => CoachingPill(
        label: chargedAt != null ? 'Đã hủy · Đã trừ lượt' : 'Đã hủy',
        tone: chargedAt != null
            ? CoachingPillTone.amber
            : CoachingPillTone.neutral,
      ),
    };
  }
}

class _SegmentTabButton extends StatelessWidget {
  const _SegmentTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.graphiteStyle = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool graphiteStyle;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final activeBg = isLight
        ? MetaGymTheme.brandOrange
        : graphiteStyle
        ? const Color(0xFF472C22)
        : const Color(0xFF544037);
    return Material(
      color: active ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: graphiteStyle && active && !isLight
                  ? Border.all(color: MetaGymTheme.brandOrange, width: 1.2)
                  : null,
            ),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : palette.textWarmMuted,
                fontSize: 12,
                height: 1.15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog cấu hình lịch làm việc hằng tuần cho Coach:
class _CoachScheduleBuilderDialog extends StatefulWidget {
  const _CoachScheduleBuilderDialog({required this.initialDays});
  final List<CoachRecord> initialDays;

  @override
  State<_CoachScheduleBuilderDialog> createState() =>
      _CoachScheduleBuilderDialogState();
}

class _CoachScheduleBuilderDialogState
    extends State<_CoachScheduleBuilderDialog> {
  static const List<Map<String, dynamic>> _presets = [
    {
      'label': 'Ca sáng tiêu chuẩn (08:00 – 14:00)',
      'slots': ['08:00', '09:30', '11:00', '12:30'],
    },
    {
      'label': 'Ca sáng sớm (07:00 – 13:00)',
      'slots': ['07:00', '08:30', '10:00', '11:30'],
    },
    {
      'label': 'Ca chiều (14:00 – 20:00)',
      'slots': ['14:00', '15:30', '17:00', '18:30'],
    },
  ];

  late final Map<int, List<String>> _daySlots;

  @override
  void initState() {
    super.initState();
    _daySlots = {};
    for (final day in widget.initialDays) {
      final w = day['weekday'] as int;
      final starts = (day['starts'] as List? ?? []).cast<String>();
      _daySlots[w] = List<String>.from(starts);
    }
    if (_daySlots.isEmpty) {
      for (var w = 1; w <= 6; w++) {
        _daySlots[w] = List<String>.from(_presets[0]['slots'] as List);
      }
    }
  }

  void _applyPresetToAll(List<String> slots) {
    setState(() {
      for (var w = 1; w <= 6; w++) {
        _daySlots[w] = List<String>.from(slots);
      }
    });
  }

  void _toggleDay(int weekday, bool active) {
    setState(() {
      if (active) {
        _daySlots[weekday] = List<String>.from(_presets[0]['slots'] as List);
      } else {
        _daySlots.remove(weekday);
      }
    });
  }

  void _setSlotsForDay(int weekday, List<String> slots) {
    setState(() {
      _daySlots[weekday] = List<String>.from(slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final activeCount = _daySlots.length;
    final isValid = activeCount >= 6 && activeCount <= 7;

    return Dialog(
      backgroundColor: isLight ? palette.surfaceSolid : const Color(0xF0241F1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
          width: 1.1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: MetaGymSvgIcon(MetaGymIcons.commonFilter, size: 20, fallbackIcon: Icons.tune_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lịch làm việc hằng tuần',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: MetaGymSvgIcon(MetaGymIcons.commonClose, fallbackIcon: Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yêu cầu tối thiểu 6 ngày/tuần, mỗi ngày 4 ca liên tiếp cách nhau 90 phút.',
              style: TextStyle(
                color: isValid ? palette.textWarmMuted : palette.error,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Áp dụng mẫu ca nhanh cho Thứ 2 - Thứ 7:',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    backgroundColor: palette.metricPanelBg,
                    side: BorderSide(color: palette.metricPanelBorder),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: Text(
                      preset['label'] as String,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _applyPresetToAll(
                      (preset['slots'] as List).cast<String>(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final weekday = index + 1;
                  final dayName = weekday == 7
                      ? 'Chủ nhật'
                      : 'Thứ ${weekday + 1}';
                  final isActive = _daySlots.containsKey(weekday);
                  final slots = _daySlots[weekday] ?? [];

                  return Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isLight
                                ? palette.surfaceSolid
                                : const Color(0xC42B2622))
                          : palette.metricPanelBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? MetaGymTheme.brandOrange.withValues(alpha: 0.65)
                            : palette.metricPanelBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isActive,
                          materialTapTargetSize:
                              MaterialTapTargetSize.padded,
                          activeColor: MetaGymTheme.primary,
                          checkColor: MetaGymTheme.onPrimary,
                          side: BorderSide(color: palette.textSecondary),
                          onChanged: (val) => _toggleDay(weekday, val ?? false),
                        ),
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isActive
                                ? palette.textPrimary
                                : palette.textWarmMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isActive) ...[
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final s in slots)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLight
                                            ? palette.chipActiveBg
                                            : const Color(0xFF472C22),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: MetaGymTheme.primary
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          color: isLight
                                              ? palette.primaryText
                                              : const Color(0xFFFF987E),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<List<String>>(
                            tooltip: 'Đổi mẫu ca',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: MetaGymSvgIcon(MetaGymIcons.commonMore, size: 19, fallbackIcon: Icons.more_vert_rounded),
                            color: isLight
                                ? palette.surfaceSolid
                                : const Color(0xF0241F1B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isLight
                                    ? palette.borderSolid
                                    : const Color(0xA3A79D92),
                              ),
                            ),
                            onSelected: (newSlots) =>
                                _setSlotsForDay(weekday, newSlots),
                            itemBuilder: (_) => [
                              for (final p in _presets)
                                PopupMenuItem(
                                  value: (p['slots'] as List).cast<String>(),
                                  child: Text(
                                    p['label'] as String,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ] else
                          const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    foregroundColor: palette.textWarmMuted,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: MetaGymTheme.onPrimary,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    onPressed: isValid
                        ? () {
                            final days = <CoachRecord>[
                              for (var w = 1; w <= 7; w++)
                                if (_daySlots.containsKey(w))
                                  {'weekday': w, 'starts': _daySlots[w]!},
                            ];
                            Navigator.pop(context, days);
                          }
                        : null,
                    child: Text(
                      'Lưu lịch ($activeCount/6 ngày)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
