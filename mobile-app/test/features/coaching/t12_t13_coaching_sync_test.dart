import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';

void main() {
  group('T12 & T13 Service API Contracts (V2 endpoints, zero legacy 410 calls)', () {
    test('MemberCoachingApi calls V2 coach-lock-choice & early-termination routes', () async {
      final adapter = _RecordingAdapter();
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final api = MemberCoachingApi(client);

      final choice = await api.submitCoachLockChoice(
        choice: 'REFUND',
        note: '  Xin hỗ trợ hoàn mô phỏng  ',
      );
      expect(choice.memberChoice, 'REFUND');
      expect(choice.memberChoiceNote, 'Xin hỗ trợ hoàn mô phỏng');
      expect(adapter.calls.last.method, 'POST');
      expect(adapter.calls.last.path, '/relationships/me/coach-lock-choice');
      expect(adapter.calls.last.body, {
        'choice': 'REFUND',
        'note': 'Xin hỗ trợ hoàn mô phỏng',
      });

      final created = await api.requestEarlyTermination('rel-1', 'Đổi lịch tập');
      expect(created.status, 'PENDING_COUNTERPARTY');
      expect(adapter.calls.last.method, 'POST');
      expect(
        adapter.calls.last.path,
        '/relationships/rel-1/early-termination-requests',
      );
      expect(adapter.calls.last.body, {'reason': 'Đổi lịch tập'});

      final list = await api.getEarlyTerminationRequests();
      expect(list, hasLength(1));
      expect(adapter.calls.last.method, 'GET');
      expect(adapter.calls.last.path, '/early-termination-requests/me');

      final responded = await api.respondEarlyTermination(
        'term-1',
        decision: 'REJECT',
        reason: 'Cần hoàn tất giáo án tuần này',
      );
      expect(responded.status, 'DISPUTED');
      expect(adapter.calls.last.method, 'PATCH');
      expect(
        adapter.calls.last.path,
        '/early-termination-requests/term-1/respond',
      );
      expect(adapter.calls.last.body, {
        'decision': 'REJECT',
        'reason': 'Cần hoàn tất giáo án tuần này',
      });

      // Verify zero legacy 410 routes were called
      for (final call in adapter.calls) {
        expect(call.path, isNot(contains('/terminations')));
        expect(call.path, isNot(contains('/coach/termination-requests')));
      }
    });

    test('CoachMembersApi calls V2 early-termination routes only', () async {
      final adapter = _RecordingAdapter();
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final api = CoachMembersApi(client);

      await api.requestTermination('rel-9', 'Coach chuyển công tác');
      expect(adapter.calls.last.method, 'POST');
      expect(
        adapter.calls.last.path,
        '/relationships/rel-9/early-termination-requests',
      );
      expect(adapter.calls.last.body, {'reason': 'Coach chuyển công tác'});

      final requests = await api.getTerminationRequests();
      expect(requests, hasLength(1));
      expect(adapter.calls.last.method, 'GET');
      expect(adapter.calls.last.path, '/early-termination-requests/me');

      final accepted = await api.respondTermination(
        'term-1',
        decision: 'ACCEPT',
      );
      expect(accepted.status, 'ACCEPTED');
      expect(adapter.calls.last.method, 'PATCH');
      expect(
        adapter.calls.last.path,
        '/early-termination-requests/term-1/respond',
      );
      expect(adapter.calls.last.body, {'decision': 'ACCEPT'});
    });
  });

  group('T13 Member Coach-Lock WAIT/REFUND Widget Flow', () {
    testWidgets(
      'submits WAIT and REFUND choices with optional note and updates UI immediately',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _SyncMemberCoachingFixture(
          relationship: const MemberCoachRelationship(
            id: 'rel-1',
            coachId: 'coach-1',
            coachName: 'Coach Quân',
            status: 'PAUSED',
            pauseReason: 'COACH_LOCKED',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: MemberCoachingPage(service: service)),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('coach-lock-choice-card')), findsOneWidget);
        expect(find.byKey(const Key('coach-lock-wait-btn')), findsOneWidget);
        expect(find.byKey(const Key('coach-lock-refund-btn')), findsOneWidget);
        expect(
          find.byKey(const Key('member-early-termination-btn')),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const Key('coach-lock-choice-note')),
          'Tôi có thể đợi đến thứ 2',
        );
        await tester.tap(find.byKey(const Key('coach-lock-wait-btn')));
        await tester.pumpAndSettle();

        expect(service.lastLockChoice, 'WAIT');
        expect(service.lastLockNote, 'Tôi có thể đợi đến thứ 2');
        expect(
          find.byKey(const Key('coach-lock-choice-status-pill')),
          findsOneWidget,
        );
        expect(find.text('Đã chọn: Chờ Coach mở khóa'), findsOneWidget);

        await tester.tap(find.byKey(const Key('coach-lock-refund-btn')));
        await tester.pumpAndSettle();

        expect(service.lastLockChoice, 'REFUND');
        expect(
          find.text('Đã chọn: Yêu cầu hoàn mô phỏng / chuyển Coach'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('T12 Mutual 72h Early Termination Widget Flows', () {
    testWidgets(
      'Member submits early termination request and sees 72h pending status',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _SyncMemberCoachingFixture(
          relationship: const MemberCoachRelationship(
            id: 'rel-1',
            coachId: 'coach-1',
            coachName: 'Coach Linh',
            status: 'ACTIVE',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(home: MemberCoachingPage(service: service)),
        );
        await tester.pumpAndSettle();

        final btn = find.byKey(const Key('member-early-termination-btn'));
        await tester.scrollUntilVisible(btn, 200);
        await tester.tap(btn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('termination-reason')),
          'Chuyển nơi làm việc xa phòng gym',
        );
        await tester.tap(find.byKey(const Key('termination-submit-btn')));
        await tester.pumpAndSettle();

        expect(service.requestedReason, 'Chuyển nơi làm việc xa phòng gym');
        expect(find.text('Chờ đối tác phản hồi (72h)'), findsOneWidget);
        expect(find.textContaining('Hạn phản hồi 72h:'), findsOneWidget);
        expect(find.text('Rút yêu cầu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Member rejects Coach-initiated request -> escalates to DISPUTED',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _SyncMemberCoachingFixture(
          relationship: const MemberCoachRelationship(
            id: 'rel-1',
            coachId: 'coach-1',
            coachName: 'Coach Linh',
            status: 'ACTIVE',
          ),
          initialTerminations: const [
            CoachTerminationRequest(
              id: 'term-coach-1',
              relationshipId: 'rel-1',
              requestedByRole: 'COACH',
              requestedByName: 'Coach Linh',
              reason: 'Coach thay đổi lịch làm việc',
              status: 'PENDING_COUNTERPARTY',
              responseDeadlineAt: '2026-11-24T09:00:00.000Z',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(home: MemberCoachingPage(service: service)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Chờ đối tác phản hồi (72h)'), findsOneWidget);
        expect(
          find.byKey(const Key('termination-accept-term-coach-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('termination-reject-term-coach-1')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('termination-reject-term-coach-1')),
        );
        await tester.pumpAndSettle();

        // Validation blocks empty reject reason
        await tester.tap(find.byKey(const Key('termination-respond-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng nhập lý do từ chối.'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('termination-respond-reason')),
          'Tôi vẫn muốn tiếp tục hết gói',
        );
        await tester.tap(find.byKey(const Key('termination-respond-confirm')));
        await tester.pumpAndSettle();

        expect(service.lastDecision, 'REJECT');
        expect(service.lastDecisionReason, 'Tôi vẫn muốn tiếp tục hết gói');
        expect(find.text('Đang tranh chấp · Chờ Admin'), findsOneWidget);
        expect(find.textContaining('chuyển Admin phân xử'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Coach accepts Member-initiated early termination request via confirmation dialog',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _SyncCoachMembersFixture(
          requests: [
            const CoachTerminationRequest(
              id: 'term-member-1',
              relationshipId: 'rel-1',
              memberName: 'Trần Thu Hà',
              requestedByRole: 'MEMBER',
              requestedByName: 'Trần Thu Hà',
              reason: 'Không sắp xếp được lịch tập',
              status: 'PENDING_COUNTERPARTY',
              responseDeadlineAt: '2026-11-24T09:00:00.000Z',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(home: CoachMembersPage(service: service)),
        );
        await tester.pumpAndSettle();

        final acceptBtn = find.byKey(
          const Key('termination-accept-term-member-1'),
        );
        await tester.scrollUntilVisible(acceptBtn, 200);
        expect(acceptBtn, findsOneWidget);

        await tester.tap(acceptBtn);
        await tester.pumpAndSettle();

        expect(find.text('Chấp nhận kết thúc sớm?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('termination-respond-confirm')));
        await tester.pumpAndSettle();

        expect(service.lastDecision, 'ACCEPT');
        expect(find.text('Đã đồng ý kết thúc'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _RecordedCall {
  const _RecordedCall(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<_RecordedCall> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(_RecordedCall(options.method, options.path, options.data));
    final Object data = switch ((options.method, options.path)) {
      ('POST', '/relationships/me/coach-lock-choice') => {
        'id': 'inc-1',
        'incidentId': 'inc-1',
        'relationshipId': 'rel-1',
        'status': 'OPEN',
        'memberChoice': (options.data as Map)['choice'],
        'memberChoiceNote': (options.data as Map)['note'],
      },
      ('POST', final path) when path.endsWith('/early-termination-requests') => {
        'id': 'term-1',
        'relationshipId': 'rel-1',
        'requestedByRole': 'MEMBER',
        'reason': (options.data as Map)['reason'],
        'status': 'PENDING_COUNTERPARTY',
        'responseDeadlineAt': '2026-11-24T09:00:00.000Z',
      },
      ('GET', '/early-termination-requests/me') => [
        {
          'id': 'term-1',
          'relationshipId': 'rel-1',
          'requestedByRole': 'MEMBER',
          'reason': 'Đổi lịch tập',
          'status': 'PENDING_COUNTERPARTY',
          'responseDeadlineAt': '2026-11-24T09:00:00.000Z',
        },
      ],
      ('PATCH', final path) when path.endsWith('/respond') => {
        'id': 'term-1',
        'relationshipId': 'rel-1',
        'requestedByRole': 'COACH',
        'reason': 'Đổi lịch',
        'status': (options.data as Map)['decision'] == 'ACCEPT'
            ? 'ACCEPTED'
            : 'DISPUTED',
        'counterpartyReason': (options.data as Map)['reason'],
        'escalationReason': (options.data as Map)['decision'] == 'REJECT'
            ? 'COUNTERPARTY_REJECTED'
            : null,
      },
      _ => throw StateError('Unexpected request: ${options.method} ${options.path}'),
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

class _SyncMemberCoachingFixture implements MemberCoachingService {
  _SyncMemberCoachingFixture({
    required this.relationship,
    List<CoachTerminationRequest> initialTerminations = const [],
  }) : terminations = List.of(initialTerminations);

  MemberCoachRelationship? relationship;
  List<CoachTerminationRequest> terminations;
  String? lastLockChoice;
  String? lastLockNote;
  String? requestedReason;
  String? lastDecision;
  String? lastDecisionReason;

  @override
  Future<Map<String, String>> getCoachNames() async => const {
    'coach-1': 'Coach Linh',
  };

  @override
  Future<List<MemberCoachRequest>> getRequests() async => const [];

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async =>
      relationship;

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async =>
      relationship == null ? const [] : [relationship!];

  @override
  Future<void> cancelRequest(String id) async {}

  @override
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  }) async {
    lastLockChoice = choice;
    lastLockNote = note?.trim();
    return CoachLockChoiceResult(
      incidentId: 'inc-1',
      relationshipId: relationship?.id ?? 'rel-1',
      status: 'OPEN',
      memberChoice: choice,
      memberChoiceNote: note?.trim().isEmpty == true ? null : note?.trim(),
    );
  }

  @override
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests() async =>
      List.of(terminations);

  @override
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  ) async {
    requestedReason = reason;
    final created = CoachTerminationRequest(
      id: 'term-new-1',
      relationshipId: relationshipId,
      requestedByRole: 'MEMBER',
      reason: reason,
      status: 'PENDING_COUNTERPARTY',
      responseDeadlineAt: '2026-11-24T09:00:00.000Z',
    );
    terminations = [created, ...terminations];
    return created;
  }

  @override
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async {
    lastDecision = decision;
    lastDecisionReason = reason;
    final existing = terminations.firstWhere((item) => item.id == requestId);
    final updated = CoachTerminationRequest(
      id: existing.id,
      relationshipId: existing.relationshipId,
      requestedByRole: existing.requestedByRole,
      requestedByName: existing.requestedByName,
      reason: existing.reason,
      status: decision == 'ACCEPT'
          ? 'ACCEPTED'
          : decision == 'REJECT'
          ? 'DISPUTED'
          : 'CANCELLED',
      counterpartyReason: reason,
      escalationReason: decision == 'REJECT' ? 'COUNTERPARTY_REJECTED' : null,
    );
    terminations = [
      updated,
      ...terminations.where((item) => item.id != requestId),
    ];
    if (decision == 'ACCEPT') {
      relationship = null;
    }
    return updated;
  }
}

class _SyncCoachMembersFixture implements CoachMembersService {
  _SyncCoachMembersFixture({required this.requests});

  List<CoachTerminationRequest> requests;
  String? lastDecision;

  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [
    CoachMemberSummary(
      relationshipId: 'rel-1',
      memberId: 'member-1',
      memberFullName: 'Trần Thu Hà',
      status: 'ACTIVE',
    ),
  ];

  @override
  Future<CoachMemberDetail> getMember(String memberId) async =>
      const CoachMemberDetail(
        relationshipId: 'rel-1',
        memberId: 'member-1',
        memberFullName: 'Trần Thu Hà',
        status: 'ACTIVE',
        email: 'ha@example.com',
      );

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      List.of(requests);

  @override
  Future<void> requestTermination(String relationshipId, String reason) async {}

  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async {
    lastDecision = decision;
    final existing = requests.firstWhere((item) => item.id == requestId);
    final updated = CoachTerminationRequest(
      id: existing.id,
      relationshipId: existing.relationshipId,
      memberName: existing.memberName,
      requestedByRole: existing.requestedByRole,
      requestedByName: existing.requestedByName,
      reason: existing.reason,
      status: decision == 'ACCEPT'
          ? 'ACCEPTED'
          : decision == 'REJECT'
          ? 'DISPUTED'
          : 'CANCELLED',
      counterpartyReason: reason,
    );
    requests = [updated, ...requests.where((item) => item.id != requestId)];
    return updated;
  }
}
