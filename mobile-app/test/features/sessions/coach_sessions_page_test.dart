import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';

void main() {
  test('rejects impossible local dates', () {
    expect(parseSessionLocalTime('31/02/2026 08:00'), isNull);
    expect(parseSessionLocalTime('23/10/2026 25:00'), isNull);
  });

  testWidgets('creates a session for an active member', (tester) async {
    final sessions = _SessionsFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachSessionsPage(
          service: sessions,
          membersService: _MembersFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo buổi tập'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-title')), 'Tập chân');
    await tester.enterText(
      find.byKey(const Key('session-start')),
      '24/10/2026 08:00',
    );
    await tester.enterText(
      find.byKey(const Key('session-end')),
      '24/10/2026 09:00',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(sessions.created?['memberId'], 'member-1');
    expect(sessions.created?['title'], 'Tập chân');
    expect(find.text('Tập chân'), findsOneWidget);
  });

  testWidgets(
    'rejects end time before start and requires cancellation reason',
    (tester) async {
      final sessions = _SessionsFixture(seed: true);
      await tester.pumpWidget(
        MaterialApp(
          home: CoachSessionsPage(
            service: sessions,
            membersService: _MembersFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buổi cũ'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('session-end')),
        '23/10/2026 07:00',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu.'), findsOneWidget);
      expect(sessions.updated, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy buổi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do hủy.'), findsOneWidget);
      expect(sessions.updated, isNull);
    },
  );

  testWidgets('marks a scheduled session completed', (tester) async {
    final sessions = _SessionsFixture(seed: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachSessionsPage(
          service: sessions,
          membersService: _MembersFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(sessions.updated, {'status': 'COMPLETED'});
  });
}

class _MembersFixture implements CoachMembersService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [
    CoachMemberSummary(
      relationshipId: 'r-1',
      memberId: 'member-1',
      memberFullName: 'Hội viên A',
      status: 'ACTIVE',
    ),
  ];
  @override
  Future<CoachMemberDetail> getMember(String id) => throw UnimplementedError();
  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() =>
      throw UnimplementedError();
  @override
  Future<void> requestTermination(String id, String reason) =>
      throw UnimplementedError();
}

class _SessionsFixture implements CoachSessionsService {
  _SessionsFixture({this.seed = false});
  final bool seed;
  Map<String, Object?>? created;
  Map<String, Object?>? updated;
  @override
  Future<List<TrainingSession>> getAll() async => [
    if (seed)
      const TrainingSession(
        id: 's-1',
        title: 'Buổi cũ',
        scheduledStartAt: '2026-10-23T08:00:00Z',
        status: 'SCHEDULED',
      ),
    if (created != null)
      TrainingSession(
        id: 's-2',
        title: created!['title'] as String,
        scheduledStartAt: created!['scheduledStartAt'] as String,
        status: 'SCHEDULED',
      ),
  ];
  @override
  Future<TrainingSession> create(Map<String, Object?> payload) async {
    created = payload;
    return TrainingSession(
      id: 's-2',
      title: payload['title'] as String,
      scheduledStartAt: payload['scheduledStartAt'] as String,
      status: 'SCHEDULED',
    );
  }

  @override
  Future<TrainingSession> update(
    String id,
    Map<String, Object?> payload,
  ) async {
    updated = payload;
    return const TrainingSession(
      id: 's-1',
      title: 'Buổi cũ',
      scheduledStartAt: '2026-10-23T08:00:00Z',
      status: 'CANCELLED',
    );
  }
}
