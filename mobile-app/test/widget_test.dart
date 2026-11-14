import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:meta_gym_app/features/coaching/presentation/coach_requests_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
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
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/member_sessions_page.dart';
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
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/presentation/member_meal_page.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/presentation/member_photo_page.dart';

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
        memberMealService: _EmptyMemberMealService(),
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

    // Quick access Coach opens CoachSelectionPage
    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn Coach', findRichText: true), findsWidgets);
    expect(find.byType(CoachSelectionPage), findsOneWidget);
    expect(find.text('Chưa có Coach để lựa chọn.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MemberHomePage), findsOneWidget);

    // Tapping bottom nav tab 1: Tập luyện -> MemberTrainingPage
    await tester.tap(
      find.descendant(
        of: find.byType(MetaGymBottomNav),
        matching: find.byIcon(Icons.fitness_center_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MemberTrainingPage), findsOneWidget);
    expect(find.text('Bạn chưa được giao giáo trình.'), findsOneWidget);

    // Tapping bottom nav tab 2: AI -> AiConversationsPage
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AiConversationsPage), findsOneWidget);

    // Tapping bottom nav tab 3: Tin nhắn -> ConversationsPage
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationsPage), findsOneWidget);

    // Tapping bottom nav tab 4: Hồ sơ -> ProfilePage
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    // Tapping bottom nav tab 0: Trang chủ -> Return to MemberDashboardView
    await tester.tap(find.byIcon(Icons.home_outlined));
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
    expect(find.byType(MemberSessionsPage), findsOneWidget);
    expect(find.text('Bạn chưa có buổi tập nào.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberSessionsPage))).go('/member');
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
    expect(find.text('Chưa có nhật ký tập.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberJournalPage))).go('/member');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MemberHomePage)))
        .go('/member/features/meals');
    await tester.pumpAndSettle();
    expect(find.byType(MemberMealPage), findsOneWidget);
    expect(find.text('Bạn chưa có nhật ký ăn.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(MemberMealPage))).go('/member');
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
    expect(find.text('Yêu cầu chọn Coach'), findsNothing);
    GoRouter.of(tester.element(find.byType(CoachHomePage))).push<void>('/coach/features/requests');
    await tester.pumpAndSettle();
    expect(find.byType(CoachRequestsPage), findsOneWidget);
    expect(find.text('Chưa có yêu cầu nào.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hội viên của tôi'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachMembersPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dinh dưỡng'), 250);
    await tester.tap(find.text('Dinh dưỡng'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachNutritionPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Giáo trình'), -250);
    await tester.tap(find.text('Giáo trình'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachTrainingPage), findsOneWidget);
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(CoachHomePage)))
        .go('/coach/features/sessions');
    await tester.pumpAndSettle();
    expect(find.byType(CoachSessionsPage), findsOneWidget);
    expect(find.text('Chưa có buổi tập nào.'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(CoachSessionsPage))).go('/coach');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kiểm thử các luồng Coach'), 300);
    final workbenchButton = find.widgetWithText(OutlinedButton, 'Kiểm thử các luồng Coach');
    await tester.ensureVisible(workbenchButton);
    await tester.pumpAndSettle();
    await tester.tap(workbenchButton);
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
  Future<List<MembershipPlan>> getPlans() async => const [];
  @override
  Future<List<Membership>> getCurrentMemberships() async => const [];
  @override
  Future<List<Membership>> getMembershipHistory() async => const [];
  @override
  Future<Payment> createPayment({required String planId,
      required String idempotencyKey}) => throw UnimplementedError();
  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) =>
      throw UnimplementedError();
}

class _EmptyMemberMealService implements MemberMealService {
  @override
  Future<List<MealLog>> getPage(int page) async => const [];
  @override
  Future<MealLog> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<MealLog> update(String id, Map<String, Object?> payload) =>
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
