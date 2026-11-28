import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/offline_sync_manager.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_3d_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/member/presentation/member_explore_articles.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_explore_and_news.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_fan_deck.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_qr_modal.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';
import 'package:meta_gym_app/features/notifications/presentation/notification_router.dart';
import 'package:meta_gym_app/features/notifications/presentation/notifications_controller.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_day_plan_page.dart';
import 'package:provider/provider.dart';

/// Member Home dashboard implementing the "Futuristic Performance Glass"
/// Design System (`DESIGN.md`, `MASTER.md`, `pages/member-home.md`).
class MemberDashboardView extends StatefulWidget {
  const MemberDashboardView({
    required this.onNavigateTab,
    this.bottomPadding = 24.0,
    this.useSolidGlassFallback = false,
    this.previewMode = false,
    super.key,
  });

  final ValueChanged<int> onNavigateTab;
  final double bottomPadding;
  final bool useSolidGlassFallback;
  final bool previewMode;

  @override
  State<MemberDashboardView> createState() => _MemberDashboardViewState();
}

class _MemberDashboardViewState extends State<MemberDashboardView> {
  SyncRevisionBinding? _syncBinding;
  bool _initialized = false;
  bool _isLoading = true;
  String? _loadError;
  List<Membership> _memberships = const [];
  List<MemberCoachRequest> _coachRequests = const [];
  MemberCoachRelationship? _activeRelationship;
  Map<String, String> _coachNames = const {};
  NutritionGuide? _activeNutrition;
  TrainingPlan? _activePlan;
  List<TrainingSession> _sessions = const [];
  ProgressSummary? _progressSummary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MetaGymBackground.precache(context);
    _syncBinding ??= bindApiCacheSync(context, () {
      if (mounted && !widget.previewMode) {
        _loadFrame3Data();
      }
    });
    if (!_initialized) {
      _initialized = true;
      _loadFrame3Data();
    }
  }

  @override
  void dispose() {
    _syncBinding?.dispose();
    super.dispose();
  }

  Future<void> _loadFrame3Data() async {
    MemberCoachingService? coachingService;
    MemberNutritionService? nutritionService;
    MemberTrainingService? trainingService;
    MemberSessionsService? sessionsService;
    MembershipService? membershipService;
    MemberProgressService? progressService;
    final journalService = context.read<MemberJournalService?>();

    try {
      coachingService = context.read<MemberCoachingService>();
    } catch (_) {
      try {
        coachingService = MemberCoachingApi(context.read<ApiClient>());
      } catch (_) {}
    }
    try {
      nutritionService = context.read<MemberNutritionService>();
    } catch (_) {}
    try {
      trainingService = context.read<MemberTrainingService>();
    } catch (_) {}
    try {
      sessionsService = context.read<MemberSessionsService>();
    } catch (_) {}
    try {
      membershipService = context.read<MembershipService>();
    } catch (_) {}
    try {
      progressService = context.read<MemberProgressService>();
    } catch (_) {}

    MemberCoachRelationship? relationship;
    Map<String, String> coachNames = const {};
    NutritionGuide? activeNutrition;
    TrainingPlan? activePlan;
    List<TrainingSession> sessions = const [];
    List<Membership> memberships = const [];
    List<MemberCoachRequest> coachRequests = const [];
    ProgressSummary? progressSummary;
    Object? firstError;

    final tasks = <Future<void>>[
      if (coachingService != null) ...[
        () async {
          try {
            relationship = await coachingService!.getCurrentRelationship();
          } catch (error) {
            firstError ??= error;
          }
        }(),
        () async {
          try {
            coachNames = await coachingService!.getCoachNames();
          } catch (_) {}
        }(),
        () async {
          try {
            coachRequests = await coachingService!.getRequests();
          } catch (_) {}
        }(),
      ],
      if (nutritionService != null)
        () async {
          try {
            final guide = await nutritionService!.getActive();
            if (guide != null && guide.status == 'ACTIVE') {
              activeNutrition = guide;
            }
          } catch (error) {
            firstError ??= error;
          }
        }(),
      if (trainingService != null)
        () async {
          try {
            activePlan = await trainingService!.getActive();
          } catch (error) {
            firstError ??= error;
          }
        }(),
      if (sessionsService != null)
        () async {
          try {
            final baseSessionsFuture = sessionsService!.getMine();
            final bookingsFuture = sessionsService is MemberSessionsApi
                ? CoachV2Api(sessionsService.client).list('/coach-bookings')
                : Future<List<Map<String, dynamic>>>.value(const []);
            final baseSessions = await baseSessionsFuture;
            final bookings = await bookingsFuture;
            if (sessionsService is MemberSessionsApi && mounted) {
              try {
                final notifCtrl = Provider.of<NotificationsController>(
                  context,
                  listen: false,
                );
                await notifCtrl.syncUpcomingBookings(bookings);
              } on ProviderNotFoundException {
                // Optional when dashboard is rendered in isolation.
              }
            }
            sessions = [
              ...baseSessions,
              for (final booking in bookings)
                TrainingSession(
                  id: booking['id'] as String,
                  title: 'Buổi tập với Coach',
                  scheduledStartAt: booking['startsAt'] as String,
                  scheduledEndAt: booking['endsAt'] as String,
                  status: booking['status'] == 'BOOKED'
                      ? 'SCHEDULED'
                      : booking['status'] as String,
                ),
            ];
          } catch (error) {
            firstError ??= error;
          }
        }(),
      if (membershipService != null)
        () async {
          try {
            memberships = await membershipService!.getCurrentMemberships();
          } catch (error) {
            firstError ??= error;
          }
        }(),
      if (journalService is MemberJournalApi)
        () async {
          try {
            progressSummary = ProgressSummary(
              workoutCount: await journalService.getCount(),
              mealCount: 0,
              progressPhotoCount: 0,
            );
          } catch (_) {}
        }()
      else if (progressService != null)
        () async {
          try {
            progressSummary = await progressService!.getSummary();
          } catch (_) {}
        }(),
    ];

    await Future.wait<void>(tasks);

    if (!mounted) return;
    setState(() {
      _activeRelationship = relationship;
      _coachNames = coachNames;
      _activeNutrition = activeNutrition;
      _activePlan = activePlan;
      _sessions = sessions;
      _memberships = memberships;
      _coachRequests = coachRequests;
      _progressSummary = progressSummary;
      _isLoading = false;
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
    final relName = _activeRelationship?.coachName?.trim();
    if (relName != null && relName.isNotEmpty) return relName;
    return 'Coach của bạn';
  }

  Membership? get _activeMembership => _memberships
      .cast<Membership?>()
      .firstWhere((item) => item?.status == 'ACTIVE', orElse: () => null);

  bool get _hasPendingCoachRequest =>
      _coachRequests.any((request) => request.status == 'PENDING');

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

  TrainingDay? get _todayPlanDay {
    if (widget.previewMode) {
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return TrainingDay(
        dayNumber: 1,
        scheduledDate: date,
        title: 'Upper Body & Core',
        notes: 'Kế hoạch do Coach Lê Hoàng Nam chuẩn bị.',
        exercises: const [
          TrainingExercise(
            exerciseId: 'preview-1',
            exerciseName: 'Incline Press',
            displayOrder: 1,
            sets: 4,
            reps: '10',
          ),
          TrainingExercise(
            exerciseId: 'preview-2',
            exerciseName: 'Lat Pulldown',
            displayOrder: 2,
            sets: 3,
            reps: '12',
          ),
        ],
        meals: const [
          PlannedMeal(
            displayOrder: 1,
            mealType: 'BREAKFAST',
            title: 'Yến mạch, trứng và chuối',
            scheduledTime: '07:30',
          ),
          PlannedMeal(
            displayOrder: 2,
            mealType: 'LUNCH',
            title: 'Ức gà, cơm gạo lứt và rau',
            scheduledTime: '12:00',
          ),
        ],
      );
    }
    return _activePlan?.dayForDate(DateTime.now());
  }

  Future<void> _pushAndReload(String route) async {
    await MetaGymNavigation.pushPathOnce(context, route);
    if (mounted) {
      await _loadFrame3Data();
    }
  }

  /// Bề mặt kính khói ấm đồng nhất với các thẻ Khám phá (`0xC42B2622` + viền `0xA3A79D92`).
  Widget _buildLiquidGlassCard({
    required Widget child,
    BorderRadius? borderRadius,
    Clip clipBehavior = Clip.antiAlias,
    bool featured = false,
  }) {
    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      featured: false,
      borderRadius:
          borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard),
      clipBehavior: clipBehavior,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final user = context.watch<SessionController>().user;
    final userName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Minh Quân';

    return Material(
      color: palette.canvas,
      child: Stack(
        children: [
          // 1. Nền Canvas & Ảnh Gym đồng bộ (có RepaintBoundary + Light/Dark fallback)
          Positioned.fill(
            child: MetaGymBackground(
              useSolidFallback: widget.useSolidGlassFallback,
            ),
          ),

          // Main scrollable viewport
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: palette.surfaceSolid,
              onRefresh: _loadFrame3Data,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  0,
                  MetaGymTheme.pageGutter,
                  widget.bottomPadding + 32,
                ),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      // 1. Header
                      _buildHeader(context, userName),
                      const SizedBox(height: 8),

                      // 2. Quick Action Dock (4 nút squircle đối xứng)
                      _buildQuickActionDock(),
                      const SizedBox(height: 10),

                      if (_loadError != null) ...[
                        _buildLoadErrorBanner(),
                        const SizedBox(height: 10),
                      ],

                      // 3. Gói tập; chỉ hiện Coach khi đang được phụ trách.
                      _buildMembershipAndCoachCard(context),
                      const SizedBox(height: 10),

                      if (_isLoading ||
                          widget.previewMode ||
                          (_activeMembership != null && _hasCoach)) ...[
                        _buildTodaySection(context),
                        const SizedBox(height: 10),
                        _buildBentoSection(context),
                        if (!_isLoading && _activeMembership != null) ...[
                          const SizedBox(height: 10),
                          _buildMascotActivityBanner(context),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (!_isLoading &&
                          !widget.previewMode &&
                          _activeMembership != null &&
                          !_hasCoach) ...[
                        _buildSelfWorkoutCard(),
                        const SizedBox(height: 10),
                        _buildMascotActivityBanner(context),
                        const SizedBox(height: 12),
                      ],

                      // 6. Khám phá Meta Gym (4 tính năng nổi bật)
                      MemberHomeExploreGrid(
                        onOpenAll: () => widget.onNavigateTab(1),
                        onOpenEquipment: () =>
                            _pushAndReload('/member/features/gym'),
                        onOpenVisits: () =>
                            _pushAndReload('/member/features/visits'),
                        onOpenMeasurements: () =>
                            _pushAndReload('/member/features/measurements'),
                        onOpenCoach: () => _pushAndReload(
                          _hasCoach || _hasPendingCoachRequest
                              ? '/member/features/my-coach'
                              : '/member/features/coaching',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 7. Đặc quyền Hội viên — Bộ thẻ quạt 4 hạng (Fan Deck)
                      MemberHomeFanDeck(
                        onOpenMembership: () =>
                            _pushAndReload('/member/features/membership'),
                      ),
                      const SizedBox(height: 16),

                      // 8. Tin tức & Bài viết (thẻ kính khói ấm)
                      MemberHomeArticlesSection(
                        onOpenGymIntro: () => MetaGymNavigation.pushOnce(
                          context,
                          MetaGymPageRoute<void>(
                            builder: (_) => MemberExploreArticleDetailPage(
                              article: kMemberExploreArticles.first,
                            ),
                          ),
                        ),
                        onOpenBeginnerGuide: () => MetaGymNavigation.pushOnce(
                          context,
                          MetaGymPageRoute<void>(
                            builder: (_) => MemberExploreArticleDetailPage(
                              article: kMemberExploreArticles.last,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
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
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.warning.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          MetaGymSvgIcon(MetaGymIcons.stateWarning, size: 19, fallbackIcon: Icons.warning_amber_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadFrame3Data,
            tooltip: 'Thử lại',
            icon: MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 19, fallbackIcon: Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final shortName = userName.split(RegExp(r'\s+')).length >= 2
        ? userName.split(RegExp(r'\s+')).sublist(1).join(' ')
        : userName;
    final userId = context.read<SessionController>().user?.id ?? '2048';
    final numericSuffix = userId.replaceAll(RegExp(r'[^0-9]'), '');
    final memberCode =
        'MG-${numericSuffix.length >= 4 ? numericSuffix.substring(numericSuffix.length - 4) : '2048'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Mã QR Check-in vào phòng tập',
            child: Tooltip(
              message: 'Mã QR Check-in phòng tập',
              child: MetaGymTap(
                key: const Key('member-home-qr-btn'),
                onTap: () => showMemberQrCheckinModal(
                  context,
                  memberName: userName,
                  memberCode: memberCode,
                ),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isLight
                              ? const [Color(0xFFFFFFFF), Color(0xFFE5ECF5)]
                              : const [Color(0x33FF5E36), Color(0xD629241F)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isLight
                              ? palette.primaryText.withValues(alpha: 0.45)
                              : MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.60,
                                ),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: MetaGymSvgIcon(
                        MetaGymIcons.qrScanFrame,
                        size: 24,
                        color: isLight ? palette.primaryText : Colors.white,
                        fallbackIcon: Icons.qr_code_2_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'META GYM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chào, $shortName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (bellCtx) {
              NotificationsController? notificationsCtrl;
              try {
                notificationsCtrl = Provider.of<NotificationsController>(
                  bellCtx,
                );
              } on ProviderNotFoundException {
                notificationsCtrl = null;
              }
              final unreadCount = notificationsCtrl?.unreadCount ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  MetaGymCircleIconButton(
                    key: const Key('member-home-bell-btn'),
                    icon: Icons.notifications_none_rounded,
                    svgAsset: MetaGymIcons.settingNotificationsBell,
                    tooltip: 'Thông báo',
                    onTap: () => _showHomeNotificationsSheet(bellCtx),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('member-home-bell-badge'),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: MetaGymTheme.brandOrange,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isLight
                                  ? palette.surfaceSolid
                                  : MetaGymTheme.scaffoldBackground,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
            },
          ),
        ],
      ),
    );
  }

  void _showHomeNotificationsSheet(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    NotificationsController? controller;
    try {
      controller = Provider.of<NotificationsController>(context, listen: false);
    } on ProviderNotFoundException {
      controller = null;
    }
    SessionController? sessionCtrl;
    try {
      sessionCtrl = Provider.of<SessionController>(context, listen: false);
    } on ProviderNotFoundException {
      sessionCtrl = null;
    }
    if (controller != null && controller.items.isEmpty && !controller.isLoading) {
      controller.refresh(initial: true);
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: isLight
          ? palette.surfaceSolid
          : MetaGymTheme.overlayGlass,
      builder: (sheetCtx) {
        final previewItems = (controller?.items ?? const <AppNotification>[])
            .take(4)
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông báo mới',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((controller?.unreadCount ?? 0) > 0)
                      TextButton(
                        onPressed: () => controller?.markAllRead(),
                        child: Text(
                          'Đọc tất cả',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (previewItems.isEmpty)
                  MetaGymGlassCard(
                    solid: true,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Bạn chưa có thông báo mới. Các nhắc lịch tập, thực đơn và tin nhắn sẽ hiển thị tại đây.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < previewItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    MetaGymGlassCard(
                      solid: true,
                      padding: const EdgeInsets.all(12),
                      borderColor: previewItems[i].isUnread
                          ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                          : null,
                      onTap: () async {
                        final item = previewItems[i];
                        Navigator.of(sheetCtx).pop();
                        if (item.isUnread && item.id.isNotEmpty) {
                          controller?.markRead(item.id);
                        }
                        if (context.mounted) {
                          await openNotificationTarget(
                            context,
                            item,
                            role: sessionCtrl?.user?.role,
                          );
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (previewItems[i].isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              decoration: const BoxDecoration(
                                color: MetaGymTheme.brandOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  previewItems[i].title ?? 'Thông báo mới',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((previewItems[i].body ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    previewItems[i].body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: const Key('member-home-view-all-notifs-btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: MetaGymTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const CoachNotificationsPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Xem tất cả thông báo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 2. QUICK ACTIONS: FOUR EQUAL NAVIGATION TILES (3D ICONS)
  // ===========================================================================
  Widget _buildQuickActionDock() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'Lịch tập',
            icon: Icons.calendar_today_rounded,
            icon3dAsset: MetaGym3dIcons.actionSchedule,
            onTap: () => _pushAndReload('/member/features/sessions'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Giáo trình',
            icon: Icons.description_outlined,
            icon3dAsset: MetaGym3dIcons.actionCurriculum,
            onTap: () => _pushAndReload('/member/features/training'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Dinh dưỡng',
            icon: Icons.spa_outlined,
            icon3dAsset: MetaGym3dIcons.actionNutrition,
            onTap: () => _pushAndReload('/member/features/nutrition'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Coach',
            icon: Icons.groups_outlined,
            icon3dAsset: MetaGym3dIcons.actionCoach,
            onTap: () => _pushAndReload(
              _hasCoach || _hasPendingCoachRequest
                  ? '/member/features/my-coach'
                  : '/member/features/coaching',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required String icon3dAsset,
    required VoidCallback onTap,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return Semantics(
      button: true,
      label: label,
      child: MetaGymGlassCard(
        solid: widget.useSolidGlassFallback,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MetaGym3dIcon(icon3dAsset, size: 34, fallbackIcon: icon),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. THẺ "HÔM NAY [SẮP DIỄN RA]" (LIQUID GLASS TRONG SUỐT)
  // ===========================================================================
  Widget _buildTodaySection(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    if (_isLoading) {
      return _buildLiquidGlassCard(
        child: SizedBox(
          height: 110,
          child: Center(
            child: MetaGymTheme.isFlutterTestEnvironment
                ? const CircularProgressIndicator(
                    value: 0.5,
                    color: MetaGymTheme.brandOrange,
                  )
                : const CircularProgressIndicator(
                    color: MetaGymTheme.brandOrange,
                  ),
          ),
        ),
      );
    }

    final day = _todayPlanDay;
    final session =
        day != null &&
            _todaySession?.title.trim().toLowerCase() ==
                day.title.trim().toLowerCase()
        ? _todaySession
        : null;
    final status = day == null
        ? 'Chưa có lịch'
        : session?.statusLabel ?? 'Đã lên lịch';
    final statusColor = switch (session?.status) {
      'COMPLETED' => palette.success,
      'CANCELLED' || 'MEMBER_ABSENT' => palette.warning,
      _ => day == null ? palette.textSecondary : palette.success,
    };
    final action = day == null
        ? 'Xem lịch'
        : session?.status == 'COMPLETED'
        ? 'Kết quả'
        : session?.status == 'CANCELLED' || session?.status == 'MEMBER_ABSENT'
        ? 'Chi tiết'
        : 'Xem ngay';

    Future<void> openDay() async {
      if (day == null) {
        await _pushAndReload('/member/features/training');
        return;
      }
      await MetaGymNavigation.pushOnce(
        context,
        MetaGymPageRoute<void>(
          builder: (_) => MemberDayPlanPage(
            day: day,
            session: session,
            planTitle: widget.previewMode
                ? 'Giáo trình tăng cơ'
                : _activePlan?.title,
          ),
        ),
      );
      if (mounted) await _loadFrame3Data();
    }

    return _buildLiquidGlassCard(
      featured: true,
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          key: const Key('member-today-plan-card'),
          onTap: openDay,
          child: Semantics(
            button: true,
            label: action,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MetaGymSvgIcon(
                        MetaGymIcons.workoutPlanCalendar,
                        size: 18,
                        fallbackIcon: Icons.event_note_rounded,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Hôm nay',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 18, fallbackIcon: Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day?.title ??
                                  'Coach chưa xếp kế hoạch cho hôm nay',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              day == null
                                  ? 'Xem các ngày đã lên lịch'
                                  : '${day.exercises.length} bài tập · ${day.meals.length} bữa ăn${session == null ? '' : ' · ${_extractTimeHHmm(session.scheduledStartAt)}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
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
                          minWidth: 82,
                          minHeight: 38,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          action,
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
            ),
          ),
        ),
      ),
    );
  }

  String _extractTimeHHmm(String rawIso) {
    final time = DateTime.tryParse(rawIso)?.toLocal();
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMembershipGlassCard({required Widget child}) {
    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      featured: false,
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
      child: child,
    );
  }

  Widget _buildMembershipMetricPanel({
    required VoidCallback onTap,
    required Widget child,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return Material(
      color: palette.metricPanelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: palette.metricPanelBorder,
          width: 1,
        ),
      ),
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. THẺ "GÓI TẬP & COACH"
  // ===========================================================================
  Widget _buildMembershipAndCoachCard(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    if (_isLoading) {
      return _buildMembershipGlassCard(
        child: Container(
          height: 90,
          alignment: Alignment.center,
          child: MetaGymTheme.isFlutterTestEnvironment
              ? const CircularProgressIndicator(
                  value: 0.5,
                  color: MetaGymTheme.brandOrange,
                  strokeWidth: 2.0,
                )
              : const CircularProgressIndicator(
                  color: MetaGymTheme.brandOrange,
                  strokeWidth: 2.0,
                ),
        ),
      );
    }

    final membership = _activeMembership;
    final endDate = membership == null
        ? null
        : DateTime.tryParse(membership.endDate)?.toLocal();
    final now = DateTime.now();
    final daysRemaining = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays
              .clamp(0, 99999);
    final displayDays = widget.previewMode
        ? '112'
        : (daysRemaining?.toString() ?? '—');
    final displayCoachName = _hasCoach
        ? _displayCoachName
        : (widget.previewMode ? 'Lê Hoàng Nam' : 'Chưa có Coach');
    final workoutLabel = widget.previewMode
        ? '24 ngày đã tập'
        : _progressSummary == null
        ? 'Chưa có nhật ký tập'
        : '${_progressSummary!.workoutCount} buổi đã tập';
    if (!widget.previewMode && (membership == null || !_hasCoach)) {
      return _buildMembershipOnlyCard(
        hasMembership: membership != null,
        daysRemaining: displayDays,
        workoutLabel: workoutLabel,
      );
    }
    final upcomingSessions = _sessions
        .where(
          (session) =>
              session.status == 'SCHEDULED' &&
              DateTime.parse(session.scheduledStartAt).isAfter(DateTime.now()),
        )
        .length;
    final coachSessionLabel = widget.previewMode
        ? '6 buổi'
        : _hasCoach
        ? '$upcomingSessions buổi đã lên lịch'
        : 'Chưa chọn Coach';
    final coachParts = displayCoachName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final coachInitialStr = coachParts.length >= 2
        ? '${coachParts.first[0]}${coachParts.last[0]}'.toUpperCase()
        : (displayCoachName.isNotEmpty
              ? displayCoachName
                    .substring(0, displayCoachName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'LN');

    return _buildMembershipGlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _pushAndReload('/member/features/membership'),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gói tập & Coach',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusFull,
                      ),
                    ),
                    child: Text(
                      'Hiệu lực',
                      style: TextStyle(
                        color: palette.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildMembershipMetricPanel(
                      onTap: () =>
                          _pushAndReload('/member/features/membership'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Gói tập',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$displayDays ngày',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            endDate == null
                                ? workoutLabel
                                : 'Hết hạn ${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textWarmMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMembershipMetricPanel(
                      onTap: () => _pushAndReload(
                        _hasCoach || _hasPendingCoachRequest
                            ? '/member/features/my-coach'
                            : '/member/features/coaching',
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
                                  coachInitialStr,
                                  style: const TextStyle(
                                    color: MetaGymTheme.coachAvatarForeground,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Coach cá nhân',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      displayCoachName,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _hasCoach ? 'Xem gói Coach ›' : coachSessionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.reflection,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildMembershipOnlyCard({
    required bool hasMembership,
    required String daysRemaining,
    required String workoutLabel,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return _buildMembershipGlassCard(
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          onTap: () => _pushAndReload('/member/features/membership'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 18, fallbackIcon: Icons.fitness_center_rounded),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Gói tập',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    MetaGymSvgIcon(MetaGymIcons.commonChevronRight, fallbackIcon: Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasMembership)
                  Row(
                    children: [
                      Text(
                        daysRemaining,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'ngày còn lại',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          workoutLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textWarmMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Chưa có gói tập · Chạm để khám phá gói',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelfWorkoutCard() {
    final palette = MetaGymTheme.paletteOf(context);
    return _buildLiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MetaGymSvgIcon(MetaGymIcons.equipDumbbell, size: 18, fallbackIcon: Icons.fitness_center_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nhật ký tập luyện',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final description = Text(
                  'Lưu lại hành trình và kết quả tập luyện',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                );
                final action = FilledButton.icon(
                  onPressed: () => _pushAndReload('/member/features/workouts'),
                  icon: const MetaGymSvgIcon(MetaGymIcons.workoutPlanCalendar, size: 17, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.calendar_month_rounded),
                  label: const Text('Mở nhật ký'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                );
                if (constraints.maxWidth < 440) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [description, const SizedBox(height: 8), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. CẶP BENTO 2 CỘT (DINH DƯỠNG & TIẾN ĐỘ TẬP LUYỆN - LIQUID GLASS)
  // ===========================================================================
  Widget _buildBentoSection(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final progTrackColor = isLight
        ? const Color(0xFFDCE4EE)
        : const Color(0x26FFFFFF);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bento Trái: Dinh dưỡng
          Expanded(
            child: _buildLiquidGlassCard(
              child: MetaGymTap(
                onTap: () => _pushAndReload('/member/features/nutrition'),
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 116),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const MetaGymSvgIcon(
                              MetaGymIcons.actionNutrition,
                              size: 17,
                              fallbackIcon: Icons.restaurant_rounded,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Dinh dưỡng',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _activeNutrition?.title ?? 'Thực đơn tăng cơ',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '1.8–2.0g đạm / kg',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đạm: 140 / 160g',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '85%',
                                style: TextStyle(
                                  color: palette.success,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 0.85,
                            minHeight: 3,
                            backgroundColor: progTrackColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bento Phải: Tiến độ tuần
          Expanded(
            child: _buildLiquidGlassCard(
              child: MetaGymTap(
                onTap: () => _pushAndReload('/member/features/workouts'),
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 116),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const MetaGymSvgIcon(
                              MetaGymIcons.statsChartLine,
                              size: 17,
                              fallbackIcon: Icons.show_chart_rounded,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Tiến độ',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: palette.success.withValues(alpha: 0.30),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                '3/7',
                                style: TextStyle(
                                  color: palette.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDayBubble('T2', isCompleted: true),
                            _buildDayBubble('T3', isCompleted: true),
                            _buildDayBubble(
                              'T4',
                              isCompleted: true,
                              isActive: true,
                            ),
                            _buildDayBubble('T5', isCompleted: false),
                            _buildDayBubble('T6', isCompleted: false),
                            _buildDayBubble('T7', isCompleted: false),
                            _buildDayBubble('CN', isCompleted: false),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              'Chuỗi: 5 ngày',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(width: 3),
                            const MetaGymSvgIcon(
                              MetaGymIcons.streakFlame,
                              size: 13,
                              fallbackIcon: Icons.local_fire_department_rounded,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Tốt',
                                style: TextStyle(
                                  color: palette.success,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: 3 / 7,
                            minHeight: 3,
                            backgroundColor: progTrackColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.success,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMascotActivityBanner(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final workoutCount = _progressSummary?.workoutCount ?? 0;
    final headline = workoutCount > 0
        ? 'Đã ghi $workoutCount buổi tập'
        : 'Nhịp tập cùng Meta Kong';
    return MetaGymGlassCard(
      key: const Key('member-home-mascot-banner'),
      solid: widget.useSolidGlassFallback,
      borderColor: MetaGymTheme.brandOrange.withValues(alpha: 0.34),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      onTap: () => _pushAndReload('/member/features/workouts'),
      child: Row(
        children: [
          Image.asset(
            'assets/images/mascot/meta_kong_streak.webp',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const MetaGymSvgIcon(
                MetaGymIcons.streakFlame,
                size: 24,
                fallbackIcon: Icons.local_fire_department_rounded,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        'Nhật ký ›',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Lưu mức tạ & lịch sử buổi tập thực tế của bạn.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBubble(
    String label, {
    required bool isCompleted,
    bool isActive = false,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? MetaGymTheme.brandOrange
                : (isLight ? const Color(0xFFE8EEF5) : const Color(0x1AFFFFFF)),
            border: Border.all(
              color: isActive
                  ? (isLight ? palette.textPrimary : Colors.white)
                  : (isCompleted
                        ? MetaGymTheme.brandOrange
                        : (isLight
                              ? const Color(0xFFB8C4D2)
                              : const Color(0x33FFFFFF))),
              width: isActive ? 1.4 : 0.8,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x66FF5A36),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? palette.primaryText : palette.textSecondary,
            fontSize: 9.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
