import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'shows current Coach hero and action rows without legacy requests',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = _MemberCoachingFixture();
      await tester.pumpWidget(
        MaterialApp(home: MemberCoachingPage(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coach Linh'), findsOneWidget);
      expect(find.text('Đang hoạt động'), findsOneWidget);
      expect(find.text('Xem lịch với Coach'), findsOneWidget);
      expect(find.text('Giáo trình tập luyện'), findsOneWidget);
      expect(find.text('Thực đơn & Dinh dưỡng'), findsOneWidget);
      expect(find.text('Nhắn Coach'), findsOneWidget);
      expect(find.text('Yêu cầu đang chờ'), findsNothing);
      expect(find.text('Kết thúc quan hệ'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('auto-end replaces manual termination and keeps chat on paused', (
    tester,
  ) async {
    final service = _MemberCoachingFixture(paused: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberCoachingPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tạm ngưng do Gym hết hạn'), findsOneWidget);
    expect(find.text('Gia hạn gói Gym'), findsOneWidget);
    expect(find.text('Đang tạm khóa'), findsOneWidget);
    expect(find.text('Nhắn Coach'), findsOneWidget);
    expect(find.text('Kết thúc quan hệ'), findsNothing);
  });

  testWidgets('shows empty state and retries an API error', (tester) async {
    final service = _MemberCoachingFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberCoachingPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được quan hệ.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có Coach'), findsOneWidget);
    expect(find.text('Khám phá Coach'), findsOneWidget);
    expect(service.loads, 2);
  });

  testWidgets(
    'displays COACH_LOCKED freeze badge and frozen entitlement dates without gym renewal CTA',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _FrozenEntitlementAdapter(),
      );
      final service = _MemberCoachingFixture(
        paused: true,
        pauseReason: 'COACH_LOCKED',
      );
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(home: MemberCoachingPage(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coach đang tạm khóa'), findsOneWidget);
      expect(find.byKey(const Key('coaching-frozen-pill')), findsOneWidget);
      expect(find.text('Đang đóng băng'), findsOneWidget);
      expect(find.text('6 / 10 buổi'), findsOneWidget);
      expect(find.text('21/11/2026'), findsOneWidget);
      expect(find.textContaining('Gói Coach đang được đóng băng'), findsOneWidget);
      expect(find.text('Gia hạn gói Gym'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'displays MEMBER_LOCKED pause state distinctly without freeze pill or gym renewal CTA',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = _MemberCoachingFixture(
        paused: true,
        pauseReason: 'MEMBER_LOCKED',
      );
      await tester.pumpWidget(
        MaterialApp(home: MemberCoachingPage(service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tài khoản đang tạm khóa'), findsWidgets);
      expect(
        find.textContaining('tài khoản của bạn đang bị khóa'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('coaching-frozen-pill')), findsNothing);
      expect(find.text('Gia hạn gói Gym'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemberCoachingFixture implements MemberCoachingService {
  _MemberCoachingFixture({
    this.empty = false,
    this.failFirst = false,
    this.paused = false,
    this.pauseReason,
  });

  final bool empty;
  final bool failFirst;
  final bool paused;
  final String? pauseReason;
  int loads = 0;
  String? endedId;
  String? endReason;
  bool ended = false;

  @override
  Future<Map<String, String>> getCoachNames() async => const {
    'coach-1': 'Coach Linh',
  };

  @override
  Future<List<MemberCoachRequest>> getRequests() async => const [];

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async {
    loads++;
    if (failFirst && loads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được quan hệ.',
      );
    }
    if (empty || ended) return null;
    return MemberCoachRelationship(
      id: 'relationship-1',
      coachId: 'coach-1',
      coachName: 'Coach Linh',
      status: paused ? 'PAUSED' : 'ACTIVE',
      pauseReason: paused ? (pauseReason ?? 'MEMBERSHIP_EXPIRED') : null,
    );
  }

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async => empty
      ? const []
      : [
          MemberCoachRelationship(
            id: 'relationship-1',
            coachId: 'coach-1',
            coachName: 'Coach Linh',
            status: ended ? 'ENDED' : (paused ? 'PAUSED' : 'ACTIVE'),
          ),
        ];

  @override
  Future<void> cancelRequest(String id) async {}

  @override
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  }) async => CoachLockChoiceResult(
    incidentId: 'inc-1',
    relationshipId: 'relationship-1',
    status: 'OPEN',
    memberChoice: choice,
    memberChoiceNote: note?.trim().isEmpty == true ? null : note?.trim(),
  );

  @override
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests() async =>
      const [];

  @override
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  ) async {
    endedId = relationshipId;
    endReason = reason;
    return CoachTerminationRequest(
      id: 'term-1',
      relationshipId: relationshipId,
      requestedByRole: 'MEMBER',
      reason: reason,
      status: 'PENDING_COUNTERPARTY',
      responseDeadlineAt: '2026-11-24T09:00:00.000Z',
    );
  }

  @override
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async => CoachTerminationRequest(
    id: requestId,
    relationshipId: 'relationship-1',
    requestedByRole: 'COACH',
    reason: 'Đổi lịch',
    status: decision == 'ACCEPT'
        ? 'ACCEPTED'
        : decision == 'REJECT'
        ? 'DISPUTED'
        : 'CANCELLED',
    counterpartyReason: reason,
  );
}

class _FrozenEntitlementAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'ent-1',
          'coachId': 'coach-1',
          'planCode': 'BASIC',
          'planName': 'Gói cơ bản',
          'status': 'ACTIVE',
          'remainingSessions': 6,
          'totalSessions': 10,
          'startsOn': '2026-11-01',
          'endsOn': '2026-12-01',
          'frozenAt': '2026-11-21T03:00:00.000Z',
          'frozenDaysTotal': 0,
        },
      ],
      _ => const <Object>[],
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
