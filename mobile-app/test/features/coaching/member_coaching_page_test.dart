import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';

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
      expect(find.text('Giáo trình'), findsOneWidget);
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
}

class _MemberCoachingFixture implements MemberCoachingService {
  _MemberCoachingFixture({
    this.empty = false,
    this.failFirst = false,
    this.paused = false,
  });

  final bool empty;
  final bool failFirst;
  final bool paused;
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
      pauseReason: paused ? 'MEMBERSHIP_EXPIRED' : null,
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
  Future<void> terminateRelationship(String id, String reason) async {
    endedId = id;
    endReason = reason;
    ended = true;
  }
}
