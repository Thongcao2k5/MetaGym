import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'meta_gym_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _accessTokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _accessTokenKey);
}

abstract interface class AuthPreferenceStorage {
  Future<bool> readRememberMe();

  Future<void> writeRememberMe(bool rememberMe);

  Future<String?> readRememberedEmail();

  Future<void> writeRememberedEmail(String? email);
}

class SecureAuthPreferenceStorage implements AuthPreferenceStorage {
  const SecureAuthPreferenceStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _rememberMeKey = 'meta_gym_remember_me';
  static const _rememberedEmailKey = 'meta_gym_remembered_email';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> readRememberMe() async {
    final raw = await _storage.read(key: _rememberMeKey);
    if (raw == null) return true;
    return raw == 'true';
  }

  @override
  Future<void> writeRememberMe(bool rememberMe) => _storage.write(
    key: _rememberMeKey,
    value: rememberMe ? 'true' : 'false',
  );

  @override
  Future<String?> readRememberedEmail() =>
      _storage.read(key: _rememberedEmailKey);

  @override
  Future<void> writeRememberedEmail(String? email) {
    final normalized = email?.trim() ?? '';
    if (normalized.isEmpty) {
      return _storage.delete(key: _rememberedEmailKey);
    }
    return _storage.write(key: _rememberedEmailKey, value: normalized);
  }
}
