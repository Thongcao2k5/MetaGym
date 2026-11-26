import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_card.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:provider/provider.dart';

enum _HistoryFilter { all, completed, absent, cancelled }

String _twoDigits(int v) => v.toString().padLeft(2, '0');

DateTime _toGymTime(DateTime t) => t.toUtc().add(const Duration(hours: 7));

String _weekdayShort(int weekday) => weekday == 7 ? 'CN' : 'T${weekday + 1}';

T? _tryReadProvider<T>(BuildContext context) {
  try {
    return context.read<T?>();
  } on ProviderNotFoundException {
    return null;
  } catch (_) {
    return null;
  }
}

class _CoachHistoryEntry {
  const _CoachHistoryEntry({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.startsAt,
    required this.gymStart,
    required this.gymEnd,
    required this.focusTitle,
    required this.status,
    this.reason,
    this.chargedAt,
  });

  final String id;
  final String memberId;
  final String memberName;
  final DateTime startsAt;
  final DateTime gymStart;
  final DateTime gymEnd;
  final String focusTitle;
  final String status;
  final String? reason;
  final Object? chargedAt;

  bool get isCompleted => status == 'COMPLETED';
  bool get isAbsent => status == 'NO_SHOW' || status == 'MEMBER_ABSENT';
  bool get isCancelled => status == 'CANCELLED';

  String get monthKey =>
      'Tháng ${_twoDigits(gymStart.month)} / ${gymStart.year}';

  String get timeRange =>
      '${_twoDigits(gymStart.hour)}:${_twoDigits(gymStart.minute)} – ${_twoDigits(gymEnd.hour)}:${_twoDigits(gymEnd.minute)}';

  String get dateClockSummary =>
      '${_weekdayShort(gymStart.weekday)}, ${_twoDigits(gymStart.day)}/${_twoDigits(gymStart.month)} · $timeRange';
}

/// Màn hình lịch sử buổi tập (Member) và **2.4 Lịch sử buổi dạy** (Coach).
class CoachBookingHistoryPage extends StatefulWidget {
  const CoachBookingHistoryPage({
    this.bookings,
    this.matchPlanDay,
    this.onOpenPlanDay,
    this.coachMode,
    this.apiClient,
    this.sessionsService,
    this.membersService,
    this.previewMode = false,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final List<CoachRecord>? bookings;
  final TrainingDay? Function(String startsAt)? matchPlanDay;
  final void Function(TrainingDay? day)? onOpenPlanDay;
  final bool? coachMode;
  final ApiClient? apiClient;
  final CoachSessionsService? sessionsService;
  final CoachMembersService? membersService;
  final bool previewMode;
  final bool useSolidGlassFallback;

  @override
  State<CoachBookingHistoryPage> createState() =>
      _CoachBookingHistoryPageState();
}

class _CoachBookingHistoryPageState extends State<CoachBookingHistoryPage> {
  bool _initialized = false;
  bool _loading = false;
  String? _loadError;
  _HistoryFilter _filter = _HistoryFilter.all;

  List<CoachRecord> _memberRecords = const [];
  List<_CoachHistoryEntry> _coachEntries = const [];
  CoachMembersService? _membersService;

  bool get _isCoachMode {
    if (widget.coachMode != null) return widget.coachMode!;
    if (widget.bookings != null) return false;
    return _tryReadProvider<SessionController>(context)?.user?.role ==
        UserRole.coach;
  }

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
    _membersService =
        widget.membersService ?? _tryReadProvider<CoachMembersService>(context);
    _initData();
  }

  @override
  void didUpdateWidget(covariant CoachBookingHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookings != widget.bookings && widget.bookings != null) {
      _memberRecords = widget.bookings!;
      if (_isCoachMode) {
        _coachEntries = _parseCoachRecords(widget.bookings!, const {});
      }
    }
  }

