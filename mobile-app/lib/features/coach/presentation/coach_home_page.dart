import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_schedule_management_pages.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
export 'package:meta_gym_app/features/coach/presentation/coach_schedule_management_pages.dart'
    show CoachBlockedSlotsPage, CoachWorkWeekPage;
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:provider/provider.dart';

const int _coachHardMemberCap = 8;

const List<String> _weekdayShortLabels = <String>[
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN',
];

DateTime _toGymLocal(DateTime time) =>
    time.toUtc().add(const Duration(hours: 7));

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatSlotClock(DateTime time) =>
    '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

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
  int _index = 0;
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
      precacheImage(
        MetaGymBackground.darkAppBackgroundAsset,
        context,
      ).catchError((_) {});
      precacheImage(
        MetaGymBackground.lightAppBackgroundAsset,
        context,
      ).catchError((_) {});
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

    CoachProfile? profile;
    List<CoachMemberSummary> members = const [];
    List<TrainingSession> trainingSessions = const [];
    List<CoachRecord> v2Bookings = const [];
    List<CoachRecord> notifications = const [];
    List<CoachRecord> offers = const [];
    List<CoachRecord> workDays = const [];
    List<CoachRecord> blocks = const [];
    Object? firstError;

    if (requestsService != null && coachId.isNotEmpty) {
      try {
        profile = await requestsService.getCoach(coachId);
      } catch (_) {
        // Fixtures without getCoach support should degrade silently.
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
        if (block['startsAt'] is String) block['startsAt'] as String,
    };

    if (!mounted) return;
    setState(() {
      _snapshot = _CoachSnapshot(
        profile: profile,
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
    if (index == _index) return;
    setState(() {
      _visitedTabs.add(index);
      _index = index;
    });
  }

  Future<void> _pushRouteAndReload(String path) async {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      await router.push<void>(path);
    } else {
      final session = _tryReadProvider<SessionController>(context);
      final api = _tryReadProvider<ApiClient>(context);
      final userId = session?.user?.id ?? '';
      final Widget? fallback = switch (path) {
        '/coach/features/members' => const CoachMembersPage(),
        '/coach/features/sessions' => CoachSessionsPage(
          coachId: userId.isNotEmpty ? userId : null,
          apiClient: api,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
        '/coach/features/training' => const CoachTrainingPage(),
        '/coach/features/nutrition' => const CoachNutritionPage(
          structured: true,
        ),
        '/coach/features/messages' => ConversationsPage(
          currentUserId: userId.isNotEmpty ? userId : 'coach',
          coachMode: true,
        ),
        '/coach/features/calls' => CallsPage(
          currentUserId: userId.isNotEmpty ? userId : 'coach',
          coachMode: true,
        ),
        '/coach/features/ai' => const AiConversationsPage(coachMode: true),
        _ => null,
      };
      if (fallback == null) return;
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => fallback));
    }
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
        builder: (_) => CoachNotificationsPage(coachMode: true, apiClient: api),
      ),
    );
    if (mounted) await _loadCoachData();
  }

  Future<void> _openWorkWeekPage() async {
    final coachId =
        _tryReadProvider<SessionController>(context)?.user?.id ?? '';
    final api = _tryReadProvider<ApiClient>(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachWorkWeekPage(
          apiClient: api,
          coachId: coachId,
          initialDays: !_snapshot.hasLiveApi ? _snapshot.workDays : null,
          hasActiveMembers: _snapshot.activeMembersCount > 0,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          onSaved: (days) {
            if (!_snapshot.hasLiveApi) {
              _saveWeeklyWorkdays({
                for (final d in days)
                  if ((d['weekday'] as num?) != null)
                    (d['weekday'] as num).toInt(),
              });
            }
          },
        ),
      ),
    );
    if (mounted) await _loadCoachData();
  }

  Future<void> _openBlockedSlotsPage() async {
    final coachId =
        _tryReadProvider<SessionController>(context)?.user?.id ?? '';
    final api = _tryReadProvider<ApiClient>(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachBlockedSlotsPage(
          apiClient: api,
          coachId: coachId,
          initialDays: !_snapshot.hasLiveApi ? _snapshot.workDays : null,
          initialBlocks: !_snapshot.hasLiveApi
              ? (_snapshot.blocks.isNotEmpty
                    ? _snapshot.blocks
                    : [
                        for (final k in _snapshot.blockedSlotKeys)
                          {'startsAt': k, 'reason': 'Lịch bận cá nhân'},
                      ])
              : null,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          onChanged: () {
            if (_snapshot.hasLiveApi) {
              _loadCoachData();
            } else {
              _toggleBlockedSlot(slotKey: 'preview', blocked: false);
            }
          },
        ),
      ),
    );
    if (mounted) await _loadCoachData();
  }

  Future<void> _openHistoryPage() async {
    final api = _tryReadProvider<ApiClient>(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachBookingHistoryPage(
          coachMode: true,
          apiClient: api,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
        ),
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
      MaterialPageRoute(builder: (_) => CoachOffersPage(coachId: coachId)),
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
    if (widget.previewMode || !_snapshot.hasLiveApi) {
      final updated = Set<String>.from(_snapshot.blockedSlotKeys);
      if (blocked) {
        updated.add(slotKey);
      } else {
        updated.remove(slotKey);
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
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = MetaGymColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.overlayGlass,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
            side: BorderSide(color: colors.liquidGlassBorder, width: 1.1),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextFormField(
            autofocus: true,
            maxLength: 300,
            cursorColor: MetaGymTheme.brandOrange,
            style: TextStyle(color: colors.textPrimary),
            onChanged: (value) => reason = value.trim(),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: colors.textWarmMuted),
              counterStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.metricPanelBg,
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
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: colors.textWarmMuted,
              ),
              onPressed: () => Navigator.pop(ctx),
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

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
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
        onPushRoute: _pushRouteAndReload,
        onOpenNotifications: _openNotificationsPage,
        onOpenOffers: _openOffersPage,
        onOpenWorkWeek: _openWorkWeekPage,
        onOpenBlockedSlots: _openBlockedSlotsPage,
        onOpenHistory: _openHistoryPage,
        onCompleteBooking: _completeBooking,
        onCancelBooking: _cancelBooking,
      ),
      if (_visitedTabs.contains(1))
        CoachSessionsPage(
          coachId: currentUserId.isNotEmpty ? currentUserId : null,
          bottomPadding: bottomPadding,
          previewMode: widget.previewMode,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          onSessionsChanged: _loadCoachData,
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(2))
        AiConversationsPage(bottomPadding: bottomPadding, coachMode: true)
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(3))
        ConversationsPage(
          currentUserId: currentUserId,
          bottomPadding: bottomPadding,
          isActive: _index == 3,
          coachMode: true,
          onAvatarTap: () => _selectTab(4),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(4))
        ProfilePage(bottomPadding: bottomPadding, coachMode: true)
      else
        const SizedBox.shrink(),
    ];

    return RepaintBoundary(
      child: Scaffold(
        extendBody: true,
        backgroundColor: colors.canvas,
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
        memberLimit: _coachHardMemberCap,
        usedSlots: 6,
        availableSlots: 2,
        specialties: ['Hypertrophy', 'Giảm mỡ'],
      ),
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
      blockedSlotKeys: const {'12:00 – 13:30'},
      hasLiveApi: false,
    );
  }

  final CoachProfile? profile;
  final List<CoachMemberSummary> members;
  final List<_CoachBookingEntry> bookings;
  final List<CoachRecord> notifications;
  final List<CoachRecord> offers;
  final List<CoachRecord> workDays;
  final Set<int> activeWorkWeekdays;
  final List<CoachRecord> blocks;
  final Set<String> blockedSlotKeys;
  final bool hasLiveApi;

  int get activeMembersCount =>
      members.where((item) => item.status == 'ACTIVE').length;

  int get unreadNotificationsCount =>
      notifications.where((item) => item['readAt'] == null).length;

  int get configuredDaysCount => activeWorkWeekdays.length;

  int get blockedCount => math.max(blocks.length, blockedSlotKeys.length);

  int get upcomingBookingsCount =>
      bookings.where((entry) => entry.isUpcomingOrActive).length;

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
}

