import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/features/training/presentation/nutrition_tracking_page.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_hub_page.dart';

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
        expect(find.text('Theo dõi dinh dưỡng'), findsOneWidget);
        final nutritionTop = tester
            .getTopLeft(find.text('Theo dõi dinh dưỡng'))
            .dy;
        expect(
          nutritionTop,
          greaterThan(tester.getTopLeft(find.text('Lịch tập của tôi')).dy),
        );
        expect(
          nutritionTop,
          lessThan(tester.getTopLeft(find.text('Công cụ & Khám phá')).dy),
        );
        await tester.tap(useButton ? button : find.text('Theo dõi dinh dưỡng'));
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
    expect(find.text('Dịch vụ của bạn'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Kế hoạch tập luyện'), findsOneWidget);
    expect(find.text('Công cụ & Khám phá'), findsOneWidget);
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
      expect(find.text('Dịch vụ của bạn'), findsOneWidget);
      expect(find.text('Gói tập'), findsOneWidget);
      expect(find.text('Gói Coach'), findsOneWidget);
      expect(find.text('LN'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('Hiệu lực'), findsNWidgets(2));
      expect(find.textContaining('ngày'), findsWidgets);

      expect(find.text('Giáo trình của Coach'), findsOneWidget);
      expect(find.text('Lịch tập của tôi'), findsOneWidget);
      expect(find.text('Nhật ký tập luyện'), findsOneWidget);
      expect(find.text('Lịch sử tập luyện'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Thư viện bài tập'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Thư viện bài tập'), findsOneWidget);
      expect(find.text('Phòng gym & thiết bị'), findsOneWidget);
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
      expect(find.text('Đăng ký'), findsNWidgets(2));

      await tester.tap(find.text('Giáo trình của Coach'));
      await tester.pumpAndSettle();

      expect(find.text('Cần gói tập'), findsOneWidget);
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
      expect(find.text('Tạm ngưng'), findsOneWidget);
      expect(
        find.text('Tạm ngưng · Gia hạn gói tập để tiếp tục.'),
        findsOneWidget,
      );
      expect(find.text('Gia hạn'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Nhật ký tập luyện'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
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

      expect(find.byType(MuscleAnatomyTile), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
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
    expect(find.text('Hiệu lực'), findsNWidgets(2));
    expect(find.text('Thử lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
  Future<void> terminateRelationship(String id, String reason) async {}
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
