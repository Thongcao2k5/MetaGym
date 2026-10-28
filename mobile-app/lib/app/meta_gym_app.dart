import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_api.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/data/membership_api.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/profile/data/profile_api.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/data/coach_progress_service.dart';
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
    this.memberMealService,
    this.memberMeasurementService,
    this.memberPhotoService,
    this.coachProgressService,
    this.messagingService,
    this.callsService,
    this.aiService,
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
  final MemberMealService? memberMealService;
  final MemberMeasurementService? memberMeasurementService;
  final MemberPhotoService? memberPhotoService;
  final CoachProgressService? coachProgressService;
  final MessagingService? messagingService;
  final CallsService? callsService;
  final AiService? aiService;

  @override
  State<MetaGymApp> createState() => _MetaGymAppState();
}

class _MetaGymAppState extends State<MetaGymApp> {
  late final SessionController _sessionController;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final AuthController _authController;
  late final ProfileService _profileService;
  late final ProfileController _profileController;
  late final PasswordResetController _passwordResetController;
  late final CatalogService _catalogService;
  late final CatalogController _catalogController;
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
  late final MemberMealService _memberMealService;
  late final MemberMeasurementService _memberMeasurementService;
  late final MemberPhotoService _memberPhotoService;
  late final CoachProgressService _coachProgressService;
  late final MessagingService _messagingService;
  late final CallsService _callsService;
  late final AiService _aiService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    if (widget.sessionController case final injected?) {
      _sessionController = injected;
      _apiClient =
          widget.apiClient ??
          ApiClient(
            config: ApiConfig.fromEnvironment(),
            accessTokenProvider: () => injected.accessToken,
            onSessionExpired: injected.expire,
          );
    } else {
      late final SessionController session;
      _apiClient = ApiClient(
        config: ApiConfig.fromEnvironment(),
        accessTokenProvider: () => session.accessToken,
        onSessionExpired: () => session.expire(),
      );
      final authApi = AuthApi(_apiClient);
      session = SessionController(
        const SecureTokenStorage(),
        authApi.loadCurrentUser,
      );
      _sessionController = session;
    }
    _authService = widget.authService ?? AuthApi(_apiClient);
    _authController = AuthController(_authService, _sessionController);
    _profileService = widget.profileService ?? ProfileApi(_apiClient);
    _profileController = ProfileController(_profileService, _sessionController);
    _passwordResetController = PasswordResetController(_profileService);
    _catalogService = widget.catalogService ?? CatalogApi(_apiClient);
    _catalogController = CatalogController(_catalogService);
    _membershipService = widget.membershipService ?? MembershipApi(_apiClient);
    _membershipController = MembershipController(_membershipService);
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
    _memberMealService = widget.memberMealService ?? MemberMealApi(_apiClient);
    _memberMeasurementService =
        widget.memberMeasurementService ?? MemberMeasurementApi(_apiClient);
    _memberPhotoService =
        widget.memberPhotoService ?? MemberPhotoApi(_apiClient);
    _coachProgressService =
        widget.coachProgressService ?? CoachProgressApi(_apiClient);
    _messagingService = widget.messagingService ?? MessagingApi(_apiClient);
    _callsService = widget.callsService ?? CallsApi(_apiClient);
    _aiService = widget.aiService ?? AiApi(_apiClient);
    _router = createAppRouter(sessionController: _sessionController);
    _sessionController.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    _authController.dispose();
    _profileController.dispose();
    _passwordResetController.dispose();
    _catalogController.dispose();
    _membershipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
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
        ChangeNotifierProvider<CatalogController>.value(
          value: _catalogController,
        ),
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
        Provider<MemberMealService>.value(value: _memberMealService),
        Provider<MemberMeasurementService>.value(
          value: _memberMeasurementService,
        ),
        Provider<MemberPhotoService>.value(value: _memberPhotoService),
        Provider<CoachProgressService>.value(value: _coachProgressService),
        Provider<MessagingService>.value(value: _messagingService),
        Provider<CallsService>.value(value: _callsService),
        Provider<AiService>.value(value: _aiService),
        ChangeNotifierProvider<MembershipController>.value(
          value: _membershipController,
        ),
        ChangeNotifierProvider<SessionController>.value(
          value: _sessionController,
        ),
      ],
      child: MaterialApp.router(
        title: 'Meta Gym',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
