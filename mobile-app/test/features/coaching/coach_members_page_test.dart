import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';

void main() {
  testWidgets('opens an active member and sends a termination reason', (
    tester,
  ) async {
    final service = _MembersFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachMembersPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu: Tăng sức bền'), findsOneWidget);
    expect(find.text('Bệnh nền: Hen nhẹ'), findsOneWidget);
    await tester.tap(find.text('Xin ngừng phụ trách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
    expect(service.reason, isNull);
    await tester.enterText(
      find.byKey(const Key('termination-request-reason')),
      '  Đổi lịch làm việc  ',
    );
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(service.reason, 'Đổi lịch làm việc');
    expect(find.text('Chờ đối tác phản hồi (72h)'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu ngừng phụ trách'), findsOneWidget);
    expect(find.text('Chờ đối tác phản hồi (72h)'), findsOneWidget);
  });

  testWidgets('clears private details when member access expires', (
    tester,
  ) async {
    final service = _MembersFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachMembersPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    expect(find.text('Bệnh nền: Hen nhẹ'), findsOneWidget);
    service.revoked = true;
    await tester.drag(find.text('Bệnh nền: Hen nhẹ'), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Bệnh nền: Hen nhẹ'), findsNothing);
    expect(find.text('Không tìm thấy Member đang phụ trách'), findsOneWidget);
  });

  testWidgets(
    'clears private details when termination discovers an ended relationship',
    (tester) async {
      final service = _MembersFixture(revokedOnSubmit: true);
      await tester.pumpWidget(
        MaterialApp(home: CoachMembersPage(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nguyễn An'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xin ngừng phụ trách'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('termination-request-reason')),
        'Đổi lịch',
      );
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(find.text('Bệnh nền: Hen nhẹ'), findsNothing);
      expect(find.text('Không tìm thấy quan hệ hiện tại'), findsOneWidget);
    },
  );

  testWidgets('shows empty and retry states without stale members', (
    tester,
  ) async {
    final service = _MembersFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachMembersPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được Member'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có hội viên đang phụ trách.'), findsOneWidget);
  });
}

class _MembersFixture implements CoachMembersService {
  _MembersFixture({
    this.empty = false,
    this.failFirst = false,
    this.revokedOnSubmit = false,
  });

  final bool empty;
  final bool failFirst;
  final bool revokedOnSubmit;
  bool revoked = false;
  int loads = 0;
  String? reason;
  CoachTerminationRequest? termination;

  @override
  Future<List<CoachMemberSummary>> getMembers() async {
    loads++;
    if (failFirst && loads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được Member',
      );
    }
    return empty
        ? const []
        : [
            const CoachMemberSummary(
              relationshipId: 'rel-1',
              memberId: 'member-1',
              memberFullName: 'Nguyễn An',
              status: 'ACTIVE',
            ),
          ];
  }

  @override
  Future<CoachMemberDetail> getMember(String memberId) async {
    if (revoked) {
      throw const ApiException(
        kind: ApiExceptionKind.request,
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'Không tìm thấy Member đang phụ trách',
      );
    }
    return const CoachMemberDetail(
      relationshipId: 'rel-1',
      memberId: 'member-1',
      memberFullName: 'Nguyễn An',
      status: 'ACTIVE',
      email: 'an@example.com',
      fitnessGoal: 'Tăng sức bền',
      healthNotes: 'Hen nhẹ',
      injuryNotes: null,
    );
  }

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      termination == null ? const [] : [termination!];

  @override
  Future<void> requestTermination(String relationshipId, String value) async {
    if (revokedOnSubmit) {
      throw const ApiException(
        kind: ApiExceptionKind.request,
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'Không tìm thấy quan hệ hiện tại',
      );
    }
    reason = value;
    termination = const CoachTerminationRequest(
      id: 'termination-1',
      relationshipId: 'rel-1',
      requestedByRole: 'COACH',
      reason: 'Đổi lịch làm việc',
      status: 'PENDING_COUNTERPARTY',
      responseDeadlineAt: '2026-11-24T09:00:00.000Z',
    );
  }

  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async {
    final updated = CoachTerminationRequest(
      id: requestId,
      relationshipId: 'rel-1',
      requestedByRole: termination?.requestedByRole ?? 'MEMBER',
      reason: termination?.reason ?? 'Đổi lịch',
      status: decision == 'ACCEPT'
          ? 'ACCEPTED'
          : decision == 'REJECT'
          ? 'DISPUTED'
          : 'CANCELLED',
      counterpartyReason: reason,
    );
    termination = updated;
    return updated;
  }
}
