import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/login_page.dart';
import 'package:meta_gym_app/features/auth/presentation/register_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/forgot_password_page.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:meta_gym_app/features/public/presentation/app_loading_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AppLoadingPage renders lifting arm animation and brand title', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoadingPage()));
    expect(find.text('Đang khởi động không gian tập luyện...'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
    'LoginPage toggles password visibility and passes rememberMe choice',
    (tester) async {
      final tokenStorage = _MemoryTokenStorage();
      final prefStorage = _MemoryPrefStorage();
      final session = SessionController(
        tokenStorage,
        (_) async => throw UnimplementedError(),
        preferenceStorage: prefStorage,
      );
      final authService = _FakeAuthService();
      final authController = AuthController(authService, session);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authController,
          child: const MaterialApp(home: LoginPage()),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'member@metagym.local',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'Secret123!',
      );

      final passwordFieldBefore = tester.widget<TextField>(
        find.byKey(const Key('login-password')),
      );
      expect(passwordFieldBefore.obscureText, isTrue);

      await tester.tap(find.byKey(const Key('login-toggle-password')));
      await tester.pump();

      final passwordFieldAfter = tester.widget<TextField>(
        find.byKey(const Key('login-password')),
      );
      expect(passwordFieldAfter.obscureText, isFalse);

      // Tắt ghi nhớ đăng nhập trước khi bấm Đăng nhập
      await tester.tap(find.byKey(const Key('login-remember-me')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(session.status, SessionStatus.authenticated);
      expect(await tokenStorage.read(), isNull);
      expect(await prefStorage.readRememberMe(), isFalse);
    },
  );

  testWidgets('RegisterPage updates password strength meter dynamically', (
    tester,
  ) async {
    final session = SessionController(
      _MemoryTokenStorage(),
      (_) async => throw UnimplementedError(),
      preferenceStorage: _MemoryPrefStorage(),
    );
    final authController = AuthController(_FakeAuthService(), session);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authController,
        child: const MaterialApp(home: RegisterPage()),
      ),
    );

    expect(find.byKey(const Key('register-password-strength')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'StrongPass9',
    );
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
  });

  testWidgets(
    'compact phone viewport renders Login and Register cleanly without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = SessionController(
        _MemoryTokenStorage(),
        (_) async => throw UnimplementedError(),
        preferenceStorage: _MemoryPrefStorage(),
      );
      final authController = AuthController(_FakeAuthService(), session);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authController,
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('META GYM'), findsOneWidget);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authController,
          child: const MaterialApp(home: RegisterPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('META GYM'), findsOneWidget);
      expect(find.byKey(const Key('register-submit')), findsOneWidget);
    },
  );

  testWidgets(
    'AuthModeSegmentSwitch navigates between LoginPage and RegisterPage via GoRouter',
    (tester) async {
      final session = SessionController(
        _MemoryTokenStorage(),
        (_) async => throw UnimplementedError(),
        preferenceStorage: _MemoryPrefStorage(),
      );
      await session.restore();
      final authController = AuthController(_FakeAuthService(), session);
      final router = createAppRouter(
        sessionController: session,
        initialLocation: AppRoutes.login,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authController,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('auth-mode-register')));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('auth-mode-login')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('LoginPage biometric quick login authenticates cleanly', (
    tester,
  ) async {
    final session = SessionController(
      _MemoryTokenStorage(),
      (_) async => throw UnimplementedError(),
      preferenceStorage: _MemoryPrefStorage(),
    );
    final authController = AuthController(_FakeAuthService(), session);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authController,
        child: MaterialApp(theme: AppTheme.dark, home: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('login-face-id')));
    await tester.tap(find.byKey(const Key('login-face-id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biometric-confirm-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('biometric-confirm-btn')));
    await tester.pumpAndSettle();

    expect(session.status, SessionStatus.authenticated);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const <Size>[Size(375, 812), Size(360, 640)]) {
    testWidgets(
      '${viewport.width.toInt()}x${viewport.height.toInt()} viewport renders Splash, Login, Register, and ForgotPassword cleanly',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.dark, home: const AppLoadingPage()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.text('Đang khởi động không gian tập luyện...'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        final session = SessionController(
          _MemoryTokenStorage(),
          (_) async => throw UnimplementedError(),
          preferenceStorage: _MemoryPrefStorage(),
        );
        final authController = AuthController(_FakeAuthService(), session);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: authController,
            child: MaterialApp(theme: AppTheme.dark, home: const LoginPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('auth-mode-login')), findsOneWidget);
        expect(find.byKey(const Key('login-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: authController,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const RegisterPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('auth-mode-register')), findsOneWidget);
        expect(find.byKey(const Key('register-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);

        final resetController = PasswordResetController(_FakeProfileService());
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: resetController,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const ForgotPasswordPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forgot-password-input')), findsOneWidget);
        expect(find.text('Quên mật khẩu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}

class _MemoryPrefStorage implements AuthPreferenceStorage {
  bool _remember = true;
  String? _email;

  @override
  Future<bool> readRememberMe() async => _remember;

  @override
  Future<String?> readRememberedEmail() async => _email;

  @override
  Future<void> writeRememberMe(bool rememberMe) async => _remember = rememberMe;

  @override
  Future<void> writeRememberedEmail(String? email) async => _email = email;
}

class _FakeAuthService implements AuthService {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return AuthSession(
      accessToken: 'jwt-token-1',
      user: AuthUser(
        id: 'u-1',
        email: email,
        fullName: 'Member Demo',
        role: UserRole.member,
        status: 'ACTIVE',
      ),
    );
  }

  @override
  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  }) async {
    return AuthUser(
      id: 'u-1',
      email: email,
      fullName: fullName,
      role: UserRole.member,
      status: 'ACTIVE',
    );
  }
}

class _FakeProfileService implements ProfileService {
  static const _demoUser = AuthUser(
    id: 'u-1',
    email: 'member@metagym.local',
    fullName: 'Member Demo',
    role: UserRole.member,
    status: 'ACTIVE',
  );

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> deleteAvatar() async => _demoUser;

  @override
  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async => null;

  @override
  Future<AuthUser> getProfile() async => _demoUser;

  @override
  Future<String> requestPasswordReset(String email) async => 'req-1';

  @override
  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async =>
      _demoUser;

  @override
  Future<AuthUser> uploadAvatar(Uint8List bytes) async => _demoUser;

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async => true;
}
