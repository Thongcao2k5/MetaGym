import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_requests_page.dart';

void main() {
  testWidgets('accepts pending request and refreshes list and slots', (
    tester,
  ) async {
    final service = _CoachRequestsFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachRequestsPage(coachId: 'coach-1', service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Còn 1 suất'), findsOneWidget);
    await tester.tap(find.text('Hội viên member-1'));
    await tester.pumpAndSettle();
    expect(find.text('Lời nhắn: Tôi muốn tập yoga'), findsOneWidget);
    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();
    expect(service.decision, 'ACCEPTED');
    expect(find.text('Đã hết suất'), findsOneWidget);
    expect(find.text('Đã chấp nhận'), findsOneWidget);
  });

  testWidgets('requires a reason to reject and reports stale request', (
    tester,
  ) async {
    final service = _CoachRequestsFixture(stale: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachRequestsPage(coachId: 'coach-1', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hội viên member-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
    expect(service.decision, isNull);
    await tester.enterText(
      find.byKey(const Key('rejection-reason')),
      '  Lịch đã kín  ',
    );
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    expect(service.reason, 'Lịch đã kín');
    expect(find.text('Không tìm thấy yêu cầu đang chờ'), findsOneWidget);
  });

  testWidgets('rejects a request with a trimmed reason and refreshes history', (
    tester,
  ) async {
    final service = _CoachRequestsFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachRequestsPage(coachId: 'coach-1', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hội viên member-1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rejection-reason')),
      '  Không còn lịch phù hợp  ',
    );
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    expect(service.decision, 'REJECTED');
    expect(service.reason, 'Không còn lịch phù hợp');
    expect(service.loads, 2);
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.text('Còn 1 suất'), findsOneWidget);
  });

  testWidgets('shows empty state and retries list error', (tester) async {
    final service = _CoachRequestsFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachRequestsPage(coachId: 'coach-1', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được yêu cầu.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có yêu cầu nào.'), findsOneWidget);
    expect(service.loads, 2);
  });
}

class _CoachRequestsFixture implements CoachRequestsService {
  _CoachRequestsFixture({
    this.empty = false,
    this.failFirst = false,
    this.stale = false,
  });

  final bool empty;
  final bool failFirst;
  final bool stale;
  int loads = 0;
  String? decision;
  String? reason;
  String status = 'PENDING';

  CoachIncomingRequest get request => CoachIncomingRequest(
    id: 'request-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    status: status,
    message: 'Tôi muốn tập yoga',
  );

  @override
  Future<List<CoachIncomingRequest>> getRequests() async {
    loads++;
    if (failFirst && loads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được yêu cầu.',
      );
    }
    return empty ? const [] : [request];
  }

  @override
  Future<CoachIncomingRequest> getRequest(String id) async => request;

  @override
  Future<CoachProfile> getCoach(String id) async => CoachProfile(
    id: id,
    fullName: 'Coach Demo',
    memberLimit: 1,
    usedSlots: status == 'ACCEPTED' ? 1 : 0,
    availableSlots: status == 'ACCEPTED' ? 0 : 1,
  );

  @override
  Future<void> decide(String id, String value, {String? reason}) async {
    decision = value;
    this.reason = reason;
    if (stale) {
      throw const ApiException(
        kind: ApiExceptionKind.request,
        statusCode: 404,
        code: 'NOT_FOUND',
        message: 'Không tìm thấy yêu cầu đang chờ',
      );
    }
    status = value;
  }
}
