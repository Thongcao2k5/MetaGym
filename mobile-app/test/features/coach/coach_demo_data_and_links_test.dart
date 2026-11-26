import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_secondary_pages.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';
import 'package:provider/provider.dart';

Widget _wrapWithProviders(
  Widget child, {
  required ApiClient client,
  Brightness brightness = Brightness.dark,
}) {
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: client),
      Provider<CoachMembersService>.value(value: CoachMembersApi(client)),
      Provider<CoachTrainingService>.value(value: CoachTrainingApi(client)),
      Provider<CoachRequestsService>.value(value: CoachRequestsApi(client)),
      Provider<CoachSessionsService>.value(value: CoachSessionsApi(client)),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? MetaGymTheme.dark
          : MetaGymTheme.light,
      home: child,
    ),
  );
}

void main() {
  tearDown(() {
    OfflineDemoControl.mode.value = DemoUiStateMode.normal;
  });

  Future<({ApiClient client, AuthSession session})> loginCoachClient() async {
    String? activeToken;
    final client = ApiClient(
      config: ApiConfig.fromValues(environment: 'local'),
      accessTokenProvider: () => activeToken,
    );
    final session = await AuthApi(client).login(
      email: LocalDemoAccounts.coachEmail,
      password: LocalDemoAccounts.demoPassword,
    );
    activeToken = session.accessToken;
    return (client: client, session: session);
  }

  Future<void> flushAsyncAndPump(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  Future<void> goBack(WidgetTester tester) async {
    final backBtn = find.byTooltip('Quay lại');
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.last);
    } else {
      final ctx = tester.element(find.byType(Navigator).last);
      Navigator.of(ctx).pop();
    }
    await flushAsyncAndPump(tester);
  }

  group('Coach local demo data contract', () {
    test('loads Coach members, detail, profile, training plans, meal plans, schedule & notifications without format errors', () async {
      final ctx = await loginCoachClient();
      final client = ctx.client;
      final coachId = ctx.session.user.id;

      final membersApi = CoachMembersApi(client);
      final members = await membersApi.getMembers();
      expect(members.length, 2);
      expect(members.first.memberFullName, 'Nguyễn Minh Quân');
      expect(members.first.relationshipId, isNotEmpty);

      final detail = await membersApi.getMember(members.first.memberId);
      expect(detail.email, isNotEmpty);
      expect(detail.fitnessGoal, isNotEmpty);

      final profile = await CoachRequestsApi(client).getCoach(coachId);
      expect(profile.memberLimit, 8);
      expect(profile.usedSlots, 2);
      expect(profile.availableSlots, 6);

      final trainingApi = CoachTrainingApi(client);
      final plans = await trainingApi.getPlans(members.first.memberId);
      expect(plans.length, greaterThanOrEqualTo(2));
      expect(plans.any((p) => p.status == 'ACTIVE'), isTrue);

      final v2 = CoachV2Api(client);
      final mealPlanQuan = await v2.get('/coach/meal-plans/${members.first.memberId}');
      expect((mealPlanQuan['items'] as List), isNotEmpty);

      final mealPlanNgoc = await v2.get('/coach/meal-plans/${members[1].memberId}');
      expect(mealPlanNgoc['items'], isA<List>());
      expect((mealPlanNgoc['items'] as List), isEmpty);

      await v2.put('/coach/meal-plans/${members[1].memberId}', {
        'title': 'Thực đơn 7 ngày cho Ngọc',
        'items': const [],
      });

      final packages = await v2.list('/coach-packages');
      expect(packages, isNotEmpty);

      final holds = await v2.list('/coach-payment-holds');
      expect(holds, isA<List<CoachRecord>>());

      final bookings = await v2.list('/coach-bookings');
      expect(bookings, isNotEmpty);

      final blocksBefore = await v2.list('/coach-bookings/blocks');
      final slotKey = '2026-12-01T14:00:00+07:00';
      await v2.put('/coach-bookings/blocks', {
        'startsAt': slotKey,
        'blocked': true,
        'reason': 'Kiểm thử khóa khung giờ',
      });
      final blocksAfter = await v2.list('/coach-bookings/blocks');
      expect(blocksAfter.length, blocksBefore.length + 1);

      final notifications = await v2.list('/coach-notifications');
      expect(notifications, isNotEmpty);
      expect(notifications.first['kind'], isNotNull);

      final unread = notifications.firstWhere(
        (n) => n['readAt'] == null,
        orElse: () => notifications.first,
      );
      await v2.patch('/coach-notifications/${unread['id']}/read', const {});

      final singlePlan = await trainingApi.getPlan(plans.first.id);
      expect(singlePlan.id, plans.first.id);

      await v2.put(
        '/coach/members/${members.first.memberId}/training-plans/current',
        {'planId': plans.first.id},
      );
    });
  });

  group('Coach UI links and data rendering', () {
    testWidgets('CoachTrainingPage loads live demo members and opens member plans & meal plans cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ctx = (await tester.runAsync(loginCoachClient))!;
      await tester.pumpWidget(
        _wrapWithProviders(
          CoachTrainingPage(service: CoachTrainingApi(ctx.client)),
          client: ctx.client,
        ),
      );
      await flushAsyncAndPump(tester);

      expect(find.text('Máy chủ trả về dữ liệu không đúng định dạng.'), findsNothing);
      expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
      expect(find.text('Trần Bảo Ngọc'), findsOneWidget);
      expect(find.text('Đủ cả hai (1)'), findsOneWidget);
      expect(find.text('Chờ thiết lập (1)'), findsOneWidget);

      final openTrainingBtn = find.byKey(
        const Key('hub-open-training-10000000-0000-4000-8000-000000000003'),
      );
      await tester.scrollUntilVisible(
        openTrainingBtn,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(openTrainingBtn);
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachMemberPlansPage), findsOneWidget);

      await tester.tap(find.byKey(const Key('member-plans-header-nutrition')));
      await flushAsyncAndPump(tester);
      expect(find.byType(MealPlansPage), findsOneWidget);
    });

    testWidgets('CoachMemberDetailPage links Giáo trình, Thực đơn and Lịch dạy', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ctx = (await tester.runAsync(loginCoachClient))!;
      final members = (await tester.runAsync(
        () => CoachMembersApi(ctx.client).getMembers(),
      ))!;

      await tester.pumpWidget(
        _wrapWithProviders(
          CoachMemberDetailPage(
            memberId: members.first.memberId,
            service: CoachMembersApi(ctx.client),
          ),
          client: ctx.client,
        ),
      );
      await flushAsyncAndPump(tester);

      expect(find.text('Giáo trình'), findsOneWidget);
      expect(find.text('Thực đơn'), findsOneWidget);
      expect(find.text('Lịch dạy'), findsOneWidget);
      expect(find.text('Nhắn tin'), findsOneWidget);

      await tester.tap(find.text('Giáo trình'));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachMemberPlansPage), findsOneWidget);

      await goBack(tester);

      await tester.tap(find.text('Lịch dạy'));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachSessionsPage), findsOneWidget);
    });

    testWidgets('CoachHomePage dashboard and work hub link to CoachSessionsPage & CoachBookingHistoryPage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ctx = (await tester.runAsync(loginCoachClient))!;
      await tester.pumpWidget(
        _wrapWithProviders(
          const CoachHomePage(previewMode: true, useSolidGlassFallback: true),
          client: ctx.client,
        ),
      );
      await flushAsyncAndPump(tester);

      await tester.scrollUntilVisible(
        find.text('Xem tất cả >'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xem tất cả >'));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachSessionsPage), findsOneWidget);

      await goBack(tester);

      await tester.scrollUntilVisible(
        find.text('Lịch sử buổi dạy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lịch sử buổi dạy'));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachBookingHistoryPage), findsOneWidget);

      await goBack(tester);

      await tester.tap(find.text('Lịch dạy').last);
      await flushAsyncAndPump(tester);

      expect(find.byType(CoachSessionsPage), findsOneWidget);
      expect(find.text('Quản lý ca 1:1 & điểm danh'), findsOneWidget);
    });

    testWidgets('CoachProfileDetailPage schedule shortcuts navigate to schedule pages', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ctx = (await tester.runAsync(loginCoachClient))!;
      await tester.pumpWidget(
        _wrapWithProviders(
          CoachProfileDetailPage(
            biography: 'HLV chuyên nghiệp',
            specialties: const ['Hypertrophy'],
            qualifications: 'NASM-CPT',
            experienceYears: 6,
            availabilityNote: 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
            onSave: (_, _, _, _, _) async => true,
          ),
          client: ctx.client,
        ),
      );
      await flushAsyncAndPump(tester);

      await tester.scrollUntilVisible(
        find.byKey(const Key('coach-pro-open-sessions')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('coach-pro-open-sessions')));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachSessionsPage), findsOneWidget);

      await goBack(tester);

      await tester.tap(find.byKey(const Key('coach-pro-open-workweek')));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachWorkWeekPage), findsOneWidget);

      await goBack(tester);

      await tester.tap(find.byKey(const Key('coach-pro-open-blocks')));
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachBlockedSlotsPage), findsOneWidget);
    });

    testWidgets('CoachNotificationsPage opens destination route when tapping read notification', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final ctx = (await tester.runAsync(loginCoachClient))!;
      await tester.pumpWidget(
        _wrapWithProviders(
          CoachNotificationsPage(coachMode: true, apiClient: ctx.client),
          client: ctx.client,
        ),
      );
      await flushAsyncAndPump(tester);

      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(find.text('Thông báo'), findsOneWidget);
      final targetCard = find.byKey(const Key('notification-card-cnoti-001'));
      expect(targetCard, findsOneWidget);

      // First tap marks unread notification as read.
      await tester.tap(targetCard);
      await flushAsyncAndPump(tester);

      // Second tap opens the linked CoachSessionsPage destination.
      await tester.tap(targetCard);
      await flushAsyncAndPump(tester);
      expect(find.byType(CoachSessionsPage), findsOneWidget);
    });
  });
}
