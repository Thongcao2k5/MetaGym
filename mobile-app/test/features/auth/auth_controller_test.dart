import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

void main() {
  const member = AuthUser(
    id: 'member-1',
    email: 'member@metagym.test',
    fullName: 'Member Demo',
    role: UserRole.member,
    status: 'ACTIVE',
  );

  test('login validates input before calling the API', () async {
    final service = _FakeAuthService();
    final controller = AuthController(service, _session(member));

    final submitted = await controller.login(email: 'sai', password: '');

    expect(submitted, isFalse);
    expect(controller.fieldErrors, containsPair('email', isNotEmpty));
    expect(controller.fieldErrors, containsPair('password', isNotEmpty));
    expect(service.loginCalls, 0);
  });

  test('successful Coach login stores the session role', () async {
    const coach = AuthUser(
      id: 'coach-1',
      email: 'coach@metagym.test',
      fullName: 'Coach Demo',
      role: UserRole.coach,
      status: 'ACTIVE',
    );
    final service = _FakeAuthService(
      loginResult: const AuthSession(accessToken: 'coach-token', user: coach),
    );
    final session = _session(member);
    final controller = AuthController(service, session);

    expect(
      await controller.login(
        email: 'coach@metagym.test',
        password: 'StrongPass1',
      ),
      isTrue,
    );
    expect(session.user?.role, UserRole.coach);
  });

  test(
    'register validates a strong password and creates only a Member',
    () async {
      final service = _FakeAuthService(
        loginResult: const AuthSession(
          accessToken: 'member-token',
          user: member,
        ),
      );
      final session = _session(member);
      final controller = AuthController(service, session);

      expect(
        await controller.register(
          fullName: 'Member Demo',
          email: 'member@metagym.test',
          password: 'StrongPass1',
        ),
        isTrue,
      );
      expect(service.registeredRoleField, isNull);
      expect(session.user?.role, UserRole.member);
    },
  );

  test('a pending submission ignores repeated taps', () async {
    final completer = Completer<AuthSession>();
    final service = _FakeAuthService(pendingLogin: completer.future);
    final controller = AuthController(service, _session(member));

    final first = controller.login(
      email: 'member@metagym.test',
      password: 'StrongPass1',
    );
    final second = await controller.login(
      email: 'member@metagym.test',
      password: 'StrongPass1',
    );
    expect(second, isFalse);
    expect(service.loginCalls, 1);

    completer.complete(
      const AuthSession(accessToken: 'member-token', user: member),
    );
    expect(await first, isTrue);
  });
}

SessionController _session(AuthUser user) =>
    SessionController(_MemoryTokenStorage(), (_) async => user);

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.loginResult, this.pendingLogin});

  final AuthSession? loginResult;
  final Future<AuthSession>? pendingLogin;
  int loginCalls = 0;
  Object? registeredRoleField;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls += 1;
    return pendingLogin ?? Future.value(loginResult);
  }

  @override
  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  }) async {
    registeredRoleField = null;
    return loginResult!.user;
  }
}

class _MemoryTokenStorage implements TokenStorage {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
