import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

void main() {
  const member = AuthUser(
    id: 'member-1',
    email: 'member@metagym.test',
    fullName: 'Member Demo',
    role: UserRole.member,
    status: 'ACTIVE',
  );

  test('starts unauthenticated when secure storage has no token', () async {
    final storage = _MemoryTokenStorage();
    final controller = SessionController(storage, (_) async => member);

    await controller.restore();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.user, isNull);
  });

  test('restores the user role from a valid stored token', () async {
    final storage = _MemoryTokenStorage('secure-token');
    final controller = SessionController(storage, (token) async {
      expect(token, 'secure-token');
      return member;
    });

    await controller.restore();

    expect(controller.status, SessionStatus.authenticated);
    expect(controller.user?.role, UserRole.member);
    expect(controller.accessToken, 'secure-token');
  });

  test('an expired token clears the session only once', () async {
    final storage = _MemoryTokenStorage('expired-token');
    final controller = SessionController(
      storage,
      (_) async => throw const ApiException(
        kind: ApiExceptionKind.sessionExpired,
        message: 'expired',
      ),
    );

    await controller.restore();
    await Future.wait([controller.expire(), controller.expire()]);

    expect(controller.status, SessionStatus.unauthenticated);
    expect(storage.deleteCount, 1);
  });

  test(
    'sign in writes only to token storage and sign out deletes it',
    () async {
      final storage = _MemoryTokenStorage();
      final controller = SessionController(storage, (_) async => member);

      await controller.authenticate(
        const AuthSession(accessToken: 'new-token', user: member),
      );
      expect(storage.value, 'new-token');
      expect(controller.status, SessionStatus.authenticated);

      await controller.signOut();
      expect(storage.value, isNull);
      expect(controller.status, SessionStatus.unauthenticated);
    },
  );
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.value]);

  String? value;
  int deleteCount = 0;

  @override
  Future<void> delete() async {
    deleteCount += 1;
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
