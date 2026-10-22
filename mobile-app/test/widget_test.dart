import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

void main() {
  testWidgets('shows the public page when no session is stored', (
    tester,
  ) async {
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) => throw StateError('must not load a user'),
    );

    await tester.pumpWidget(MetaGymApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.text('Không gian dành cho hội viên'), findsNothing);
  });

  testWidgets('restores a Member session to the Member home page', (
    tester,
  ) async {
    final controller = SessionController(
      _MemoryTokenStorage('valid-token'),
      (_) async => const AuthUser(
        id: 'member-1',
        email: 'member@metagym.test',
        fullName: 'Member Demo',
        role: UserRole.member,
        status: 'ACTIVE',
      ),
    );

    await tester.pumpWidget(MetaGymApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Không gian dành cho hội viên'), findsOneWidget);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsNothing);
  });

  testWidgets('login form validates locally and routes a Coach by role', (
    tester,
  ) async {
    const coach = AuthUser(
      id: 'coach-1',
      email: 'coach@metagym.test',
      fullName: 'Coach Demo',
      role: UserRole.coach,
      status: 'ACTIVE',
    );
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) async => coach,
    );
    final service = _FakeAuthService(
      const AuthSession(accessToken: 'coach-token', user: coach),
    );
    await tester.pumpWidget(
      MetaGymApp(sessionController: controller, authService: service),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(service.loginCalls, 0);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'coach@metagym.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'StrongPass1',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(service.loginCalls, 1);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsOneWidget);
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService(this.session);

  final AuthSession session;
  int loginCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    return session;
  }

  @override
  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  }) async => session.user;
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.value]);

  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