  void _initData() {
    if (!_isCoachMode) {
      _memberRecords = widget.bookings ?? const [];
      _loading = false;
      return;
    }

    if (widget.previewMode) {
      final now = _toGymTime(DateTime.now());
      DateTime atGym(int daysAgo, int hour, int minute) => DateTime.utc(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).subtract(Duration(days: daysAgo));
      _coachEntries = [
        _CoachHistoryEntry(
          id: 'h-1',
          memberId: 'm-1',
          memberName: 'Nguyễn Minh Quân',
          startsAt: atGym(1, 18, 0).subtract(const Duration(hours: 7)),
          gymStart: atGym(1, 18, 0),
          gymEnd: atGym(1, 19, 30),
          focusTitle: 'Upper Body & Core',
          status: 'COMPLETED',
        ),
        _CoachHistoryEntry(
          id: 'h-2',
          memberId: 'm-2',
          memberName: 'Trần Thảo Vy',
          startsAt: atGym(2, 19, 45).subtract(const Duration(hours: 7)),
          gymStart: atGym(2, 19, 45),
          gymEnd: atGym(2, 21, 15),
          focusTitle: 'Glutes & Core',
          status: 'COMPLETED',
        ),
        _CoachHistoryEntry(
          id: 'h-3',
          memberId: 'm-4',
          memberName: 'Đỗ Khánh Linh',
          startsAt: atGym(3, 17, 0).subtract(const Duration(hours: 7)),
          gymStart: atGym(3, 17, 0),
          gymEnd: atGym(3, 18, 30),
          focusTitle: 'Full Body Conditioning',
          status: 'NO_SHOW',
        ),
        _CoachHistoryEntry(
          id: 'h-4',
          memberId: 'm-3',
          memberName: 'Phạm Quốc Bảo',
          startsAt: atGym(5, 9, 0).subtract(const Duration(hours: 7)),
          gymStart: atGym(5, 9, 0),
          gymEnd: atGym(5, 10, 30),
          focusTitle: 'Dời lịch trước 12 giờ',
          status: 'CANCELLED',
          reason: 'Hội viên xin dời lịch trước 12 giờ',
        ),
      ];
      _loading = false;
      return;
    }

    if (widget.bookings != null) {
      _coachEntries = _parseCoachRecords(widget.bookings!, const {});
      _loading = false;
      return;
    }

    _loadCoachHistory();
  }

