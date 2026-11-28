import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

enum SessionStatus { restoring, unauthenticated, authenticated }

typedef CurrentUserLoader = Future<AuthUser> Function(String accessToken);

class SessionController extends ChangeNotifier {
  SessionController(
    this._tokenStorage,
    this._loadCurrentUser, {
    AuthPreferenceStorage? preferenceStorage,
    CachedUserStorage? cachedUserStorage,
    this.onClearCache,
    this.onOfflineSessionRestored,
    this.allowLocalDemoTokens = ApiClient.localDemoFromEnvironment,
  }) : _preferenceStorage =
           preferenceStorage ??
           (MetaGymTheme.isFlutterTestEnvironment
               ? null
               : const SecureAuthPreferenceStorage()),
       _cachedUserStorage =
           cachedUserStorage ??
           (MetaGymTheme.isFlutterTestEnvironment
               ? null
               : const SecureCachedUserStorage());

  final TokenStorage _tokenStorage;
  final CurrentUserLoader _loadCurrentUser;
  final AuthPreferenceStorage? _preferenceStorage;
  final CachedUserStorage? _cachedUserStorage;
  final Future<void> Function()? onClearCache;
  final void Function(DateTime savedAt)? onOfflineSessionRestored;
  final bool allowLocalDemoTokens;

  SessionStatus _status = SessionStatus.restoring;
  AuthUser? _user;
  String? _accessToken;
  bool _rememberMe = true;
  String? _rememberedEmail;
  Future<void>? _expiryOperation;
  Completer<void>? _splashGate;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get rememberMe => _rememberMe;
  String? get rememberedEmail => _rememberedEmail;

  /// Được gọi bởi `AppLoadingPage` ngay khi toàn bộ animation Splash đã chạy xong 100%.
  void completeSplashGate() {
    final gate = _splashGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  Future<void> restore() async {
    if (_status != SessionStatus.restoring) {
      _status = SessionStatus.restoring;
      notifyListeners();
    }

    final Future<void> minimumSplash;
    if (MetaGymTheme.isFlutterTestEnvironment) {
      minimumSplash = Future<void>.value();
    } else {
      final gate = Completer<void>();
      _splashGate = gate;
      minimumSplash = gate.future.timeout(
        const Duration(milliseconds: 9500),
        onTimeout: () {},
      );
    }

    await Future.wait([_restoreInternal(), minimumSplash]);

    if (_user != null && _accessToken != null) {
      _status = SessionStatus.authenticated;
      notifyListeners();
    } else {
      _setUnauthenticated();
    }
  }

  Future<void> _restoreInternal() async {
    if (_preferenceStorage case final prefs?) {
      try {
        _rememberMe = await prefs.readRememberMe();
        _rememberedEmail = await prefs.readRememberedEmail();
      } catch (_) {
        _rememberMe = true;
      }
    }

    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      return;
    }
    if (!allowLocalDemoTokens && LocalDemoAccounts.isDemoToken(token)) {
      await _tokenStorage.delete();
      return;
    }

    _accessToken = token;
    try {
      final loaded = await _loadCurrentUser(token);
      _user = loaded;
      if (_rememberMe) {
        await _persistCachedUserSafely(loaded);
      }
    } on ApiException catch (error) {
      if (error.kind == ApiExceptionKind.sessionExpired ||
          error.kind == ApiExceptionKind.forbidden) {
        await _tokenStorage.delete();
        await _deleteCachedUserSafely();
        await _clearCacheSafely();
        _accessToken = null;
        _user = null;
      } else if (error.kind == ApiExceptionKind.network ||
          error.kind == ApiExceptionKind.server) {
        final snapshot = await _readCachedUserSafely();
        if (snapshot != null) {
          _user = snapshot.user;
          onOfflineSessionRestored?.call(snapshot.savedAt);
        } else {
          _accessToken = null;
          _user = null;
        }
      } else {
        _accessToken = null;
        _user = null;
      }
    }
  }

  Future<void> authenticate(
    AuthSession session, {
    bool rememberMe = true,
  }) async {
    _rememberMe = rememberMe;
    if (rememberMe) {
      await _tokenStorage.write(session.accessToken);
      _rememberedEmail = session.user.email;
      await _persistCachedUserSafely(session.user);
    } else {
      await _tokenStorage.delete();
      _rememberedEmail = null;
      await _deleteCachedUserSafely();
    }
    if (_preferenceStorage case final prefs?) {
      try {
        await prefs.writeRememberMe(rememberMe);
        await prefs.writeRememberedEmail(
          rememberMe ? session.user.email : null,
        );
      } catch (_) {}
    }
    _accessToken = session.accessToken;
    _user = session.user;
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  void updateUser(AuthUser user) {
    if (_status != SessionStatus.authenticated || user.id != _user?.id) return;
    _user = user;
    if (_rememberMe) {
      unawaited(_persistCachedUserSafely(user));
    }
    notifyListeners();
  }

  Future<void> signOut() => expire();

  Future<void> expire() {
    if (_expiryOperation != null) return _expiryOperation!;
    if (_status == SessionStatus.unauthenticated && _accessToken == null) {
      return Future.value();
    }

    final operation = _clearSession();
    _expiryOperation = operation;
    return operation.whenComplete(() => _expiryOperation = null);
  }

  Future<void> _clearSession() async {
    await _tokenStorage.delete();
    await _deleteCachedUserSafely();
    await _clearCacheSafely();
    _setUnauthenticated();
  }

  Future<CachedUserSnapshot?> _readCachedUserSafely() async {
    try {
      return await _cachedUserStorage?.read();
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistCachedUserSafely(AuthUser user) async {
    try {
      await _cachedUserStorage?.write(
        CachedUserSnapshot(user: user, savedAt: DateTime.now().toUtc()),
      );
    } catch (_) {
      // Non-fatal on environments without keystore.
    }
  }

  Future<void> _deleteCachedUserSafely() async {
    try {
      await _cachedUserStorage?.delete();
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _clearCacheSafely() async {
    try {
      await onClearCache?.call();
    } catch (_) {
      // Non-fatal.
    }
  }

  void _setUnauthenticated() {
    _accessToken = null;
    _user = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }
}
