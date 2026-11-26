import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_schedule_management_pages.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:provider/provider.dart';

enum _CoachSessionStatusTab { today, upcoming, done, cancelled }

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime _toGymLocal(DateTime time) =>
    time.toUtc().add(const Duration(hours: 7));

String _weekdayShort(int weekday) => weekday == 7 ? 'CN' : 'T${weekday + 1}';

String _formatClock(DateTime d) =>
    '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

T? _tryReadProvider<T>(BuildContext context) {
  try {
    return context.read<T?>();
  } on ProviderNotFoundException {
    return null;
  } catch (_) {
    return null;
  }
}

class _UnifiedCoachSession {
  const _UnifiedCoachSession({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.gymStart,
    required this.gymEnd,
    required this.status,
    required this.isV2Booking,
    this.notes,
    this.cancellationReason,
    this.chargedAt,
    this.legacySession,
  });

  final String id;
  final String memberId;
  final String memberName;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime gymStart;
  final DateTime gymEnd;
  final String status;
  final bool isV2Booking;
  final String? notes;
  final String? cancellationReason;
  final Object? chargedAt;
  final TrainingSession? legacySession;

  bool get isActive => status == 'BOOKED' || status == 'SCHEDULED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isAbsent => status == 'NO_SHOW' || status == 'MEMBER_ABSENT';
  bool get isCancelled => status == 'CANCELLED' || isAbsent;

  String get timeRange => '${_formatClock(gymStart)} – ${_formatClock(gymEnd)}';

  String get dateAndRange {
    final dayLabel =
        '${_weekdayShort(gymStart.weekday)}, ${_twoDigits(gymStart.day)}/${_twoDigits(gymStart.month)}';
    return '$dayLabel · $timeRange';
  }
}