// =============================================================================
// Tab 0: Trang chủ Coach (Futuristic Performance Glass — đồng bộ Member Home 1.1)
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
    required this.onPushRoute,
    required this.onOpenNotifications,
    required this.onOpenOffers,
    required this.onOpenWorkWeek,
    required this.onOpenBlockedSlots,
    required this.onOpenHistory,
    required this.onCompleteBooking,
    required this.onCancelBooking,
  });

  final double bottomPadding;
  final bool useSolidGlassFallback;
  final bool isLoading;
  final bool isMutating;
  final String? loadError;
  final _CoachSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigateTab;
  final Future<void> Function(String path) onPushRoute;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenOffers;
  final Future<void> Function() onOpenWorkWeek;
  final Future<void> Function() onOpenBlockedSlots;
  final Future<void> Function() onOpenHistory;
  final Future<void> Function(_CoachBookingEntry entry) onCompleteBooking;
  final Future<void> Function(_CoachBookingEntry entry) onCancelBooking;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final user = _tryReadProvider<SessionController>(context)?.user;
    final coachName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName.trim()
        : (snapshot.profile?.fullName ?? 'Huấn luyện viên');

    return Material(
      color: colors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MetaGymBackground(useSolidFallback: useSolidGlassFallback),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: colors.overlayGlass,
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
                  _buildHeader(context, colors, coachName),
                  const SizedBox(height: 8),
                  _buildQuickActionDock(context, colors),
                  const SizedBox(height: 10),
                  if (loadError != null) ...[
                    _buildLoadErrorBanner(context, colors),
                    const SizedBox(height: 10),
                  ],
                  // 3. Hero Tóm tắt công việc (Warm Smoked Glass / Daylight White)
                  _buildHeroSummaryCard(context, colors, coachName),
                  const SizedBox(height: 10),
                  // 4. Ca dạy tiếp theo (Featured Liquid Glass đồng bộ Hôm nay của Member)
                  _buildNextSessionCard(context, colors),
                  const SizedBox(height: 10),
                  // 5. Bento 2 cột cân đối (Lịch tuần & Gói PT)
                  _buildBentoSection(context, colors),
                  const SizedBox(height: 14),
                  // 6. Quản lý & Thiết lập lịch
                  const _CoachSectionHeader(
                    title: 'Quản lý & Thiết lập lịch',
                    svgAsset: MetaGymIcons.actionCoachWorkweek,
                    fallbackIcon: Icons.tune_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildManagementCard(context, colors),
                  const SizedBox(height: 14),
                  // 7. Lịch dạy hôm nay
                  _buildTodayBookingsSection(context, colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors,
    String coachName,
  ) {
    return MetaGymBrandHeader(
      eyebrow: 'META GYM · COACH',
      title: 'Xin chào, $coachName',
      subtitle: 'Không gian dành cho huấn luyện viên',
      inlineSubtitle: true,
      actionSpacing: 6,
      actions: [
        _CoachNotificationIconButton(
          unreadCount: snapshot.unreadNotificationsCount,
          onTap: onOpenNotifications,
        ),
        Semantics(
          button: true,
          label: 'Hồ sơ Coach',
          child: Tooltip(
            message: 'Hồ sơ Coach',
            child: SizedBox(
              width: 48,
              height: 48,
              child: MetaGymTap(
                onTap: () => onNavigateTab(4),
                customBorder: const CircleBorder(),
                splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: MetaGymTheme.coachAvatarBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.warmGlassHighlight.withValues(
                          alpha: 0.55,
                        ),
                        width: 1.1,
                      ),
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
        ),
      ],
    );
  }

  Widget _buildQuickActionDock(BuildContext context, MetaGymColors colors) {
    return Row(
      children: [
        Expanded(
          child: _CoachQuickActionTile(
            svgAsset: MetaGymIcons.actionMembers,
            icon: Icons.groups_outlined,
            label: 'Học viên',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/members'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            svgAsset: MetaGymIcons.actionCoachPlans,
            icon: Icons.description_outlined,
            label: 'Giáo trình',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/training'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            svgAsset: MetaGymIcons.actionNutrition,
            icon: Icons.spa_outlined,
            label: 'Dinh dưỡng',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/nutrition'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickActionTile(
            svgAsset: MetaGymIcons.actionCoachSessions,
            icon: Icons.calendar_today_rounded,
            label: 'Lịch dạy',
            useSolidFallback: useSolidGlassFallback,
            onTap: () => onPushRoute('/coach/features/sessions'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadErrorBanner(BuildContext context, MetaGymColors colors) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: isLight
            ? colors.warning.withValues(alpha: 0.12)
            : const Color(0xD435281C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.50),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loadError!,
              style: TextStyle(color: colors.textWarmMuted, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Thử lại',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(Icons.refresh_rounded, color: colors.warning, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(
    BuildContext context,
    MetaGymColors colors,
    String coachName,
  ) {
    if (isLoading) {
      return MetaGymHeroGlassCard(
        useSolidFallback: useSolidGlassFallback,
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
    final unreadNotifications = snapshot.unreadNotificationsCount;
    final upcomingCount = snapshot.bookings
        .where((b) => b.isUpcomingOrActive)
        .length;
    final hasCapacityData = profile != null;
    final effectiveLimit = hasCapacityData
        ? math.min(profile.memberLimit, _coachHardMemberCap)
        : _coachHardMemberCap;
    final effectiveAvailableSlots = hasCapacityData
        ? math.max(0, effectiveLimit - profile.usedSlots)
        : 0;
    final isFull = hasCapacityData && effectiveAvailableSlots <= 0;
    final statusLabel = !hasCapacityData
        ? 'Hoạt động'
        : (isFull ? 'Đã đủ suất' : 'Còn $effectiveAvailableSlots suất');
    final statusTone = !hasCapacityData
        ? CoachingPillTone.green
        : (isFull ? CoachingPillTone.amber : CoachingPillTone.green);

    final heroContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onNavigateTab(1),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const MetaGymIcon(
                    MetaGymIcons.coachAchievement,
                    size: MetaGymIconSize.xs,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tổng quan công việc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CoachingPill(label: statusLabel, tone: statusTone),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textWarmMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetaGymMetricPanel(
                  onTap: () => onPushRoute('/coach/features/members'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hasCapacityData
                            ? '${profile.usedSlots}/$effectiveLimit'
                            : '$activeMembers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
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
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () => onPushRoute('/coach/features/sessions'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const MetaGymIcon(
                                MetaGymIcons.actionCoachSessions,
                                size: 13.5,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$upcomingCount buổi sắp tới',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textWarmMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetaGymMetricPanel(
                  onTap: onOpenNotifications,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
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
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  'Thông báo Coach',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unreadNotifications > 0
                            ? '$unreadNotifications thông báo chưa đọc'
                            : 'Chưa có thông báo mới',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadNotifications > 0
                              ? colors.warning
                              : colors.textWarmMuted,
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

    return MetaGymHeroGlassCard(
      useSolidFallback: useSolidGlassFallback,
      padding: const EdgeInsets.all(14),
      child: heroContent,
    );
  }

  Widget _buildNextSessionCard(BuildContext context, MetaGymColors colors) {
    final next = snapshot.nextUpcomingBooking;
    return MetaGymGlassCard(
      solid: useSolidGlassFallback,
      featured: !useSolidGlassFallback,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: next == null
          ? () => onPushRoute('/coach/features/sessions')
          : () => _openBookingDetailSheet(context, next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.actionCoachSessions,
                size: MetaGymIconSize.xs,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Ca dạy tiếp theo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CoachingPill(
                label: next == null
                    ? 'Chưa có lịch'
                    : (next.isCompleted ? 'Hoàn thành' : next.timeRange),
                tone: next == null
                    ? CoachingPillTone.neutral
                    : (next.isCompleted
                          ? CoachingPillTone.green
                          : CoachingPillTone.coral),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (next == null)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chưa có ca dạy nào sắp tới',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Thiết lập lịch tuần hoặc xem toàn bộ lịch đặt ca 90 phút.',
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 82,
                    minHeight: 38,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Lịch dạy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                CoachingAvatar(
                  fullName: next.memberName,
                  size: 40,
                  round: true,
                  paletteIndex: 1,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${next.timeRange} · ${next.focusTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 11.5,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 84,
                    minHeight: 38,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    next.isUpcomingOrActive ? 'Điểm danh' : 'Chi tiết',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBentoSection(BuildContext context, MetaGymColors colors) {
    final activeWeekdays = snapshot.activeWorkWeekdays;
    final configuredDays = snapshot.configuredDaysCount;
    final offers = snapshot.offers;
    final firstOffer = offers.isNotEmpty ? offers.first : null;
    final offerTitle = firstOffer?['name'] as String? ?? 'Gói tập PT 1:1';
    final offerPrice = firstOffer?['price'] as num?;
    final offerSessions = (firstOffer?['sessionCount'] as num?)?.toInt();
    final profile = snapshot.profile;
    final effectiveLimit = profile != null
        ? math.min(profile.memberLimit, _coachHardMemberCap)
        : _coachHardMemberCap;
    final usedRatio = (profile != null && effectiveLimit > 0)
        ? (profile.usedSlots / effectiveLimit).clamp(0.0, 1.0)
        : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MetaGymGlassCard(
              solid: useSolidGlassFallback,
              onTap: onOpenWorkWeek,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 122),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const MetaGymIcon(
                            MetaGymIcons.actionCoachWorkweek,
                            size: 16,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Lịch tuần',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CompactBentoBadge(
                            label: '$configuredDays/7 ngày',
                            color: configuredDays >= 6
                                ? colors.success
                                : colors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < _weekdayShortLabels.length; i++)
                            Expanded(
                              child: _CoachWeekBubble(
                                label: _weekdayShortLabels[i],
                                active: activeWeekdays.contains(i + 1),
                              ),
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
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CompactBentoBadge(
                            label: configuredDays >= 6
                                ? 'Đủ chuẩn'
                                : 'Cập nhật',
                            color: configuredDays >= 6
                                ? colors.success
                                : colors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (configuredDays / 7).clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: colors.metricPanelBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            configuredDays >= 6
                                ? colors.success
                                : colors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetaGymGlassCard(
              solid: useSolidGlassFallback,
              onTap: onOpenOffers,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 122),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const MetaGymIcon(
                            MetaGymIcons.coachPkg1on1,
                            size: 16,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Gói PT',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CompactBentoBadge(
                            label: '${offers.length} gói',
                            color: colors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        offerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
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
                        style: TextStyle(
                          color: colors.textWarmMuted,
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
                                  ? 'Suất: ${profile.usedSlots}/$effectiveLimit'
                                  : 'HV: ${snapshot.activeMembersCount}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CompactBentoBadge(
                            label: 'Mở',
                            color: colors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: profile != null ? usedRatio : 0.25,
                          minHeight: 3,
                          backgroundColor: colors.metricPanelBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context, MetaGymColors colors) {
    final activeMembers = snapshot.activeMembersCount;
    final configuredDays = snapshot.configuredDaysCount;
    final blockedCount = snapshot.blockedCount;
    final unreadCount = snapshot.unreadNotificationsCount;
    final upcomingCount = snapshot.upcomingBookingsCount;
    final dividerColor = colors.metricPanelBorder.withValues(alpha: 0.45);

    return MetaGymGlassCard(
      solid: useSolidGlassFallback,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionMembers,
            accent: colors.success,
            title: 'Hội viên của tôi',
            subtitle: activeMembers > 0
                ? 'Đang phụ trách $activeMembers học viên'
                : 'Danh sách học viên đang phụ trách',
            onTap: () => onPushRoute('/coach/features/members'),
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionCoachSessions,
            accent: MetaGymTheme.brandOrange,
            title: 'Lịch dạy & Buổi hẹn',
            subtitle: upcomingCount > 0
                ? '$upcomingCount buổi sắp tới · Quản lý đặt ca 90p'
                : 'Xem toàn bộ ca dạy & buổi hẹn 90p',
            onTap: () => onPushRoute('/coach/features/sessions'),
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionCoachWorkweek,
            accent: colors.reflection,
            title: 'Lịch làm việc cố định theo tuần',
            subtitle: 'Đang mở $configuredDays/7 ngày · Khung 90 phút',
            onTap: onOpenWorkWeek,
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionCoachBlockSlot,
            accent: colors.warning,
            title: 'Chặn khung giờ bận',
            subtitle: blockedCount == 0
                ? 'Chưa chặn khung giờ nào'
                : 'Đang chặn $blockedCount khung giờ',
            onTap: onOpenBlockedSlots,
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.workoutHistory,
            accent: colors.textWarmMuted,
            title: 'Lịch sử buổi dạy',
            subtitle: 'Thống kê ca hoàn thành, vắng & hủy',
            onTap: onOpenHistory,
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionCoachPlans,
            accent: colors.info,
            title: 'Giáo án tập & Thực đơn',
            subtitle: 'Soạn giáo trình tập & thực đơn 7 ngày',
            onTap: () => onPushRoute('/coach/features/training'),
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.actionOffers,
            accent: MetaGymTheme.brandOrange,
            title: 'Gói PT & Bảng giá',
            subtitle: snapshot.offers.isEmpty
                ? 'Xem các gói huấn luyện 1:1'
                : '${snapshot.offers.length} gói đang mở bán',
            onTap: onOpenOffers,
          ),
          Divider(height: 1, color: dividerColor),
          _CoachMenuRow(
            svgAsset: MetaGymIcons.settingNotificationsBell,
            accent: colors.info,
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

  Widget _buildTodayBookingsSection(
    BuildContext context,
    MetaGymColors colors,
  ) {
    final today = snapshot.todayBookings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _CoachSectionHeader(
                title: 'Lịch dạy hôm nay',
                svgAsset: MetaGymIcons.actionCoachSessions,
                fallbackIcon: Icons.today_rounded,
              ),
            ),
            InkWell(
              onTap: () => onPushRoute('/coach/features/sessions'),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    'Xem tất cả >',
                    style: TextStyle(
                      color: colors.primaryText,
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
          MetaGymGlassCard(
            solid: useSolidGlassFallback,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.metricPanelBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.metricPanelBorder),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymIcon(
                    MetaGymIcons.emptySessions,
                    size: MetaGymIconSize.xs,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hôm nay chưa có ca dạy nào được đặt.',
                    style: TextStyle(color: colors.textWarmMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          for (final entry in today)
            _CoachBookingTile(
              entry: entry,
              useSolidGlassFallback: useSolidGlassFallback,
              onTap: () => _openBookingDetailSheet(context, entry),
            ),
      ],
    );
  }

  Future<void> _openBookingDetailSheet(
    BuildContext context,
    _CoachBookingEntry entry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = MetaGymColors.of(ctx);
        return _CoachModalSheet(
          title: entry.memberName,
          subtitle: '${entry.timeRange} (90 phút)',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nội dung: ${entry.focusTitle}',
                style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CoachingSecondaryButton(
                      label: 'Nhắn tin',
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNavigateTab(3);
                      },
                    ),
                  ),
                  if (entry.isUpcomingOrActive) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          foregroundColor: MetaGymTheme.onPrimary,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: isMutating
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                onCompleteBooking(entry);
                              },
                        child: const Text('Hoàn tất'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              CoachingSecondaryButton(
                label: 'Mở trang Lịch dạy',
                expand: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  onPushRoute('/coach/features/sessions');
                },
              ),
              if (entry.isUpcomingOrActive) ...[
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: isMutating
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onCancelBooking(entry);
                        },
                  child: Text(
                    'Hủy buổi dạy này',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Focused UI Helpers (1:1 với MemberDashboardView + DESIGN.md Dark & Light)
// =============================================================================

class _CoachQuickActionTile extends StatelessWidget {
  const _CoachQuickActionTile({
    required this.svgAsset,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.useSolidFallback,
  });

  final String svgAsset;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool useSolidFallback;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: MetaGymGlassCard(
        solid: useSolidFallback,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MetaGymIcon(
                svgAsset,
                size: MetaGymIconSize.md,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
    final colors = MetaGymColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? MetaGymTheme.brandOrange : colors.metricPanelBg,
            border: Border.all(
              color: active
                  ? MetaGymTheme.brandOrange
                  : colors.metricPanelBorder,
              width: 0.9,
            ),
          ),
          alignment: Alignment.center,
          child: active
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: active ? colors.textPrimary : colors.textWarmMuted,
              fontSize: 9.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 88),
      child: Container(
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
      ),
    );
  }
}

class _CoachSectionHeader extends StatelessWidget {
  const _CoachSectionHeader({
    required this.title,
    required this.svgAsset,
    required this.fallbackIcon,
  });

  final String title;
  final String svgAsset;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Row(
      children: [
        MetaGymIcon(svgAsset, size: 16, excludeFromSemantics: true),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
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
    required this.svgAsset,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String svgAsset;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: onTap,
      splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                alignment: Alignment.center,
                child: MetaGymIcon(
                  svgAsset,
                  size: MetaGymIconSize.xs,
                  excludeFromSemantics: true,
                ),
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
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textWarmMuted,
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
  const _CoachBookingTile({
    required this.entry,
    required this.useSolidGlassFallback,
    required this.onTap,
  });

  final _CoachBookingEntry entry;
  final bool useSolidGlassFallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
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

    return MetaGymGlassCard(
      solid: useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.timeRange} · ${entry.focusTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textWarmMuted,
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
      ),
    );
  }
}

class _CoachModalSheet extends StatelessWidget {
  const _CoachModalSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(color: colors.textWarmMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _CoachNotificationIconButton extends StatelessWidget {
  const _CoachNotificationIconButton({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MetaGymCircleIconButton(
          icon: Icons.notifications_none_rounded,
          svgAsset: MetaGymIcons.settingNotificationsBell,
          tooltip: 'Thông báo Coach',
          onTap: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -1,
            top: -1,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.canvas, width: 2),
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
    );
  }
}
