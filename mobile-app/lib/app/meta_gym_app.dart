import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/core/network/offline_sync_manager.dart';
import 'package:meta_gym_app/core/storage/offline_mutation_queue.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/theme_mode_controller.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_responsive_scale.dart';
import 'package:meta_gym_app/core/widgets/offline_cache_banner.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_api.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/data/membership_api.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/presentation/incoming_call_listener.dart';
import 'package:meta_gym_app/features/notifications/data/notifications_api.dart';
import 'package:meta_gym_app/features/notifications/presentation/in_app_notification_listener.dart';
import 'package:meta_gym_app/features/notifications/presentation/notifications_controller.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/profile/data/profile_api.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:provider/provider.dart';

class MetaGymApp extends StatefulWidget {
  const MetaGymApp({
    super.key,
    this.sessionController,
    this.apiClient,
    this.authService,
    this.profileService,
    this.catalogService,
    this.membershipService,
    this.coachSelectionService,
    this.coachRequestsService,
    this.coachMembersService,
    this.memberCoachingService,
    this.memberTrainingService,
    this.coachTrainingService,
    this.memberNutritionService,
    this.coachNutritionService,
    this.memberSessionsService,
    this.coachSessionsService,
    this.memberProgressService,
    this.memberWorkoutService,
    this.memberJournalService,
    this.memberMeasurementService,
    this.memberPhotoService,
    this.messagingService,
    this.callsService,
    this.aiService,
    this.notificationsController,
    this.themeModeController,
  });

  final SessionController? sessionController;
  final ApiClient? apiClient;
  final AuthService? authService;
  final ProfileService? profileService;
  final CatalogService? catalogService;
  final MembershipService? membershipService;
  final CoachSelectionService? coachSelectionService;
  final CoachRequestsService? coachRequestsService;
  final CoachMembersService? coachMembersService;
  final MemberCoachingService? memberCoachingService;
  final MemberTrainingService? memberTrainingService;
  final CoachTrainingService? coachTrainingService;
  final MemberNutritionService? memberNutritionService;
  final CoachNutritionService? coachNutritionService;
  final MemberSessionsService? memberSessionsService;
  final CoachSessionsService? coachSessionsService;
  final MemberProgressService? memberProgressService;
  final MemberWorkoutService? memberWorkoutService;
  final MemberJournalService? memberJournalService;
  final MemberMeasurementService? memberMeasurementService;
  final MemberPhotoService? memberPhotoService;
  final MessagingService? messagingService;
  final CallsService? callsService;
  final AiService? aiService;
  final NotificationsController? notificationsController;
  final ThemeModeController? themeModeController;

  @override
  State<MetaGymApp> createState() => _MetaGymAppState();
}

