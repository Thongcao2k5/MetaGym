import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';

enum PasswordResetStep { requestCode, verifyCode, setPassword, completed }

class PasswordResetController extends ChangeNotifier {
  PasswordResetController(this._service);

  final ProfileService _service;
  PasswordResetStep step = PasswordResetStep.requestCode;
  bool isBusy = false;
  String? errorMessage;
  String? _requestId;
  String? _code;

  Future<bool> requestCode(String email) => _run(() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const FormatException('Email không hợp lệ.');
    }
    _requestId = await _service.requestPasswordReset(email);
    step = PasswordResetStep.verifyCode;
  });

  Future<bool> verifyCode(String code) => _run(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Mã xác minh phải gồm 6 chữ số.');
    }
    final valid = await _service.verifyPasswordReset(
      requestId: _requestId!,
      code: code,
    );
    if (!valid) throw const FormatException('Mã xác minh không hợp lệ.');
    _code = code;
    step = PasswordResetStep.setPassword;
  });

  Future<bool> resetPassword(String newPassword) => _run(() async {
    if (!_isStrongPassword(newPassword)) {
      throw const FormatException('Mật khẩu mới chưa đủ mạnh.');
    }
    await _service.resetPassword(
      requestId: _requestId!,
      code: _code!,
      newPassword: newPassword,
    );
    step = PasswordResetStep.completed;
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

bool _isStrongPassword(String value) =>
    value.length >= 8 &&
    RegExp('[a-z]').hasMatch(value) &&
    RegExp('[A-Z]').hasMatch(value) &&
    RegExp('[0-9]').hasMatch(value);
