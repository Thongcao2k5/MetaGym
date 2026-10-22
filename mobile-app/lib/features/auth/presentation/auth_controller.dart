import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService, this._sessionController);

  final AuthService _authService;
  final SessionController _sessionController;

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;

  Future<bool> login({required String email, required String password}) async {
    if (_isSubmitting) return false;
    final errors = <String, String>{};
    if (!_isValidEmail(email)) errors['email'] = 'Email không hợp lệ.';
    if (password.isEmpty) errors['password'] = 'Vui lòng nhập mật khẩu.';
    if (!_begin(errors)) return false;

    try {
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _sessionController.authenticate(session);
      return true;
    } on ApiException catch (error) {
      _applyApiError(error);
      return false;
    } finally {
      _finish();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (_isSubmitting) return false;
    final errors = <String, String>{};
    if (fullName.trim().length < 2) {
      errors['fullName'] = 'Họ tên phải có ít nhất 2 ký tự.';
    }
    if (!_isValidEmail(email)) errors['email'] = 'Email không hợp lệ.';
    if (!_isStrongPassword(password)) {
      errors['password'] =
          'Mật khẩu cần ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số.';
    }
    if (!_begin(errors)) return false;

    try {
      await _authService.registerMember(
        email: email,
        fullName: fullName,
        password: password,
      );
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _sessionController.authenticate(session);
      return true;
    } on ApiException catch (error) {
      _applyApiError(error);
      return false;
    } finally {
      _finish();
    }
  }

  bool _begin(Map<String, String> errors) {
    _fieldErrors = errors;
    _errorMessage = null;
    if (errors.isNotEmpty) {
      notifyListeners();
      return false;
    }
    _isSubmitting = true;
    notifyListeners();
    return true;
  }

  void _applyApiError(ApiException error) {
    final rawFields = error.details['fields'];
    if (rawFields is Map) {
      _fieldErrors = {
        for (final entry in rawFields.entries)
          if (entry.key is String &&
              entry.value is List &&
              entry.value.isNotEmpty)
            entry.key as String: entry.value.first.toString(),
      };
    }
    _errorMessage = error.message;
  }

  void _finish() {
    _isSubmitting = false;
    notifyListeners();
  }
}

bool _isValidEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim().toLowerCase());

bool _isStrongPassword(String value) =>
    value.length >= 8 &&
    utf8.encode(value).length <= 72 &&
    RegExp('[a-z]').hasMatch(value) &&
    RegExp('[A-Z]').hasMatch(value) &&
    RegExp('[0-9]').hasMatch(value);