class _MetaGymAppState extends State<MetaGymApp> {
  late final ThemeModeController _themeModeController;
  late final bool _ownsThemeModeController;
  late final SessionController _sessionController;
  late final ApiCacheStatusController _apiCacheStatus;
  late final OfflineSyncManager _offlineSyncManager;
  late final ApiClient _apiClient;
  String? _prewarmedUserId;
  late final AuthService _authService;
  late final AuthController _authController;
  late final ProfileService _profileService;
  late final ProfileController _profileController;
  late final PasswordResetController _passwordResetController;
  late final CatalogService _catalogService;
  late final MembershipService _membershipService;
  late final MembershipController _membershipController;
  late final CoachSelectionService _coachSelectionService;
  late final CoachRequestsService _coachRequestsService;
  late final CoachMembersService _coachMembersService;
  late final MemberCoachingService _memberCoachingService;
  late final MemberTrainingService _memberTrainingService;
  late final CoachTrainingService _coachTrainingService;
  late final MemberNutritionService _memberNutritionService;
  late final CoachNutritionService _coachNutritionService;
  late final MemberSessionsService _memberSessionsService;
  late final CoachSessionsService _coachSessionsService;
  late final MemberProgressService _memberProgressService;
  late final MemberWorkoutService _memberWorkoutService;
  late final MemberJournalService _memberJournalService;
  late final MemberMeasurementService _memberMeasurementService;
  late final MemberPhotoService _memberPhotoService;
  late final MessagingService _messagingService;
  late final CallsService _callsService;
  late final AiService _aiService;
  late final NotificationsController _notificationsController;
  late final bool _ownsNotificationsController;
  late final GoRouter _router;
  MetaGymRealtime? _realtime;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _ownsThemeModeController = widget.themeModeController == null;
    _themeModeController = widget.themeModeController ?? ThemeModeController();
    _themeModeController.restore();
    _apiCacheStatus = ApiCacheStatusController();
    if (widget.sessionController case final injected?) {
      _sessionController = injected;
      _apiClient =
          widget.apiClient ??
          ApiClient(
            config: ApiConfig.fromEnvironment(),
            accessTokenProvider: () => injected.accessToken,
            onSessionExpired: injected.expire,
            cacheStatus: _apiCacheStatus,
            isDeviceOffline: () => _apiCacheStatus.isDeviceOffline,
          );
    } else {
      late final SessionController session;
      _apiClient = ApiClient(
        config: ApiConfig.fromEnvironment(),
        accessTokenProvider: () => session.accessToken,
        onSessionExpired: () => session.expire(),
        cacheStatus: _apiCacheStatus,
        isDeviceOffline: () => _apiCacheStatus.isDeviceOffline,
      );
      final authApi = AuthApi(_apiClient);
      session = SessionController(
        const SecureTokenStorage(),
        authApi.loadCurrentUser,
        onClearCache: _apiClient.clearCache,
        onOfflineSessionRestored: _apiCacheStatus.recordCacheFallback,
      );
      _sessionController = session;
    }
    _authService = widget.authService ?? AuthApi(_apiClient);
    _authController = AuthController(_authService, _sessionController);
    _profileService = widget.profileService ?? ProfileApi(_apiClient);
    _profileController = ProfileController(_profileService, _sessionController);
    _passwordResetController = PasswordResetController(_profileService);
    _catalogService = widget.catalogService ?? CatalogApi(_apiClient);
    _membershipService = widget.membershipService ?? MembershipApi(_apiClient);
    _membershipController = MembershipController(
      _membershipService,
      session: _sessionController,
    );
    _coachSelectionService =
        widget.coachSelectionService ?? CoachSelectionApi(_apiClient);
    _coachRequestsService =
        widget.coachRequestsService ?? CoachRequestsApi(_apiClient);
    _coachMembersService =
        widget.coachMembersService ?? CoachMembersApi(_apiClient);
    _memberCoachingService =
        widget.memberCoachingService ?? MemberCoachingApi(_apiClient);
    _memberTrainingService =
        widget.memberTrainingService ?? MemberTrainingApi(_apiClient);
    _coachTrainingService =
        widget.coachTrainingService ?? CoachTrainingApi(_apiClient);
    _memberNutritionService =
        widget.memberNutritionService ?? MemberNutritionApi(_apiClient);
    _coachNutritionService =
        widget.coachNutritionService ?? CoachNutritionApi(_apiClient);
    _memberSessionsService =
        widget.memberSessionsService ?? MemberSessionsApi(_apiClient);
    _coachSessionsService =
        widget.coachSessionsService ?? CoachSessionsApi(_apiClient);
    _memberProgressService =
        widget.memberProgressService ?? MemberProgressApi(_apiClient);
    _memberWorkoutService =
        widget.memberWorkoutService ?? MemberWorkoutApi(_apiClient);
    _memberJournalService =
        widget.memberJournalService ?? MemberJournalApi(_apiClient);
    _memberMeasurementService =
        widget.memberMeasurementService ?? MemberMeasurementApi(_apiClient);
    _memberPhotoService =
        widget.memberPhotoService ?? MemberPhotoApi(_apiClient);
    _messagingService = widget.messagingService ?? MessagingApi(_apiClient);
    _callsService = widget.callsService ?? CallsApi(_apiClient);
    _aiService = widget.aiService ?? AiApi(_apiClient);
    if (widget.sessionController == null) {
      _realtime = MetaGymRealtime(_apiClient, _sessionController);
    }
    _ownsNotificationsController = widget.notificationsController == null;
    _notificationsController =
        widget.notificationsController ??
        NotificationsController(
          api: NotificationsApi(_apiClient),
          session: _sessionController,
          realtime: _realtime,
        );
    _router = createAppRouter(
      sessionController: _sessionController,
      navigatorKey: _navigatorKey,
    );
    _offlineSyncManager = OfflineSyncManager(
      apiClient: _apiClient,
      mutationQueue: _apiClient.mutationQueue ?? MemoryOfflineMutationQueue(),
      statusController: _apiCacheStatus,
      sessionController: _sessionController,
      onRefreshControllers: _refreshCoreControllers,
    );
    unawaited(_offlineSyncManager.start());
    _sessionController.addListener(_handleSessionChanged);
    _handleSessionChanged();
    _sessionController.restore();
  }

  void _handleSessionChanged() {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    final user = _sessionController.user;
    if (_sessionController.status != SessionStatus.authenticated ||
        user == null) {
      _prewarmedUserId = null;
      return;
    }
    if (_prewarmedUserId == user.id) return;
    _prewarmedUserId = user.id;
    unawaited(_prewarmOfflineCatalog());
  }

  Future<void> _prewarmOfflineCatalog() async {
    if (_sessionController.status != SessionStatus.authenticated ||
        _apiCacheStatus.isDeviceOffline) {
      return;
    }
    await Future.wait<void>([
      _catalogService.getGymProfile().then((_) {}).catchError((_) {}),
      _catalogService.getEquipment().then((_) {}).catchError((_) {}),
      _catalogService.getExercises().then((_) {}).catchError((_) {}),
    ]);
  }

  Future<void> _refreshCoreControllers() async {
    if (_sessionController.status != SessionStatus.authenticated) return;
    await Future.wait<void>([
      _profileController.load().then((_) {}).catchError((_) {}),
      _membershipController.load().catchError((_) {}),
      _notificationsController.refresh(initial: false).catchError((_) {}),
      if (!MetaGymTheme.isFlutterTestEnvironment) _prewarmOfflineCatalog(),
    ]);
  }

  @override
  void dispose() {
    _sessionController.removeListener(_handleSessionChanged);
    _offlineSyncManager.dispose();
    if (_ownsNotificationsController) {
      _notificationsController.dispose();
    }
    _realtime?.dispose();
    _router.dispose();
    _authController.dispose();
    _profileController.dispose();
    _passwordResetController.dispose();
    _membershipController.dispose();
    _apiCacheStatus.dispose();
    if (_ownsThemeModeController) {
      _themeModeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<ApiCacheStatusController>.value(
          value: _apiCacheStatus,
        ),
        Provider<OfflineSyncManager>.value(value: _offlineSyncManager),
        Provider<MetaGymRealtime?>.value(value: _realtime),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AuthController>.value(value: _authController),
        Provider<ProfileService>.value(value: _profileService),
        ChangeNotifierProvider<ProfileController>.value(
          value: _profileController,
        ),
        ChangeNotifierProvider<PasswordResetController>.value(
          value: _passwordResetController,
        ),
        Provider<CatalogService>.value(value: _catalogService),
        Provider<MembershipService>.value(value: _membershipService),
        Provider<CoachSelectionService>.value(value: _coachSelectionService),
        Provider<CoachRequestsService>.value(value: _coachRequestsService),
        Provider<CoachMembersService>.value(value: _coachMembersService),
        Provider<MemberCoachingService>.value(value: _memberCoachingService),
        Provider<MemberTrainingService>.value(value: _memberTrainingService),
        Provider<CoachTrainingService>.value(value: _coachTrainingService),
        Provider<MemberNutritionService>.value(value: _memberNutritionService),
        Provider<CoachNutritionService>.value(value: _coachNutritionService),
        Provider<MemberSessionsService>.value(value: _memberSessionsService),
        Provider<CoachSessionsService>.value(value: _coachSessionsService),
        Provider<MemberProgressService>.value(value: _memberProgressService),
        Provider<MemberWorkoutService>.value(value: _memberWorkoutService),
        Provider<MemberJournalService>.value(value: _memberJournalService),
        Provider<MemberMeasurementService>.value(
          value: _memberMeasurementService,
        ),
        Provider<MemberPhotoService>.value(value: _memberPhotoService),
        Provider<MessagingService>.value(value: _messagingService),
        Provider<CallsService>.value(value: _callsService),
        Provider<AiService>.value(value: _aiService),
        ChangeNotifierProvider<MembershipController>.value(
          value: _membershipController,
        ),
        ChangeNotifierProvider<SessionController>.value(
          value: _sessionController,
        ),
        ChangeNotifierProvider<ThemeModeController>.value(
          value: _themeModeController,
        ),
        ChangeNotifierProvider<NotificationsController>.value(
          value: _notificationsController,
        ),
      ],
      child: ListenableBuilder(
        listenable: _themeModeController,
        builder: (context, _) => MaterialApp.router(
          title: 'Meta Gym',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeModeController.themeMode,
          routerConfig: _router,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final api = _callsService;
            final wrappedCalls = api is CallsApi
                ? IncomingCallListener(
                    navigatorKey: _navigatorKey,
                    session: _sessionController,
                    api: api,
                    realtime: _realtime,
                    child: child,
                  )
                : child;
            return MetaGymResponsiveScale(
              child: OfflineCacheBannerOverlay(
                controller: _apiCacheStatus,
                child: InAppNotificationListener(
                  navigatorKey: _navigatorKey,
                  controller: _notificationsController,
                  session: _sessionController,
                  router: _router,
                  child: wrappedCalls,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
