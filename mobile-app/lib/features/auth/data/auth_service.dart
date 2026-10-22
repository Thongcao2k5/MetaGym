import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

abstract interface class AuthService {
  Future<AuthSession> login({required String email, required String password});

  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  });
}
