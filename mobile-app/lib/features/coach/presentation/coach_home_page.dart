import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_request_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';
import 'package:provider/provider.dart';

const List<String> _weekdayShortLabels = <String>[
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN',
];

const List<String> _defaultSlotStarts = <String>[
  '07:30',
  '09:00',
  '10:30',
  '12:00',
  '14:00',
  '15:30',
  '17:30',
  '19:00',
];

DateTime _toGymLocal(DateTime time) =>
    time.toUtc().add(const Duration(hours: 7));

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatSlotClock(DateTime time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

String _formatIsoDate(DateTime time) =>
    '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)}';

String _formatDayMonth(DateTime time) =>
    '${_twoDigits(time.day)}/${_twoDigits(time.month)}';

String _formatFullDate(DateTime time) =>
    '${_twoDigits(time.day)}/${_twoDigits(time.month)}/${time.year}';

String _slotDateTimeKey(DateTime gymLocalTime) =>
    '${_formatIsoDate(gymLocalTime)}T${_formatSlotClock(gymLocalTime)}';

String _normalizeBlockSlotKey(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    return _slotDateTimeKey(_toGymLocal(parsed));
  }
  return raw.trim();
}

T? _tryReadProvider<T>(BuildContext context) {
  try {
    return context.read<T>();
  } catch (_) {
    return null;
  }
}

/// Không gian làm việc chính của Huấn luyện viên (Coach),
/// đồng bộ Futuristic Performance Glass với `MemberDashboardView`.
class CoachHomePage extends StatefulWidget {
  const CoachHomePage({
    this.useSolidGlassFallback = false,
    this.previewMode = false,
    super.key,
  });

  final bool useSolidGlassFallback;
  final bool previewMode;

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  static const AssetImage _gymBannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  int _index = 0;
  int _workHubInitialTab = 0;
  final Set<int> _visitedTabs = {0};

