import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_card.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_schedule_picker_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_day_plan_page.dart';
import 'package:provider/provider.dart';

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
        ),
      ),
    );
    if (changedCount != null && changedCount > 0 && mounted) {
      await _run(_reload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingId != null
                  ? 'Đã đổi lịch buổi tập thành công.'
                  : 'Đã đặt $changedCount buổi tập thành công.',
            ),
          ),
        );
      }
    }
  }

  Future<String?> _reason(String heading) async {
    var reason = '';
    String? validationError;
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xB8040609),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: MetaGymTheme.cardSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
          ),
          title: Text(
            heading,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: TextFormField(
            maxLength: 500,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 14,
            ),
            onChanged: (value) {
              reason = value.trim();
              if (validationError != null && reason.isNotEmpty) {
                setDialogState(() => validationError = null);
              }
            },
            decoration: coachingInputDecoration(
              label: 'Lý do',
              errorText: validationError,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                foregroundColor: MetaGymTheme.textSecondary,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Quay lại'),
            ),
            CoachingCompactAccentButton(
              label: 'Xác nhận',
              onPressed: () {
                if (reason.isEmpty) {
                  setDialogState(
                    () => validationError = 'Vui lòng nhập lý do.',
                  );
                  return;
                }
                Navigator.pop(ctx, reason);
              },
            ),
          ],
        ),
      ),
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
          builder: (dialog) => AlertDialog(
            backgroundColor: MetaGymTheme.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Còn dưới 12 giờ đến buổi tập. Nếu tiếp tục, gói Coach sẽ bị trừ một lượt.',
              style: TextStyle(color: Color(0xFFD9DDE4), height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(color: MetaGymTheme.textSecondary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                  foregroundColor: MetaGymTheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: MetaGymTheme.primary,
            onPrimary: MetaGymTheme.onPrimary,
            surface: MetaGymTheme.cardSurface,
            onSurface: MetaGymTheme.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: MetaGymTheme.cardSurface,
          ),
        ),
        child: child!,
      ),
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
      builder: (ctx) => SimpleDialog(
        backgroundColor: MetaGymTheme.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
        ),
        title: const Text(
          'Chọn giờ cần khóa',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        children: [
          if (starts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Ngày này không có lịch làm việc.',
                style: TextStyle(color: MetaGymTheme.textSecondary),
              ),
            ),
          for (final slot in starts)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              onPressed: () => Navigator.pop(ctx, slot),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MetaGymTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetaGymTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: MetaGymTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slot,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: MetaGymTheme.textSecondary,
                    ),
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
                  minimumSize: const Size(64, 44),
                  foregroundColor: MetaGymTheme.textSecondary,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ),
          ),
        ],
      ),
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
    final now = DateTime.now();
    final gymNow = _date(_gymTime(now));

    final upcomingBookings = _bookings.where((b) {
      if (b['status'] != 'BOOKED') return false;
      final startsAt = DateTime.tryParse(b['startsAt'] as String? ?? '');
      return startsAt != null && startsAt.isAfter(now);
    }).toList();

    final pastBookings = _bookings.where((b) {
      if (b['status'] != 'BOOKED') return true;
      final startsAt = DateTime.tryParse(b['startsAt'] as String? ?? '');
      return startsAt == null || !startsAt.isAfter(now);
    }).toList();

    final showPackages =
        !_isCoach ||
        _currentTab == _BookingTab.all ||
        _currentTab == _BookingTab.packages;
    final showUpcoming =
        !_isCoach ||
        _currentTab == _BookingTab.all ||
        _currentTab == _BookingTab.upcoming;
    final showHistory =
        _isCoach &&
        (_currentTab == _BookingTab.all || _currentTab == _BookingTab.history);

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
                _buildHeader(context, pastBookings),
                if (_isCoach)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _buildSegmentedTabs(),
                  )
                else
                  const SizedBox(height: 6),
                Expanded(
                  child: RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: const Color(0xFF2B2622),
                    onRefresh: _reload,
                    child: !_loaded && _busy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.brandOrange,
                            ),
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                            children: [
                              if (_busy)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: LinearProgressIndicator(
                                    color: MetaGymTheme.brandOrange,
                                    backgroundColor: Color(0x5426221F),
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
                                      color: const Color(0x33FF453A),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0x66FF453A),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFFF6961),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
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
                                                style: const TextStyle(
                                                  color:
                                                      MetaGymTheme.textPrimary,
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
                                          const Text(
                                            'Bạn chưa thiết lập lịch làm việc tuần. Vui lòng cấu hình tối thiểu 6 ngày làm việc.',
                                            style: TextStyle(
                                              color: MetaGymTheme.textSecondary,
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
                                                    color: const Color(
                                                      0xC42B2622,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xA3A79D92,
                                                      ),
                                                      width: 1.1,
                                                    ),
                                                  ),
                                                  child: Text.rich(
                                                    TextSpan(
                                                      text: day['weekday'] == 7
                                                          ? 'CN'
                                                          : 'T${(day['weekday'] as int) + 1}',
                                                      style: const TextStyle(
                                                        color: MetaGymTheme
                                                            .primary,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              ' · ${(day['starts'] as List).length} ca',
                                                          style: const TextStyle(
                                                            color: MetaGymTheme
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
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      MetaGymTheme.primary,
                                                  foregroundColor:
                                                      MetaGymTheme.onPrimary,
                                                  minimumSize: const Size(
                                                    0,
                                                    48,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
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
                                                icon: const Icon(
                                                  Icons.edit_calendar_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Cấu hình lịch tuần',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0x332B2622,
                                                ),
                                                foregroundColor: const Color(
                                                  0xFFF7F9FC,
                                                ),
                                                minimumSize: const Size(0, 48),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                    ),
                                                side: const BorderSide(
                                                  color: Color(0xA3A79D92),
                                                  width: 1.1,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        MetaGymTheme
                                                            .radiusInput,
                                                      ),
                                                ),
                                              ),
                                              onPressed: _busy || _days.isEmpty
                                                  ? null
                                                  : _block,
                                              icon: const Icon(
                                                Icons.block_rounded,
                                                size: 18,
                                                color:
                                                    MetaGymTheme.warningAmber,
                                              ),
                                              label: const Text(
                                                'Khóa giờ',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      MetaGymTheme.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
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
                                              color: const Color(0xFF45311D),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              border: Border.all(
                                                color: const Color(0xFF815423),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.lock_clock_rounded,
                                              color: MetaGymTheme.warningAmber,
                                              size: 18,
                                            ),
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
                                                  style: const TextStyle(
                                                    color: MetaGymTheme
                                                        .textPrimary,
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
                                                  style: const TextStyle(
                                                    color: MetaGymTheme
                                                        .textSecondary,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              minimumSize: const Size(68, 44),
                                              foregroundColor:
                                                  MetaGymTheme.primary,
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
                                // Member: Gói Coach
                                if (showPackages) ...[
                                  if (_loaded && _packages.isEmpty)
                                    _buildEmptyStateCard(
                                      'Bạn chưa có gói Coach.',
                                    ),
                                  for (final pack in _packages) ...[
                                    _buildPackageCard(pack, gymNow, now),
                                    const SizedBox(height: 12),
                                  ],
                                  const SizedBox(height: 6),
                                ],
                              ],

                              // Section: Lịch sắp tới
                              if (showUpcoming) ...[
                                _buildSectionHeader(
                                  title: _isCoach
                                      ? 'Lịch tập sắp tới'
                                      : 'Sắp tới',
                                  subtitle: _isCoach
                                      ? '${upcomingBookings.length} buổi đã đặt'
                                      : '${upcomingBookings.length} buổi',
                                  icon: Icons.event_available_rounded,
                                ),
                                const SizedBox(height: 8),
                                if (_loaded && upcomingBookings.isEmpty)
                                  _buildEmptyStateCard(
                                    'Chưa có buổi tập nào sắp tới.',
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
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 14),
                              ],

                              if (!_isCoach) ...[
                                CoachingGraphiteCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  child: const Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: MetaGymTheme.warningAmber,
                                      ),
                                      SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          'Lưu ý: Hủy hoặc đổi giờ trong vòng 12 giờ trước buổi tập sẽ bị trừ 1 lượt trong gói.',
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
                                const SizedBox(height: 24),
                              ],

                              // Section: Lịch sử buổi tập (Coach only; Member xem ở icon Lịch sử)
                              if (showHistory) ...[
                                _buildSectionHeader(
                                  title: _isCoach
                                      ? 'Lịch sử buổi tập'
                                      : 'Lịch sử',
                                  subtitle: _isCoach
                                      ? '${pastBookings.length} buổi đã qua'
                                      : '${pastBookings.length} buổi',
                                  icon: Icons.history_rounded,
                                ),
                                const SizedBox(height: 8),
                                if (_loaded && pastBookings.isEmpty)
                                  _buildEmptyStateCard(
                                    'Chưa có lịch sử buổi tập với Coach.',
                                  ),
                                for (final booking in pastBookings) ...[
                                  _buildBookingCard(
                                    booking,
                                    isUpcoming: false,
                                    now: now,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 20),
                              ],
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

  Widget _buildEmptyStateCard(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: CoachingGraphiteCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<CoachRecord> pastBookings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            MetaGymCircleIconButton(
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
                  'Lịch Coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isCoach
                        ? MetaGymTheme.textPrimary
                        : const Color(0xFFF6F3F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCoach
                      ? 'Cấu hình lịch dạy & quản lý buổi hẹn'
                      : 'Đặt lịch & quản lý buổi tập 1:1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isCoach
                        ? MetaGymTheme.textSecondary
                        : const Color(0xFFBCB5AE),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (!_isCoach)
            MetaGymCircleIconButton(
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
                            color: MetaGymTheme.darkCanvas,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
      ),
      child: Row(
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
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: MetaGymTheme.brandOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
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
    Color valueColor = MetaGymTheme.textPrimary,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              children: [
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(CoachRecord pack, String gymNow, DateTime now) {
    final remaining = (pack['remainingSessions'] as num?)?.toInt() ?? 0;
    final total = (pack['totalSessions'] as num?)?.toInt() ?? 0;
    final bookedCount = _bookings
        .where(
          (b) => b['entitlementId'] == pack['id'] && b['status'] == 'BOOKED',
        )
        .length;
    final availableToBook = (remaining - bookedCount).clamp(0, remaining);
    final minForCurriculum = total > 0 ? (total / 2).ceil() : 0;
    final registeredCount = total > 0
        ? ((total - remaining) + bookedCount).clamp(0, total)
        : 0;
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

    final progress = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack['planName'] as String,
                    style: const TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (endsOn.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      remaining <= 0 && isActivePack
                          ? 'Đã hết số buổi tập · Hạn ${_formatDmy(endsOn)}'
                          : 'Hạn dùng đến ${_formatDmy(endsOn)}',
                      style: const TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildPackageStatusBadge(
              status: pack['status'] as String,
              relationshipStatus: pack['relationshipStatus'] as String?,
              isExpired: isExpired,
              remaining: remaining,
            ),
          ],
        ),
        if (isActivePack) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x9E0F1115),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1AD4E4FF)),
            ),
            child: Row(
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
                    valueColor: MetaGymTheme.warningAmber,
                  )
                else
                  _buildStatCell(
                    label: 'Chưa đặt',
                    value: '$availableToBook',
                    suffix: ' lượt',
                    valueColor: availableToBook > 0
                        ? MetaGymTheme.brandOrange
                        : MetaGymTheme.textPrimary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: MetaGymTheme.elevatedSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPaused
                    ? MetaGymTheme.warningAmber
                    : (remaining > 0
                          ? MetaGymTheme.brandOrange
                          : MetaGymTheme.textSecondary),
              ),
            ),
          ),
          if (_activePlan == null && total > 0) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0x7A0F1115),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x12FFFFFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    registeredCount >= minForCurriculum
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 15,
                    color: registeredCount >= minForCurriculum
                        ? const Color(0xFF59E59A)
                        : const Color(0xFFFFC573),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      registeredCount >= minForCurriculum
                          ? 'Đã đăng ký $registeredCount/$minForCurriculum buổi · Chờ Coach lên giáo án'
                          : 'Đặt tối thiểu $minForCurriculum/$total buổi để Coach lên giáo án ($registeredCount/$minForCurriculum)',
                      style: TextStyle(
                        color: registeredCount >= minForCurriculum
                            ? const Color(0xFF59E59A)
                            : const Color(0xFFFFC573),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
            pack['status'] == 'QUEUED' ? 'Chờ kích hoạt' : 'Đã kết thúc',
            style: const TextStyle(color: Color(0xFFC4C8CE), fontSize: 13),
          ),
        ],
        if (canBook) ...[
          const SizedBox(height: 14),
          CoachingPrimaryButton(
            label: 'Đặt lịch',
            icon: Icons.add_circle_outline_rounded,
            onPressed: _busy ? null : () => _openSchedulePicker(pack),
          ),
        ],
      ],
    );

    if (isActivePack && !isPaused && !isExpired) {
      return MetaGymHeroGlassCard(
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }
    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(16),
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
    final plan = _activePlan;
    if (plan == null) return null;
    final date = _date(_gymTime(DateTime.parse(startsAtStr)));
    return plan.days.where((day) => day.scheduledDate == date).firstOrNull;
  }

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isUpcoming)
                  CoachingAvatar(fullName: memberName, size: 44)
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x80211E1C),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0x9A8C8176)),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Color(0xFFB7B2AF),
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _slotLabel(startsAtStr),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isToday
                              ? MetaGymTheme.brandOrange
                              : MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFEAE6E2),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
                style: const TextStyle(
                  color: Color(0xFFB7B2AF),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (status == 'BOOKED') ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0x26FFFFFF), height: 1),
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
                        foregroundColor: MetaGymTheme.dangerCoral,
                        side: const BorderSide(color: Color(0xFF642B32)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                        foregroundColor: MetaGymTheme.warningAmber,
                        side: const BorderSide(color: Color(0xFF815423)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                          borderRadius: BorderRadius.circular(14),
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
                          fontWeight: FontWeight.w600,
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
                    ? MetaGymTheme.brandOrange.withValues(alpha: 0.16)
                    : MetaGymTheme.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: isUpcoming
                    ? MetaGymTheme.brandOrange
                    : MetaGymTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _slotLabel(startsAtStr),
                    style: const TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    otherName ?? 'Huấn luyện viên',
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
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
            style: const TextStyle(
              color: Color(0xFFC4C8CE),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (status == 'BOOKED') ...[
          const SizedBox(height: 12),
          const Divider(color: Color(0x26FFFFFF), height: 1),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (startsAt != null && startsAt.isAfter(now)) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 44),
                    side: const BorderSide(color: Color(0xFFFF6961)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _busy ? null : () => _resolve(booking, 'CANCEL'),
                  child: const Text(
                    'Hủy buổi',
                    style: TextStyle(color: Color(0xFFFF857D), fontSize: 13),
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
                      minimumSize: const Size(88, 44),
                      backgroundColor: MetaGymTheme.elevatedSurface,
                      foregroundColor: MetaGymTheme.brandOrange,
                      side: const BorderSide(color: MetaGymTheme.brandOrange),
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

    return CoachingGraphiteCard(padding: const EdgeInsets.all(16), child: body);
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
    final activeBg = MetaGymTheme.primary.withValues(alpha: 0.22);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: active
              ? Border.all(
                  color: MetaGymTheme.primary.withValues(alpha: 0.7),
                  width: 1.1,
                )
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFB7B2AF),
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
    final activeCount = _daySlots.length;
    final isValid = activeCount >= 6 && activeCount <= 7;

    return Dialog(
      backgroundColor: const Color(0xFA26211D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: const BorderSide(color: Color(0xA3A79D92), width: 1.1),
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
                    color: MetaGymTheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: MetaGymTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lịch làm việc hằng tuần',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: MetaGymTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yêu cầu tối thiểu 6 ngày/tuần, mỗi ngày 4 ca liên tiếp cách nhau 90 phút.',
              style: TextStyle(
                color: isValid
                    ? MetaGymTheme.textSecondary
                    : MetaGymTheme.dangerCoral,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Áp dụng mẫu ca nhanh cho Thứ 2 - Thứ 7:',
              style: TextStyle(
                color: MetaGymTheme.textPrimary,
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
                    backgroundColor: const Color(0xC42B2622),
                    side: const BorderSide(
                      color: Color(0xA3A79D92),
                      width: 1.1,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: Text(
                      preset['label'] as String,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
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
                          ? const Color(0xC42B2622)
                          : const Color(0x382B2622),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? MetaGymTheme.primary.withValues(alpha: 0.6)
                            : const Color(0xA3A79D92),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isActive,
                          activeColor: MetaGymTheme.primary,
                          checkColor: MetaGymTheme.onPrimary,
                          side: const BorderSide(
                            color: MetaGymTheme.textSecondary,
                          ),
                          onChanged: (val) => _toggleDay(weekday, val ?? false),
                        ),
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isActive
                                ? MetaGymTheme.textPrimary
                                : MetaGymTheme.textSecondary,
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
                                        color: MetaGymTheme.primary.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: MetaGymTheme.primary
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        s,
                                        style: const TextStyle(
                                          color: Color(0xFFFF987E),
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
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: MetaGymTheme.textSecondary,
                              size: 19,
                            ),
                            color: MetaGymTheme.elevatedSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: MetaGymTheme.darkBorderStrong,
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
                                    style: const TextStyle(
                                      color: MetaGymTheme.textPrimary,
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
                    foregroundColor: MetaGymTheme.textSecondary,
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
