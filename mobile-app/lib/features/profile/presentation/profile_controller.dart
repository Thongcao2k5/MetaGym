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

  static const Set<String> _commonAllowedKeys = {'fullName', 'phone'};
  static const Set<String> _memberAllowedKeys = {
    'dateOfBirth',
    'gender',
    'heightCm',
    'fitnessGoal',
    'experienceLevel',
    'activityLevel',
    'healthNotes',
    'injuryNotes',
    'dietaryPreferences',
  };
  static const Set<String> _coachAllowedKeys = {
    'biography',
    'specialties',
    'qualifications',
    'experienceYears',
    'availabilityNote',
  };

  Future<bool> load() => _run(() async {
    _session.updateUser(await _service.getProfile());
  });

  Future<bool> uploadAvatar(Uint8List bytes) => _run(() async {
    final updated = await _service.uploadAvatar(bytes);
    _session.updateUser(updated);
  });

  Future<bool> deleteAvatar() => _run(() async {
    final updated = await _service.deleteAvatar();
    _session.updateUser(updated);
  });

  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async {
    return _service.fetchAvatarBytes(avatarUrl);
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? fitnessGoal,
    String? biography,
    String? dateOfBirth,
    String? gender,
    double? heightCm,
    String? experienceLevel,
    String? activityLevel,
    String? healthNotes,
    String? injuryNotes,
    String? dietaryPreferences,
    List<String>? specialties,
    String? qualifications,
    int? experienceYears,
    String? availabilityNote,
  }) => _run(() async {
    final user = _session.user;
    if (user == null) throw StateError('Cần đăng nhập.');
    final fields = <String, Object?>{
      'fullName': fullName.trim(),
      'phone': _nullableText(phone),
      if (user.role == UserRole.member) ...{
        'fitnessGoal': _nullableText(fitnessGoal),
        if (dateOfBirth != null) 'dateOfBirth': _nullableText(dateOfBirth),
        if (gender != null) 'gender': _nullableText(gender),
        'heightCm': ?heightCm,
        if (experienceLevel != null)
          'experienceLevel': _nullableText(experienceLevel),
        if (activityLevel != null)
          'activityLevel': _nullableText(activityLevel),
        if (healthNotes != null) 'healthNotes': _nullableText(healthNotes),
        if (injuryNotes != null) 'injuryNotes': _nullableText(injuryNotes),
        if (dietaryPreferences != null)
          'dietaryPreferences': _nullableText(dietaryPreferences),
      },
      if (user.role == UserRole.coach) ...{
        'biography': _nullableText(biography),
        if (specialties != null)
          'specialties': specialties
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        if (qualifications != null)
          'qualifications': _nullableText(qualifications),
        'experienceYears': ?experienceYears,
        if (availabilityNote != null)
          'availabilityNote': _nullableText(availabilityNote),
      },
    };
    _session.updateUser(await _service.updateProfile(fields));
  });

  /// Cập nhật từng nhóm trường theo đúng schema `PATCH /users/me` của từng vai trò.
  Future<bool> patchProfile(Map<String, Object?> rawFields) => _run(() async {
    final user = _session.user;
    if (user == null) throw StateError('Cần đăng nhập.');
    final allowed = <String>{
      ..._commonAllowedKeys,
      if (user.role == UserRole.member) ..._memberAllowedKeys,
      if (user.role == UserRole.coach) ..._coachAllowedKeys,
    };
    final filtered = <String, Object?>{};
    for (final entry in rawFields.entries) {
      if (!allowed.contains(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        filtered[entry.key] = entry.key == 'fullName'
            ? value.trim()
            : _nullableText(value);
      } else {
        filtered[entry.key] = value;
      }
    }
    if (filtered.isEmpty) return;
    _session.updateUser(await _service.updateProfile(filtered));
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
