import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

class AuthApi implements AuthService {
  const AuthApi(this._client);

  final ApiClient _client;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final result = await _client.post<AuthSession>(
      '/auth/sessions',
      body: {'email': email.trim(), 'password': password},
      decode: AuthSession.fromJson,
    );
    return result.data;
  }

  @override
  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  }) async {
    final result = await _client.post<AuthUser>(
      '/auth/registrations',
      body: {
        'email': email.trim(),
        'fullName': fullName.trim(),
        'password': password,
      },
      decode: AuthUser.fromJson,
    );
    return result.data;
  }

  Future<AuthUser> loadCurrentUser(String accessToken) async {
    final result = await _client.get<AuthUser>(
      '/users/me',
      headers: {'authorization': 'Bearer $accessToken'},
      decode: AuthUser.fromJson,
    );
    return result.data;
  }
}
