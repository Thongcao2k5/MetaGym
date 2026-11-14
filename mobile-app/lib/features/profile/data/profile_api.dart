import 'package:flutter/services.dart' show Uint8List;
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';

class ProfileApi implements ProfileService {
  const ProfileApi(this._client);

  final ApiClient _client;

  @override
  Future<AuthUser> getProfile() async => (await _client.get<AuthUser>(
    '/users/me',
    decode: AuthUser.fromJson,
  )).data;

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async =>
      (await _client.patch<AuthUser>(
        '/users/me',
        body: fields,
        decode: AuthUser.fromJson,
      )).data;

  @override
  Future<AuthUser> uploadAvatar(Uint8List bytes) async =>
      (await _client.post<AuthUser>(
        '/users/me/avatar',
        body: bytes,
        headers: {'content-type': 'image/jpeg'},
        decode: AuthUser.fromJson,
      )).data;

  @override
  Future<AuthUser> deleteAvatar() async => (await _client.delete<AuthUser>(
    '/users/me/avatar',
    decode: AuthUser.fromJson,
  )).data;

  @override
  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async {
    try {
      final bytes = await _client.getBytes(avatarUrl);
      if (bytes != null && bytes.isNotEmpty) {
        return Uint8List.fromList(bytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => (await _client.patch<bool>(
    '/users/me/password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    decode: _decodeChanged,
  )).data;

  @override
  Future<String> requestPasswordReset(String email) async =>
      (await _client.post<String>(
        '/password-reset-requests',
        body: {'email': email.trim()},
        decode: (value) => (value as Map)['requestId'] as String,
      )).data;

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async => (await _client.post<bool>(
    '/password-reset-verifications',
    body: {'requestId': requestId, 'code': code},
    decode: (value) => (value as Map)['valid'] as bool,
  )).data;

  @override
  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  }) async => (await _client.post<bool>(
    '/password-resets',
    body: {'requestId': requestId, 'code': code, 'newPassword': newPassword},
    decode: _decodeChanged,
  )).data;
}

bool _decodeChanged(Object? value) => (value as Map)['changed'] as bool;
