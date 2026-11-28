import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
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

  test(
    'clears stale local-demo token during restore when offline demo is disabled',
    () async {
      var loaderCalled = false;
      final storage = _MemoryTokenStorage('local-demo-member-token');
      final controller = SessionController(storage, (_) async {
        loaderCalled = true;
        return member;
      });

      await controller.restore();

      expect(loaderCalled, isFalse);
      expect(storage.deleteCount, 1);
      expect(storage.value, isNull);
      expect(controller.accessToken, isNull);
      expect(controller.status, SessionStatus.unauthenticated);
    },
  );

  test(
    'restores cached user snapshot on network failure and updates banner callback',
    () async {
      final tokenStorage = _MemoryTokenStorage('jwt-valid-1');
      final cachedStorage = _MemoryCachedUserStorage(
        CachedUserSnapshot(
          user: member,
          savedAt: DateTime.utc(2026, 11, 28, 9, 30),
        ),
      );
      DateTime? restoredAt;
      final controller = SessionController(
        tokenStorage,
        (_) async => throw const ApiException(
          kind: ApiExceptionKind.network,
          message: 'offline',
        ),
        cachedUserStorage: cachedStorage,
        onOfflineSessionRestored: (at) => restoredAt = at,
      );

      await controller.restore();

      expect(controller.status, SessionStatus.authenticated);
      expect(controller.user?.email, member.email);
      expect(controller.accessToken, 'jwt-valid-1');
      expect(restoredAt, DateTime.utc(2026, 11, 28, 9, 30));
    },
  );

  test(
    'clears cached user and API cache on 401 session expiry and signOut',
    () async {
      final tokenStorage = _MemoryTokenStorage('expired-jwt');
      final cachedStorage = _MemoryCachedUserStorage(
        CachedUserSnapshot(
          user: member,
          savedAt: DateTime.utc(2026, 11, 28, 9, 30),
        ),
      );
      var clearCacheCount = 0;
      final expiredController = SessionController(
        tokenStorage,
        (_) async => throw const ApiException(
          kind: ApiExceptionKind.sessionExpired,
          message: 'expired',
        ),
        cachedUserStorage: cachedStorage,
        onClearCache: () async => clearCacheCount += 1,
      );

      await expiredController.restore();
      expect(expiredController.status, SessionStatus.unauthenticated);
      expect(cachedStorage.snapshot, isNull);
      expect(clearCacheCount, 1);

      final signOutController = SessionController(
        _MemoryTokenStorage(),
        (_) async => member,
        cachedUserStorage: cachedStorage,
        onClearCache: () async => clearCacheCount += 1,
      );
      await signOutController.authenticate(
        const AuthSession(accessToken: 'jwt-2', user: member),
      );
      expect(cachedStorage.snapshot?.user.email, member.email);

      await signOutController.signOut();
      expect(cachedStorage.snapshot, isNull);
      expect(clearCacheCount, 2);
    },
  );
}

class _MemoryCachedUserStorage implements CachedUserStorage {
  _MemoryCachedUserStorage([this.snapshot]);

  CachedUserSnapshot? snapshot;

  @override
  Future<void> delete() async => snapshot = null;

  @override
  Future<CachedUserSnapshot?> read() async => snapshot;

  @override
  Future<void> write(CachedUserSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
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
