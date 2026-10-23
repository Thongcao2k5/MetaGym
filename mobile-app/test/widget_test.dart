import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';

void main() {
  testWidgets('shows the public page when no session is stored', (
    tester,
  ) async {
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) => throw StateError('must not load a user'),
    );

    await tester.pumpWidget(MetaGymApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.text('Không gian dành cho hội viên'), findsNothing);
  });

  testWidgets('restores a Member session to the Member home page', (
    tester,
  ) async {
    final controller = SessionController(
      _MemoryTokenStorage('valid-token'),
      (_) async => const AuthUser(
        id: 'member-1',
        email: 'member@metagym.test',
        fullName: 'Member Demo',
        role: UserRole.member,
        status: 'ACTIVE',
      ),
    );

    await tester.pumpWidget(MetaGymApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Không gian dành cho hội viên'), findsOneWidget);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsNothing);
    expect(find.text('Chọn Coach'), findsOneWidget);
    await tester.tap(find.text('Chọn Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn Coach', findRichText: true), findsWidgets);
    expect(find.textContaining('UI04'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Không gian dành cho hội viên'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/coach/features/requests');
    await tester.pumpAndSettle();
    expect(find.text('Không gian dành cho hội viên'), findsOneWidget);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Kiểm thử các luồng hội viên'),
      300,
    );
    await tester.tap(find.text('Kiểm thử các luồng hội viên'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm thử luồng hội viên'), findsOneWidget);
  });

  testWidgets('login form validates locally and routes a Coach by role', (
    tester,
  ) async {
    const coach = AuthUser(
      id: 'coach-1',
      email: 'coach@metagym.test',
      fullName: 'Coach Demo',
      role: UserRole.coach,
      status: 'ACTIVE',
    );
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) async => coach,
    );
    final service = _FakeAuthService(
      const AuthSession(accessToken: 'coach-token', user: coach),
    );
    await tester.pumpWidget(
      MetaGymApp(sessionController: controller, authService: service),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(service.loginCalls, 0);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'coach@metagym.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'StrongPass1',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(service.loginCalls, 1);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsOneWidget);
    expect(find.text('Yêu cầu chọn Coach'), findsOneWidget);
    await tester.tap(find.text('Yêu cầu chọn Coach'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UI06'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kiểm thử các luồng Coach'), 300);
    await tester.tap(find.text('Kiểm thử các luồng Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm thử luồng Coach'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(CoachHomePage)))
        .go('/member/features/coaching');
    await tester.pumpAndSettle();
    expect(find.byType(CoachHomePage), findsOneWidget);
    expect(find.byType(MemberHomePage), findsNothing);
  });

  testWidgets('password reset completes all three steps', (tester) async {
    const member = AuthUser(
      id: 'member-1',
      email: 'member@metagym.test',
      fullName: 'Member Demo',
      role: UserRole.member,
      status: 'ACTIVE',
    );
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) async => member,
    );
    await tester.pumpWidget(
      MetaGymApp(
        sessionController: controller,
        profileService: _FakeProfileService(member),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'member@metagym.test');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Xác minh mã'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'NewPass1');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mật khẩu đã được cập nhật. Hãy đăng nhập lại.'),
      findsOneWidget,
    );
  });
}

class _FakeAuthService implements AuthService {
  _FakeAuthService(this.session);

  final AuthSession session;
  int loginCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    return session;
  }

  @override
  Future<AuthUser> registerMember({
    required String email,
    required String fullName,
    required String password,
  }) async => session.user;
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this.user);

  final AuthUser user;

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
  }) async => true;

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async => user;

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async => true;
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
