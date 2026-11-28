import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_day_plan_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_hub_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/nutrition_tracking_page.dart';
import 'package:provider/provider.dart';

void main() {
  for (final useButton in [false, true]) {
    testWidgets(
      'nutrition tool opens diary via ${useButton ? 'button' : 'row'}',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: _NutritionAdapter(),
        );
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: client,
            child: MaterialApp(
              theme: MetaGymTheme.dark,
              home: MemberTrainingHubPage(
                membershipController: MembershipController(
                  _FakeMembershipService(),
                ),
                coachingService: _FakeCoachingService(),
                selfTrainingApi: _FakeSelfTrainingApi(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('nutrition-tool-open')),
          200,
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('nutrition-tool-open'));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        expect(find.text('Dinh dưỡng hôm nay'), findsOneWidget);
        final nutritionTop = tester
            .getTopLeft(find.text('Dinh dưỡng hôm nay'))
            .dy;
        expect(
          nutritionTop,
          lessThan(tester.getTopLeft(find.text('Lịch tập tuần của tôi')).dy),
        );
        expect(
          nutritionTop,
          lessThan(tester.getTopLeft(find.text('Công cụ & Thư viện')).dy),
        );
        await tester.tap(useButton ? button : find.text('Dinh dưỡng hôm nay'));
        await tester.pumpAndSettle();
        expect(find.byType(NutritionTrackingPage), findsOneWidget);
        expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);
        expect(
          find.text('Không có món ăn nào được ghi trong ngày này.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  String todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String futureIso(int days) {
    final date = DateTime.now().add(Duration(days: days));
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String pastIso(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget wrapPage({
    required MembershipController membershipController,
    required MemberCoachingService coachingService,
    MemberSelfTrainingApi? selfTrainingApi,
  }) {
    return MaterialApp(
      theme: MetaGymTheme.dark,
      home: MemberTrainingHubPage(
        bottomPadding: 96,
        membershipController: membershipController,
        coachingService: coachingService,
        selfTrainingApi: selfTrainingApi,
      ),
    );
  }

  testWidgets('renders loading state cleanly at 375x812 without overflow', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    final membership = MembershipController(
      _FakeMembershipService(pendingGate: gate),
    );
    final coaching = _FakeCoachingService();

    await tester.pumpWidget(
      wrapPage(membershipController: membership, coachingService: coaching),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('META GYM · TẬP LUYỆN'), findsOneWidget);
    expect(find.text('Tập luyện'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Kế hoạch & Dinh dưỡng'), findsOneWidget);
    expect(find.text('Công cụ & Thư viện'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders active membership and active Coach LN avatar at 375x812 and 800x600',
    (tester) async {
      setPhoneViewport(tester);
      final membership = MembershipController(
        _FakeMembershipService(
          memberships: [
            Membership(
              id: 'mem-1',
              startDate: pastIso(5),
              endDate: futureIso(10),
              status: 'ACTIVE',
              planName: 'Gói Vàng 6 tháng',
            ),
          ],
        ),
      );
      final coaching = _FakeCoachingService(
        relationship: const MemberCoachRelationship(
          id: 'rel-1',
          coachId: 'coach-1',
          status: 'ACTIVE',
        ),
        coachNames: const {'coach-1': 'Lê Hoàng Nam'},
      );

      await tester.pumpWidget(
        wrapPage(membershipController: membership, coachingService: coaching),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tập luyện'), findsOneWidget);
      expect(find.text('HẠNG VÀNG'), findsOneWidget);
      expect(find.text('COACH 1:1'), findsOneWidget);
      expect(find.text('LN'), findsNWidgets(2));
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('ngày còn lại'), findsOneWidget);
      expect(find.text('Bắt đầu tập →'), findsOneWidget);
      expect(find.text('Xem giáo trình'), findsOneWidget);

      expect(find.text('Dinh dưỡng hôm nay'), findsOneWidget);
      expect(find.text('Lịch tập tuần của tôi'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Thư viện bài tập'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Nhật ký tập luyện'), findsOneWidget);
      expect(find.text('Lịch sử & Check-in'), findsOneWidget);
      expect(find.text('Thư viện bài tập'), findsOneWidget);
      expect(find.text('Phòng gym & Thiết bị'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify landscape/tablet layout at 800x600 as well.
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders no-package state and opens package requirement sheet when locked',
    (tester) async {
      setPhoneViewport(tester);
      final membership = MembershipController(_FakeMembershipService());
      final coaching = _FakeCoachingService();

      await tester.pumpWidget(
        wrapPage(membershipController: membership, coachingService: coaching),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có gói'), findsOneWidget);
      expect(find.text('Khám phá Coach'), findsOneWidget);
      expect(find.text('Giáo trình của Coach'), findsOneWidget);

      await tester.tap(find.text('Xem giáo trình'));
      await tester.pumpAndSettle();

      expect(find.text('Cần gói tập'), findsWidgets);
      expect(
        find.text('Đăng ký gói tập để sử dụng giáo trình của Coach.'),
        findsOneWidget,
      );
      expect(find.text('Đăng ký ngay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders expired gym and paused Coach state with renewal prompts',
    (tester) async {
      setPhoneViewport(tester);
      final membership = MembershipController(
        _FakeMembershipService(
          history: [
            Membership(
              id: 'mem-old',
              startDate: pastIso(40),
              endDate: pastIso(10),
              status: 'EXPIRED',
            ),
          ],
        ),
      );
      final coaching = _FakeCoachingService(
        relationship: const MemberCoachRelationship(
          id: 'rel-paused',
          coachId: 'coach-1',
          status: 'PAUSED',
        ),
        coachNames: const {'coach-1': 'Lê Hoàng Nam'},
      );

      await tester.pumpWidget(
        wrapPage(membershipController: membership, coachingService: coaching),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã hết hạn'), findsOneWidget);
      expect(find.text('Tạm ngưng · Gia hạn'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Nhật ký tập luyện'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Gia hạn'), findsOneWidget);

      await tester.tap(find.text('Nhật ký tập luyện'));
      await tester.pumpAndSettle();

      expect(find.text('Gói tập đã hết hạn'), findsOneWidget);
      expect(find.text('Xem lịch sử'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders self-plan preview with MuscleAnatomyTile when today plan exists',
    (tester) async {
      setPhoneViewport(tester);
      SelfTrainingIconStore.clearMemoryCache();
      addTearDown(SelfTrainingIconStore.clearMemoryCache);

      final membership = MembershipController(_FakeMembershipService());
      final coaching = _FakeCoachingService();
      final selfApi = _FakeSelfTrainingApi(
        plans: [
          MemberSelfTrainingDay(
            id: 'self-1',
            planDate: todayIso(),
            title: 'Ngực & Vai',
            startTime: '18:30',
            exercises: const [
              SelfTrainingExercise(id: 'ex-1', name: 'Incline Bench Press'),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        wrapPage(
          membershipController: membership,
          coachingService: coaching,
          selfTrainingApi: selfApi,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Lịch tập tuần của tôi'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MuscleAnatomyTile), findsOneWidget);
      expect(find.text('Hôm nay · 18:30 · Ngực & Vai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders error state and recovers cleanly on retry', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final membershipService = _FakeMembershipService(
      failFirstLoad: true,
      memberships: [
        Membership(
          id: 'mem-1',
          startDate: pastIso(2),
          endDate: futureIso(28),
          status: 'ACTIVE',
          planName: 'Gói Vàng 6 tháng',
        ),
      ],
    );
    final membership = MembershipController(membershipService);
    final coaching = _FakeCoachingService(
      relationship: const MemberCoachRelationship(
        id: 'rel-1',
        coachId: 'coach-1',
        status: 'ACTIVE',
      ),
      coachNames: const {'coach-1': 'Lê Hoàng Nam'},
    );

    await tester.pumpWidget(
      wrapPage(membershipController: membership, coachingService: coaching),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Chưa tải được thông tin gói tập. Hãy thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Lê Hoàng Nam'), findsOneWidget);
    expect(find.text('HẠNG VÀNG'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Bắt đầu tập opens MemberDayPlanPage when Coach plan has today workout and does not open journal',
    (tester) async {
      setPhoneViewport(tester);
      final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
      final todayVnStr =
          '${vnNow.year.toString().padLeft(4, '0')}-'
          '${vnNow.month.toString().padLeft(2, '0')}-'
          '${vnNow.day.toString().padLeft(2, '0')}';

      final membership = MembershipController(
        _FakeMembershipService(
          memberships: [
            Membership(
              id: 'mem-1',
              startDate: pastIso(5),
              endDate: futureIso(10),
              status: 'ACTIVE',
              planName: 'Gói Vàng 6 tháng',
            ),
          ],
        ),
      );
      final coaching = _FakeCoachingService(
        relationship: const MemberCoachRelationship(
          id: 'rel-1',
          coachId: 'coach-1',
          coachName: 'Lê Hoàng Nam',
          status: 'ACTIVE',
        ),
      );
      final training = _FakeTrainingService(
        plan: TrainingPlan(
          id: 'plan-1',
          title: 'Lộ Trình Tăng Cơ',
          status: 'ACTIVE',
          version: 1,
          days: [
            TrainingDay(
              dayNumber: vnNow.weekday,
              title: 'Ngực & Tay sau hôm nay',
              scheduledDate: todayVnStr,
              exercises: const [
                TrainingExercise(
                  exerciseId: 'ex-1',
                  exerciseName: 'Barbell Bench Press',
                  displayOrder: 1,
                  sets: 4,
                  reps: '8-10',
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: MemberTrainingHubPage(
            membershipController: membership,
            coachingService: coaching,
            trainingService: training,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngực & Tay sau hôm nay'), findsOneWidget);
      expect(find.text('Bắt đầu tập →'), findsOneWidget);

      await tester.tap(find.text('Bắt đầu tập →'));
      await tester.pumpAndSettle();

      expect(find.byType(MemberDayPlanPage), findsOneWidget);
      expect(find.byType(MemberJournalPage), findsNothing);
      expect(find.text('Barbell Bench Press'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Bắt đầu tập falls back to MemberTrainingPage when active Coach has no plan and Lịch Coach opens CoachBookingPage',
    (tester) async {
      setPhoneViewport(tester);
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _CoachBookingEmptyAdapter(),
      );
      final membership = MembershipController(
        _FakeMembershipService(
          memberships: [
            Membership(
              id: 'mem-1',
              startDate: pastIso(5),
              endDate: futureIso(10),
              status: 'ACTIVE',
              planName: 'Gói Vàng 6 tháng',
            ),
          ],
        ),
      );
      final coaching = _FakeCoachingService(
        relationship: const MemberCoachRelationship(
          id: 'rel-1',
          coachId: 'coach-1',
          status: 'ACTIVE',
        ),
        coachNames: const {'coach-1': 'Lê Hoàng Nam'},
      );
      final training = _FakeTrainingService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: client),
            Provider<MemberCoachingService>.value(value: coaching),
            Provider<MemberTrainingService>.value(value: training),
          ],
          child: MaterialApp(
            theme: MetaGymTheme.dark,
            home: MemberTrainingHubPage(
              membershipController: membership,
              coachingService: coaching,
              trainingService: training,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bắt đầu tập →'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberTrainingPage), findsOneWidget);
      expect(find.byType(MemberJournalPage), findsNothing);

      Navigator.of(tester.element(find.byType(MemberTrainingPage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lịch Coach'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachBookingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders dynamic membership tier badge and GÓI TẬP fallback when planName is null',
    (tester) async {
      setPhoneViewport(tester);

      Future<void> pumpWithPlanName(String? planName) async {
        final membership = MembershipController(
          _FakeMembershipService(
            memberships: [
              Membership(
                id: 'mem-tier',
                startDate: pastIso(3),
                endDate: futureIso(27),
                status: 'ACTIVE',
                planName: planName,
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey(planName ?? '__null__'),
            child: wrapPage(
              membershipController: membership,
              coachingService: _FakeCoachingService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWithPlanName('Gói Kim Cương 12 tháng');
      expect(find.text('HẠNG KIM CƯƠNG'), findsOneWidget);
      expect(find.text('HẠNG VÀNG'), findsNothing);
      expect(tester.takeException(), isNull);

      await pumpWithPlanName('Gói Bạc 3 tháng');
      expect(find.text('HẠNG BẠC'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpWithPlanName(null);
      expect(find.text('GÓI TẬP'), findsOneWidget);
      expect(find.text('HẠNG ĐỒNG'), findsNothing);
      expect(find.text('HẠNG VÀNG'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps membership and coach cards visible without spinner during background refresh after subpage pop',
    (tester) async {
      setPhoneViewport(tester);
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _CoachBookingEmptyAdapter(),
      );
      final secondLoadGate = Completer<void>();
      addTearDown(() {
        if (!secondLoadGate.isCompleted) secondLoadGate.complete();
      });

      final membership = MembershipController(
        _DeferredReloadMembershipService(
          memberships: [
            Membership(
              id: 'mem-1',
              startDate: pastIso(5),
              endDate: futureIso(10),
              status: 'ACTIVE',
              planName: 'Gói Vàng 6 tháng',
            ),
          ],
          secondLoadGate: secondLoadGate,
        ),
      );
      final coaching = _FakeCoachingService(
        relationship: const MemberCoachRelationship(
          id: 'rel-1',
          coachId: 'coach-1',
          status: 'ACTIVE',
        ),
        coachNames: const {'coach-1': 'Lê Hoàng Nam'},
      );
      final training = _FakeTrainingService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: client),
            Provider<MemberCoachingService>.value(value: coaching),
            Provider<MemberTrainingService>.value(value: training),
          ],
          child: MaterialApp(
            theme: MetaGymTheme.dark,
            home: MemberTrainingHubPage(
              membershipController: membership,
              coachingService: coaching,
              trainingService: training,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HẠNG VÀNG'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);

      await tester.tap(find.text('Bắt đầu tập →'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberTrainingPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(MemberTrainingPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('HẠNG VÀNG'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);

      secondLoadGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('HẠNG VÀNG'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DeferredReloadMembershipService extends _FakeMembershipService {
  _DeferredReloadMembershipService({
    required super.memberships,
    required this.secondLoadGate,
  });

  final Completer<void> secondLoadGate;
  int _getPlanCalls = 0;

  @override
  Future<List<MembershipPlan>> getPlans() async {
    _getPlanCalls += 1;
    if (_getPlanCalls >= 2) {
      await secondLoadGate.future;
    }
    return const [];
  }
}

class _FakeMembershipService implements MembershipService {
  _FakeMembershipService({
    this.memberships = const [],
    this.history = const [],
    this.failFirstLoad = false,
    this.pendingGate,
  });

  final List<Membership> memberships;
  final List<Membership> history;
  final bool failFirstLoad;
  final Completer<void>? pendingGate;
  int _loads = 0;

  @override
  Future<List<MembershipPlan>> getPlans() async {
    _loads++;
    if (pendingGate != null) {
      await pendingGate!.future;
    }
    if (failFirstLoad && _loads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Mất kết nối',
      );
    }
    return const [];
  }

  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      throw UnimplementedError();

  @override
  Future<List<Membership>> getCurrentMemberships() async => memberships;

  @override
  Future<List<Membership>> getMembershipHistory() async => history;

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) async =>
      throw UnimplementedError();
}

class _FakeCoachingService implements MemberCoachingService {
  _FakeCoachingService({this.relationship, this.coachNames = const {}});

  final MemberCoachRelationship? relationship;
  final Map<String, String> coachNames;

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async =>
      relationship;

  @override
  Future<Map<String, String>> getCoachNames() async => coachNames;

  @override
  Future<List<MemberCoachRequest>> getRequests() async => const [];

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async =>
      const [];

  @override
  Future<void> cancelRequest(String id) async {}

  @override
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  }) async => CoachLockChoiceResult(
    incidentId: 'inc-1',
    relationshipId: relationship?.id ?? 'rel-1',
    status: 'OPEN',
    memberChoice: choice,
    memberChoiceNote: note,
  );

  @override
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests() async =>
      const [];

  @override
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) => throw UnimplementedError();
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('Unexpected HTTP request: ${options.path}');

  @override
  void close({bool force = false}) {}
}

class _FakeSelfTrainingApi extends MemberSelfTrainingApi {
  _FakeSelfTrainingApi({this.plans = const []})
    : super(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: _NoopAdapter(),
        ),
      );

  final List<MemberSelfTrainingDay> plans;

  @override
  Future<List<MemberSelfTrainingDay>> getRange(String from, String to) async =>
      plans;
}

class _NutritionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"data":{"canWrite":false,"hasActiveMembership":false,"relationshipStatus":"NONE","entries":[]}}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _FakeTrainingService implements MemberTrainingService {
  _FakeTrainingService({this.plan});

  final TrainingPlan? plan;

  @override
  Future<TrainingPlan?> getActive() async => plan;

  @override
  Future<List<TrainingPlan>> getHistory() async => const [];

  @override
  Future<TrainingPlan> getPlan(String id) => throw UnimplementedError();
}

class _CoachBookingEmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = options.path == '/training-plans/me/active'
        ? '{"data":null}'
        : '{"data":[]}';
    return ResponseBody.fromString(
      payload,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
