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
import 'package:provider/provider.dart';

class MetaGymApp extends StatefulWidget {
  const MetaGymApp({
    super.key,
    this.sessionController,
    this.apiClient,
    this.authService,
  });

  final SessionController? sessionController;
  final ApiClient? apiClient;
  final AuthService? authService;

  @override
  State<MetaGymApp> createState() => _MetaGymAppState();
}

class _MetaGymAppState extends State<MetaGymApp> {
  late final SessionController _sessionController;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final AuthController _authController;
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
    _router = createAppRouter(sessionController: _sessionController);
    _sessionController.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AuthController>.value(value: _authController),
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
