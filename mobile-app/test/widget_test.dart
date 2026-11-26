import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/theme_controller.dart';
import 'package:meta_gym_app/features/auth/data/auth_service.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_hub_page.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/presentation/member_progress_page.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/presentation/member_photo_page.dart';

void main() {
  testWidgets('appearance selection changes the app and survives restart', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SessionController session() => SessionController(
      _MemoryTokenStorage('valid-token'),
      (_) async => const AuthUser(
        id: 'member-1',
        email: 'member@metagym.test',
        fullName: 'Member Demo',
        role: UserRole.member,
        status: 'ACTIVE',
      ),
    );
    Widget app(SessionController controller) => MetaGymApp(
      sessionController: controller,
      membershipService: _EmptyMembershipService(),
      coachSelectionService: _EmptyCoachSelectionService(),
      memberTrainingService: _EmptyMemberTrainingService(),
      memberNutritionService: _EmptyMemberNutritionService(),
      memberSessionsService: _EmptyMemberSessionsService(),
      memberProgressService: _EmptyMemberProgressService(),
      memberWorkoutService: _EmptyMemberWorkoutService(),
      memberJournalService: _EmptyMemberJournalService(),
      memberMeasurementService: _EmptyMemberMeasurementService(),
      memberPhotoService: _EmptyMemberPhotoService(),
    );
    await tester.pumpWidget(app(session()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MetaGymBottomNav),
        matching: find.text('Hồ sơ'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tài khoản & hỗ trợ'));
    await tester.tap(find.text('Tài khoản & hỗ trợ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cài đặt ứng dụng'));
    await tester.tap(find.text('Cài đặt ứng dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-settings-theme-light')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await tester.tap(find.byKey(const Key('app-settings-reduce-blur-toggle')));
    await tester.pumpAndSettle();
    expect(
      MetaGymSurfacePreferences.reduceBlurOf(
        tester.element(find.byType(MaterialApp)),
      ),
      isTrue,
    );
    await tester.tap(find.byTooltip('Quay lại').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ProfilePage))).brightness,
      Brightness.light,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(session()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(
      MetaGymSurfacePreferences.reduceBlurOf(
        tester.element(find.byType(MemberHomePage)),
      ),
      isTrue,
    );
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final width in [375.0, 768.0]) {
    testWidgets(
      'Member tabs preserve state and avoid duplicate routes at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
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
        await tester.pumpWidget(
          MetaGymApp(
            sessionController: controller,
            membershipService: _EmptyMembershipService(),
            coachSelectionService: _EmptyCoachSelectionService(),
            memberTrainingService: _EmptyMemberTrainingService(),
            memberNutritionService: _EmptyMemberNutritionService(),
            memberSessionsService: _EmptyMemberSessionsService(),
            memberProgressService: _EmptyMemberProgressService(),
            memberWorkoutService: _EmptyMemberWorkoutService(),
            memberJournalService: _EmptyMemberJournalService(),
            memberMeasurementService: _EmptyMemberMeasurementService(),
            memberPhotoService: _EmptyMemberPhotoService(),
          ),
        );
        await tester.pumpAndSettle();
        final origin = tester.state(find.byType(MemberHomePage));
        Future<void> tab(String label) async {
          await tester.tap(
            find.descendant(
              of: find.byType(MetaGymBottomNav),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
        }

        await tab('Tập luyện');
        final training = tester.state(find.byType(MemberTrainingHubPage));
        await tab('AI');
        await tab('Tin nhắn');
        await tab('Hồ sơ');
        await tab('Trang chủ');
        await tab('Trang chủ');
        expect(
          GoRouter.of(tester.element(find.byType(MemberHomePage))).canPop(),
          isFalse,
        );
        await tab('Tập luyện');
        expect(
          tester.state(find.byType(MemberTrainingHubPage)),
          same(training),
        );
        expect(tester.state(find.byType(MemberHomePage)), same(origin));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shows the public page when no session is stored', (
    tester,
  ) async {
    final controller = SessionController(
      _MemoryTokenStorage(),
      (_) => throw StateError('must not load a user'),
    );

    await tester.pumpWidget(MetaGymApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
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

    await tester.pumpWidget(
      MetaGymApp(
        sessionController: controller,
        membershipService: _EmptyMembershipService(),
        coachSelectionService: _EmptyCoachSelectionService(),
        memberTrainingService: _EmptyMemberTrainingService(),
        memberNutritionService: _EmptyMemberNutritionService(),
        memberSessionsService: _EmptyMemberSessionsService(),
        memberProgressService: _EmptyMemberProgressService(),
        memberWorkoutService: _EmptyMemberWorkoutService(),
        memberJournalService: _EmptyMemberJournalService(),
        memberMeasurementService: _EmptyMemberMeasurementService(),
        memberPhotoService: _EmptyMemberPhotoService(),
      ),
    );
    await tester.pumpAndSettle();

    // Bottom navigation renders the 5 tabs in exact order
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Tập luyện'), findsWidgets);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Tin nhắn'), findsWidgets);
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsNothing);
    expect(find.text('Gói tập & Coach'), findsNothing);
    expect(find.text('Chưa có gói tập · Chạm để khám phá gói'), findsOneWidget);
    expect(find.byKey(const Key('member-today-plan-card')), findsNothing);
    expect(find.text('Tiến độ'), findsNothing);

    // The demo member has an active Coach, so quick access opens their relationship.
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('Coach & Lịch hẹn'), findsOneWidget);
    expect(find.byType(MetaGymBottomNav), findsNothing);
    await tester.tap(find.byTooltip('Quay lại').first);

    await tester.pumpAndSettle();
    expect(find.byType(MemberHomePage), findsOneWidget);

    // Tapping bottom nav tab 1 opens the training hub.
    await tester.tap(
      find.descendant(
        of: find.byType(MetaGymBottomNav),
        matching: find.text('Tập luyện'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MemberTrainingHubPage), findsOneWidget);

    // Tapping bottom nav tab 2: AI -> AiConversationsPage
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.byType(AiConversationsPage), findsOneWidget);

    // Tapping bottom nav tab 3: Tin nhắn -> ConversationsPage
    await tester.tap(find.text('Tin nhắn'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationsPage), findsOneWidget);

    // Tapping bottom nav tab 4: Hồ sơ -> ProfilePage
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    // Tapping bottom nav tab 0: Trang chủ -> Return to MemberDashboardView
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberHomePage), findsOneWidget);

    // Direct routing to nutrition
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/nutrition');
    await tester.pumpAndSettle();
    expect(find.byType(MemberNutritionPage), findsOneWidget);
    expect(find.text('Bạn chưa có hướng dẫn dinh dưỡng.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberNutritionPage))).go('/member');
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/sessions');
    await tester.pumpAndSettle();
    expect(find.byType(CoachBookingPage), findsOneWidget);
    expect(find.text('Lịch Coach'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(CoachBookingPage))).go('/member');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/progress');
    await tester.pumpAndSettle();
    expect(find.byType(MemberProgressPage), findsOneWidget);
    expect(find.text('Chưa có số đo để vẽ biểu đồ.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberProgressPage))).go('/member');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/workouts');
    await tester.pumpAndSettle();
    expect(find.byType(MemberJournalPage), findsOneWidget);
    expect(find.text('Nhật ký tập luyện'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberJournalPage))).go('/member');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/measurements');
    await tester.pumpAndSettle();
    expect(find.byType(MemberMeasurementPage), findsOneWidget);
    expect(find.text('Bạn chưa có số đo nào.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberMeasurementPage)))
        .go('/member');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/photos');
    await tester.pumpAndSettle();
    expect(find.byType(MemberPhotoPage), findsOneWidget);
    expect(find.text('Bạn chưa có ảnh tiến trình.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberPhotoPage))).go('/member');
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/coach/features/requests');
    await tester.pumpAndSettle();
    expect(find.byType(MemberHomePage), findsOneWidget);
    expect(find.text('Không gian dành cho huấn luyện viên'), findsNothing);

    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go(AppRoutes.memberWorkbench);
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
      MetaGymApp(
        sessionController: controller,
        authService: service,
        coachRequestsService: _EmptyCoachRequestsService(),
        coachMembersService: _EmptyCoachMembersService(),
        coachTrainingService: _EmptyCoachTrainingService(),
        coachNutritionService: _EmptyCoachNutritionService(),
        coachSessionsService: _EmptyCoachSessionsService(),
      ),
    );
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
    expect(find.text('Yêu cầu chọn Coach'), findsNothing);
    GoRouter.of(tester.element(find.byType(CoachHomePage)))
        .go('/coach/features/requests');
    await tester.pumpAndSettle();
    expect(find.byType(CoachHomePage), findsOneWidget);
    await tester.tap(find.text('Học viên').first);
    await tester.pumpAndSettle();
    expect(find.byType(CoachMembersPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dinh dưỡng'), 250);
    await tester.tap(find.text('Dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachNutritionPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Giáo trình'), -250);
    await tester.tap(find.text('Giáo trình'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachTrainingPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại').first);
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(CoachHomePage)))
        .go('/coach/features/sessions');
    await tester.pumpAndSettle();
    expect(find.byType(CoachSessionsPage), findsOneWidget);
    expect(find.text('Chưa có buổi tập nào.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(CoachSessionsPage))).go('/coach');
    await tester.pumpAndSettle();
    expect(find.text('Kiểm thử các luồng Coach'), findsNothing);
    GoRouter.of(tester.element(find.byType(CoachHomePage)))
        .push<void>(AppRoutes.coachWorkbench);
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
  Future<AuthUser> uploadAvatar(Uint8List bytes) async => user;

  @override
  Future<AuthUser> deleteAvatar() async => user;

  @override
  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async => null;

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

class _EmptyCoachSelectionService implements CoachSelectionService {
  @override
  Future<List<CoachProfile>> getCoaches() async => const [];

  @override
  Future<CoachProfile> getCoach(String id) =>
      throw UnimplementedError('No coach in this fixture');

  @override
  Future<CoachRequest> sendRequest(String coachId, String? message) =>
      throw UnimplementedError('No coach in this fixture');
}

class _EmptyCoachRequestsService implements CoachRequestsService {
  @override
  Future<List<CoachIncomingRequest>> getRequests() async => const [];

  @override
  Future<CoachProfile> getCoach(String id) async => const CoachProfile(
    id: 'coach-1',
    fullName: 'Coach Demo',
    memberLimit: 1,
    usedSlots: 0,
    availableSlots: 1,
  );

  @override
  Future<CoachIncomingRequest> getRequest(String requestId) =>
      throw UnimplementedError('No request in this fixture');

  @override
  Future<void> decide(String id, String decision, {String? reason}) =>
      throw UnimplementedError('No request in this fixture');
}

class _EmptyCoachMembersService implements CoachMembersService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];

  @override
  Future<CoachMemberDetail> getMember(String memberId) =>
      throw UnimplementedError('No member in this fixture');

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      const [];

  @override
  Future<void> requestTermination(String relationshipId, String reason) =>
      throw UnimplementedError('No relationship in this fixture');

  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) => throw UnimplementedError('No termination request in this fixture');
}

class _EmptyMemberTrainingService implements MemberTrainingService {
  @override
  Future<TrainingPlan?> getActive() async => null;

  @override
  Future<List<TrainingPlan>> getHistory() async => const [];

  @override
  Future<TrainingPlan> getPlan(String id) =>
      throw UnimplementedError('No plan in this fixture');
}

class _EmptyCoachTrainingService implements CoachTrainingService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];

  @override
  Future<List<CatalogItem>> getExercises() async => const [];

  @override
  Future<List<TrainingPlan>> getPlans(String memberId) async => const [];

  @override
  Future<TrainingPlan> getPlan(String id) =>
      throw UnimplementedError('No plan in this fixture');

  @override
  Future<TrainingPlan> create(String memberId, Map<String, Object?> payload) =>
      throw UnimplementedError('No member in this fixture');

  @override
  Future<TrainingPlan> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError('No plan in this fixture');

  @override
  Future<TrainingPlan> publish(String id) =>
      throw UnimplementedError('No plan in this fixture');
}

class _EmptyMemberNutritionService implements MemberNutritionService {
  @override
  Future<NutritionGuide?> getActive() async => null;

  @override
  Future<List<NutritionGuide>> getHistory() async => const [];
}

class _EmptyCoachNutritionService implements CoachNutritionService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];

  @override
  Future<List<NutritionGuide>> getGuides(String memberId) async => const [];

  @override
  Future<NutritionGuide> create(
    String memberId,
    String title,
    String content,
  ) => throw UnimplementedError('No member in this fixture');

  @override
  Future<NutritionGuide> update(
    String id,
    String title,
    String content, {
    bool publish = false,
  }) => throw UnimplementedError('No guide in this fixture');
}

class _EmptyMemberSessionsService implements MemberSessionsService {
  @override
  Future<List<TrainingSession>> getMine() async => const [];

  @override
  Future<TrainingSession> getDetail(String id) =>
      throw UnimplementedError('No session in this fixture');
}

class _EmptyCoachSessionsService implements CoachSessionsService {
  @override
  Future<List<TrainingSession>> getAll() async => const [];

  @override
  Future<TrainingSession> create(Map<String, Object?> payload) =>
      throw UnimplementedError('No member in this fixture');

  @override
  Future<TrainingSession> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError('No session in this fixture');
}

class _EmptyMemberProgressService implements MemberProgressService {
  @override
  Future<ProgressSummary> getSummary() async => const ProgressSummary(
    workoutCount: 0,
    mealCount: 0,
    progressPhotoCount: 0,
  );

  @override
  Future<List<WeightPoint>> getCharts({DateTime? from, DateTime? to}) async =>
      const [];

  @override
  Future<List<ProgressComment>> getComments() async => const [];
}

class _EmptyMemberWorkoutService implements MemberWorkoutService {
  @override
  Future<List<WorkoutLog>> getPage(int page) async => const [];
  @override
  Future<WorkoutLog> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<WorkoutLog> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError();
}

class _EmptyMemberJournalService implements MemberJournalService {
  @override
  Future<List<JournalEntry>> getPage(int page) async => const [];
  @override
  Future<List<JournalChartPoint>> getChart() async => const [];
  @override
  Future<JournalEntry> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<JournalEntry> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _EmptyMembershipService implements MembershipService {
  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      throw UnimplementedError();

  @override
  Future<List<MembershipPlan>> getPlans() async => const [];
  @override
  Future<List<Membership>> getCurrentMemberships() async => const [];
  @override
  Future<List<Membership>> getMembershipHistory() async => const [];
  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) =>
      throw UnimplementedError();
}

class _EmptyMemberMeasurementService implements MemberMeasurementService {
  @override
  Future<List<BodyMeasurement>> getPage(int page) async => const [];
  @override
  Future<BodyMeasurement> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<BodyMeasurement> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError();
}

class _EmptyMemberPhotoService implements MemberPhotoService {
  @override
  Future<List<ProgressPhoto>> getPage(int page) async => const [];
  @override
  Future<String> upload(SelectedProgressImage image) =>
      throw UnimplementedError();
  @override
  Future<ProgressPhoto> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<Uri> getAccessUrl(String mediaId) => throw UnimplementedError();
}
