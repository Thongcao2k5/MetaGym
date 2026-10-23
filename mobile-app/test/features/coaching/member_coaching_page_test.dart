import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';

void main() {
  testWidgets('shows pending request and refreshes after cancellation', (
    tester,
  ) async {
    final service = _MemberCoachingFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberCoachingPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu đang chờ'), findsOneWidget);
    expect(find.text('Coach hiện tại'), findsOneWidget);
    expect(find.text('Coach Linh'), findsWidgets);
    await tester.tap(find.text('Hủy yêu cầu'));
    await tester.pumpAndSettle();
    expect(service.cancelledId, 'request-1');
    expect(find.text('Không có yêu cầu đang chờ.'), findsOneWidget);
    expect(find.text('Đã hủy'), findsOneWidget);
  });

  testWidgets('requires reason and confirmation before ending relationship', (
    tester,
  ) async {
    final service = _MemberCoachingFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberCoachingPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kết thúc quan hệ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(service.endedId, isNull);

    await tester.tap(find.text('Kết thúc quan hệ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận kết thúc'));
    await tester.pumpAndSettle();
    expect(service.endedId, isNull);
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('termination-reason')),
      '  Đổi lịch tập  ',
    );
    await tester.tap(find.text('Xác nhận kết thúc'));
    await tester.pumpAndSettle();
    expect(service.endedId, 'relationship-1');
    expect(service.endReason, 'Đổi lịch tập');
    expect(find.text('Chưa có Coach hiện tại.'), findsOneWidget);
    expect(find.text('Đã kết thúc'), findsOneWidget);
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
    expect(find.text('Không có yêu cầu đang chờ.'), findsOneWidget);
    expect(find.text('Chưa có Coach hiện tại.'), findsOneWidget);
    expect(service.loads, 2);
  });
}

class _MemberCoachingFixture implements MemberCoachingService {
  _MemberCoachingFixture({this.empty = false, this.failFirst = false});

  final bool empty;
  final bool failFirst;
  int loads = 0;
  String? cancelledId;
  String? endedId;
  String? endReason;
  bool cancelled = false;
  bool ended = false;

  @override
  Future<Map<String, String>> getCoachNames() async => const {
    'coach-1': 'Coach Linh',
  };

  @override
  Future<List<MemberCoachRequest>> getRequests() async {
    loads++;
    if (failFirst && loads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được quan hệ.',
      );
    }
    if (empty) return const [];
    return [
      MemberCoachRequest(
        id: 'request-1',
        coachId: 'coach-1',
        status: cancelled ? 'CANCELLED' : 'PENDING',
        message: 'Tôi muốn tập Yoga',
      ),
    ];
  }

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async =>
      empty || ended
      ? null
      : const MemberCoachRelationship(
          id: 'relationship-1',
          coachId: 'coach-1',
          status: 'ACTIVE',
        );

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async => empty
      ? const []
      : [
          MemberCoachRelationship(
            id: 'relationship-1',
            coachId: 'coach-1',
            status: ended ? 'ENDED' : 'ACTIVE',
          ),
        ];

  @override
  Future<void> cancelRequest(String id) async {
    cancelledId = id;
    cancelled = true;
  }

  @override
  Future<void> terminateRelationship(String id, String reason) async {
    endedId = id;
    endReason = reason;
    ended = true;
  }
}
