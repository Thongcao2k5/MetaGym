import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
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
  }) : _preferenceStorage =
           preferenceStorage ??
           (MetaGymTheme.isFlutterTestEnvironment
               ? null
               : const SecureAuthPreferenceStorage());

  final TokenStorage _tokenStorage;
  final CurrentUserLoader _loadCurrentUser;
  final AuthPreferenceStorage? _preferenceStorage;

  SessionStatus _status = SessionStatus.restoring;
  AuthUser? _user;
  String? _accessToken;
  bool _rememberMe = true;
  String? _rememberedEmail;
  Future<void>? _expiryOperation;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get rememberMe => _rememberMe;
  String? get rememberedEmail => _rememberedEmail;

  Future<void> restore() async {
    final minimumSplash = MetaGymTheme.isFlutterTestEnvironment
        ? Future<void>.value()
        : Future<void>.delayed(const Duration(milliseconds: 2200));

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

    _accessToken = token;
    try {
      _user = await _loadCurrentUser(token);
    } on ApiException catch (error) {
      if (error.kind == ApiExceptionKind.sessionExpired ||
          error.kind == ApiExceptionKind.forbidden) {
        await _tokenStorage.delete();
      }
      _accessToken = null;
      _user = null;
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
    } else {
      await _tokenStorage.delete();
      _rememberedEmail = null;
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
    _setUnauthenticated();
  }

  void _setUnauthenticated() {
    _accessToken = null;
    _user = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }
}
