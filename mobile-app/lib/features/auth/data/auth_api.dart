import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<AuthUser> loadCurrentUser(String accessToken) async {
    final result = await _client.get<AuthUser>(
      '/users/me',
      headers: {'authorization': 'Bearer $accessToken'},
      decode: AuthUser.fromJson,
    );
    return result.data;
  }
}