/// Màn hình **2.1 Lịch dạy & Buổi hẹn** (`detail.js`),
/// đồng bộ Warm Smoked Liquid Glass (Dark) & Daylight Studio (Light)
/// cùng 4 trạng thái: Hôm nay, Sắp tới, Đã xong, Đã hủy.
class CoachSessionsPage extends StatefulWidget {
  const CoachSessionsPage({
    this.service,
    this.membersService,
    this.coachBooking,
    this.apiClient,
    this.coachId,
    this.now,
    this.bottomPadding,
    this.onSessionsChanged,
    this.previewMode = false,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachSessionsService? service;
  final CoachMembersService? membersService;
  final Widget? coachBooking;
  final ApiClient? apiClient;
  final String? coachId;
  final DateTime Function()? now;
  final double? bottomPadding;
  final Future<void> Function()? onSessionsChanged;
  final bool previewMode;
  final bool useSolidGlassFallback;

  @override
  State<CoachSessionsPage> createState() => _CoachSessionsPageState();
}

class _CoachSessionsPageState extends State<CoachSessionsPage> {
  CoachSessionsService? _service;
  CoachMembersService? _membersService;
  ApiClient? _apiClient;
  bool _initialized = false;
  bool _useV2Api = false;
  bool _loading = true;
  bool _mutating = false;
  String? _error;

  List<CoachMemberSummary> _members = const [];
  List<TrainingSession> _sessions = const [];
  List<CoachRecord> _v2Bookings = const [];
  List<CoachRecord> _workDays = const [];
  List<CoachRecord> _blocks = const [];
  int _unreadNotifications = 0;

  _CoachSessionStatusTab _currentTab = _CoachSessionStatusTab.today;

  DateTime _nowUtc() => (widget.now?.call() ?? DateTime.now()).toUtc();

  DateTime _gymToday() => _dateOnly(_toGymLocal(_nowUtc()));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(
        MetaGymBackground.darkAppBackgroundAsset,
        context,
      ).catchError((_) {});
      precacheImage(
        MetaGymBackground.lightAppBackgroundAsset,
        context,
      ).catchError((_) {});
    }
    if (_initialized) return;
    _initialized = true;
    _service =
        widget.service ?? _tryReadProvider<CoachSessionsService>(context);
    _membersService =
        widget.membersService ?? _tryReadProvider<CoachMembersService>(context);
    _apiClient = widget.apiClient ?? _tryReadProvider<ApiClient>(context);

    final hasCustomMockService =
        (_service != null && _service is! CoachSessionsApi) ||
        (_membersService != null && _membersService is! CoachMembersApi);
    _useV2Api =
        _apiClient != null &&
        (widget.apiClient != null || !hasCustomMockService);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _effectiveCoachId() {
    return widget.coachId ??
        _tryReadProvider<SessionController>(context)?.user?.id ??
        '';
  }

  Future<void> _load() async {
    if (widget.previewMode) {
      _loadPreviewSeed();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    List<CoachMemberSummary> members = const [];
    List<TrainingSession> sessions = const [];
    List<CoachRecord> bookings = const [];
    List<CoachRecord> workDays = const [];
    List<CoachRecord> blocks = const [];
    int unread = 0;
    Object? firstError;

    if (_membersService != null) {
      try {
        members = await _membersService!.getMembers();
      } catch (e) {
        firstError ??= e;
      }
    }

    if (_service != null) {
      try {
        sessions = await _service!.getAll();
      } catch (e) {
        firstError ??= e;
      }
    }

    if (_useV2Api && _apiClient != null) {
      final api = CoachV2Api(_apiClient!);
      final coachId = _effectiveCoachId();
      try {
        bookings = await api.list('/coach-bookings');
      } catch (e) {
        firstError ??= e;
      }
      if (coachId.isNotEmpty) {
        try {
          final schedule = await api.get('/coaches/$coachId/work-slots');
          workDays = (schedule['days'] as List? ?? const [])
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
        } catch (_) {}
      }
      try {
        blocks = await api.list('/coach-bookings/blocks');
      } catch (_) {}
      try {
        final notifs = await api.list('/coach-notifications');
        unread = notifs.where((row) => row['readAt'] == null).length;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _members = members;
      _sessions = sessions;
      _v2Bookings = bookings;
      _workDays = workDays;
      _blocks = blocks;
      _unreadNotifications = unread;
      _loading = false;
      final hasAnyData =
          sessions.isNotEmpty || bookings.isNotEmpty || workDays.isNotEmpty;
      if (!hasAnyData && firstError != null) {
        _error = firstError is ApiException
            ? firstError.message
            : 'Không tải được lịch buổi tập.';
      }
    });
  }

  void _loadPreviewSeed() {
    final nowGym = _toGymLocal(_nowUtc());
    DateTime gymAt(int deltaDays, int hour, int minute) => DateTime.utc(
      nowGym.year,
      nowGym.month,
      nowGym.day,
      hour,
      minute,
    ).add(Duration(days: deltaDays));
    String isoUtc(DateTime gym) =>
        gym.subtract(const Duration(hours: 7)).toIso8601String();

    setState(() {
      _members = const [
        CoachMemberSummary(
          relationshipId: 'rel-1',
          memberId: 'm-1',
          memberFullName: 'Nguyễn Minh Quân',
          status: 'ACTIVE',
        ),
        CoachMemberSummary(
          relationshipId: 'rel-2',
          memberId: 'm-2',
          memberFullName: 'Trần Thảo Vy',
          status: 'ACTIVE',
        ),
        CoachMemberSummary(
          relationshipId: 'rel-3',
          memberId: 'm-3',
          memberFullName: 'Phạm Quốc Bảo',
          status: 'ACTIVE',
        ),
        CoachMemberSummary(
          relationshipId: 'rel-4',
          memberId: 'm-4',
          memberFullName: 'Đỗ Khánh Linh',
          status: 'PAUSED',
        ),
      ];
      _workDays = [
        for (var wd = 1; wd <= 6; wd++)
          {
            'weekday': wd,
            'starts': ['07:30', '09:00', '14:00', '18:00', '19:45'],
          },
      ];
      _blocks = [
        {
          'startsAt': isoUtc(gymAt(2, 14, 0)),
          'reason': 'Họp chuyên môn nội bộ',
        },
        {
          'startsAt': isoUtc(gymAt(5, 9, 0)),
          'reason': 'Kiểm tra thể lực định kỳ',
        },
      ];
      _unreadNotifications = 3;
      _v2Bookings = [
        {
          'id': 'b-today-1',
          'memberId': 'm-1',
          'memberName': 'Nguyễn Minh Quân',
          'startsAt': isoUtc(gymAt(0, 18, 0)),
          'endsAt': isoUtc(gymAt(0, 19, 30)),
          'focusTitle': 'Upper Body · Sức mạnh · Buổi 11/24',
          'status': 'BOOKED',
        },
        {
          'id': 'b-today-2',
          'memberId': 'm-2',
          'memberName': 'Trần Thảo Vy',
          'startsAt': isoUtc(gymAt(0, 19, 45)),
          'endsAt': isoUtc(gymAt(0, 21, 15)),
          'focusTitle': 'Glutes & Core · Giảm mỡ',
          'status': 'BOOKED',
        },
        {
          'id': 'b-upcoming-1',
          'memberId': 'm-3',
          'memberName': 'Phạm Quốc Bảo',
          'startsAt': isoUtc(gymAt(1, 7, 30)),
          'endsAt': isoUtc(gymAt(1, 9, 0)),
          'focusTitle': 'Lower Body · Powerbuilding · Buổi 11/12',
          'status': 'BOOKED',
        },
        {
          'id': 'b-done-1',
          'memberId': 'm-1',
          'memberName': 'Nguyễn Minh Quân',
          'startsAt': isoUtc(gymAt(-1, 18, 0)),
          'endsAt': isoUtc(gymAt(-1, 19, 30)),
          'focusTitle': 'Upper Body & Core · Đã trừ 1 buổi PT',
          'status': 'COMPLETED',
        },
        {
          'id': 'b-absent-1',
          'memberId': 'm-4',
          'memberName': 'Đỗ Khánh Linh',
          'startsAt': isoUtc(gymAt(-2, 17, 0)),
          'endsAt': isoUtc(gymAt(-2, 18, 30)),
          'focusTitle': 'Full Body · Đã ghi nhận vắng mặt',
          'status': 'NO_SHOW',
        },
        {
          'id': 'b-cancel-1',
          'memberId': 'm-3',
          'memberName': 'Phạm Quốc Bảo',
          'startsAt': isoUtc(gymAt(-3, 9, 0)),
          'endsAt': isoUtc(gymAt(-3, 10, 30)),
          'focusTitle': 'Dời lịch trước 12 giờ · Hoàn lại 1 buổi PT',
          'status': 'CANCELLED',
          'reason': 'Hội viên xin dời lịch trước 12 giờ',
        },
      ];
      _loading = false;
      _error = null;
    });
  }

  List<_UnifiedCoachSession> _buildUnifiedItems() {
    final memberNames = <String, String>{
      for (final m in _members) m.memberId: m.memberFullName,
    };
    final items = <_UnifiedCoachSession>[];

    for (final raw in _v2Bookings) {
      final startsRaw = raw['startsAt'] as String? ?? '';
      final start = DateTime.tryParse(startsRaw);
      if (start == null) continue;
      final endsRaw = raw['endsAt'] as String?;
      final parsedEnd = endsRaw != null ? DateTime.tryParse(endsRaw) : null;
      final gymStart = _toGymLocal(start);
      final gymEnd = parsedEnd != null
          ? _toGymLocal(parsedEnd)
          : gymStart.add(const Duration(minutes: 90));
      final memberId = raw['memberId'] as String? ?? '';
      final rawName = (raw['memberName'] as String?)?.trim();
      final resolvedName = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : (memberNames[memberId] ?? 'Hội viên');
      final focus = (raw['focusTitle'] as String?)?.trim().isNotEmpty == true
          ? (raw['focusTitle'] as String).trim()
          : 'Buổi tập 1:1 (90 phút)';

      items.add(
        _UnifiedCoachSession(
          id: raw['id'] as String? ?? startsRaw,
          memberId: memberId,
          memberName: resolvedName,
          title: focus,
          startsAt: start,
          endsAt: start.add(const Duration(minutes: 90)),
          gymStart: gymStart,
          gymEnd: gymEnd,
          status: (raw['status'] as String? ?? 'BOOKED').toUpperCase(),
          isV2Booking: true,
          cancellationReason: (raw['reason'] as String?)?.trim(),
          chargedAt: raw['chargedAt'],
        ),
      );
    }

    for (final session in _sessions) {
      final start = DateTime.tryParse(session.scheduledStartAt);
      if (start == null) continue;
      final endParsed = session.scheduledEndAt != null
          ? DateTime.tryParse(session.scheduledEndAt!)
          : null;
      final gymStart = _toGymLocal(start);
      final gymEnd = endParsed != null
          ? _toGymLocal(endParsed)
          : gymStart.add(const Duration(minutes: 90));
      final memberName = memberNames[session.memberId ?? ''] ?? 'Hội viên';
      items.add(
        _UnifiedCoachSession(
          id: session.id,
          memberId: session.memberId ?? '',
          memberName: memberName,
          title: session.title,
          startsAt: start,
          endsAt: endParsed ?? start.add(const Duration(minutes: 90)),
          gymStart: gymStart,
          gymEnd: gymEnd,
          status: session.status.toUpperCase(),
          isV2Booking: false,
          notes: session.notes?.trim(),
          cancellationReason: session.cancellationReason?.trim(),
          legacySession: session,
        ),
      );
    }

    return items;
  }

  List<_UnifiedCoachSession> _itemsForTab(
    List<_UnifiedCoachSession> all,
    _CoachSessionStatusTab tab,
  ) {
    final today = _gymToday();
    final filtered = all.where((item) {
      final itemDay = _dateOnly(item.gymStart);
      return switch (tab) {
        _CoachSessionStatusTab.today =>
          item.isActive && !itemDay.isAfter(today),
        _CoachSessionStatusTab.upcoming =>
          item.isActive && itemDay.isAfter(today),
        _CoachSessionStatusTab.done => item.isCompleted,
        _CoachSessionStatusTab.cancelled => item.isCancelled,
      };
    }).toList();

    if (tab == _CoachSessionStatusTab.done ||
        tab == _CoachSessionStatusTab.cancelled) {
      filtered.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    } else {
      filtered.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    return filtered;
  }

  void _openWorkWeekPage() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoachWorkWeekPage(
          apiClient: widget.apiClient,
          coachId: _effectiveCoachId(),
          initialDays: !_useV2Api ? _workDays : null,
          hasActiveMembers: _members.any((m) => m.status == 'ACTIVE'),
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          onSaved: (days) {
            if (!_useV2Api || widget.previewMode) {
              setState(() => _workDays = days);
            }
          },
        ),
      ),
    );
    if (saved == true && mounted) {
      if (_useV2Api && !widget.previewMode) {
        await _load();
      }
      await widget.onSessionsChanged?.call();
    }
  }

