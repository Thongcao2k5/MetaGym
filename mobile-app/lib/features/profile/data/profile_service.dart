import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

abstract interface class ProfileService {
  Future<AuthUser> getProfile();

  Future<AuthUser> updateProfile(Map<String, Object?> fields);

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<String> requestPasswordReset(String email);

  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  });

  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  });
}
