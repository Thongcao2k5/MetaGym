import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:provider/provider.dart';

void main() {
  const member = AuthUser(
    id: 'member-1',
    email: 'member@metagym.test',
    fullName: 'Member Demo',
    role: UserRole.member,
    status: 'ACTIVE',
  );

  test('Member profile update sends only fields allowed for Member', () async {
    final service = _FakeProfileService(member);
    final controller = ProfileController(service, await _session(member));

    await controller.updateProfile(
      fullName: 'Tên mới',
      phone: '0900000000',
      fitnessGoal: 'Tăng sức bền',
      biography: 'Không được gửi',
    );

    expect(service.lastUpdate, {
      'fullName': 'Tên mới',
      'phone': '0900000000',
      'fitnessGoal': 'Tăng sức bền',
    });
    expect(service.lastUpdate, isNot(contains('biography')));
  });

  testWidgets('opening a profile does not notify its provider during build',
      (tester) async {
    final session = await _session(member);
    final controller = ProfileController(_FakeProfileService(member), session);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<ProfileController>.value(value: controller),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('member@metagym.test'), findsOneWidget);
  });

  test('changing password clears the invalidated session', () async {
    final storage = _MemoryTokenStorage('old-token');
    final session = SessionController(storage, (_) async => member);
    await session.authenticate(
      const AuthSession(accessToken: 'old-token', user: member),
    );
    final service = _FakeProfileService(member);
    final controller = ProfileController(service, session);

    expect(
      await controller.changePassword(
        currentPassword: 'OldPass1',
        newPassword: 'NewPass1',
      ),
      isTrue,
    );
    expect(session.status, SessionStatus.unauthenticated);
    expect(storage.value, isNull);
  });

  test(
    'password reset follows request, verification, and reset steps',
    () async {
      final service = _FakeProfileService(member);
      final controller = PasswordResetController(service);

      expect(await controller.requestCode('member@metagym.test'), isTrue);
      expect(controller.step, PasswordResetStep.verifyCode);
      expect(await controller.verifyCode('123456'), isTrue);
      expect(controller.step, PasswordResetStep.setPassword);
      expect(await controller.resetPassword('NewPass1'), isTrue);
      expect(controller.step, PasswordResetStep.completed);
      expect(service.resetRequestId, 'request-1');
      expect(service.resetCode, '123456');
    },
  );
}

Future<SessionController> _session(AuthUser user) async {
  final session = SessionController(_MemoryTokenStorage(), (_) async => user);
  await session.authenticate(AuthSession(accessToken: 'token', user: user));
  return session;
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this.user);

  final AuthUser user;
  Map<String, Object?>? lastUpdate;
  String? resetRequestId;
  String? resetCode;

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> getProfile() async => user;

  @override
  Future<String> requestPasswordReset(String email) async => 'request-1';

  @override
  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  }) async {
    resetRequestId = requestId;
    resetCode = code;
    return true;
  }

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async {
    lastUpdate = fields;
    return user;
  }

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async {
    resetRequestId = requestId;
    resetCode = code;
    return true;
  }
}

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