  void _openBlockedSlotsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachBlockedSlotsPage(
          apiClient: widget.apiClient,
          coachId: _effectiveCoachId(),
          initialDays: !_useV2Api ? _workDays : null,
          initialBlocks: !_useV2Api ? _blocks : null,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          onChanged: () {
            if (_useV2Api && !widget.previewMode) _load();
            widget.onSessionsChanged?.call();
          },
        ),
      ),
    );
    if (mounted) {
      if (_useV2Api && !widget.previewMode) {
        await _load();
      }
      await widget.onSessionsChanged?.call();
    }
  }

  void _openHistoryPage(List<_UnifiedCoachSession> allItems) {
    final historyRaw = <CoachRecord>[
      for (final item in allItems)
        if (item.isCompleted || item.isCancelled)
          {
            'id': item.id,
            'memberId': item.memberId,
            'memberName': item.memberName,
            'startsAt': item.startsAt.toIso8601String(),
            'endsAt': item.endsAt.toIso8601String(),
            'focusTitle': item.title,
            'status': item.status,
            if (item.cancellationReason != null)
              'reason': item.cancellationReason,
            if (item.chargedAt != null) 'chargedAt': item.chargedAt,
          },
    ];
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachBookingHistoryPage(
          coachMode: true,
          bookings: historyRaw.isNotEmpty || !_useV2Api || widget.previewMode
              ? historyRaw
              : null,
          apiClient: widget.apiClient,
          sessionsService: _service,
          membersService: _membersService,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
      ),
    );
  }

  void _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachNotificationsPage(
          apiClient: widget.apiClient,
          coachMode: true,
        ),
      ),
    );
    if (mounted && !widget.previewMode) {
      await _load();
      await widget.onSessionsChanged?.call();
    }
  }

  void _openMemberDetail(_UnifiedCoachSession item) {
    final membersService = _membersService;
    if (item.memberId.isEmpty || membersService == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachMemberDetailPage(
          memberId: item.memberId,
          service: membersService,
        ),
      ),
    );
  }

  void _openCoachBookingFallback() {
    final booking = widget.coachBooking;
    if (booking == null) return;
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => booking));
  }

  Future<void> _editLegacy([TrainingSession? session]) async {
    if (_service == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SessionFormPage(
          useSolidGlassFallback: widget.useSolidGlassFallback,
          service: _service!,
          session: session,
          members: _members.where((m) => m.status == 'ACTIVE').toList(),
        ),
      ),
    );
    if (saved == true && mounted) {
      await _load();
      await widget.onSessionsChanged?.call();
    }
  }

  Future<void> _changeStatus(
    _UnifiedCoachSession item,
    String actionOrStatus,
  ) async {
    if (_mutating) return;
    final colors = MetaGymColors.of(context);
    final isCancel =
        actionOrStatus == 'CANCELLED' || actionOrStatus == 'CANCEL';

    String? reason;
    if (isCancel) {
      reason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CancelSessionSheet(
          memberName: item.memberName,
          dateRange: item.dateAndRange,
        ),
      );
      if (reason == null || !mounted) return;
    } else {
      final isComplete =
          actionOrStatus == 'COMPLETED' || actionOrStatus == 'COMPLETE';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: colors.overlayGlass,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
            side: BorderSide(color: colors.liquidGlassBorder, width: 1.1),
          ),
          title: Text(
            'Đổi trạng thái ca dạy',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            isComplete
                ? 'Đánh dấu hoàn thành ca dạy này?'
                : 'Đánh dấu hội viên vắng mặt ở ca dạy này?',
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: colors.textWarmMuted,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Đóng'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final normalizedV2Status = switch (actionOrStatus) {
      'COMPLETED' || 'COMPLETE' => 'COMPLETED',
      'NO_SHOW' || 'MEMBER_ABSENT' => 'NO_SHOW',
      _ => 'CANCELLED',
    };
    final v2Action = switch (actionOrStatus) {
      'COMPLETED' || 'COMPLETE' => 'COMPLETE',
      'NO_SHOW' || 'MEMBER_ABSENT' => 'NO_SHOW',
      _ => 'CANCEL',
    };

    if (widget.previewMode) {
      setState(() {
        _v2Bookings = [
          for (final b in _v2Bookings)
            if (b['id'] == item.id)
              {...b, 'status': normalizedV2Status, 'reason': ?reason}
            else
              b,
        ];
      });
      if (mounted) {
        showCoachingSnackBar(
          context,
          v2Action == 'COMPLETE'
              ? 'Đã hoàn thành ca dạy & trừ 1 buổi PT.'
              : v2Action == 'NO_SHOW'
              ? 'Đã đánh dấu hội viên vắng mặt.'
              : 'Đã hủy ca dạy & hoàn lại 1 buổi cho học viên.',
        );
      }
      return;
    }

    setState(() => _mutating = true);
    try {
      if (item.isV2Booking && _apiClient != null) {
        await CoachV2Api(_apiClient!).patch('/coach-bookings/${item.id}', {
          'action': v2Action,
          'reason': ?reason,
        });
      } else if (_service != null) {
        final legacyStatus = switch (actionOrStatus) {
          'COMPLETED' || 'COMPLETE' => 'COMPLETED',
          'NO_SHOW' || 'MEMBER_ABSENT' => 'MEMBER_ABSENT',
          _ => 'CANCELLED',
        };
        await _service!.update(item.id, {
          'status': legacyStatus,
          if (legacyStatus == 'CANCELLED') 'cancellationReason': reason,
        });
      }
      if (!mounted) return;
      await _load();
      await widget.onSessionsChanged?.call();
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được buổi tập.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _openDetailSheet(_UnifiedCoachSession item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionDetailSheet(
        item: item,
        canEditLegacy: !item.isV2Booking && item.isActive && _service != null,
        canOpenMember: item.memberId.isNotEmpty && _membersService != null,
        onCancel: () => _changeStatus(item, 'CANCELLED'),
        onAbsent: () => _changeStatus(item, 'NO_SHOW'),
        onComplete: () => _changeStatus(item, 'COMPLETED'),
        onOpenMember: () => _openMemberDetail(item),
        onEditLegacy: item.legacySession != null
            ? () => _editLegacy(item.legacySession)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    final allItems = _buildUnifiedItems();
    final visibleItems = _itemsForTab(allItems, _currentTab);
    final canCreate =
        _service != null &&
        !_loading &&
        _members.any((m) => m.status == 'ACTIVE');
    final fabBottomOffset = math.max(
      widget.bottomPadding ?? 0.0,
      MediaQuery.paddingOf(context).bottom + 16.0,
    );
    final fab = FloatingActionButton.extended(
      backgroundColor: MetaGymTheme.brandOrange,
      foregroundColor: MetaGymTheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () => _editLegacy(),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Tạo buổi tập',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors, isLight, allItems),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
                  child: _build4StatusTabs(colors, isLight),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              2,
                              gutter,
                              (widget.bottomPadding ??
                                      MediaQuery.paddingOf(context).bottom) +
                                  96,
                            ),
                            children: [
                              _buildWeeklyScheduleBanner(colors),
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: CoachingSecondaryButton(
                                    label: 'Thử lại',
                                    onPressed: _load,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ] else if (allItems.isEmpty)
                                _buildEmptyCard(
                                  colors,
                                  title: 'Chưa có buổi tập nào.',
                                  subtitle: 'Các buổi hẹn 1:1 và lịch tập với học viên sẽ hiển thị tại đây.',
                                )
                              else if (visibleItems.isEmpty)
                                _buildTabEmptyCard(colors)
                              else ...[
                                _buildSectionHeading(
                                  colors,
                                  count: visibleItems.length,
                                  allItems: allItems,
                                ),
                                const SizedBox(height: 8),
                                for (var i = 0; i < visibleItems.length; i++)
                                  _buildSessionCard(
                                    colors,
                                    visibleItems[i],
                                    index: i,
                                    featured:
                                        _currentTab ==
                                            _CoachSessionStatusTab.today &&
                                        i == 0,
                                  ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (canCreate)
            Positioned(right: gutter, bottom: fabBottomOffset, child: fab),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors,
    bool isLight,
    List<_UnifiedCoachSession> allItems,
  ) {
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final canPop = Navigator.of(context).canPop();
    final notifAction = Stack(
      clipBehavior: Clip.none,
      children: [
        _SessionsCircleSvgButton(
          svgAsset: MetaGymIcons.settingNotificationsBell,
          fallbackIcon: Icons.notifications_none_rounded,
          tooltip: 'Thông báo Coach',
          isLight: isLight,
          onTap: _openNotifications,
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 1,
            top: 1,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.canvas, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
    final historyAction = _SessionsCircleSvgButton(
      svgAsset: MetaGymIcons.timeClock,
      fallbackIcon: Icons.history_rounded,
      tooltip: 'Lịch sử buổi dạy',
      isLight: isLight,
      onTap: () => _openHistoryPage(allItems),
    );

    if (!canPop && widget.bottomPadding != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            MetaGymBrandHeader(
              eyebrow: 'META GYM · COACH',
              title: 'Lịch dạy',
              subtitle: 'Quản lý ca 1:1 & điểm danh',
              inlineSubtitle: true,
              actions: [notifAction, historyAction],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            _SessionsCircleSvgButton(
              svgAsset: MetaGymIcons.commonBack,
              fallbackIcon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              isLight: isLight,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ] else ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.circleButtonBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: colors.circleButtonBorder),
              ),
              alignment: Alignment.center,
              child: const MetaGymIcon(
                MetaGymIcons.appIconMark,
                size: 24,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'META GYM · COACH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Lịch dạy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                Text(
                  'Quản lý ca 1:1 & điểm danh',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          notifAction,
          const SizedBox(width: 4),
          historyAction,
        ],
      ),
    );
  }

  Widget _build4StatusTabs(MetaGymColors colors, bool isLight) {
    final tabs = <(_CoachSessionStatusTab, String, Key)>[
      (
        _CoachSessionStatusTab.today,
        'Hôm nay',
        const Key('sessions-tab-today'),
      ),
      (
        _CoachSessionStatusTab.upcoming,
        'Sắp tới',
        const Key('sessions-tab-upcoming'),
      ),
      (_CoachSessionStatusTab.done, 'Đã xong', const Key('sessions-tab-done')),
      (
        _CoachSessionStatusTab.cancelled,
        'Đã hủy',
        const Key('sessions-tab-cancelled'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.metricPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.metricPanelBorder, width: 1.0),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _SessionStatusSegmentButton(
                key: tabs[i].$3,
                label: tabs[i].$2,
                active: _currentTab == tabs[i].$1,
                isLight: isLight,
                colors: colors,
                onTap: () => setState(() => _currentTab = tabs[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleBanner(MetaGymColors colors) {
    final configuredDays = _workDays
        .where((row) => ((row['starts'] as List?)?.isNotEmpty ?? false))
        .length;
    final blockedCount = _blocks.length;

    return MetaGymHeroGlassCard(
      useSolidFallback: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.actionCoachWorkweek,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lịch làm việc hằng tuần',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: CoachingPill(
                  label: '$configuredDays/7 ngày',
                  tone: configuredDays >= 6
                      ? CoachingPillTone.green
                      : CoachingPillTone.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            blockedCount > 0
                ? 'Khung 90 phút · Đang khóa $blockedCount khung giờ bận tuần này'
                : 'Khung 90 phút · Chưa khóa khung giờ bận tuần này',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12,
              height: 1.35,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('sessions-open-workweek-btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: MetaGymTheme.onPrimary,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: _openWorkWeekPage,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Lịch tuần',
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('sessions-open-blocks-btn'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.metricPanelBg,
                      foregroundColor: colors.textPrimary,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(color: colors.metricPanelBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: _openBlockedSlotsPage,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Chặn khung giờ',
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.coachBooking != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: colors.primaryText,
                ),
                onPressed: _openCoachBookingFallback,
                child: const Text(
                  'Quản lý lịch làm việc Coach',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeading(
    MetaGymColors colors, {
    required int count,
    required List<_UnifiedCoachSession> allItems,
  }) {
    final title = switch (_currentTab) {
      _CoachSessionStatusTab.today => 'Buổi hẹn hôm nay ($count)',
      _CoachSessionStatusTab.upcoming => 'Buổi hẹn sắp tới ($count)',
      _CoachSessionStatusTab.done => 'Ca dạy đã xong ($count)',
      _CoachSessionStatusTab.cancelled => 'Ca dạy đã hủy ($count)',
    };
    final actionText =
        (_currentTab == _CoachSessionStatusTab.done ||
            _currentTab == _CoachSessionStatusTab.cancelled)
        ? 'Xem tất cả ›'
        : 'Lịch sử ›';

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InkWell(
          key: const Key('sessions-open-history-link'),
          onTap: () => _openHistoryPage(allItems),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              actionText,
              style: TextStyle(
                color: colors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(
    MetaGymColors colors,
    _UnifiedCoachSession item, {
    required int index,
    required bool featured,
  }) {
    final today = _gymToday();
    final isTodayItem = _dateOnly(item.gymStart) == today;
    final isOverduePending =
        item.isActive && _dateOnly(item.gymStart).isBefore(today);

    final timeBadgeLabel = isTodayItem
        ? 'Hôm nay · ${item.timeRange}'
        : item.dateAndRange;
    final timeBadgeTone = featured
        ? CoachingPillTone.coral
        : CoachingPillTone.neutral;

    final statusPill = item.isCompleted
        ? const CoachingPill(
            label: 'Đã hoàn thành',
            tone: CoachingPillTone.green,
          )
        : item.isAbsent
        ? const CoachingPill(
            label: 'Hội viên vắng',
            tone: CoachingPillTone.amber,
          )
        : item.isCancelled
        ? CoachingPill(
            label: item.chargedAt != null ? 'Đã hủy · Đã trừ lượt' : 'Đã hủy',
            tone: item.chargedAt != null
                ? CoachingPillTone.amber
                : CoachingPillTone.neutral,
          )
        : isOverduePending
        ? const CoachingPill(
            label: 'Chờ điểm danh',
            tone: CoachingPillTone.amber,
          )
        : const CoachingPill(
            label: 'Đã lên lịch',
            tone: CoachingPillTone.green,
          );

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      borderColor: featured
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.44)
          : null,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _openDetailSheet(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CoachingPill(label: timeBadgeLabel, tone: timeBadgeTone),
              statusPill,
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              CoachingAvatar(
                fullName: item.memberName,
                size: 38,
                round: true,
                paletteIndex: index,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.memberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12,
                        height: 1.35,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
            ],
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colors.metricPanelBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.metricPanelBorder),
              ),
              child: Text(
                item.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (item.cancellationReason != null &&
              item.cancellationReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Lý do: ${item.cancellationReason!}',
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (featured && item.isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CardActionButton(
                    key: const Key('session-action-cancel'),
                    label: 'Hủy ca',
                    foreground: colors.error,
                    borderColor: colors.error.withValues(alpha: 0.45),
                    backgroundColor: colors.metricPanelBg,
                    onPressed: _mutating
                        ? null
                        : () => _changeStatus(item, 'CANCELLED'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionButton(
                    key: const Key('session-action-absent'),
                    label: 'HV vắng',
                    foreground: colors.warning,
                    borderColor: colors.warning.withValues(alpha: 0.48),
                    backgroundColor: colors.metricPanelBg,
                    onPressed: _mutating
                        ? null
                        : () => _changeStatus(item, 'NO_SHOW'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CardActionButton(
                    key: const Key('session-action-complete'),
                    label: 'Hoàn thành',
                    foreground: MetaGymTheme.onPrimary,
                    borderColor: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.brandOrange,
                    bold: true,
                    onPressed: _mutating
                        ? null
                        : () => _changeStatus(item, 'COMPLETED'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabEmptyCard(MetaGymColors colors) {
    final (title, subtitle) = switch (_currentTab) {
      _CoachSessionStatusTab.today => (
        'Hôm nay không có ca dạy nào.',
        'Các ca dạy hôm nay sẽ hiển thị tại đây để điểm danh nhanh.',
      ),
      _CoachSessionStatusTab.upcoming => (
        'Chưa có buổi hẹn sắp tới.',
        'Khi học viên đặt ca từ ngày mai trở đi, lịch hẹn sẽ hiện tại đây.',
      ),
      _CoachSessionStatusTab.done => (
        'Chưa có ca dạy đã hoàn thành.',
        'Các ca đã điểm danh Hoàn thành sẽ được lưu tại đây.',
      ),
      _CoachSessionStatusTab.cancelled => (
        'Chưa có ca dạy bị hủy hoặc vắng mặt.',
        'Mọi ca hủy hoặc ghi nhận vắng mặt đều được theo dõi minh bạch.',
      ),
    };
    return _buildEmptyCard(colors, title: title, subtitle: subtitle);
  }

  Widget _buildEmptyCard(
    MetaGymColors colors, {
    required String title,
    required String subtitle,
  }) {
    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.metricPanelBorder),
            ),
            alignment: Alignment.center,
            child: const MetaGymIcon(
              MetaGymIcons.emptySessions,
              size: MetaGymIconSize.md,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsCircleSvgButton extends StatelessWidget {
  const _SessionsCircleSvgButton({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.tooltip,
    required this.isLight,
    required this.onTap,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final String tooltip;
  final bool isLight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: MetaGymTap(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.circleButtonBg,
                  gradient: isLight
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFFFFF), Color(0xFFE5ECF5)],
                        )
                      : null,
                  border: Border.all(
                    color: colors.circleButtonBorder,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MetaGymIcon(
                      svgAsset,
                      size: MetaGymIconSize.md,
                      excludeFromSemantics: true,
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        fallbackIcon,
                        size: 20,
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionStatusSegmentButton extends StatelessWidget {
  const _SessionStatusSegmentButton({
    required this.label,
    required this.active,
    required this.isLight,
    required this.colors,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final bool isLight;
  final MetaGymColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MetaGymTheme.brandOrange : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : colors.textWarmMuted,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.foreground,
    required this.borderColor,
    required this.backgroundColor,
    required this.onPressed,
    this.bold = false,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foreground,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({
    required this.item,
    required this.canEditLegacy,
    required this.canOpenMember,
    required this.onCancel,
    required this.onAbsent,
    required this.onComplete,
    required this.onOpenMember,
    this.onEditLegacy,
  });

  final _UnifiedCoachSession item;
  final bool canEditLegacy;
  final bool canOpenMember;
  final VoidCallback onCancel;
  final VoidCallback onAbsent;
  final VoidCallback onComplete;
  final VoidCallback onOpenMember;
  final VoidCallback? onEditLegacy;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        22 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.overlayGlass,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.liquidGlassBorder, width: 1.1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.metricPanelBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CoachingAvatar(
                  fullName: item.memberName,
                  size: 42,
                  round: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.dateAndRange} (90 phút)',
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const MetaGymIcon(
                    MetaGymIcons.commonClose,
                    size: MetaGymIconSize.sm,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MetaGymMetricPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trạng thái ca tập',
                          style: TextStyle(
                            color: colors.textWarmMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CoachingPill(
                        label: item.isCompleted
                            ? 'Đã hoàn thành'
                            : item.isAbsent
                            ? 'Hội viên vắng'
                            : item.isCancelled
                            ? 'Đã hủy'
                            : '${item.status} · Đã lên lịch',
                        tone: item.isActive || item.isCompleted
                            ? CoachingPillTone.green
                            : item.isAbsent
                            ? CoachingPillTone.amber
                            : CoachingPillTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (item.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CardActionButton(
                      label: 'Hủy ca',
                      foreground: colors.error,
                      borderColor: colors.error.withValues(alpha: 0.45),
                      backgroundColor: colors.metricPanelBg,
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CardActionButton(
                      label: 'HV vắng',
                      foreground: colors.warning,
                      borderColor: colors.warning.withValues(alpha: 0.48),
                      backgroundColor: colors.metricPanelBg,
                      onPressed: () {
                        Navigator.pop(context);
                        onAbsent();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CardActionButton(
                      label: 'Hoàn thành',
                      foreground: MetaGymTheme.onPrimary,
                      borderColor: MetaGymTheme.brandOrange,
                      backgroundColor: MetaGymTheme.brandOrange,
                      bold: true,
                      onPressed: () {
                        Navigator.pop(context);
                        onComplete();
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (canEditLegacy && onEditLegacy != null) ...[
              const SizedBox(height: 10),
              CoachingSecondaryButton(
                label: 'Chỉnh sửa buổi tập',
                expand: true,
                onPressed: () {
                  Navigator.pop(context);
                  onEditLegacy!();
                },
              ),
            ],
            if (canOpenMember) ...[
              const SizedBox(height: 10),
              CoachingSecondaryButton(
                label: 'Xem hồ sơ hội viên ›',
                expand: true,
                onPressed: () {
                  Navigator.pop(context);
                  onOpenMember();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CancelSessionSheet extends StatefulWidget {
  const _CancelSessionSheet({
    required this.memberName,
    required this.dateRange,
  });

  final String memberName;
  final String dateRange;

  @override
  State<_CancelSessionSheet> createState() => _CancelSessionSheetState();
}

class _CancelSessionSheetState extends State<_CancelSessionSheet> {
  static const List<String> _presets = <String>[
    'Bận đột xuất',
    'HV xin dời lịch',
    'Lý do sức khỏe',
  ];

  final TextEditingController _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          22 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: colors.overlayGlass,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.liquidGlassBorder, width: 1.1),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.42),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const MetaGymIcon(
                      MetaGymIcons.coachingTermination,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hủy buổi dạy này?',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.memberName} · ${widget.dateRange}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textWarmMuted,
                            fontSize: 12,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Hủy ca sẽ hoàn lại 1 buổi PT vào gói của học viên và gửi thông báo ngay lập tức.',
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in _presets)
                    ActionChip(
                      label: Text(
                        preset,
                        style: TextStyle(
                          color: _reason.text.trim() == preset
                              ? colors.chipActiveText
                              : colors.textWarmMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: _reason.text.trim() == preset
                          ? colors.chipActiveBg
                          : colors.metricPanelBg,
                      side: BorderSide(
                        color: _reason.text.trim() == preset
                            ? MetaGymTheme.brandOrange
                            : colors.metricPanelBorder,
                      ),
                      onPressed: () => setState(() {
                        _reason.text = preset;
                        _invalid = false;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                key: const Key('session-cancellation-reason'),
                maxLength: 2000,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary),
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                decoration: InputDecoration(
                  labelText: 'Lý do hủy',
                  hintText: 'Nhập lý do gửi tới học viên…',
                  labelStyle: TextStyle(color: colors.textWarmMuted),
                  hintStyle: TextStyle(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.metricPanelBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                    borderSide: BorderSide(color: colors.metricPanelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                    borderSide: BorderSide(color: colors.metricPanelBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                    borderSide: const BorderSide(
                      color: MetaGymTheme.brandOrange,
                      width: 1.5,
                    ),
                  ),
                  errorText: _invalid ? 'Vui lòng nhập lý do hủy.' : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CoachingSecondaryButton(
                      label: 'Giữ lịch',
                      expand: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: MetaGymTheme.onPrimary,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final text = _reason.text.trim();
                        if (text.isEmpty) {
                          setState(() => _invalid = true);
                          return;
                        }
                        Navigator.pop(context, text);
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Xác nhận hủy ca',
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionFormPage extends StatefulWidget {
  const _SessionFormPage({
    required this.useSolidGlassFallback,
    required this.service,
    required this.members,
    this.session,
  });

  final CoachSessionsService service;
  final List<CoachMemberSummary> members;
  final TrainingSession? session;

  final bool useSolidGlassFallback;

  @override
  State<_SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends State<_SessionFormPage> {
  final _title = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _notes = TextEditingController();
  String? _memberId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _memberId =
        session?.memberId ??
        (widget.members.isEmpty ? null : widget.members.first.memberId);
    if (session != null) {
      _title.text = session.title;
      _start.text = formatSessionLocalTime(session.scheduledStartAt);
      _end.text = session.scheduledEndAt == null
          ? ''
          : formatSessionLocalTime(session.scheduledEndAt!);
      _notes.text = session.notes ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _start.dispose();
    _end.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    MetaGymColors colors, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: colors.textWarmMuted),
      hintStyle: TextStyle(color: colors.textSecondary),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 19, color: colors.textWarmMuted),
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
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: BorderSide(color: colors.error),
      ),
    );
  }

  Future<void> _save() async {
    final start = parseSessionLocalTime(_start.text);
    final end = _end.text.trim().isEmpty
        ? null
        : parseSessionLocalTime(_end.text);
    String? validation;
    if (_memberId == null ||
        _title.text.trim().isEmpty ||
        start == null ||
        (_end.text.trim().isNotEmpty && end == null)) {
      validation = 'Nhập tên và thời gian hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (end != null && !end.isAfter(start)) {
      validation = 'Giờ kết thúc phải sau giờ bắt đầu.';
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
      if (widget.session == null) 'memberId': _memberId,
      'title': _title.text.trim(),
      'scheduledStartAt': start!.toUtc().toIso8601String(),
      'scheduledEndAt': end?.toUtc().toIso8601String(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.session case final session?) {
        await widget.service.update(session.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được buổi tập.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isCreate = widget.session == null;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      _SessionsCircleSvgButton(
                        svgAsset: MetaGymIcons.commonBack,
                        fallbackIcon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        isLight: isLight,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'META GYM · COACH',
                              style: TextStyle(
                                color: colors.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              isCreate ? 'Tạo buổi tập' : 'Sửa buổi tập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Thiết lập lịch tập & ghi chú cho học viên',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textWarmMuted,
                                fontSize: 12,
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      MediaQuery.paddingOf(context).bottom + 28,
                    ),
                    children: [
                      MetaGymGlassCard(
                        solid: widget.useSolidGlassFallback,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isCreate) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _memberId,
                                dropdownColor: colors.overlayGlass,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: _fieldDecoration(
                                  colors,
                                  label: 'Hội viên',
                                  icon: Icons.person_outline_rounded,
                                ),
                                items: widget.members
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.memberId,
                                        child: Text(
                                          m.memberFullName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _memberId = value),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextField(
                              key: const Key('session-title'),
                              controller: _title,
                              maxLength: 150,
                              style: TextStyle(color: colors.textPrimary),
                              decoration: _fieldDecoration(
                                colors,
                                label: 'Tên buổi tập',
                                hint: 'VD: Tập chân & Core',
                                icon: Icons.fitness_center_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('session-start'),
                              controller: _start,
                              keyboardType: TextInputType.datetime,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                              decoration: _fieldDecoration(
                                colors,
                                label: 'Bắt đầu (dd/MM/yyyy HH:mm)',
                                hint: '24/10/2026 08:00',
                                icon: Icons.schedule_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('session-end'),
                              controller: _end,
                              keyboardType: TextInputType.datetime,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                              decoration: _fieldDecoration(
                                colors,
                                label: 'Kết thúc (tùy chọn)',
                                hint: '24/10/2026 09:00',
                                icon: Icons.timer_off_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _notes,
                              maxLength: 5000,
                              maxLines: 3,
                              style: TextStyle(color: colors.textPrimary),
                              decoration: _fieldDecoration(
                                colors,
                                label: 'Ghi chú',
                                hint:
                                    'Yêu cầu khởi động hoặc lưu ý chấn thương…',
                                icon: Icons.notes_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) CoachingErrorBanner(message: _error!),
                      CoachingPrimaryButton(
                        label: _saving ? 'Đang lưu…' : 'Lưu',
                        icon: Icons.check_rounded,
                        onPressed: _saving ? null : _save,
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

DateTime? parseSessionLocalTime(String input) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$')
      .firstMatch(input.trim());
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final time = DateTime(year, month, day, hour, minute);
  if (time.year != year ||
      time.month != month ||
      time.day != day ||
      time.hour != hour ||
      time.minute != minute) {
    return null;
  }
  return time;
}
