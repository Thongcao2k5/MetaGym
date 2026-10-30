import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/member/presentation/member_explore_articles.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';
import 'package:provider/provider.dart';

/// Member Home dashboard implementing the "Futuristic Performance Glass"
/// Design System (`DESIGN.md`, `MASTER.md`, `pages/member-home.md`).
class MemberDashboardView extends StatefulWidget {
  const MemberDashboardView({
    required this.onNavigateTab,
    this.bottomPadding = 24.0,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final ValueChanged<int> onNavigateTab;
  final double bottomPadding;
  final bool useSolidGlassFallback;

  @override
  State<MemberDashboardView> createState() => _MemberDashboardViewState();
}

class _MemberDashboardViewState extends State<MemberDashboardView> {
  static const AssetImage _gymBannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  bool _initialized = false;
  bool _isLoading = true;
  bool _sessionsLoadFailed = false;
  bool _membershipLoadFailed = false;
  String? _loadError;
  List<Membership> _memberships = const [];
  List<MemberCoachRequest> _coachRequests = const [];
  List<MemberCoachRelationship> _relationshipHistory = const [];
  List<Membership> _membershipHistory = const [];
  Payment? _pendingPayment;
  MemberCoachRelationship? _activeRelationship;
  Map<String, String> _coachNames = const {};
  TrainingPlan? _activePlan;
  NutritionGuide? _activeNutrition;
  List<TrainingSession> _sessions = const [];
  WorkoutLog? _latestWorkout;
  MealLog? _latestMeal;
  List<WorkoutLog> _workouts = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_gymBannerAsset, context).catchError((_) {});
    }
    if (!_initialized) {
      _initialized = true;
      _loadFrame3Data();
    }
  }

  Future<void> _loadFrame3Data() async {
    MembershipController? membershipController;
    try {
      membershipController = context.read<MembershipController>();
    } catch (_) {}

    MemberCoachingService? coachingService;
    MemberTrainingService? trainingService;
    MemberNutritionService? nutritionService;
    MemberSessionsService? sessionsService;
    MemberWorkoutService? workoutService;
    MemberMealService? mealService;
    MembershipService? membershipService;

    try {
      coachingService = context.read<MemberCoachingService>();
    } catch (_) {
      try {
        coachingService = MemberCoachingApi(context.read<ApiClient>());
      } catch (_) {}
    }
    try {
      trainingService = context.read<MemberTrainingService>();
    } catch (_) {}
    try {
      nutritionService = context.read<MemberNutritionService>();
    } catch (_) {}
    try {
      sessionsService = context.read<MemberSessionsService>();
    } catch (_) {}
    try {
      workoutService = context.read<MemberWorkoutService>();
    } catch (_) {}
    try {
      mealService = context.read<MemberMealService>();
    } catch (_) {}
    try {
      membershipService = context.read<MembershipService>();
    } catch (_) {}

    MemberCoachRelationship? relationship;
    Map<String, String> coachNames = const {};
    TrainingPlan? activePlan;
    NutritionGuide? activeNutrition;
    List<TrainingSession> sessions = const [];
    WorkoutLog? latestWorkout;
    MealLog? latestMeal;
    List<Membership> memberships = const [];
    List<MemberCoachRequest> coachRequests = const [];
    List<MemberCoachRelationship> relationshipHistory = const [];
    List<Membership> membershipHistory = const [];
    List<WorkoutLog> workouts = const [];
    Payment? pendingPayment;
    var sessionsLoadFailed = false;
    var membershipLoadFailed = false;
    Object? firstError;

    if (coachingService != null) {
      try {
        final current = await coachingService.getCurrentRelationship();
        relationship = current;
      } catch (error) {
        firstError ??= error;
      }
      try {
        coachNames = await coachingService.getCoachNames();
      } catch (_) {}
      try {
        coachRequests = await coachingService.getRequests();
      } catch (_) {}
      try {
        relationshipHistory = await coachingService.getRelationshipHistory();
      } catch (_) {}
    }

    if (trainingService != null) {
      try {
        final plan = await trainingService.getActive();
        if (plan != null && plan.status == 'ACTIVE') {
          activePlan = plan;
        }
      } catch (error) {
        firstError ??= error;
      }
    }

    if (nutritionService != null) {
      try {
        final guide = await nutritionService.getActive();
        if (guide != null && guide.status == 'ACTIVE') {
          activeNutrition = guide;
        }
      } catch (error) {
        firstError ??= error;
      }
    }

    if (sessionsService != null) {
      try {
        sessions = await sessionsService.getMine();
      } catch (error) {
        sessionsLoadFailed = true;
        firstError ??= error;
      }
    }

    if (workoutService != null) {
      try {
        final page = await workoutService.getPage(1);
        workouts = page;
        if (page.isNotEmpty) {
          latestWorkout = page.first;
        }
      } catch (error) {
        firstError ??= error;
      }
    }

    if (mealService != null) {
      try {
        final page = await mealService.getPage(1);
        if (page.isNotEmpty) {
          latestMeal = page.first;
        }
      } catch (error) {
        firstError ??= error;
      }
    }

    if (membershipService != null) {
      try {
        memberships = await membershipService.getCurrentMemberships();
      } catch (error) {
        membershipLoadFailed = true;
        firstError ??= error;
      }
      try {
        membershipHistory = await membershipService.getMembershipHistory();
      } catch (_) {}
    }

    pendingPayment = membershipController?.pendingPayment;

    if (!mounted) return;
    setState(() {
      _activeRelationship = relationship;
      _coachNames = coachNames;
      _activePlan = activePlan;
      _activeNutrition = activeNutrition;
      _sessions = sessions;
      _latestWorkout = latestWorkout;
      _latestMeal = latestMeal;
      _memberships = memberships;
      _coachRequests = coachRequests;
      _relationshipHistory = relationshipHistory;
      _membershipHistory = membershipHistory;
      _pendingPayment = pendingPayment;
      _workouts = workouts;
      _isLoading = false;
      _sessionsLoadFailed = sessionsLoadFailed;
      _membershipLoadFailed = membershipLoadFailed;
      _loadError = firstError == null
          ? null
          : 'Không thể cập nhật toàn bộ dữ liệu. Kéo xuống để thử lại.';
    });
  }

  bool get _hasCoach {
    return _activeRelationship?.status == 'ACTIVE';
  }

  String get _displayCoachName {
    final coachId = _activeRelationship?.coachId;
    if (coachId != null && _coachNames.containsKey(coachId)) {
      final mapped = _coachNames[coachId]!.trim();
      if (mapped.isNotEmpty) return mapped;
    }
    return 'Coach của bạn';
  }

  TrainingSession? get _todayScheduledSession {
    final now = DateTime.now();
    for (final session in _sessions) {
      if (session.status != 'SCHEDULED' && session.status != 'COMPLETED') {
        continue;
      }
      final parsed = DateTime.tryParse(session.scheduledStartAt)?.toLocal();
      if (parsed != null &&
          parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day) {
        return session;
      }
    }
    return null;
  }

  Membership? get _activeMembership => _memberships
      .cast<Membership?>()
      .firstWhere((item) => item?.status == 'ACTIVE', orElse: () => null);

  Membership? get _scheduledMembership => _memberships
      .cast<Membership?>()
      .firstWhere((item) => item?.status == 'SCHEDULED', orElse: () => null);

  Membership? get _expiredMembership => _membershipHistory
      .cast<Membership?>()
      .firstWhere((item) => item?.status == 'EXPIRED', orElse: () => null);

  MemberCoachRelationship? get _endedRelationship => _relationshipHistory
      .cast<MemberCoachRelationship?>()
      .firstWhere((item) => item?.status == 'ENDED', orElse: () => null);

  MemberCoachRequest? get _latestCoachRequest =>
      _coachRequests.isEmpty ? null : _coachRequests.first;

  bool get _hasPendingCoachRequest =>
      _coachRequests.any((request) => request.status == 'PENDING');

  bool get _hasRecords => _latestWorkout != null || _latestMeal != null;

  bool get _isMembershipExpiring {
    final membership = _activeMembership;
    final end = membership == null
        ? null
        : DateTime.tryParse(membership.endDate)?.toLocal();
    if (end == null) return false;
    final remaining = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.now()).inDays;
    return remaining >= 0 && remaining <= 7;
  }

  TrainingSession? get _todaySession {
    final now = DateTime.now();
    for (final session in _sessions) {
      final parsed = DateTime.tryParse(session.scheduledStartAt)?.toLocal();
      if (parsed != null &&
          parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day) {
        return session;
      }
    }
    return null;
  }

  TrainingSession? get _nextScheduledSession {
    final now = DateTime.now();
    final upcoming =
        _sessions.where((session) {
            final parsed = DateTime.tryParse(session.scheduledStartAt)
                ?.toLocal();
            return session.status == 'SCHEDULED' &&
                parsed != null &&
                parsed.isAfter(now);
          }).toList()
          ..sort((a, b) => a.scheduledStartAt.compareTo(b.scheduledStartAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<_MockDayProgress> get _weekDays {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      final sessions = _sessions.where((session) {
        final parsed = DateTime.tryParse(session.scheduledStartAt)?.toLocal();
        return parsed != null &&
            parsed.year == date.year &&
            parsed.month == date.month &&
            parsed.day == date.day;
      });
      final hasWorkoutLog = _workouts.any((workout) {
        final parsed = DateTime.tryParse(workout.performedAt)?.toLocal();
        return parsed != null &&
            parsed.year == date.year &&
            parsed.month == date.month &&
            parsed.day == date.day;
      });
      return _MockDayProgress(
        day: labels[index],
        isCompleted:
            hasWorkoutLog ||
            sessions.any((session) => session.status == 'COMPLETED'),
        hasScheduled:
            sessions.any(
              (session) =>
                  session.status == 'SCHEDULED' ||
                  session.status == 'COMPLETED',
            ) ||
            hasWorkoutLog,
        isToday:
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
      );
    });
  }

  int get _completedDaysCount => _weekDays.where((d) => d.isCompleted).length;

  Future<void> _pushAndReload(String route) async {
    await context.push(route);
    if (mounted) {
      await _loadFrame3Data();
    }
  }

  /// Level 1 Solid Surface (`#11161C`, radius `20px`, `1px` border at ~10% opacity).
  BoxDecoration _solidCardDecoration({Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? MetaGymTheme.darkSurface,
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
      border: Border.all(color: MetaGymTheme.darkCardBorderSubtle, width: 1.0),
      boxShadow: const [
        BoxShadow(
          color: Color(0x47000000),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildTonalIconTile(
    IconData icon, {
    Color iconColor = MetaGymTheme.reflectionBlue,
    double size = 40,
    double iconSize = 20,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MetaGymTheme.darkSurfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final userName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Minh Quân';

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        children: [
          // Static dimmed atmospheric gym background at top (precached, 78–85% scrim)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _gymBannerAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: MetaGymTheme.darkCanvas),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xD6080A0D), // 84% obsidian at top
                          Color(0xC7080A0D), // 78% obsidian behind glass dock
                          MetaGymTheme.darkCanvas, // 100% solid obsidian canvas
                        ],
                        stops: [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main scrollable viewport
          RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: MetaGymTheme.darkSurface,
            onRefresh: _loadFrame3Data,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MetaGymTheme.pageGutter,
                0,
                MetaGymTheme.pageGutter,
                widget.bottomPadding,
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    // 1. Seamless Obsidian Header
                    _buildHeader(context, userName),
                    const SizedBox(height: 12),

                    // 2. Quick-Action Dock (Level 2 Performance Glass)
                    _QuickAccessSection(
                      onNavigateTab: widget.onNavigateTab,
                      useSolidFallback: widget.useSolidGlassFallback,
                    ),
                    const SizedBox(height: 16),

                    if (_loadError != null) ...[
                      _buildLoadErrorBanner(),
                      const SizedBox(height: 12),
                    ],

                    // 3. Focal Point Card: "Hôm nay" (placed BEFORE "Gói tập & Coach")
                    _buildTodaySection(context),
                    const SizedBox(height: 16),

                    // 4. Single Solid Card: "Gói tập & Coach"
                    _buildMembershipAndCoachCard(context),
                    const SizedBox(height: 16),

                    // 5. Nutrition & Member Logs ("Dinh dưỡng" & "Nhật ký của bạn")
                    _buildMemberLogsSection(context),
                    const SizedBox(height: 16),
                    if (_hasCoach) ...[
                      _buildNutritionSummaryCard(context),
                      const SizedBox(height: 16),
                    ],

                    // 6. Weekly Progress ("Tiến độ tuần") & Editorial "Khám phá"
                    _buildWeeklyProgressCard(context),
                    const SizedBox(height: 16),
                    _buildExploreSection(context),
                    const SizedBox(height: 16),

                    // Collapsible full feature workbench directory
                    _buildFullFeatureSection(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER: Obsidian blend, "META GYM" in #A9C7E8, "Chào, <Tên>" in #F7F9FC w700,
  //    Circular glass Search & Avatar with cool reflective border, no orange ring.
  // ===========================================================================
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
              _loadError!,
              style: const TextStyle(
                color: MetaGymTheme.darkTextSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadFrame3Data,
            tooltip: 'Thử lại',
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

  Widget _buildHeader(BuildContext context, String userName) {
    final cleanName = userName.trim();
    final parts = cleanName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (cleanName.isNotEmpty
              ? cleanName
                    .substring(0, cleanName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'MQ');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MetaGymTheme.darkSurfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MetaGymTheme.headerCircleBorder,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'MG',
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'META GYM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaGymTheme.reflectionBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chào, $userName',
                    style: const TextStyle(
                      color: MetaGymTheme.darkTextPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _CircleHeaderGlassButton(
              icon: Icons.search_rounded,
              semanticLabel: 'Tìm kiếm phòng gym và thiết bị',
              onTap: () => context.push('/member/features/gym'),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'Mở hồ sơ hội viên $userName',
              child: Tooltip(
                message: 'Hồ sơ',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onNavigateTab(4),
                    customBorder: const CircleBorder(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: MetaGymTheme.headerCircleGlass,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MetaGymTheme.headerCircleBorder,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. CARD "HÔM NAY" (PRIMARY FOCAL POINT — PLACED BEFORE "GÓI TẬP & COACH")
  // ===========================================================================
  Widget _buildTodaySection(BuildContext context) {
    final todaySession = _todaySession;
    final showTrainingCard = _hasCoach && _activePlan != null;
    final hasActiveMembership = _activeMembership != null;

    if (_isLoading) {
      return _buildTodayStatusCard(
        icon: Icons.sync_rounded,
        title: 'Đang cập nhật lịch hôm nay',
        subtitle: 'Thông tin mới nhất sẽ xuất hiện trong giây lát.',
      );
    }
    if (_sessionsLoadFailed) {
      return _buildTodayStatusCard(
        icon: Icons.error_outline_rounded,
        title: 'Không tải được lịch tập',
        subtitle: 'Các phần khác vẫn dùng được. Hãy thử tải lại riêng mục này.',
        actionLabel: 'Thử lại',
        onTap: _loadFrame3Data,
        tone: MetaGymTheme.dangerCoral,
      );
    }
    if (_activeRelationship?.status == 'PAUSED') {
      return _buildTodayStatusCard(
        icon: Icons.pause_circle_outline_rounded,
        title: 'Coach đang tạm dừng',
        subtitle: 'Bạn vẫn xem được lịch sử; gia hạn để mở lại các thao tác.',
        actionLabel: 'Gia hạn',
        onTap: () => _pushAndReload('/member/features/membership'),
        tone: MetaGymTheme.warningAmber,
      );
    }
    if (!hasActiveMembership) {
      return _buildTodayStatusCard(
        icon: Icons.lock_outline_rounded,
        title: _expiredMembership == null
            ? 'Lịch tập mở sau khi có gói'
            : 'Gói tập đã hết hạn',
        subtitle: _scheduledMembership == null
            ? 'Đăng ký gói để bắt đầu tập luyện.'
            : 'Gói mới bắt đầu ${_scheduledMembership!.startDate.split('T').first}.',
        actionLabel: _expiredMembership == null ? 'Đăng ký' : 'Gia hạn',
        onTap: () => _pushAndReload('/member/features/membership'),
      );
    }
    if (!_hasCoach) {
      return _buildSelfTrainingTodaySection(context);
    }
    if (todaySession == null) {
      final next = _nextScheduledSession;
      if (next != null) {
        final nextDate = DateTime.tryParse(next.scheduledStartAt)?.toLocal();
        return _buildTodayStatusCard(
          icon: Icons.event_available_rounded,
          title: 'Buổi tiếp theo · ${next.title}',
          subtitle: nextDate == null
              ? 'Đã được Coach lên lịch.'
              : '${_formatShortDate(nextDate)} · ${_extractTimeHHmm(next.scheduledStartAt)}',
          actionLabel: 'Xem lịch',
          onTap: () => _pushAndReload('/member/features/sessions'),
          tone: MetaGymTheme.infoSteelBlue,
        );
      }
      if (_activePlan != null) {
        return _buildTodayStatusCard(
          icon: Icons.description_outlined,
          title: 'Không có lịch hôm nay',
          subtitle: 'Giáo trình “${_activePlan!.title}” đang có hiệu lực.',
          actionLabel: 'Giáo trình',
          onTap: () => _pushAndReload('/member/features/training'),
          tone: MetaGymTheme.infoSteelBlue,
        );
      }
      return _buildTodayStatusCard(
        icon: Icons.hourglass_empty_rounded,
        title: 'Coach chưa gửi nội dung',
        subtitle: 'Giáo trình, dinh dưỡng và lịch tập sẽ xuất hiện tại đây.',
        actionLabel: 'Xem Coach',
        onTap: () => _pushAndReload('/member/features/my-coach'),
      );
    }
    if (todaySession.status != 'SCHEDULED') {
      final tone = switch (todaySession.status) {
        'COMPLETED' => MetaGymTheme.progressGreen,
        'MEMBER_ABSENT' => MetaGymTheme.warningAmber,
        'CANCELLED' => MetaGymTheme.dangerCoral,
        _ => MetaGymTheme.reflectionBlue,
      };
      return _buildTodayStatusCard(
        icon: todaySession.status == 'COMPLETED'
            ? Icons.check_circle_outline_rounded
            : Icons.event_busy_rounded,
        title: todaySession.title,
        subtitle: todaySession.statusLabel,
        actionLabel: 'Xem chi tiết',
        onTap: () => _pushAndReload('/member/features/sessions'),
        tone: tone,
      );
    }
    final workoutHeadline = todaySession.title;
    final notes = todaySession.notes?.trim();
    final workoutSubtitle =
        'Coach $_displayCoachName${notes?.isNotEmpty == true ? ' · $notes' : ''}';
    final sessionTimeText = _extractTimeHHmm(todaySession.scheduledStartAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hôm nay của bạn',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                todaySession.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.reflectionBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Primary Focal Card ("Hôm nay") — only featured image card in viewport
        ClipRRect(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          child: Container(
            decoration: _solidCardDecoration(),
            child: Stack(
              children: [
                // Right-side dark workout image with strong left-to-right gradient
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 180,
                  child: IgnorePointer(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: _gymBannerAsset,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: MetaGymTheme.darkSurfaceRaised,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                MetaGymTheme.darkSurface,
                                Color(0xEB11161C),
                                Color(0xB811161C),
                              ],
                              stops: [0.0, 0.48, 1.0],
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x6611161C),
                                Color(0x0011161C),
                                Color(0xCC11161C),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Foreground content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: MetaGymTheme.brandOrange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'BUỔI TẬP HÔM NAY',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: MetaGymTheme.brandOrange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  workoutHeadline,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  workoutSubtitle,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MetaGymTheme.darkSurfaceRaised,
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  sessionTimeText,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  todaySession.scheduledEndAt == null
                                      ? 'Theo lịch Coach'
                                      : 'Kết thúc ${_extractTimeHHmm(todaySession.scheduledEndAt!)}',
                                  style: TextStyle(
                                    color: MetaGymTheme.darkTextTertiary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Bắt đầu buổi tập $workoutHeadline',
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MetaGymTheme.brandOrange,
                                  foregroundColor: MetaGymTheme.onBrandOrange,
                                  minimumSize: const Size(48, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      MetaGymTheme.radiusInput,
                                    ),
                                  ),
                                ),
                                onPressed: () => _pushAndReload(
                                  hasActiveMembership
                                      ? '/member/features/workouts'
                                      : '/member/features/membership',
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'Bắt đầu buổi tập',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Semantics(
                            button: true,
                            label: 'Xem lịch tập chi tiết',
                            child: Tooltip(
                              message: 'Xem lịch tập',
                              child: Material(
                                color: MetaGymTheme.darkSurfaceRaised,
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                                child: InkWell(
                                  onTap: () => _pushAndReload(
                                    '/member/features/sessions',
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    MetaGymTheme.radiusInput,
                                  ),
                                  child: const SizedBox(
                                    width: 48,
                                    height: 44,
                                    child: Icon(
                                      Icons.calendar_today_outlined,
                                      color: MetaGymTheme.reflectionBlue,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (showTrainingCard) ...[
          const SizedBox(height: 10),
          _buildCoachTrainingCard(context, _activePlan!),
        ],
      ],
    );
  }

  Widget _buildTodayStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onTap,
    Color tone = MetaGymTheme.reflectionBlue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hôm nay của bạn',
          style: TextStyle(
            color: MetaGymTheme.darkTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(16),
              decoration: _solidCardDecoration(),
              child: Row(
                children: [
                  Icon(icon, color: tone, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: tone,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: tone, size: 17),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelfTrainingTodaySection(BuildContext context) {
    final request = _latestCoachRequest;
    final coachTitle = _hasPendingCoachRequest
        ? 'Chờ Coach duyệt'
        : request?.status == 'REJECTED'
        ? 'Chọn Coach khác'
        : request?.status == 'CANCELLED'
        ? 'Yêu cầu đã hủy'
        : _endedRelationship != null
        ? 'Chọn Coach mới'
        : 'Chọn Coach';
    final coachIcon = _hasPendingCoachRequest
        ? Icons.hourglass_top_rounded
        : Icons.people_outline_rounded;
    final coachTone = _hasPendingCoachRequest
        ? MetaGymTheme.warningAmber
        : MetaGymTheme.brandOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hôm nay của bạn',
          style: TextStyle(
            color: MetaGymTheme.darkTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TodayActionTile(
                icon: Icons.fitness_center_rounded,
                title: _hasRecords ? 'Ghi buổi tập' : 'Tự ghi buổi tập',
                color: MetaGymTheme.infoSteelBlue,
                onTap: () => _pushAndReload('/member/features/workouts'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayActionTile(
                icon: coachIcon,
                title: coachTitle,
                color: coachTone,
                onTap: _hasPendingCoachRequest
                    ? () => _pushAndReload('/member/features/my-coach')
                    : () => _pushAndReload('/member/features/coaching'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _extractTimeHHmm(String rawIso) {
    final parsed = DateTime.tryParse(rawIso)?.toLocal();
    if (parsed == null) return '--:--';
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildCoachTrainingCard(BuildContext context, TrainingPlan plan) {
    final todaySession = _todayScheduledSession;
    final hasReliableTodaySchedule = todaySession != null;

    final badgeLabel = hasReliableTodaySchedule
        ? 'Lịch tập hôm nay'
        : 'Giáo trình hiện hành';

    final firstDay = plan.days.isNotEmpty ? plan.days.first : null;
    final totalExercises = plan.days.fold<int>(
      0,
      (sum, d) => sum + d.exercises.length,
    );

    final primaryTitle = hasReliableTodaySchedule
        ? todaySession.title
        : (firstDay != null && firstDay.title.trim().isNotEmpty
              ? '${plan.title} · ${firstDay.title}'
              : plan.title);

    final exerciseCountLabel = firstDay != null && plan.days.length == 1
        ? '${firstDay.exercises.length} bài tập'
        : '$totalExercises bài tập · ${plan.days.length} buổi';

    final shortInfoParts = <String>[
      exerciseCountLabel,
      if (plan.goal != null && plan.goal!.trim().isNotEmpty)
        plan.goal!.trim()
      else if (firstDay?.notes != null && firstDay!.notes!.trim().isNotEmpty)
        firstDay.notes!.trim()
      else
        'Phiên bản ${plan.version}',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('frame3-coach-training-card'),
        onTap: () => _pushAndReload('/member/features/training'),
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _solidCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.darkSurfaceRaised,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.reflectionBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Mở giáo trình',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MetaGymTheme.reflectionBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: MetaGymTheme.reflectionBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTonalIconTile(
                      Icons.description_outlined,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryTitle,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            shortInfoParts.join(' · '),
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. CARD "GÓI TẬP & COACH" (SINGLE SOLID CARD — NO NESTED BORDERED SUB-CARDS)
  // ===========================================================================
  Widget _buildMembershipAndCoachCard(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 156,
        decoration: _solidCardDecoration(),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: MetaGymTheme.brandOrange,
          strokeWidth: 2.4,
        ),
      );
    }

    if (_membershipLoadFailed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _solidCardDecoration(),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: MetaGymTheme.dangerCoral,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Không tải được thông tin gói tập',
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _loadFrame3Data,
              tooltip: 'Thử lại',
              icon: const Icon(
                Icons.refresh_rounded,
                color: MetaGymTheme.reflectionBlue,
              ),
            ),
          ],
        ),
      );
    }

    final membership = _activeMembership;
    if (membership == null) {
      return _buildNoActiveMembershipCard(context);
    }

    final coachName = _displayCoachName;
    final endDate = DateTime.tryParse(membership.endDate)?.toLocal();
    final now = DateTime.now();
    final daysRemaining = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays
              .clamp(0, 99999);
    final coachStatus = _activeRelationship?.status;
    final requestStatus = _latestCoachRequest?.status;
    final packageTone = _isMembershipExpiring
        ? MetaGymTheme.warningAmber
        : MetaGymTheme.progressGreen;
    final packageLabel = _isMembershipExpiring ? 'Sắp hết hạn' : 'Hiệu lực';
    final hasCurrentCoach = coachStatus == 'ACTIVE' || coachStatus == 'PAUSED';
    final coachTitle = hasCurrentCoach
        ? coachName
        : _hasPendingCoachRequest
        ? 'Chờ Coach duyệt'
        : requestStatus == 'REJECTED'
        ? 'Yêu cầu bị từ chối'
        : requestStatus == 'CANCELLED'
        ? 'Yêu cầu đã hủy'
        : _endedRelationship != null
        ? 'Quan hệ đã kết thúc'
        : 'Chưa có Coach';
    final coachSubtitle = coachStatus == 'ACTIVE'
        ? 'Đang đồng hành cùng bạn'
        : coachStatus == 'PAUSED'
        ? 'Tạm dừng · lịch sử vẫn được giữ'
        : _hasPendingCoachRequest
        ? 'Không thể gửi thêm yêu cầu song song'
        : requestStatus == 'REJECTED'
        ? 'Bạn có thể chọn một Coach khác'
        : requestStatus == 'CANCELLED'
        ? 'Bạn có thể gửi yêu cầu mới'
        : _endedRelationship != null
        ? 'Chọn Coach mới khi bạn sẵn sàng'
        : 'Chọn Coach để được hướng dẫn';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _solidCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gói tập của bạn',
                  style: TextStyle(
                    color: MetaGymTheme.darkTextPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: packageTone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: packageTone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      packageLabel,
                      style: TextStyle(
                        color: packageTone,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Xem gói tập và thanh toán',
                child: InkWell(
                  onTap: () => context.push('/member/features/membership'),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 40,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isMembershipExpiring ? 'Gia hạn' : 'Xem gói tập',
                            style: TextStyle(
                              color: _isMembershipExpiring
                                  ? MetaGymTheme.warningAmber
                                  : MetaGymTheme.reflectionBlue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: _isMembershipExpiring
                                ? MetaGymTheme.warningAmber
                                : MetaGymTheme.reflectionBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Prominent membership metric comes from the membership end date.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                daysRemaining?.toString() ?? '—',
                style: TextStyle(
                  color: _isMembershipExpiring
                      ? MetaGymTheme.warningAmber
                      : MetaGymTheme.darkTextPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFeatures: MetaGymTheme.tabularFigures,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ngày còn lại',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.darkTextSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  endDate == null
                      ? 'Chưa có ngày kết thúc'
                      : 'Đến ${_formatShortDate(endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.darkTextTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_scheduledMembership case final scheduled?) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MetaGymTheme.infoSteelBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: MetaGymTheme.infoSteelBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gói tiếp theo bắt đầu ${scheduled.startDate.split('T').first}',
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Subtle 9% opacity divider separating Package metric and Coach row
          const Divider(
            height: 1,
            thickness: 1,
            color: MetaGymTheme.darkDividerSubtle,
          ),
          const SizedBox(height: 10),

          // Coach information reflects the real relationship state.
          InkWell(
            onTap: () => context.push(
              hasCurrentCoach || _hasPendingCoachRequest
                  ? '/member/features/my-coach'
                  : '/member/features/coaching',
            ),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  _buildTonalIconTile(
                    Icons.person_outline_rounded,
                    iconColor: MetaGymTheme.reflectionBlue,
                    size: 38,
                    iconSize: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                hasCurrentCoach ? 'Coach · ' : 'Trạng thái · ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: MetaGymTheme.darkTextTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                coachTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MetaGymTheme.darkTextPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          coachSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MetaGymTheme.darkTextTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveMembershipCard(BuildContext context) {
    final scheduled = _scheduledMembership;
    final pending = _pendingPayment;
    final expired = _expiredMembership;
    final title = pending != null
        ? 'Chờ thanh toán'
        : scheduled != null
        ? 'Gói tiếp theo đã được xếp lịch'
        : expired != null
        ? 'Gói tập đã hết hạn'
        : 'Bạn chưa có gói tập';
    final subtitle = pending != null
        ? '${pending.planName ?? 'Gói đã chọn'}${pending.amount == null ? '' : ' · ${pending.amount}₫'}'
        : scheduled != null
        ? 'Bắt đầu ${scheduled.startDate.split('T').first} · kết thúc ${scheduled.endDate.split('T').first}'
        : expired != null
        ? 'Hết hạn ${expired.endDate.split('T').first} · lịch sử vẫn được giữ.'
        : 'Đăng ký để mở nhật ký, lịch tập và quyền chọn Coach.';
    final tone = pending != null || scheduled != null
        ? MetaGymTheme.warningAmber
        : expired != null
        ? MetaGymTheme.dangerCoral
        : MetaGymTheme.brandOrange;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _solidCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTonalIconTile(
                Icons.card_membership_rounded,
                iconColor: tone,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 10),
            Text(
              _loadError!,
              style: const TextStyle(
                color: MetaGymTheme.warningAmber,
                fontSize: 11.5,
              ),
            ),
          ],
          if (_activeRelationship?.status == 'PAUSED') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MetaGymTheme.warningAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline_rounded,
                    color: MetaGymTheme.warningAmber,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coach tạm dừng · lịch sử vẫn xem được',
                      style: TextStyle(
                        color: MetaGymTheme.warningAmber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pushAndReload('/member/features/membership'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                pending != null
                    ? 'Tiếp tục thanh toán'
                    : expired != null
                    ? 'Gia hạn ngay'
                    : scheduled == null
                    ? 'Đăng ký ngay'
                    : 'Xem gói tập',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  // ===========================================================================
  // 5.1 NHẬT KÝ CỦA BẠN (2 SCANNABLE ROWS ON LEVEL 1 SOLID SURFACE)
  // ===========================================================================
  Widget _buildMemberLogsSection(BuildContext context) {
    final workout = _latestWorkout;
    final meal = _latestMeal;
    final canCreate =
        _activeMembership != null && _activeRelationship?.status != 'PAUSED';

    String workoutSubtitle;
    String workoutActionLabel;
    if (workout != null) {
      final dateStr = _safeFormatDate(workout.performedAt);
      final parts = <String>[
        dateStr,
        if (workout.durationMinutes != null) '${workout.durationMinutes} phút',
        if (workout.exercises.isNotEmpty) '${workout.exercises.length} bài tập',
      ];
      workoutSubtitle = parts.join(' · ');
      workoutActionLabel = canCreate ? 'Mở nhật ký' : 'Xem lịch sử';
    } else {
      workoutSubtitle = 'Bắt đầu ghi lại quá trình tập luyện';
      workoutActionLabel = canCreate ? 'Ghi buổi đầu tiên' : 'Cần gói';
    }

    String mealSubtitle;
    String mealActionLabel;
    if (meal != null) {
      final dateStr = _safeFormatDate(meal.eatenAt);
      mealSubtitle = '$dateStr · ${meal.mealName}';
      mealActionLabel = canCreate ? 'Mở nhật ký' : 'Xem lịch sử';
    } else {
      mealSubtitle = 'Ghi bữa ăn đầu tiên';
      mealActionLabel = canCreate ? 'Ghi bữa ăn đầu tiên' : 'Cần gói';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Flexible(
              child: Text(
                'Nhật ký của bạn',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '· Tự ghi hằng ngày',
                style: TextStyle(
                  color: MetaGymTheme.darkTextTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _solidCardDecoration(),
          child: Column(
            children: [
              _buildLogRow(
                rowKey: const Key('frame3-workout-log-row'),
                icon: Icons.fitness_center_outlined,
                title: 'Nhật ký tập luyện',
                subtitle: workoutSubtitle,
                actionLabel: workoutActionLabel,
                hasData: workout != null,
                onTap: () => _pushAndReload(
                  canCreate || workout != null
                      ? '/member/features/workouts'
                      : '/member/features/membership',
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: MetaGymTheme.darkDividerSubtle,
                indent: 16,
                endIndent: 16,
              ),
              _buildLogRow(
                rowKey: const Key('frame3-meal-log-row'),
                icon: Icons.restaurant_menu_rounded,
                title: 'Nhật ký ăn uống',
                subtitle: mealSubtitle,
                actionLabel: mealActionLabel,
                hasData: meal != null,
                onTap: () => _pushAndReload(
                  canCreate || meal != null
                      ? '/member/features/meals'
                      : '/member/features/membership',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow({
    required Key rowKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool hasData,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _buildTonalIconTile(icon, size: 38, iconSize: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: hasData
                              ? MetaGymTheme.darkTextSecondary
                              : MetaGymTheme.darkTextTertiary,
                          fontSize: 12,
                          fontWeight: hasData
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.darkSurfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            actionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasData
                                  ? MetaGymTheme.darkTextPrimary
                                  : MetaGymTheme.reflectionBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: hasData
                              ? MetaGymTheme.darkTextTertiary
                              : MetaGymTheme.reflectionBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _safeFormatDate(String rawIso) {
    try {
      return formatProgressTime(rawIso);
    } catch (_) {
      return rawIso.split('T').first;
    }
  }

  // ===========================================================================
  // 5.2 DINH DƯỠNG HÔM NAY (SOLID LEVEL 1 SURFACE, TABULAR FIGURES, TONAL PILLS)
  // ===========================================================================
  Widget _buildNutritionSummaryCard(BuildContext context) {
    final guide = _activeNutrition;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(
          guide == null
              ? 'frame3-nutrition-empty-card'
              : 'frame3-coach-nutrition-card',
        ),
        onTap: () => _pushAndReload('/member/features/nutrition'),
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _solidCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hướng dẫn dinh dưỡng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (guide == null
                                  ? MetaGymTheme.reflectionBlue
                                  : MetaGymTheme.progressGreen)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      guide == null ? 'Tự tập' : 'Từ Coach',
                      style: TextStyle(
                        color: guide == null
                            ? MetaGymTheme.reflectionBlue
                            : MetaGymTheme.progressGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                guide?.title ?? 'Chưa có hướng dẫn từ Coach',
                style: const TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                guide?.content ?? 'Ưu tiên bữa ăn cân bằng, uống đủ nước và ghi nhật ký để theo dõi thói quen của bạn.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.darkTextSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _pushAndReload('/member/features/nutrition'),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 17),
                  label: Text(
                    guide == null ? 'Mở dinh dưỡng' : 'Xem hướng dẫn',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: MetaGymTheme.reflectionBlue,
                    minimumSize: const Size(48, 40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 6.1 TIẾN ĐỘ TUẦN (SOLID LEVEL 1 SURFACE, #23C997 COMPLETED, #FF5A36 TODAY)
  // ===========================================================================
  Widget _buildWeeklyProgressCard(BuildContext context) {
    final completed = _completedDaysCount;
    final targetSessions = _weekDays.where((day) => day.hasScheduled).length;
    final ratio = targetSessions == 0
        ? 0.0
        : (completed / targetSessions).clamp(0.0, 1.0);
    final percentText = '${(ratio * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tiến độ tuần',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Xem chi tiết tiến độ tuần',
              child: InkWell(
                onTap: () => context.push('/member/features/progress'),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 40,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            color: MetaGymTheme.reflectionBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: MetaGymTheme.reflectionBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _solidCardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  _buildTonalIconTile(
                    Icons.bar_chart_rounded,
                    iconColor: MetaGymTheme.progressGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    targetSessions == 0 ? '0' : '$completed/$targetSessions',
                    style: const TextStyle(
                      color: MetaGymTheme.darkTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'buổi',
                    style: TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 7,
                        color: MetaGymTheme.darkSurfaceRaised,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: MetaGymTheme.progressGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    percentText,
                    style: const TextStyle(
                      color: MetaGymTheme.progressGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(_weekDays.length, (idx) {
                  final item = _weekDays[idx];
                  return Expanded(
                    child: _DayProgressItem(
                      day: item.day,
                      isCompleted: item.isCompleted,
                      isToday: item.isToday,
                      hasScheduled: item.hasScheduled,
                      onTap: () => context.push('/member/features/sessions'),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6.2 KHÁM PHÁ (EDITORIAL 2-ITEM LIST ON LEVEL 1 SOLID SURFACE)
  // ===========================================================================
  Widget _buildExploreSection(BuildContext context) {
    final homeArticles = kMemberExploreArticles.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Khám phá',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              key: const Key('frame3-explore-see-more'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const MemberExploreListPage(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem thêm',
                        style: TextStyle(
                          color: MetaGymTheme.reflectionBlue,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: MetaGymTheme.reflectionBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: _solidCardDecoration(),
          child: Column(
            children: [
              for (var i = 0; i < homeArticles.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: MetaGymTheme.darkDividerSubtle,
                    indent: 16,
                    endIndent: 16,
                  ),
                _buildExploreArticleRow(context, homeArticles[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExploreArticleRow(
    BuildContext context,
    ExploreArticleItem article,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('frame3-explore-item-${article.id}'),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => MemberExploreArticleDetailPage(article: article),
            ),
          );
        },
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Image.asset(
                      article.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: MetaGymTheme.darkSurfaceRaised,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.article_outlined,
                          color: MetaGymTheme.reflectionBlue,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.shortDescription,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: MetaGymTheme.darkTextTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullFeatureSection(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Không gian dành cho hội viên',
            style: TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Tất cả danh mục tính năng & kiểm thử',
            style: TextStyle(
              color: MetaGymTheme.darkTextTertiary,
              fontSize: 12,
            ),
          ),
          iconColor: MetaGymTheme.reflectionBlue,
          collapsedIconColor: MetaGymTheme.darkTextTertiary,
          children: [
            Container(
              decoration: _solidCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (final destination in memberDestinations)
                      ListTile(
                        title: Text(
                          destination.title,
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${destination.section} · ${destination.task}',
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: MetaGymTheme.darkTextTertiary,
                          size: 20,
                        ),
                        onTap: () => context.push(destination.path),
                      ),
                    if (FlowWorkbenchConfig.enabled)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                context.push(AppRoutes.memberWorkbench),
                            child: const Text('Kiểm thử các luồng hội viên'),
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
    );
  }
}

class _TodayActionTile extends StatelessWidget {
  const _TodayActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: MetaGymTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetaGymTheme.darkCardBorderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockDayProgress {
  _MockDayProgress({
    required this.day,
    required this.isCompleted,
    this.isToday = false,
    this.hasScheduled = false,
  });

  final String day;
  bool isCompleted;
  final bool isToday;
  final bool hasScheduled;
}

class _CircleHeaderGlassButton extends StatelessWidget {
  const _CircleHeaderGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.headerCircleGlass,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MetaGymTheme.headerCircleBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: MetaGymTheme.darkTextPrimary,
                    size: 20,
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

// ===========================================================================
// 2. QUICK-ACTION DOCK (LEVEL 2 PERFORMANCE GLASS)
// ===========================================================================
class _QuickAccessSection extends StatefulWidget {
  const _QuickAccessSection({
    required this.onNavigateTab,
    this.useSolidFallback = false,
  });

  final ValueChanged<int> onNavigateTab;
  final bool useSolidFallback;

  @override
  State<_QuickAccessSection> createState() => _QuickAccessSectionState();
}

class _QuickAccessSectionState extends State<_QuickAccessSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _selectedActionIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectAndPush(int globalIndex, String route) {
    setState(() => _selectedActionIndex = globalIndex);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final useGlassSurface = !widget.useSolidFallback && !disableAnimations;
    final enableBlur =
        useGlassSurface && !MetaGymTheme.isFlutterTestEnvironment;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final dockHeight = 108.0 + ((textScale - 1).clamp(0.0, 1.0) * 16);

    final dockBody = Container(
      height: dockHeight,
      decoration: BoxDecoration(
        gradient: useGlassSurface
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xB81C232D), // rgba(28, 35, 45, 0.72)
                  Color(0x940E1218), // rgba(14, 18, 24, 0.58)
                ],
              )
            : null,
        color: useGlassSurface ? null : MetaGymTheme.darkSurface,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        border: Border.all(
          color: MetaGymTheme.performanceGlassBorder,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000), // rgba(0, 0, 0, 0.24)
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 1,
            width: double.infinity,
            child: ColoredBox(color: MetaGymTheme.performanceGlassTopHighlight),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                // Page 1: Lịch tập · Giáo trình · Dinh dưỡng · Coach
                _buildDockPage([
                  _DockActionSpec(
                    index: 0,
                    accentColor: MetaGymTheme.brandOrange,
                    icon: Icons.calendar_today_outlined,
                    selectedIcon: Icons.calendar_today_rounded,
                    label: 'Lịch tập',
                    onTap: () => _selectAndPush(0, '/member/features/sessions'),
                  ),
                  _DockActionSpec(
                    index: 1,
                    accentColor: const Color(0xFF68B5FF),
                    icon: Icons.description_outlined,
                    selectedIcon: Icons.description_rounded,
                    label: 'Giáo trình',
                    onTap: () => _selectAndPush(1, '/member/features/training'),
                  ),
                  _DockActionSpec(
                    index: 2,
                    accentColor: const Color(0xFF48D5A8),
                    icon: Icons.restaurant_outlined,
                    selectedIcon: Icons.restaurant_rounded,
                    label: 'Dinh dưỡng',
                    onTap: () =>
                        _selectAndPush(2, '/member/features/nutrition'),
                  ),
                  _DockActionSpec(
                    index: 3,
                    accentColor: const Color(0xFFB79CFF),
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: 'Coach',
                    onTap: () => _selectAndPush(3, '/member/features/coaching'),
                  ),
                ]),
                // Page 2: Gói tập · Nhật ký tập · Nhật ký ăn · Tiến độ
                _buildDockPage([
                  _DockActionSpec(
                    index: 4,
                    accentColor: const Color(0xFFFFC266),
                    icon: Icons.card_membership_outlined,
                    selectedIcon: Icons.card_membership_rounded,
                    label: 'Gói tập',
                    onTap: () =>
                        _selectAndPush(4, '/member/features/membership'),
                  ),
                  _DockActionSpec(
                    index: 5,
                    accentColor: const Color(0xFF6EA8FF),
                    icon: Icons.assignment_outlined,
                    selectedIcon: Icons.assignment_rounded,
                    label: 'Nhật ký tập',
                    onTap: () => _selectAndPush(5, '/member/features/workouts'),
                  ),
                  _DockActionSpec(
                    index: 6,
                    accentColor: const Color(0xFFFF8A72),
                    icon: Icons.restaurant_menu_outlined,
                    selectedIcon: Icons.restaurant_menu_rounded,
                    label: 'Nhật ký ăn',
                    onTap: () => _selectAndPush(6, '/member/features/meals'),
                  ),
                  _DockActionSpec(
                    index: 7,
                    accentColor: const Color(0xFF55D6E8),
                    icon: Icons.bar_chart_outlined,
                    selectedIcon: Icons.bar_chart_rounded,
                    label: 'Tiến độ',
                    onTap: () => _selectAndPush(7, '/member/features/progress'),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 7, 4),
            child: Row(
              children: [
                _buildPageDot(isActive: _currentPage == 0),
                const SizedBox(width: 6),
                _buildPageDot(isActive: _currentPage == 1),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Xem tất cả tiện ích',
                  child: InkWell(
                    onTap: _showAllActions,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xem tất cả',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: MetaGymTheme.brandOrange,
                              size: 15,
                            ),
                          ],
                        ),
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

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MetaGymTheme.performanceGlassBlur,
                  sigmaY: MetaGymTheme.performanceGlassBlur,
                ),
                child: dockBody,
              )
            : dockBody,
      ),
    );
  }

  Widget _buildDockPage(List<_DockActionSpec> specs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < specs.length; i++)
          Expanded(
            child: _QuickAccessItem(
              icon: specs[i].icon,
              selectedIcon: specs[i].selectedIcon,
              accentColor: specs[i].accentColor,
              label: specs[i].label,
              selected: _selectedActionIndex == specs[i].index,
              onTap: specs[i].onTap,
            ),
          ),
      ],
    );
  }

  void _showAllActions() {
    final actions =
        <({String label, IconData icon, Color color, String route})>[
          (
            label: 'Phòng gym',
            icon: Icons.storefront_rounded,
            color: MetaGymTheme.brandOrange,
            route: '/member/features/gym',
          ),
          (
            label: 'Số đo',
            icon: Icons.straighten_rounded,
            color: MetaGymTheme.infoSteelBlue,
            route: '/member/features/measurements',
          ),
          (
            label: 'Ảnh tiến trình',
            icon: Icons.camera_alt_rounded,
            color: MetaGymTheme.progressGreen,
            route: '/member/features/photos',
          ),
          (
            label: 'Cuộc gọi',
            icon: Icons.call_rounded,
            color: const Color(0xFFB79CFF),
            route: '/member/features/calls',
          ),
        ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaGymTheme.darkSurface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tất cả tiện ích',
                style: TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 82,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: actions.length,
                itemBuilder: (_, index) {
                  final action = actions[index];
                  return InkWell(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push(action.route);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, color: action.color, size: 24),
                        const SizedBox(height: 7),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageDot({required bool isActive}) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MetaGymTheme.localStateDuration;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: isActive ? 12 : 5,
      height: 5,
      decoration: BoxDecoration(
        color: isActive
            ? MetaGymTheme.brandOrange
            : MetaGymTheme.darkTextTertiary.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _DockActionSpec {
  const _DockActionSpec({
    required this.index,
    required this.accentColor,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final Color accentColor;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({
    required this.icon,
    required this.selectedIcon,
    required this.accentColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = accentColor;
    final labelColor = selected ? accentColor : MetaGymTheme.darkTextPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withValues(alpha: 0.22)
                          : accentColor.withValues(alpha: 0.11),
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: selected ? 0.62 : 0.28,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: selected ? 0.20 : 0.06,
                          ),
                          blurRadius: selected ? 16 : 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.1,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayProgressItem extends StatelessWidget {
  const _DayProgressItem({
    required this.day,
    required this.isCompleted,
    required this.onTap,
    this.isToday = false,
    this.hasScheduled = false,
  });

  final String day;
  final bool isCompleted;
  final bool isToday;
  final bool hasScheduled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget indicatorChild;
    Color indicatorBg;
    Color borderColor;

    if (isCompleted) {
      indicatorBg = MetaGymTheme.progressGreen.withValues(alpha: 0.18);
      borderColor = MetaGymTheme.progressGreen;
      indicatorChild = const Icon(
        Icons.check_rounded,
        color: MetaGymTheme.progressGreen,
        size: 14,
      );
    } else if (isToday) {
      indicatorBg = MetaGymTheme.brandOrange;
      borderColor = MetaGymTheme.brandOrange;
      final digits = day.replaceAll(RegExp(r'\D'), '');
      indicatorChild = Text(
        digits.isNotEmpty ? digits : '6',
        style: const TextStyle(
          color: MetaGymTheme.onBrandOrange,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (hasScheduled) {
      indicatorBg = MetaGymTheme.darkSurfaceRaised;
      borderColor = MetaGymTheme.brandOrange.withValues(alpha: 0.45);
      indicatorChild = Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: MetaGymTheme.brandOrange,
          ),
        ),
      );
    } else {
      indicatorBg = MetaGymTheme.darkSurfaceRaised;
      borderColor = MetaGymTheme.darkCardBorderSubtle;
      indicatorChild = Center(
        child: Container(
          width: 6,
          height: 1.5,
          color: MetaGymTheme.darkTextTertiary.withValues(alpha: 0.45),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: isCompleted || isToday,
      label:
          'Ngày $day ${isCompleted ? "đã tập" : (isToday ? "hôm nay" : (hasScheduled ? "có lịch tập" : "nghỉ ngơi"))}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: indicatorBg,
                    border: Border.all(
                      color: borderColor,
                      width: isToday ? 1.6 : 1.0,
                    ),
                  ),
                  child: Center(child: indicatorChild),
                ),
                const SizedBox(height: 4),
                Text(
                  day,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isToday
                        ? MetaGymTheme.brandOrange
                        : isCompleted
                        ? MetaGymTheme.darkTextPrimary
                        : MetaGymTheme.darkTextTertiary,
                    fontSize: 11,
                    fontWeight: isCompleted || isToday
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontFeatures: MetaGymTheme.tabularFigures,
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
