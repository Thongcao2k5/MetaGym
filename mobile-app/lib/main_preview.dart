import 'package:flutter/material.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.value]);
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionController = SessionController(
    _MemoryTokenStorage('preview-token'),
    (_) async => const AuthUser(
      id: 'member-demo',
      email: 'member@metagym.local',
      fullName: 'Minh Quân',
      role: UserRole.member,
      status: 'ACTIVE',
    ),
  );

  runApp(MetaGymApp(sessionController: sessionController));
}