  Future<void> _loadCoachHistory() async {
    final apiClient = widget.apiClient ?? _tryReadProvider<ApiClient>(context);
    final sessionsService =
        widget.sessionsService ??
        _tryReadProvider<CoachSessionsService>(context);
    final membersService =
        widget.membersService ?? _tryReadProvider<CoachMembersService>(context);
    final hasMockSessions =
        sessionsService != null && sessionsService is! CoachSessionsApi;
    final hasMockMembers =
        membersService != null && membersService is! CoachMembersApi;
    final useV2 =
        apiClient != null &&
        (widget.apiClient != null || (!hasMockSessions && !hasMockMembers));

    if (!useV2 && sessionsService == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    List<CoachMemberSummary> members = const [];
    List<CoachRecord> bookings = const [];
    List<TrainingSession> sessions = const [];
    Object? firstError;

    if (membersService != null) {
      try {
        members = await membersService.getMembers();
      } catch (_) {}
    }

    if (useV2) {
      try {
        bookings = await CoachV2Api(apiClient).list('/coach-bookings');
      } catch (e) {
        firstError ??= e;
      }
    }

    if (sessionsService != null) {
      try {
        sessions = await sessionsService.getAll();
      } catch (e) {
        firstError ??= e;
      }
    }

    final memberNames = <String, String>{
      for (final m in members) m.memberId: m.memberFullName,
    };

    final merged = <_CoachHistoryEntry>[
      ..._parseCoachRecords(bookings, memberNames),
      ..._parseLegacySessions(sessions, memberNames),
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    if (!mounted) return;
    setState(() {
      _coachEntries = merged;
      _loading = false;
      if (merged.isEmpty && firstError != null) {
        _loadError = firstError is ApiException
            ? firstError.message
            : 'Không tải được lịch sử buổi dạy.';
      }
    });
  }

  List<_CoachHistoryEntry> _parseCoachRecords(
    List<CoachRecord> rows,
    Map<String, String> memberNames,
  ) {
    final now = DateTime.now();
    final list = <_CoachHistoryEntry>[];
    for (final raw in rows) {
      final status = (raw['status'] as String? ?? 'COMPLETED').toUpperCase();
      final startsRaw = raw['startsAt'] as String? ?? '';
      final start = DateTime.tryParse(startsRaw);
      if (start == null) continue;
      if (status == 'BOOKED' && start.isAfter(now)) continue;
      final endsRaw = raw['endsAt'] as String?;
      final parsedEnd = endsRaw != null ? DateTime.tryParse(endsRaw) : null;
      final gymStart = _toGymTime(start);
      final gymEnd = parsedEnd != null
          ? _toGymTime(parsedEnd)
          : gymStart.add(const Duration(minutes: 90));
      final memberId = raw['memberId'] as String? ?? '';
      final rawName = raw['memberName'] as String?;
      final resolvedName = (rawName != null && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : (memberNames[memberId] ?? 'Hội viên');
      final focus = (raw['focusTitle'] as String?)?.trim().isNotEmpty == true
          ? (raw['focusTitle'] as String).trim()
          : 'Buổi dạy 1:1 (90 phút)';
      list.add(
        _CoachHistoryEntry(
          id: raw['id'] as String? ?? startsRaw,
          memberId: memberId,
          memberName: resolvedName,
          startsAt: start,
          gymStart: gymStart,
          gymEnd: gymEnd,
          focusTitle: focus,
          status: status,
          reason: (raw['reason'] as String?)?.trim(),
          chargedAt: raw['chargedAt'],
        ),
      );
    }
    return list;
  }

  List<_CoachHistoryEntry> _parseLegacySessions(
    List<TrainingSession> sessions,
    Map<String, String> memberNames,
  ) {
    final list = <_CoachHistoryEntry>[];
    for (final s in sessions) {
      if (s.status == 'SCHEDULED') continue;
      final start = DateTime.tryParse(s.scheduledStartAt);
      if (start == null) continue;
      final endParsed = s.scheduledEndAt != null
          ? DateTime.tryParse(s.scheduledEndAt!)
          : null;
      final gymStart = _toGymTime(start);
      final gymEnd = endParsed != null
          ? _toGymTime(endParsed)
          : gymStart.add(const Duration(minutes: 90));
      list.add(
        _CoachHistoryEntry(
          id: s.id,
          memberId: s.memberId ?? '',
          memberName: memberNames[s.memberId ?? ''] ?? 'Học viên Meta Gym',
          startsAt: start,
          gymStart: gymStart,
          gymEnd: gymEnd,
          focusTitle: s.title,
          status: s.status.toUpperCase(),
          reason: s.cancellationReason?.trim(),
        ),
      );
    }
    return list;
  }

  String _formatPercent(int numerator, int total) {
    if (total <= 0) return '0%';
    final pct = (numerator * 100) / total;
    if ((pct - pct.roundToDouble()).abs() < 0.05) {
      return '${pct.round()}%';
    }
    return '${pct.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  @override
  Widget build(BuildContext context) {
    final isCoach = _isCoachMode;
    if (!isCoach) {
      return _buildMemberLegacyLayout(context);
    }
    return _buildCoachLayout(context);
  }

  Widget _buildCoachLayout(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    final completedCount = _coachEntries.where((e) => e.isCompleted).length;
    final missedOrCancelledCount = _coachEntries.length - completedCount;
    final rateLabel = _formatPercent(completedCount, _coachEntries.length);

    final filtered = _coachEntries.where((entry) {
      return switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.completed => entry.isCompleted,
        _HistoryFilter.absent => entry.isAbsent,
        _HistoryFilter.cancelled => entry.isCancelled,
      };
    }).toList();

    final grouped = <String, List<_CoachHistoryEntry>>{};
    for (final entry in filtered) {
      (grouped[entry.monthKey] ??= []).add(entry);
    }

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
                _buildCoachHeader(context, colors, isLight),
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
                          onRefresh:
                              widget.previewMode || widget.bookings != null
                              ? () async {}
                              : _loadCoachHistory,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              MediaQuery.paddingOf(context).bottom + 36,
                            ),
                            children: [
                              if (_loadError != null) ...[
                                CoachingErrorBanner(message: _loadError!),
                                CoachingSecondaryButton(
                                  label: 'Thử lại',
                                  expand: true,
                                  onPressed: _loadCoachHistory,
                                ),
                                const SizedBox(height: 12),
                              ],
                              // Hero Card: Tổng hợp chuyên cần
                              MetaGymHeroGlassCard(
                                useSolidFallback: widget.useSolidGlassFallback,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.timeClock,
                                          size: MetaGymIconSize.sm,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Tổng hợp chuyên cần',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          flex: 0,
                                          child: CoachingPill(
                                            label: '$rateLabel hoàn thành',
                                            tone: _coachEntries.isEmpty
                                                ? CoachingPillTone.neutral
                                                : CoachingPillTone.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: MetaGymMetricPanel(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Đã hoàn thành',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textWarmMuted,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '$completedCount',
                                                    style: TextStyle(
                                                      color: colors.success,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontFeatures: MetaGymTheme
                                                          .tabularFigures,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Buổi 90 phút',
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: MetaGymMetricPanel(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Đã hủy / HV vắng',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textWarmMuted,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '$missedOrCancelledCount',
                                                    style: TextStyle(
                                                      color:
                                                          missedOrCancelledCount >
                                                              0
                                                          ? colors.warning
                                                          : colors.textPrimary,
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontFeatures: MetaGymTheme
                                                          .tabularFigures,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Tổng bản ghi lịch sử',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 11,
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
                                ),
                              ),

                              // 4 filter pills
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HistoryFilterPill(
                                      key: const Key('history-filter-all'),
                                      label: 'Tất cả',
                                      selected: _filter == _HistoryFilter.all,
                                      onTap: () => setState(
                                        () => _filter = _HistoryFilter.all,
                                      ),
                                    ),
                                    _HistoryFilterPill(
                                      key: const Key(
                                        'history-filter-completed',
                                      ),
                                      label: 'Hoàn thành',
                                      selected:
                                          _filter == _HistoryFilter.completed,
                                      onTap: () => setState(
                                        () =>
                                            _filter = _HistoryFilter.completed,
                                      ),
                                    ),
                                    _HistoryFilterPill(
                                      key: const Key('history-filter-absent'),
                                      label: 'HV vắng',
                                      selected:
                                          _filter == _HistoryFilter.absent,
                                      onTap: () => setState(
                                        () => _filter = _HistoryFilter.absent,
                                      ),
                                    ),
                                    _HistoryFilterPill(
                                      key: const Key(
                                        'history-filter-cancelled',
                                      ),
                                      label: 'Đã hủy',
                                      selected:
                                          _filter == _HistoryFilter.cancelled,
                                      onTap: () => setState(
                                        () =>
                                            _filter = _HistoryFilter.cancelled,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_coachEntries.isEmpty)
                                MetaGymGlassCard(
                                  solid: widget.useSolidGlassFallback,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const MetaGymIcon(
                                        MetaGymIcons.emptySessions,
                                        size: MetaGymIconSize.lg,
                                        excludeFromSemantics: true,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Chưa có lịch sử buổi dạy.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Các buổi dạy đã hoàn thành, vắng mặt hoặc hủy sẽ được tổng hợp tại đây.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 12.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (filtered.isEmpty)
                                MetaGymGlassCard(
                                  solid: widget.useSolidGlassFallback,
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Không có bản ghi phù hợp bộ lọc.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      CoachingSecondaryButton(
                                        label: 'Xem tất cả',
                                        onPressed: () => setState(
                                          () => _filter = _HistoryFilter.all,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (final monthEntry in grouped.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      2,
                                      4,
                                      2,
                                      8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            monthEntry.key,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${monthEntry.value.length} bản ghi',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures:
                                                MetaGymTheme.tabularFigures,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final item in monthEntry.value)
                                    _buildCoachHistoryCard(colors, item),
                                  const SizedBox(height: 6),
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

  Widget _buildCoachHeader(
    BuildContext context,
    MetaGymColors colors,
    bool isLight,
  ) {
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            _HistoryBackButton(
              isLight: isLight,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'THỐNG KÊ GIẢNG DẠY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lịch sử buổi dạy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachHistoryCard(MetaGymColors colors, _CoachHistoryEntry item) {
    final pill = item.isCompleted
        ? const CoachingPill(label: 'Hoàn thành', tone: CoachingPillTone.green)
        : item.isAbsent
        ? const CoachingPill(
            label: 'Hội viên vắng',
            tone: CoachingPillTone.amber,
          )
        : CoachingPill(
            label: item.chargedAt != null ? 'Đã hủy · Đã trừ lượt' : 'Đã hủy',
            tone: item.chargedAt != null
                ? CoachingPillTone.amber
                : CoachingPillTone.neutral,
          );

    final membersService = _membersService;
    final canOpenMember = item.memberId.isNotEmpty && membersService != null;

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: canOpenMember
          ? () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CoachMemberDetailPage(
                  memberId: item.memberId,
                  service: membersService,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.memberName,
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
              Flexible(flex: 0, child: pill),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${item.dateClockSummary} · ${item.focusTitle}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12,
              height: 1.4,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Lý do: ${item.reason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberLegacyLayout(BuildContext context) {
    final now = DateTime.now();
    final completedCount = _memberRecords
        .where((b) => b['status'] == 'COMPLETED')
        .length;
    final cancelledCount = _memberRecords.length - completedCount;

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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lịch sử buổi tập',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Các buổi đã tập & đã hủy với Coach',
                              style: TextStyle(
                                color: Color(0xFFC8C2BC),
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
                    padding: EdgeInsets.fromLTRB(
                      16,
                      6,
                      16,
                      MediaQuery.paddingOf(context).bottom + 32,
                    ),
                    children: [
                      MetaGymHeroGlassCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: MetaGymMetricPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Đã hoàn thành',
                                      style: TextStyle(
                                        color: Color(0xFFB8B0A8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount buổi',
                                      style: const TextStyle(
                                        color: MetaGymTheme.progressGreen,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MetaGymMetricPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Đã hủy / Khác',
                                      style: TextStyle(
                                        color: Color(0xFFB8B0A8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$cancelledCount buổi',
                                      style: const TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              color: MetaGymTheme.brandOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Các buổi đã tập & đã hủy',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_memberRecords.length} buổi',
                              style: const TextStyle(
                                color: Color(0xFFC8C2BC),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_memberRecords.isEmpty)
                        const MetaGymGlassCard(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Chưa có lịch sử buổi tập với Coach.',
                              style: TextStyle(
                                color: Color(0xFFC8C2BC),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final booking in _memberRecords) ...[
                          Builder(
                            builder: (context) {
                              final matchedDay = widget.matchPlanDay?.call(
                                booking['startsAt'] as String,
                              );
                              final coachName = booking['coachName'] as String?;
                              return CoachMemberBookingCard(
                                booking: booking,
                                isUpcoming: false,
                                now: now,
                                primaryTitle:
                                    matchedDay?.title ??
                                    (coachName != null &&
                                            coachName.trim().isNotEmpty
                                        ? coachName.trim()
                                        : 'Huấn luyện viên'),
                                matchedDay: matchedDay,
                                onOpenCurriculum:
                                    matchedDay != null &&
                                        widget.onOpenPlanDay != null
                                    ? () => widget.onOpenPlanDay!(matchedDay)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
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

class _HistoryBackButton extends StatelessWidget {
  const _HistoryBackButton({required this.isLight, required this.onTap});

  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Tooltip(
      message: 'Quay lại',
      child: Semantics(
        button: true,
        label: 'Quay lại',
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
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
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
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      MetaGymIcon(
                        MetaGymIcons.commonBack,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.arrow_back_rounded,
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
      ),
    );
  }
}

class _HistoryFilterPill extends StatelessWidget {
  const _HistoryFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = selected
        ? colors.chipActiveBg
        : (isLight ? colors.surface : colors.liquidGlass);
    final border = selected
        ? MetaGymTheme.brandOrange
        : (isLight ? colors.borderStrong : colors.liquidGlassBorder);
    final fg = selected
        ? (isLight ? colors.chipActiveText : colors.textPrimary)
        : colors.textWarmMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          side: BorderSide(color: border, width: selected ? 1.2 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