  bool _initialized = false;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _loadError;
  _CoachSnapshot _snapshot = _CoachSnapshot.empty();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_gymBannerAsset, context).catchError((_) {});
    }
    if (!_initialized) {
      _initialized = true;
      _loadCoachData();
    }
  }

  bool _canQueryCoachV2Api(
    ApiClient? apiClient,
    CoachSessionsService? sessionsService,
    CoachRequestsService? requestsService,
    CoachMembersService? membersService,
  ) {
    if (apiClient == null) return false;
    final hasMockService =
        (sessionsService != null && sessionsService is! CoachSessionsApi) ||
        (requestsService != null && requestsService is! CoachRequestsApi) ||
        (membersService != null && membersService is! CoachMembersApi);
    return !hasMockService;
  }

  Future<void> _loadCoachData() async {
    if (widget.previewMode) {
      if (!mounted) return;
      setState(() {
        _snapshot = _CoachSnapshot.preview();
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    final coachId =
        _tryReadProvider<SessionController>(context)?.user?.id ?? '';
    final requestsService = _tryReadProvider<CoachRequestsService>(context);
    final membersService = _tryReadProvider<CoachMembersService>(context);
    final sessionsService = _tryReadProvider<CoachSessionsService>(context);
    final apiClient = _tryReadProvider<ApiClient>(context);
    final useV2Api = _canQueryCoachV2Api(
      apiClient,
      sessionsService,
      requestsService,
      membersService,
    );

    List<CoachIncomingRequest> requests = const [];
    CoachProfile? profile;
    List<CoachMemberSummary> members = const [];
    List<TrainingSession> trainingSessions = const [];
    List<CoachRecord> v2Bookings = const [];
    List<CoachRecord> notifications = const [];
    List<CoachRecord> offers = const [];
    List<CoachRecord> workDays = const [];
    List<CoachRecord> blocks = const [];
    Object? firstError;

    if (requestsService != null) {
      try {
        requests = await requestsService.getRequests();
      } catch (error) {
        firstError ??= error;
      }
      if (coachId.isNotEmpty) {
        try {
          profile = await requestsService.getCoach(coachId);
        } catch (_) {
          // Fixtures without getCoach support should degrade silently.
        }
      }
    }

    if (membersService != null) {
      try {
        members = await membersService.getMembers();
      } catch (error) {
        firstError ??= error;
      }
    }

    if (sessionsService != null) {
      try {
        trainingSessions = await sessionsService.getAll();
      } catch (error) {
        firstError ??= error;
      }
    }

    if (useV2Api) {
      final api = CoachV2Api(apiClient!);
      try {
        v2Bookings = await api.list('/coach-bookings');
      } catch (error) {
        firstError ??= error;
      }
      try {
        notifications = await api.list('/coach-notifications');
      } catch (_) {}
      try {
        offers = await api.list('/coach-packages');
      } catch (_) {}
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
    }

    final memberNames = <String, String>{
      for (final member in members) member.memberId: member.memberFullName,
    };

    final mergedBookings = _mergeBookings(
      v2Bookings: v2Bookings,
      trainingSessions: trainingSessions,
      memberNames: memberNames,
    );

    final activeWorkWeekdays = <int>{
      for (final day in workDays)
        if ((day['weekday'] as num?) != null &&
            ((day['starts'] as List?)?.isNotEmpty ?? false))
          (day['weekday'] as num).toInt(),
    };

    final blockedKeys = <String>{
      for (final block in blocks)
        if (block['startsAt'] is String)
          _normalizeBlockSlotKey(block['startsAt'] as String),
    };

    if (!mounted) return;
    setState(() {
      _snapshot = _CoachSnapshot(
        profile: profile,
        requests: requests,
        members: members,
        bookings: mergedBookings,
        notifications: notifications,
        offers: offers,
        workDays: workDays,
        activeWorkWeekdays: activeWorkWeekdays.isEmpty && !useV2Api
            ? {1, 2, 3, 4, 5, 6}
            : activeWorkWeekdays,
        blocks: blocks,
        blockedSlotKeys: blockedKeys,
        hasLiveApi: useV2Api,
      );
      _isLoading = false;
      _loadError = firstError == null
          ? null
          : 'Không thể cập nhật toàn bộ dữ liệu. Kéo xuống để thử lại.';
    });
  }

  List<_CoachBookingEntry> _mergeBookings({
    required List<CoachRecord> v2Bookings,
    required List<TrainingSession> trainingSessions,
    required Map<String, String> memberNames,
  }) {
    final entries = <_CoachBookingEntry>[];
    for (final raw in v2Bookings) {
      final startsRaw = raw['startsAt'] as String? ?? '';
      final endsRaw = raw['endsAt'] as String?;
      final start = DateTime.tryParse(startsRaw);
      if (start == null) continue;
      final gymStart = _toGymLocal(start);
      final gymEnd = endsRaw != null && DateTime.tryParse(endsRaw) != null
          ? _toGymLocal(DateTime.parse(endsRaw))
          : gymStart.add(const Duration(minutes: 90));
      final memberName =
          (raw['memberName'] as String?)?.trim().isNotEmpty == true
          ? (raw['memberName'] as String).trim()
          : 'Hội viên';
      entries.add(
        _CoachBookingEntry(
          id: raw['id'] as String? ?? startsRaw,
          memberId: raw['memberId'] as String? ?? '',
          memberName: memberName,
          startsAt: start,
          gymStart: gymStart,
          gymEnd: gymEnd,
          focusTitle: 'Buổi tập 1:1 với Coach (90 phút)',
          status: raw['status'] as String? ?? 'BOOKED',
          isV2Booking: true,
        ),
      );
    }

    for (final session in trainingSessions) {
      final start = DateTime.tryParse(session.scheduledStartAt);
      if (start == null) continue;
      final gymStart = _toGymLocal(start);
      final endParsed = session.scheduledEndAt != null
          ? DateTime.tryParse(session.scheduledEndAt!)
          : null;
      final gymEnd = endParsed != null
          ? _toGymLocal(endParsed)
          : gymStart.add(const Duration(minutes: 90));
      final memberName =
          memberNames[session.memberId ?? ''] ?? 'Học viên Meta Gym';
      entries.add(
        _CoachBookingEntry(
          id: session.id,
          memberId: session.memberId ?? '',
          memberName: memberName,
          startsAt: start,
          gymStart: gymStart,
          gymEnd: gymEnd,
          focusTitle: session.title,
          status: session.status,
          isV2Booking: false,
        ),
      );
    }

    entries.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return entries;
  }

  void _selectTab(int index) {
    setState(() {
      _visitedTabs.add(index);
      _index = index;
    });
  }

  void _openWorkHubTab(int subTab) {
    setState(() {
      _workHubInitialTab = subTab;
      _visitedTabs.add(1);
      _index = 1;
    });
  }

  Future<void> _pushRouteAndReload(String path) async {
    await context.push(path);
    if (mounted) await _loadCoachData();
  }

  Future<void> _openNotificationsPage() async {
    final api = _tryReadProvider<ApiClient>(context);
    if (api == null || !_snapshot.hasLiveApi) {
      showCoachingSnackBar(
        context,
        'Thông báo Coach đồng bộ trực tiếp khi kết nối máy chủ.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const CoachNotificationsPage(coachRole: true),
      ),
    );
    if (mounted) await _loadCoachData();
  }

  Future<void> _openOffersPage() async {
    final coachId =
        _tryReadProvider<SessionController>(context)?.user?.id ?? '';
    final api = _tryReadProvider<ApiClient>(context);
    if (api == null || coachId.isEmpty) {
      showCoachingSnackBar(context, 'Chưa có thông tin tài khoản Coach.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachOffersPage(coachId: coachId, coachView: true),
      ),
    );
    if (mounted) await _loadCoachData();
  }

  Future<void> _completeBooking(_CoachBookingEntry entry) async {
    if (_isMutating) return;
    if (widget.previewMode) {
      setState(() {
        _snapshot = _snapshot.withBookingStatus(entry.id, 'COMPLETED');
      });
      showCoachingSnackBar(context, 'Đã hoàn tất buổi dạy.');
      return;
    }

    setState(() => _isMutating = true);
    try {
      if (entry.isV2Booking) {
        final apiClient = _tryReadProvider<ApiClient>(context);
        if (apiClient != null) {
          await CoachV2Api(apiClient)
              .patch('/coach-bookings/${entry.id}', {'action': 'COMPLETE'});
        }
      } else {
        final sessionsService = _tryReadProvider<CoachSessionsService>(context);
        if (sessionsService != null) {
          await sessionsService.update(entry.id, {'status': 'COMPLETED'});
        }
      }
      if (mounted) {
        await _loadCoachData();
        if (mounted) {
          showCoachingSnackBar(context, 'Đã đánh dấu hoàn thành buổi dạy.');
        }
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được trạng thái ca dạy.');
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _cancelBooking(_CoachBookingEntry entry) async {
    if (_isMutating) return;
    final reason = await _askReasonDialog(
      title: 'Hủy buổi dạy',
      label: 'Lý do hủy buổi',
    );
    if (reason == null || !mounted) return;

    if (widget.previewMode) {
      setState(() {
        _snapshot = _snapshot.withBookingStatus(entry.id, 'CANCELLED');
      });
      showCoachingSnackBar(context, 'Đã hủy buổi dạy.');
      return;
    }

    setState(() => _isMutating = true);
    try {
      if (entry.isV2Booking) {
        final apiClient = _tryReadProvider<ApiClient>(context);
        if (apiClient != null) {
          await CoachV2Api(apiClient).patch('/coach-bookings/${entry.id}', {
            'action': 'CANCEL',
            'reason': reason,
          });
        }
      } else {
        final sessionsService = _tryReadProvider<CoachSessionsService>(context);
        if (sessionsService != null) {
          await sessionsService.update(entry.id, {
            'status': 'CANCELLED',
            'cancellationReason': reason,
          });
        }
      }
      if (mounted) {
        await _loadCoachData();
        if (mounted) showCoachingSnackBar(context, 'Đã hủy buổi dạy.');
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) showCoachingSnackBar(context, 'Không thể hủy buổi dạy.');
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _decideRequest(
    CoachIncomingRequest request,
    String decision,
  ) async {
    if (_isMutating) return;
    String? reason;
    if (decision == 'REJECTED') {
      reason = await _askReasonDialog(
        title: 'Từ chối yêu cầu',
        label: 'Lý do từ chối',
      );
      if (reason == null || !mounted) return;
    }

    if (widget.previewMode) {
      setState(() {
        _snapshot = _snapshot.withoutRequest(request.id);
      });
      showCoachingSnackBar(
        context,
        decision == 'ACCEPTED'
            ? 'Đã chấp nhận học viên.'
            : 'Đã từ chối yêu cầu.',
      );
      return;
    }

    final requestsService = _tryReadProvider<CoachRequestsService>(context);
    if (requestsService == null) return;

    setState(() => _isMutating = true);
    try {
      await requestsService.decide(request.id, decision, reason: reason);
      if (mounted) {
        await _loadCoachData();
        if (mounted) {
          showCoachingSnackBar(
            context,
            decision == 'ACCEPTED'
                ? 'Đã chấp nhận yêu cầu chọn Coach.'
                : 'Đã từ chối yêu cầu.',
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không xử lý được yêu cầu.');
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _saveWeeklyWorkdays(Set<int> weekdays) async {
    if (weekdays.length < 6) {
      showCoachingSnackBar(
        context,
        'Cần chọn tối thiểu 6 ngày làm việc mỗi tuần.',
      );
      return;
    }
    if (widget.previewMode || !_snapshot.hasLiveApi) {
      setState(() {
        _snapshot = _snapshot.copyWith(activeWorkWeekdays: weekdays);
      });
      showCoachingSnackBar(context, 'Đã cập nhật lịch làm việc tuần.');
      return;
    }
    final apiClient = _tryReadProvider<ApiClient>(context);
    if (apiClient == null) return;

    final sorted = weekdays.toList()..sort();
    final existingMap = <int, List<String>>{
      for (final day in _snapshot.workDays)
        if ((day['weekday'] as num?) != null)
          (day['weekday'] as num).toInt(): (day['starts'] as List? ?? const [])
              .cast<String>(),
    };
    final payloadDays = [
      for (final wd in sorted)
        {
          'weekday': wd,
          'starts': (existingMap[wd]?.length ?? 0) >= 4
              ? existingMap[wd]!
              : const ['07:30', '09:00', '10:30', '12:00'],
        },
    ];

    setState(() => _isMutating = true);
    try {
      await CoachV2Api(apiClient)
          .put('/coach/work-slots', {'days': payloadDays});
      if (mounted) {
        await _loadCoachData();
        if (mounted) {
          showCoachingSnackBar(context, 'Đã lưu lịch làm việc tuần.');
        }
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không lưu được lịch làm việc.');
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _toggleBlockedSlot({
    required String slotKey,
    required bool blocked,
    String? reason,
  }) async {
    final canonicalKey = _normalizeBlockSlotKey(slotKey);
    if (widget.previewMode || !_snapshot.hasLiveApi) {
      final updated = Set<String>.from(_snapshot.blockedSlotKeys);
      if (blocked) {
        updated.add(canonicalKey);
      } else {
        updated.remove(canonicalKey);
      }
      setState(() {
        _snapshot = _snapshot.copyWith(blockedSlotKeys: updated);
      });
      showCoachingSnackBar(
        context,
        blocked ? 'Đã chặn khung giờ bận.' : 'Đã mở lại khung giờ.',
      );
      return;
    }

    final apiClient = _tryReadProvider<ApiClient>(context);
    if (apiClient == null) return;
    setState(() => _isMutating = true);
    try {
      await CoachV2Api(apiClient).put('/coach-bookings/blocks', {
        'startsAt': slotKey,
        'blocked': blocked,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      if (mounted) {
        await _loadCoachData();
        if (mounted) {
          showCoachingSnackBar(
            context,
            blocked ? 'Đã khóa khung giờ.' : 'Đã mở khóa khung giờ.',
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được khung giờ khóa.');
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<String?> _askReasonDialog({
    required String title,
    required String label,
  }) async {
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
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
            side: const BorderSide(color: MetaGymTheme.cardBorder),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextFormField(
            autofocus: true,
            maxLength: 300,
            maxLines: 3,
            style: const TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 14,
            ),
            onChanged: (value) {
              reason = value.trim();
              if (validationError != null && reason.isNotEmpty) {
                setDialogState(() => validationError = null);
              }
            },
            decoration: coachingInputDecoration(
              label: label,
              errorText: validationError,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                foregroundColor: MetaGymTheme.darkTextSecondary,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
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

  @override
  Widget build(BuildContext context) {
    final session = _tryReadProvider<SessionController>(context);
    final currentUserId = session?.user?.id ?? '';
    final bottomPadding = MetaGymBottomNav.contentBottomPadding(context);

    final pages = [
      _CoachDashboardView(
        bottomPadding: bottomPadding,
        useSolidGlassFallback: widget.useSolidGlassFallback,
        isLoading: _isLoading,
        isMutating: _isMutating,
        loadError: _loadError,
        snapshot: _snapshot,
        onRefresh: _loadCoachData,
        onNavigateTab: _selectTab,
        onOpenWorkHub: _openWorkHubTab,
        onPushRoute: _pushRouteAndReload,
        onOpenNotifications: _openNotificationsPage,
        onOpenOffers: _openOffersPage,
        onCompleteBooking: _completeBooking,
        onCancelBooking: _cancelBooking,
        onSaveWeeklyWorkdays: _saveWeeklyWorkdays,
        onToggleBlockedSlot: _toggleBlockedSlot,
      ),
      if (_visitedTabs.contains(1))
        _CoachWorkHubView(
          bottomPadding: bottomPadding,
          initialSegment: _workHubInitialTab,
          isLoading: _isLoading,
          isMutating: _isMutating,
          snapshot: _snapshot,
          onRefresh: _loadCoachData,
          onOpenMessages: () => _selectTab(3),
          onPushRoute: _pushRouteAndReload,
          onOpenNotifications: _openNotificationsPage,
          onOpenOffers: _openOffersPage,
          onCompleteBooking: _completeBooking,
          onCancelBooking: _cancelBooking,
          onDecideRequest: _decideRequest,
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(2))
        AiConversationsPage(bottomPadding: bottomPadding)
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(3))
        ConversationsPage(
          currentUserId: currentUserId,
          bottomPadding: bottomPadding,
          isActive: _index == 3,
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(4))
        ProfilePage(bottomPadding: bottomPadding)
      else
        const SizedBox.shrink(),
    ];

    return RepaintBoundary(
      child: Scaffold(
        extendBody: true,
        backgroundColor: MetaGymTheme.darkCanvas,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: MetaGymBottomNav(
          currentIndex: _index,
          warmGlass: true,
          useSolidFallback: widget.useSolidGlassFallback,
          secondTabLabel: 'Lịch dạy',
          secondTabIcon: Icons.calendar_month_outlined,
          onTap: _selectTab,
        ),
      ),
    );
  }
}

// =============================================================================
// Data Snapshot Models
// =============================================================================

class _CoachBookingEntry {
  const _CoachBookingEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.startsAt,
    required this.gymStart,
    required this.gymEnd,
    required this.focusTitle,
    required this.status,
    required this.isV2Booking,
  });

  final String id;
  final String memberId;
  final String memberName;
  final DateTime startsAt;
  final DateTime gymStart;
  final DateTime gymEnd;
  final String focusTitle;
  final String status;
  final bool isV2Booking;

  bool get isUpcomingOrActive => status == 'BOOKED' || status == 'SCHEDULED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled =>
      status == 'CANCELLED' || status == 'NO_SHOW' || status == 'MEMBER_ABSENT';

  String get timeRange =>
      '${_formatSlotClock(gymStart)} – ${_formatSlotClock(gymEnd)}';

  String get initials => coachInitials(memberName);

  _CoachBookingEntry copyWith({String? status}) {
    return _CoachBookingEntry(
      id: id,
      memberId: memberId,
      memberName: memberName,
      startsAt: startsAt,
      gymStart: gymStart,
      gymEnd: gymEnd,
      focusTitle: focusTitle,
      status: status ?? this.status,
      isV2Booking: isV2Booking,
    );
  }
}

class _CoachSnapshot {
  const _CoachSnapshot({
    required this.profile,
    required this.requests,
    required this.members,
    required this.bookings,
    required this.notifications,
    required this.offers,
    required this.workDays,
    required this.activeWorkWeekdays,
    required this.blocks,
    required this.blockedSlotKeys,
    required this.hasLiveApi,
  });

  factory _CoachSnapshot.empty() => const _CoachSnapshot(
    profile: null,
    requests: [],
    members: [],
    bookings: [],
    notifications: [],
    offers: [],
    workDays: [],
    activeWorkWeekdays: {},
    blocks: [],
    blockedSlotKeys: {},
    hasLiveApi: false,
  );

  factory _CoachSnapshot.preview() {
    final nowUtc = DateTime.now().toUtc();
    final gymNow = _toGymLocal(nowUtc);
    final gymTodayMax = DateTime.utc(
      gymNow.year,
      gymNow.month,
      gymNow.day,
      23,
      0,
    );
    final firstGymCandidate = gymNow.add(const Duration(minutes: 20));
    final firstGymStart = firstGymCandidate.isAfter(gymTodayMax)
        ? gymTodayMax
        : firstGymCandidate;
    final firstStartUtc = firstGymStart.subtract(const Duration(hours: 7));
    final secondStartUtc = firstStartUtc.add(const Duration(hours: 2));
    final secondGymStart = firstGymStart.add(const Duration(hours: 2));
    final thirdStartUtc = nowUtc.subtract(const Duration(hours: 2));
    final thirdGymStart = gymNow.subtract(const Duration(hours: 2));
    return _CoachSnapshot(
      profile: const CoachProfile(
        id: 'preview-coach',
        fullName: 'Lê Hoàng Nam',
        memberLimit: 12,
        usedSlots: 8,
        availableSlots: 4,
        specialties: ['Hypertrophy', 'Giảm mỡ'],
      ),
      requests: const [
        CoachIncomingRequest(
          id: 'req-1',
          memberId: 'member-1',
          coachId: 'preview-coach',
          status: 'PENDING',
          message: 'Mình muốn tập khung 18h các ngày 2-4-6.',
        ),
        CoachIncomingRequest(
          id: 'req-2',
          memberId: 'member-2',
          coachId: 'preview-coach',
          status: 'PENDING',
          message: 'Người mới bắt đầu, cần hướng dẫn kỹ thuật cơ bản.',
        ),
      ],
      members: const [
        CoachMemberSummary(
          relationshipId: 'rel-1',
          memberId: 'm-1',
          memberFullName: 'Nguyễn Minh Tuấn',
          status: 'ACTIVE',
        ),
        CoachMemberSummary(
          relationshipId: 'rel-2',
          memberId: 'm-2',
          memberFullName: 'Trần Thảo Vy',
          status: 'ACTIVE',
        ),
      ],
      bookings: [
        _CoachBookingEntry(
          id: 'bk-1',
          memberId: 'm-1',
          memberName: 'Nguyễn Minh Tuấn',
          startsAt: firstStartUtc,
          gymStart: firstGymStart,
          gymEnd: firstGymStart.add(const Duration(minutes: 90)),
          focusTitle: 'Upper Body · Sức mạnh',
          status: 'BOOKED',
          isV2Booking: true,
        ),
        _CoachBookingEntry(
          id: 'bk-2',
          memberId: 'm-2',
          memberName: 'Trần Thảo Vy',
          startsAt: secondStartUtc,
          gymStart: secondGymStart,
          gymEnd: secondGymStart.add(const Duration(minutes: 90)),
          focusTitle: 'Glutes & Core · Giảm mỡ',
          status: 'BOOKED',
          isV2Booking: true,
        ),
        _CoachBookingEntry(
          id: 'bk-3',
          memberId: 'm-3',
          memberName: 'Phạm Quốc Bảo',
          startsAt: thirdStartUtc,
          gymStart: thirdGymStart,
          gymEnd: thirdGymStart.add(const Duration(minutes: 90)),
          focusTitle: 'Pull & Mobility',
          status: 'COMPLETED',
          isV2Booking: true,
        ),
      ],
      notifications: const [
        {'id': '1', 'kind': 'BOOKED', 'readAt': null},
        {'id': '2', 'kind': 'PACKAGE_ACTIVE', 'readAt': null},
      ],
      offers: const [
        {
          'code': 'BASIC',
          'name': 'Gói PT Cơ bản',
          'sessionCount': 8,
          'durationDays': 30,
          'price': 3200000,
          'status': 'ACTIVE',
        },
        {
          'code': 'STANDARD',
          'name': 'Gói PT Tiêu chuẩn',
          'sessionCount': 12,
          'durationDays': 45,
          'price': 4500000,
          'status': 'ACTIVE',
        },
      ],
      workDays: const [
        {
          'weekday': 1,
          'starts': ['07:30', '09:00', '14:00', '17:30'],
        },
        {
          'weekday': 2,
          'starts': ['07:30', '09:00', '14:00', '17:30'],
        },
        {
          'weekday': 3,
          'starts': ['07:30', '09:00', '14:00', '17:30'],
        },
        {
          'weekday': 4,
          'starts': ['07:30', '09:00', '14:00', '17:30'],
        },
        {
          'weekday': 5,
          'starts': ['07:30', '09:00', '14:00', '17:30'],
        },
        {
          'weekday': 6,
          'starts': ['09:00', '10:30', '14:00', '15:30'],
        },
      ],
      activeWorkWeekdays: const {1, 2, 3, 4, 5, 6},
      blocks: const [],
      blockedSlotKeys: {'${_formatIsoDate(gymNow)}T12:00'},
      hasLiveApi: false,
    );
  }

  final CoachProfile? profile;
  final List<CoachIncomingRequest> requests;
  final List<CoachMemberSummary> members;
  final List<_CoachBookingEntry> bookings;
  final List<CoachRecord> notifications;
  final List<CoachRecord> offers;
  final List<CoachRecord> workDays;
  final Set<int> activeWorkWeekdays;
  final List<CoachRecord> blocks;
  final Set<String> blockedSlotKeys;
  final bool hasLiveApi;

  int get pendingRequestsCount =>
      requests.where((item) => item.status == 'PENDING').length;

  int get activeMembersCount =>
      members.where((item) => item.status == 'ACTIVE').length;

  int get unreadNotificationsCount =>
      notifications.where((item) => item['readAt'] == null).length;

  int get configuredDaysCount => activeWorkWeekdays.length;

  int get blockedCount => math.max(blocks.length, blockedSlotKeys.length);

  List<_CoachBookingEntry> get todayBookings {
    final today = _toGymLocal(DateTime.now());
    return bookings.where((entry) {
      return entry.gymStart.year == today.year &&
          entry.gymStart.month == today.month &&
          entry.gymStart.day == today.day;
    }).toList();
  }

  _CoachBookingEntry? get nextUpcomingBooking {
    final now = DateTime.now();
    for (final entry in bookings) {
      if (entry.isUpcomingOrActive &&
          entry.startsAt.isAfter(now.subtract(const Duration(minutes: 90)))) {
        return entry;
      }
    }
    return todayBookings.isNotEmpty ? todayBookings.first : null;
  }

  _CoachSnapshot copyWith({
    Set<int>? activeWorkWeekdays,
    Set<String>? blockedSlotKeys,
  }) {
    return _CoachSnapshot(
      profile: profile,
      requests: requests,
      members: members,
      bookings: bookings,
      notifications: notifications,
      offers: offers,
      workDays: workDays,
      activeWorkWeekdays: activeWorkWeekdays ?? this.activeWorkWeekdays,
      blocks: blocks,
      blockedSlotKeys: blockedSlotKeys ?? this.blockedSlotKeys,
      hasLiveApi: hasLiveApi,
    );
  }

  _CoachSnapshot withBookingStatus(String bookingId, String newStatus) {
    return _CoachSnapshot(
      profile: profile,
      requests: requests,
      members: members,
      bookings: [
        for (final entry in bookings)
          if (entry.id == bookingId)
            entry.copyWith(status: newStatus)
          else
            entry,
      ],
      notifications: notifications,
      offers: offers,
      workDays: workDays,
      activeWorkWeekdays: activeWorkWeekdays,
      blocks: blocks,
      blockedSlotKeys: blockedSlotKeys,
      hasLiveApi: hasLiveApi,
    );
  }

  _CoachSnapshot withoutRequest(String requestId) {
    return _CoachSnapshot(
      profile: profile,
      requests: requests.where((item) => item.id != requestId).toList(),
      members: members,
      bookings: bookings,
      notifications: notifications,
      offers: offers,
      workDays: workDays,
      activeWorkWeekdays: activeWorkWeekdays,
      blocks: blocks,
      blockedSlotKeys: blockedSlotKeys,
      hasLiveApi: hasLiveApi,
    );
  }
}

// =============================================================================
// Tab 0: Trang chủ Coach (Futuristic Performance Glass — 1:1 với Member Home)
// =============================================================================

class _CoachDashboardView extends StatelessWidget {
  const _CoachDashboardView({
    required this.bottomPadding,
    required this.useSolidGlassFallback,
    required this.isLoading,
    required this.isMutating,
    required this.loadError,
    required this.snapshot,
    required this.onRefresh,
    required this.onNavigateTab,
    required this.onOpenWorkHub,
    required this.onPushRoute,
    required this.onOpenNotifications,
    required this.onOpenOffers,
    required this.onCompleteBooking,
    required this.onCancelBooking,
    required this.onSaveWeeklyWorkdays,
    required this.onToggleBlockedSlot,
  });

  final double bottomPadding;
  final bool useSolidGlassFallback;
  final bool isLoading;
  final bool isMutating;
  final String? loadError;
  final _CoachSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<int> onOpenWorkHub;
  final Future<void> Function(String path) onPushRoute;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenOffers;
  final Future<void> Function(_CoachBookingEntry entry) onCompleteBooking;
  final Future<void> Function(_CoachBookingEntry entry) onCancelBooking;
  final Future<void> Function(Set<int> weekdays) onSaveWeeklyWorkdays;
  final Future<void> Function({
    required String slotKey,
    required bool blocked,
    String? reason,
  })
  onToggleBlockedSlot;

  @override
  Widget build(BuildContext context) {
    final user = _tryReadProvider<SessionController>(context)?.user;
    final coachName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : (snapshot.profile?.fullName ?? 'Huấn luyện viên');

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurface,
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  0,
                  MetaGymTheme.pageGutter,
                  bottomPadding + 32,
                ),
                children: [
                  const SizedBox(height: 6),
                  _buildHeader(context, coachName),
                  const SizedBox(height: 4),
                  const Text(
                    'Không gian dành cho huấn luyện viên',
                    style: TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActionDock(),
                  const SizedBox(height: 14),
                  if (loadError != null) ...[
                    _buildLoadErrorBanner(),
                    const SizedBox(height: 12),
                  ],
                  // Warm Smoked Glass Hero Work Summary (<= 20% glass budget)
                  _buildHeroSummaryCard(context, coachName),
                  const SizedBox(height: 14),
                  // Level 1 Solid Cards (>= 80% solid surface budget)
                  const _CoachSectionHeader(
                    title: 'Quản lý & Thiết lập lịch',
                    icon: Icons.tune_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildManagementCard(context),
                  const SizedBox(height: 14),
                  _buildNextSessionCard(context),
                  const SizedBox(height: 14),
                  _buildBentoSection(context),
                  const SizedBox(height: 16),
                  _buildTodayBookingsSection(context),
                  const SizedBox(height: 20),
                  const _CoachSectionHeader(
                    title: 'Khám phá & Liên lạc',
                    icon: Icons.explore_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildUtilitiesCard(),
                  if (FlowWorkbenchConfig.enabled) ...[
                    const SizedBox(height: 14),
                    CoachingSecondaryButton(
                      label: 'Kiểm thử các luồng Coach',
                      expand: true,
                      onPressed: () => context.push(AppRoutes.coachWorkbench),
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

  Widget _buildHeader(BuildContext context, String coachName) {
    final unreadCount = snapshot.unreadNotificationsCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DFF5A36),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'MG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'META GYM · COACH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Xin chào, $coachName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          MetaGymCircleIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Phòng gym và thiết bị',
            onTap: () => onPushRoute('/coach/features/gym'),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              MetaGymCircleIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Thông báo Coach',
                onTap: onOpenNotifications,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
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
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Hồ sơ Coach',
            child: InkWell(
              onTap: () => onNavigateTab(4),
              customBorder: const CircleBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: MetaGymTheme.coachAvatarBackground,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      coachInitials(coachName),
                      style: const TextStyle(
                        color: MetaGymTheme.coachAvatarForeground,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionDock() {
    final pending = snapshot.pendingRequestsCount;
    return Row(
      children: [
        Expanded(
          child: _CoachQuickActionTile(
            icon: Icons.pending_actions_rounded,
            label: 'Yêu cầu',
            badgeCount: pending,
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/requests'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            icon: Icons.description_outlined,
            label: 'Giáo trình',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/training'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            icon: Icons.spa_outlined,
            label: 'Dinh dưỡng',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/nutrition'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            icon: Icons.calendar_today_rounded,
            label: 'Lịch tập',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/sessions'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadErrorBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: MetaGymTheme.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MetaGymTheme.warningAmber.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: MetaGymTheme.warningAmber,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loadError!,
              style: const TextStyle(
                color: MetaGymTheme.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Thử lại',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(
              Icons.refresh_rounded,
              color: MetaGymTheme.warningAmber,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(BuildContext context, String coachName) {
    if (isLoading) {
      return MetaGymHeroGlassCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 98,
          child: Center(
            child: MetaGymTheme.isFlutterTestEnvironment
                ? const CircularProgressIndicator(
                    value: 0.5,
                    color: MetaGymTheme.brandOrange,
                    strokeWidth: 2,
                  )
                : const CircularProgressIndicator(
                    color: MetaGymTheme.brandOrange,
                    strokeWidth: 2,
                  ),
          ),
        ),
      );
    }

    final profile = snapshot.profile;
    final activeMembers = snapshot.activeMembersCount;
    final pendingRequests = snapshot.pendingRequestsCount;
    final upcomingCount = snapshot.bookings
        .where((b) => b.isUpcomingOrActive)
        .length;
    final hasCapacityData = profile != null;
    final isFull = hasCapacityData && profile.availableSlots <= 0;
    final statusLabel = !hasCapacityData
        ? 'Hoạt động'
        : (isFull ? 'Đã đủ suất' : 'Còn ${profile.availableSlots} suất');
    final statusTone = !hasCapacityData
        ? CoachingPillTone.green
        : (isFull ? CoachingPillTone.amber : CoachingPillTone.green);

    final heroContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onOpenWorkHub(0),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: MetaGymTheme.brandOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tổng quan công việc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CoachingPill(label: statusLabel, tone: statusTone),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MetaGymTheme.darkTextSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetaGymMetricPanel(
                  onTap: () => onPushRoute('/coach/features/members'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasCapacityData
                            ? '${profile.usedSlots}/${profile.memberLimit}'
                            : '$activeMembers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasCapacityData
                            ? 'suất học viên'
                            : 'học viên đang theo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB7B2AF),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 13.5,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$upcomingCount buổi sắp tới',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEAE6E2),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetaGymMetricPanel(
                  onTap: () => onPushRoute('/coach/features/requests'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: MetaGymTheme.coachAvatarBackground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              coachInitials(coachName),
                              style: const TextStyle(
                                color: MetaGymTheme.coachAvatarForeground,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  coachName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFF7F9FC),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                ),
                                const Text(
                                  'Yêu cầu & Thông báo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFB7B2AF),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        pendingRequests > 0
                            ? '$pendingRequests yêu cầu chờ duyệt'
                            : 'Không có yêu cầu chờ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: pendingRequests > 0
                              ? MetaGymTheme.warningAmber
                              : const Color(0xFFEAE6E2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (useSolidGlassFallback) {
      return CoachingGraphiteCard(
        padding: const EdgeInsets.all(14),
        child: heroContent,
      );
    }
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(14),
      child: heroContent,
    );
  }

  Widget _buildNextSessionCard(BuildContext context) {
    final next = snapshot.nextUpcomingBooking;
    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: MetaGymTheme.brandOrange,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ca dạy tiếp theo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CoachingPill(
                label: next == null
                    ? 'Chưa có lịch'
                    : (next.isCompleted ? 'Hoàn thành' : 'Sắp diễn ra'),
                tone: next == null
                    ? CoachingPillTone.neutral
                    : (next.isCompleted
                          ? CoachingPillTone.neutral
                          : CoachingPillTone.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (next == null)
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa có ca dạy nào sắp tới',
                        style: TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Thiết lập lịch tuần hoặc xem toàn bộ lịch đặt ca 90 phút.',
                        style: TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CoachingCompactAccentButton(
                  label: 'Lịch dạy',
                  onPressed: () => onOpenWorkHub(0),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.50),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    next.initials,
                    style: const TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatDayMonth(next.gymStart)} · ${next.timeRange} · ${next.focusTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
                          fontSize: 12,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CoachingCompactAccentButton(
                  label: 'Chi tiết',
                  onPressed: () => onOpenWorkHub(0),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBentoSection(BuildContext context) {
    final activeWeekdays = snapshot.activeWorkWeekdays;
    final configuredDays = snapshot.configuredDaysCount;
    final offers = snapshot.offers;
    final firstOffer = offers.isNotEmpty ? offers.first : null;
    final offerTitle = firstOffer?['name'] as String? ?? 'Gói tập PT 1:1';
    final offerPrice = firstOffer?['price'] as num?;
    final offerSessions = (firstOffer?['sessionCount'] as num?)?.toInt();
    final profile = snapshot.profile;
    final usedRatio = (profile != null && profile.memberLimit > 0)
        ? (profile.usedSlots / profile.memberLimit).clamp(0.0, 1.0)
        : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CoachingGraphiteCard(
              padding: const EdgeInsets.all(12),
              onTap: () => onPushRoute('/coach/features/sessions'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_view_week_rounded,
                          color: MetaGymTheme.brandOrange,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'Lịch tuần',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _CompactBentoBadge(
                          label: '$configuredDays/7 ngày',
                          color: configuredDays >= 6
                              ? MetaGymTheme.progressGreen
                              : MetaGymTheme.warningAmber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _weekdayShortLabels.length; i++)
                          _CoachWeekBubble(
                            label: _weekdayShortLabels[i],
                            active: activeWeekdays.contains(i + 1),
                          ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Khóa: ${snapshot.blockedCount} giờ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _CompactBentoBadge(
                          label: configuredDays >= 6 ? 'Đủ chuẩn' : 'Cập nhật',
                          color: configuredDays >= 6
                              ? MetaGymTheme.progressGreen
                              : MetaGymTheme.warningAmber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (configuredDays / 7).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: const Color(0x26FFFFFF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          configuredDays >= 6
                              ? MetaGymTheme.progressGreen
                              : MetaGymTheme.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CoachingGraphiteCard(
              padding: const EdgeInsets.all(12),
              onTap: onOpenOffers,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          color: MetaGymTheme.brandOrange,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'Gói PT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _CompactBentoBadge(
                          label: '${offers.length} gói',
                          color: MetaGymTheme.progressGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offerPrice != null
                          ? '${formatVnd(offerPrice)} · ${offerSessions ?? 0} buổi'
                          : 'Xem bảng giá gói 1:1',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextSecondary,
                        fontSize: 10.5,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile != null
                                ? 'Suất: ${profile.usedSlots}/${profile.memberLimit}'
                                : 'HV: ${snapshot.activeMembersCount}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const _CompactBentoBadge(
                          label: 'Mở',
                          color: MetaGymTheme.progressGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: profile != null ? usedRatio : 0.25,
                        minHeight: 3,
                        backgroundColor: const Color(0x26FFFFFF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          MetaGymTheme.progressGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context) {
    final activeMembers = snapshot.activeMembersCount;
    final configuredDays = snapshot.configuredDaysCount;
    final blockedCount = snapshot.blockedCount;
    final unreadCount = snapshot.unreadNotificationsCount;

    return CoachingGraphiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CoachMenuRow(
            icon: Icons.people_alt_outlined,
            accent: MetaGymTheme.progressGreen,
            title: 'Hội viên của tôi',
            subtitle: activeMembers > 0
                ? 'Đang phụ trách $activeMembers học viên'
                : 'Danh sách học viên đang phụ trách',
            onTap: () => onPushRoute('/coach/features/members'),
          ),
          const Divider(height: 1, color: MetaGymTheme.cardBorder),
          _CoachMenuRow(
            icon: Icons.event_repeat_rounded,
            accent: MetaGymTheme.reflectionBlue,
            title: 'Lịch làm việc cố định theo tuần',
            subtitle: 'Đang mở $configuredDays/7 ngày · Khung 90 phút',
            onTap: () => _openWeeklyScheduleSheet(context),
          ),
          const Divider(height: 1, color: MetaGymTheme.cardBorder),
          _CoachMenuRow(
            icon: Icons.block_rounded,
            accent: MetaGymTheme.warningAmber,
            title: 'Chặn khung giờ bận',
            subtitle: blockedCount == 0
                ? 'Chưa chặn khung giờ nào'
                : 'Đang chặn $blockedCount khung giờ',
            onTap: () => _openBlockedSlotsSheet(context),
          ),
          const Divider(height: 1, color: MetaGymTheme.cardBorder),
          _CoachMenuRow(
            icon: Icons.local_offer_outlined,
            accent: MetaGymTheme.brandOrange,
            title: 'Gói PT & Bảng giá',
            subtitle: snapshot.offers.isEmpty
                ? 'Xem các gói huấn luyện 1:1'
                : '${snapshot.offers.length} gói đang mở bán',
            onTap: onOpenOffers,
          ),
          const Divider(height: 1, color: MetaGymTheme.cardBorder),
          _CoachMenuRow(
            icon: Icons.notifications_active_outlined,
            accent: MetaGymTheme.infoSteelBlue,
            title: 'Thông báo Coach',
            subtitle: unreadCount > 0
                ? '$unreadCount thông báo chưa đọc'
                : 'Lịch đặt ca, hủy buổi & gói học viên',
            onTap: onOpenNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayBookingsSection(BuildContext context) {
    final today = snapshot.todayBookings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _CoachSectionHeader(
                title: 'Lịch dạy hôm nay',
                icon: Icons.today_rounded,
              ),
            ),
            InkWell(
              onTap: () => onOpenWorkHub(0),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(
                    'Xem tất cả >',
                    style: TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (today.isEmpty)
          CoachingGraphiteCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: MetaGymTheme.darkTextSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Hôm nay chưa có ca dạy nào được đặt.',
                    style: TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final entry in today)
            _CoachBookingTile(
              entry: entry,
              onTap: () => _openBookingDetailSheet(context, entry),
            ),
      ],
    );
  }

  Widget _buildUtilitiesCard() {
    return CoachingGraphiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CoachMenuRow(
            icon: Icons.call_outlined,
            accent: MetaGymTheme.progressGreen,
            title: 'Cuộc gọi thoại & video',
            subtitle: 'Gọi trực tiếp và xem lịch sử cuộc gọi với học viên',
            onTap: () => onPushRoute('/coach/features/calls'),
          ),
          const Divider(height: 1, color: MetaGymTheme.cardBorder),
          _CoachMenuRow(
            icon: Icons.fitness_center_outlined,
            accent: MetaGymTheme.reflectionBlue,
            title: 'Phòng gym và thiết bị',
            subtitle: 'Tra cứu thông tin phòng tập, khu tập & máy móc',
            onTap: () => onPushRoute('/coach/features/gym'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBookingDetailSheet(
    BuildContext context,
    _CoachBookingEntry entry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CoachingOverlaySheet(
        title: entry.memberName,
        subtitle:
            '${_formatFullDate(entry.gymStart)} · ${entry.timeRange} (90 phút)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nội dung: ${entry.focusTitle}',
              style: const TextStyle(
                color: MetaGymTheme.darkTextPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CoachingSecondaryButton(
                    label: 'Nhắn tin',
                    expand: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      onNavigateTab(3);
                    },
                  ),
                ),
                if (entry.isUpcomingOrActive) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: CoachingCompactAccentButton(
                      label: 'Hoàn tất',
                      expand: true,
                      onPressed: isMutating
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onCompleteBooking(entry);
                            },
                    ),
                  ),
                ],
              ],
            ),
            if (entry.isUpcomingOrActive) ...[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  foregroundColor: MetaGymTheme.dangerCoral,
                ),
                onPressed: isMutating
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        onCancelBooking(entry);
                      },
                child: const Text('Hủy buổi dạy này'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openWeeklyScheduleSheet(BuildContext context) async {
    final selectedDays = Set<int>.from(snapshot.activeWorkWeekdays);
    const fullWeekLabels = <int, String>{
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ nhật',
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => CoachingOverlaySheet(
          title: 'Lịch làm việc cố định',
          subtitle: 'Chọn tối thiểu 6 ngày mở nhận đặt ca 90 phút',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in fullWeekLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: selectedDays.contains(entry.key),
                      selectedColor: const Color(0xFF33201B),
                      surfaceTintColor: Colors.transparent,
                      checkmarkColor: MetaGymTheme.brandOrange,
                      backgroundColor: MetaGymTheme.elevatedSurface,
                      side: BorderSide(
                        color: selectedDays.contains(entry.key)
                            ? MetaGymTheme.brandOrange
                            : MetaGymTheme.cardBorder,
                      ),
                      labelStyle: TextStyle(
                        color: selectedDays.contains(entry.key)
                            ? MetaGymTheme.darkTextPrimary
                            : MetaGymTheme.darkTextSecondary,
                      ),
                      onSelected: (selected) {
                        setModalState(() {
                          if (selected) {
                            selectedDays.add(entry.key);
                          } else {
                            selectedDays.remove(entry.key);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CoachingPrimaryButton(
                label: 'Lưu lịch làm việc',
                onPressed: () {
                  Navigator.pop(ctx);
                  onSaveWeeklyWorkdays(selectedDays);
                },
              ),
              const SizedBox(height: 8),
              CoachingSecondaryButton(
                label: 'Cấu hình từng khung giờ',
                expand: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  onPushRoute('/coach/features/sessions');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBlockedSlotsSheet(BuildContext context) async {
    final gymNow = _toGymLocal(DateTime.now());
    final baseDate = DateTime.utc(gymNow.year, gymNow.month, gymNow.day);
    final candidateDates = [
      for (var offset = 0; offset < 14; offset++)
        baseDate.add(Duration(days: offset)),
    ];
    var selectedDate = candidateDates[1];
    final currentBlocked = Set<String>.from(snapshot.blockedSlotKeys);

    List<String> slotsForWeekday(int weekday) {
      for (final day in snapshot.workDays) {
        if ((day['weekday'] as num?)?.toInt() == weekday) {
          final starts = (day['starts'] as List? ?? const [])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (starts.isNotEmpty) return starts;
        }
      }
      return _defaultSlotStarts;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dateStr = _formatIsoDate(selectedDate);
          final slotStarts = slotsForWeekday(selectedDate.weekday);
          return CoachingOverlaySheet(
            title: 'Chặn khung giờ bận',
            subtitle:
                'Chọn ngày và chạm vào khung giờ 90 phút để khóa hoặc mở lại',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final date in candidateDates)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${_weekdayShortLabels[date.weekday - 1]} ${_formatDayMonth(date)}',
                            ),
                            selected: date == selectedDate,
                            selectedColor: const Color(0xFF33201B),
                            surfaceTintColor: Colors.transparent,
                            checkmarkColor: MetaGymTheme.brandOrange,
                            backgroundColor: MetaGymTheme.elevatedSurface,
                            side: BorderSide(
                              color: date == selectedDate
                                  ? MetaGymTheme.brandOrange
                                  : MetaGymTheme.cardBorder,
                            ),
                            labelStyle: TextStyle(
                              color: date == selectedDate
                                  ? MetaGymTheme.darkTextPrimary
                                  : MetaGymTheme.darkTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                            onSelected: (_) =>
                                setModalState(() => selectedDate = date),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final start in slotStarts)
                      Builder(
                        builder: (context) {
                          final canonical = '${dateStr}T$start';
                          final isBlocked = currentBlocked.contains(canonical);
                          return FilterChip(
                            label: Text(start),
                            selected: isBlocked,
                            selectedColor: const Color(0xFF312819),
                            surfaceTintColor: Colors.transparent,
                            checkmarkColor: MetaGymTheme.warningAmber,
                            backgroundColor: MetaGymTheme.elevatedSurface,
                            side: BorderSide(
                              color: isBlocked
                                  ? MetaGymTheme.warningAmber
                                  : MetaGymTheme.cardBorder,
                            ),
                            labelStyle: TextStyle(
                              color: isBlocked
                                  ? MetaGymTheme.warningAmber
                                  : MetaGymTheme.darkTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                            onSelected: (selected) async {
                              final payloadIso = '${dateStr}T$start:00+07:00';
                              setModalState(() {
                                if (selected) {
                                  currentBlocked.add(canonical);
                                } else {
                                  currentBlocked.remove(canonical);
                                }
                              });
                              await onToggleBlockedSlot(
                                slotKey: payloadIso,
                                blocked: selected,
                                reason: selected ? 'Lịch bận cá nhân' : null,
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                CoachingSecondaryButton(
                  label: 'Quản lý khóa lịch theo ngày',
                  expand: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    onPushRoute('/coach/features/sessions');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Tab 1: Quản lý Lịch dạy 90p & Học viên / Yêu cầu
// =============================================================================

class _CoachWorkHubView extends StatefulWidget {
  const _CoachWorkHubView({
    required this.bottomPadding,
    required this.initialSegment,
    required this.isLoading,
    required this.isMutating,
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenMessages,
    required this.onPushRoute,
    required this.onOpenNotifications,
    required this.onOpenOffers,
    required this.onCompleteBooking,
    required this.onCancelBooking,
    required this.onDecideRequest,
  });

  final double bottomPadding;
  final int initialSegment;
  final bool isLoading;
  final bool isMutating;
  final _CoachSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenMessages;
  final Future<void> Function(String path) onPushRoute;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenOffers;
  final Future<void> Function(_CoachBookingEntry entry) onCompleteBooking;
  final Future<void> Function(_CoachBookingEntry entry) onCancelBooking;
  final Future<void> Function(CoachIncomingRequest request, String decision)
  onDecideRequest;

  @override
  State<_CoachWorkHubView> createState() => _CoachWorkHubViewState();
}

class _CoachWorkHubViewState extends State<_CoachWorkHubView> {
  late int _segment;
  late DateTime _selectedDate;

  DateTime get _todayGym {
    final gymNow = _toGymLocal(DateTime.now());
    return DateTime.utc(gymNow.year, gymNow.month, gymNow.day);
  }

  DateTime _weekMonday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _selectedDate = _todayGym;
  }

  @override
  void didUpdateWidget(covariant _CoachWorkHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      _segment = widget.initialSegment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayGym = _todayGym;
    final weekStart = _weekMonday(_selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekDates = [
      for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
    ];
    final dayBookings = widget.snapshot.bookings
        .where((entry) => _isSameDay(entry.gymStart, _selectedDate))
        .toList();
    final pendingRequests = widget.snapshot.requests
        .where((item) => item.status == 'PENDING')
        .toList();
    final members = widget.snapshot.members;
    final memberNames = {for (final m in members) m.memberId: m.memberFullName};
    final requestsService = _tryReadProvider<CoachRequestsService>(context);
    final membersService = _tryReadProvider<CoachMembersService>(context);

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurface,
              onRefresh: widget.onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  10,
                  MetaGymTheme.pageGutter,
                  widget.bottomPadding + 32,
                ),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'META GYM · QUẢN LÝ',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Lịch dạy & Học viên',
                              style: TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MetaGymCircleIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Thông báo Coach',
                        onTap: widget.onOpenNotifications,
                      ),
                      const SizedBox(width: 8),
                      MetaGymCircleIconButton(
                        icon: Icons.calendar_month_rounded,
                        tooltip: 'Lịch đặt ca đầy đủ',
                        onTap: () =>
                            widget.onPushRoute('/coach/features/sessions'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentPill(
                          label: 'Lịch dạy (90p)',
                          selected: _segment == 0,
                          onTap: () => setState(() => _segment = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SegmentPill(
                          label:
                              'Học viên & Yêu cầu (${pendingRequests.length})',
                          selected: _segment == 1,
                          onTap: () => setState(() => _segment = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (widget.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                        ),
                      ),
                    )
                  else if (_segment == 0) ...[
                    CoachingGraphiteCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Tuần trước',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () => setState(
                              () => _selectedDate = _selectedDate.subtract(
                                const Duration(days: 7),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: MetaGymTheme.darkTextPrimary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Tuần ${_formatDayMonth(weekStart)} – ${_formatFullDate(weekEnd)}',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                                if (!_isSameDay(_selectedDate, todayGym))
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedDate = todayGym,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Về hôm nay',
                                        style: TextStyle(
                                          color: MetaGymTheme.brandOrange,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tuần sau',
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            onPressed: () => setState(
                              () => _selectedDate = _selectedDate.add(
                                const Duration(days: 7),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: MetaGymTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < weekDates.length; i++) ...[
                          if (i > 0) const SizedBox(width: 5),
                          Expanded(
                            child: _WeekdaySelectorButton(
                              label: _weekdayShortLabels[i],
                              dayNumber: '${weekDates[i].day}',
                              isToday: _isSameDay(weekDates[i], todayGym),
                              selected: _isSameDay(weekDates[i], _selectedDate),
                              hasSessions: widget.snapshot.bookings.any(
                                (b) => _isSameDay(b.gymStart, weekDates[i]),
                              ),
                              onTap: () =>
                                  setState(() => _selectedDate = weekDates[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (dayBookings.isEmpty)
                      CoachingGraphiteCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Chưa có ca dạy nào ngày ${_formatFullDate(_selectedDate)}.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CoachingSecondaryButton(
                              label: 'Mở lịch Coach đầy đủ',
                              onPressed: () => widget.onPushRoute(
                                '/coach/features/sessions',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final booking in dayBookings)
                        _buildWorkHubBookingCard(booking),
                  ] else ...[
                    if (pendingRequests.isNotEmpty) ...[
                      const _CoachSectionHeader(
                        title: 'Yêu cầu chờ duyệt',
                        icon: Icons.pending_actions_rounded,
                      ),
                      const SizedBox(height: 8),
                      for (final req in pendingRequests)
                        _buildRequestCard(
                          req,
                          requestsService,
                          memberNames[req.memberId],
                        ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: _CoachSectionHeader(
                            title: 'Học viên đang đồng hành',
                            icon: Icons.groups_outlined,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              widget.onPushRoute('/coach/features/members'),
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Text(
                                'Tất cả >',
                                style: TextStyle(
                                  color: MetaGymTheme.brandOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (members.isEmpty)
                      CoachingGraphiteCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Text(
                              'Chưa có hội viên đang phụ trách.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MetaGymTheme.darkTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CoachingSecondaryButton(
                              label: 'Xem gói PT & Bảng giá',
                              onPressed: widget.onOpenOffers,
                            ),
                          ],
                        ),
                      )
                    else
                      for (final member in members)
                        _buildMemberCard(member, membersService),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkHubBookingCard(_CoachBookingEntry booking) {
    final pill = switch (booking.status) {
      'COMPLETED' => const CoachingPill(
        label: 'Hoàn thành',
        tone: CoachingPillTone.green,
      ),
      'CANCELLED' || 'NO_SHOW' || 'MEMBER_ABSENT' => const CoachingPill(
        label: 'Đã hủy',
        tone: CoachingPillTone.neutral,
      ),
      _ => const CoachingPill(
        label: 'Đã lên lịch',
        tone: CoachingPillTone.coral,
      ),
    };

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDayMonth(booking.gymStart)} · ${booking.timeRange}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              pill,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            booking.memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            booking.focusTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.darkTextSecondary,
              fontSize: 12.5,
            ),
          ),
          if (booking.isUpcomingOrActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      foregroundColor: MetaGymTheme.darkTextPrimary,
                      side: const BorderSide(
                        color: MetaGymTheme.darkBorderStrong,
                      ),
                    ),
                    onPressed: widget.onOpenMessages,
                    child: const Text(
                      'Nhắn tin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      foregroundColor: MetaGymTheme.dangerCoral,
                      side: BorderSide(
                        color: MetaGymTheme.dangerCoral.withValues(alpha: 0.45),
                      ),
                    ),
                    onPressed: widget.isMutating
                        ? null
                        : () => widget.onCancelBooking(booking),
                    child: const Text(
                      'Hủy ca',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CoachingCompactAccentButton(
                    label: 'Hoàn tất',
                    onPressed: widget.isMutating
                        ? null
                        : () => widget.onCompleteBooking(booking),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    CoachIncomingRequest req,
    CoachRequestsService? service,
    String? resolvedMemberName,
  ) {
    final displayName = (resolvedMemberName?.trim().isNotEmpty ?? false)
        ? resolvedMemberName!.trim()
        : 'Hội viên ${req.memberId}';
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: service == null
          ? null
          : () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CoachRequestDetailPage(
                    requestId: req.id,
                    service: service,
                  ),
                ),
              );
              if (changed == true && mounted) {
                await widget.onRefresh();
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(fullName: displayName, size: 38, round: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.statusLabel,
                      style: const TextStyle(
                        color: MetaGymTheme.warningAmber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const CoachingPill(
                label: 'Chờ duyệt',
                tone: CoachingPillTone.amber,
              ),
            ],
          ),
          if (req.message != null && req.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${req.message!.trim()}"',
              style: const TextStyle(
                color: MetaGymTheme.darkTextSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: MetaGymTheme.dangerCoral,
                    backgroundColor: MetaGymTheme.elevatedSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                    side: BorderSide(
                      color: MetaGymTheme.dangerCoral.withValues(alpha: 0.45),
                    ),
                  ),
                  onPressed: widget.isMutating
                      ? null
                      : () => widget.onDecideRequest(req, 'REJECTED'),
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CoachingCompactAccentButton(
                  label: 'Chấp nhận',
                  expand: true,
                  onPressed: widget.isMutating
                      ? null
                      : () => widget.onDecideRequest(req, 'ACCEPTED'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    CoachMemberSummary member,
    CoachMembersService? service,
  ) {
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: service == null
          ? null
          : () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CoachMemberDetailPage(
                    memberId: member.memberId,
                    service: service,
                  ),
                ),
              );
              if (mounted) await widget.onRefresh();
            },
      child: Row(
        children: [
          CoachingAvatar(
            fullName: member.memberFullName,
            size: 42,
            round: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.memberFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                CoachingPill(
                  label: member.statusLabel,
                  tone: member.status == 'ACTIVE'
                      ? CoachingPillTone.green
                      : CoachingPillTone.amber,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nhắn tin',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: widget.onOpenMessages,
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: MetaGymTheme.brandOrange,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Focused UI Helpers (1:1 với MemberDashboardView + DESIGN.md)
// =============================================================================

class _CoachQuickActionTile extends StatelessWidget {
  const _CoachQuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.useSolidFallback,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool useSolidFallback;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: useSolidFallback ? const Color(0xFF302923) : null,
            gradient: useSolidFallback
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xC637302A), Color(0xBB2C2621)],
                  ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xB7ADA396), width: 1.1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: const Color(0x20FFFFFF),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 74),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, size: 22, color: MetaGymTheme.brandOrange),
                        if (badgeCount > 0)
                          Positioned(
                            right: -8,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: MetaGymTheme.brandOrange,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
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

class _CoachWeekBubble extends StatelessWidget {
  const _CoachWeekBubble({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? MetaGymTheme.brandOrange : const Color(0x1AFFFFFF),
            border: Border.all(
              color: active
                  ? MetaGymTheme.brandOrange
                  : const Color(0x33FFFFFF),
              width: 0.9,
            ),
          ),
          alignment: Alignment.center,
          child: active
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active
                ? MetaGymTheme.darkTextPrimary
                : MetaGymTheme.darkTextSecondary,
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CompactBentoBadge extends StatelessWidget {
  const _CompactBentoBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }
}

class _CoachSectionHeader extends StatelessWidget {
  const _CoachSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MetaGymTheme.reflectionBlue, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachMenuRow extends StatelessWidget {
  const _CoachMenuRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MetaGymTheme.darkTextSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachBookingTile extends StatelessWidget {
  const _CoachBookingTile({required this.entry, required this.onTap});

  final _CoachBookingEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = switch (entry.status) {
      'COMPLETED' => const CoachingPill(
        label: 'Hoàn thành',
        tone: CoachingPillTone.green,
      ),
      'CANCELLED' || 'NO_SHOW' || 'MEMBER_ABSENT' => const CoachingPill(
        label: 'Đã hủy',
        tone: CoachingPillTone.neutral,
      ),
      _ => const CoachingPill(
        label: 'Đã xác nhận',
        tone: CoachingPillTone.coral,
      ),
    };

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          CoachingAvatar(fullName: entry.memberName, size: 38, round: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.timeRange} · ${entry.focusTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.darkTextSecondary,
                    fontSize: 11.5,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          pill,
        ],
      ),
    );
  }
}

class _WeekdaySelectorButton extends StatelessWidget {
  const _WeekdaySelectorButton({
    required this.label,
    required this.dayNumber,
    required this.isToday,
    required this.selected,
    required this.hasSessions,
    required this.onTap,
  });

  final String label;
  final String dayNumber;
  final bool isToday;
  final bool selected;
  final bool hasSessions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.22)
          : MetaGymTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? MetaGymTheme.brandOrange
              : (isToday
                    ? MetaGymTheme.reflectionBlue.withValues(alpha: 0.65)
                    : MetaGymTheme.cardBorder),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? MetaGymTheme.darkTextPrimary
                        : MetaGymTheme.darkTextSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNumber,
                  style: TextStyle(
                    color: selected
                        ? MetaGymTheme.brandOrange
                        : MetaGymTheme.darkTextPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasSessions
                        ? MetaGymTheme.brandOrange
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MetaGymTheme.brandOrange.withValues(alpha: 0.18)
          : MetaGymTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : MetaGymTheme.cardBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? MetaGymTheme.darkTextPrimary
                      : MetaGymTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
