import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._service, this._session);

  final ProfileService _service;
  final SessionController _session;

  bool isBusy = false;
  String? errorMessage;

  Future<bool> load() => _run(() async {
    _session.updateUser(await _service.getProfile());
  });

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? fitnessGoal,
    String? biography,
  }) => _run(() async {
    final user = _session.user;
    if (user == null) throw StateError('Cần đăng nhập.');
    final fields = <String, Object?>{
      'fullName': fullName.trim(),
      'phone': _nullableText(phone),
      if (user.role == UserRole.member)
        'fitnessGoal': _nullableText(fitnessGoal),
      if (user.role == UserRole.coach) 'biography': _nullableText(biography),
    };
    _session.updateUser(await _service.updateProfile(fields));
  });

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _run(() async {
    if (!_isStrongPassword(newPassword)) {
      throw const FormatException('Mật khẩu mới chưa đủ mạnh.');
    }
    await _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _session.expire();
  });

  Future<bool> _run(Future<void> Function() action) async {
    if (isBusy) return false;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } on FormatException catch (error) {
      errorMessage = error.message;
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _isStrongPassword(String value) =>
    value.length >= 8 &&
    RegExp('[a-z]').hasMatch(value) &&
    RegExp('[A-Z]').hasMatch(value) &&
    RegExp('[0-9]').hasMatch(value);
