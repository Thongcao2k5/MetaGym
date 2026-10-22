import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

enum SessionStatus { restoring, unauthenticated, authenticated }

typedef CurrentUserLoader = Future<AuthUser> Function(String accessToken);

class SessionController extends ChangeNotifier {
  SessionController(this._tokenStorage, this._loadCurrentUser);

  final TokenStorage _tokenStorage;
  final CurrentUserLoader _loadCurrentUser;

  SessionStatus _status = SessionStatus.restoring;
  AuthUser? _user;
  String? _accessToken;
  Future<void>? _expiryOperation;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String? get accessToken => _accessToken;

  Future<void> restore() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      _setUnauthenticated();
      return;
    }

    _accessToken = token;
    try {
      _user = await _loadCurrentUser(token);
      _status = SessionStatus.authenticated;
      notifyListeners();
    } on ApiException catch (error) {
      if (error.kind == ApiExceptionKind.sessionExpired ||
          error.kind == ApiExceptionKind.forbidden) {
        await expire();
        return;
      }
      _setUnauthenticated();
    }
  }

  Future<void> authenticate(AuthSession session) async {
    await _tokenStorage.write(session.accessToken);
    _accessToken = session.accessToken;
    _user = session.user;
    _status = SessionStatus.authenticated;
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
