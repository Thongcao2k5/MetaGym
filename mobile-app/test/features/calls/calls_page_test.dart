import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';

void main() {
  test('parses call metadata without treating it as a live connection', () {
    final call = CallLog.fromJson({
      'id': 'call-1',
      'relationshipId': 'relationship-1',
      'callerId': 'member-1',
      'receiverId': 'coach-1',
      'callType': 'VOICE',
      'status': 'CREATED',
      'initiatedAt': '2026-10-23T08:00:00Z',
      'answeredAt': null,
      'endedAt': null,
      'durationSeconds': 0,
      'failureReason': null,
    });
    expect(call.statusLabel, 'Đã tạo');
    expect(call.isFinished, isFalse);
  });

  testWidgets('creates a metadata call and updates its status', (tester) async {
    final service = _CallsFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CallsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('không thể kết nối'), findsOneWidget);
    await tester.tap(find.text('Tạo bản ghi cuộc gọi'));
    await tester.pumpAndSettle();
    expect(service.createdRelationship, 'relationship-1');
    expect(service.createdType, 'VOICE');
    expect(find.text('Đã tạo'), findsOneWidget);
    await tester.tap(find.text('Đánh dấu nhỡ'));
    await tester.pumpAndSettle();
    expect(service.lastStatus, 'MISSED');
    expect(find.text('Cuộc gọi nhỡ'), findsOneWidget);
  });

  testWidgets('shows error, retry, and empty history', (tester) async {
    final service = _CallsFixture(failFirst: true, noRelationships: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CallsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được lịch sử gọi.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có cuộc gọi nào.'), findsOneWidget);
    expect(
      find.text('Chưa có quan hệ hoạt động để tạo cuộc gọi.'),
      findsOneWidget,
    );
  });
}

class _CallsFixture implements CallsService {
  _CallsFixture({this.failFirst = false, this.noRelationships = false});
  final bool failFirst;
  final bool noRelationships;
  int loads = 0;
  String? createdRelationship;
  String? createdType;
  String? lastStatus;

  @override
  Future<List<CallLog>> getCalls(int page) async {
    loads++;
    if (failFirst && loads == 1) throw StateError('offline');
    return [];
  }

  @override
  Future<List<Conversation>> getActiveRelationships() async => noRelationships
      ? []
      : const [
          Conversation(
            id: 'conversation-1',
            relationshipId: 'relationship-1',
            memberId: 'member-1',
            coachId: 'coach-1',
            status: 'ACTIVE',
            unreadCount: 0,
          ),
        ];

  @override
  Future<CallLog> create(String relationshipId, String callType) async {
    createdRelationship = relationshipId;
    createdType = callType;
    return const CallLog(
      id: 'call-1',
      relationshipId: 'relationship-1',
      callerId: 'member-1',
      receiverId: 'coach-1',
      callType: 'VOICE',
      status: 'CREATED',
      initiatedAt: '2026-10-23T08:00:00Z',
      durationSeconds: 0,
    );
  }

  @override
  Future<CallLog> updateStatus(
    String callId,
    String status, {
    String? failureReason,
  }) async {
    lastStatus = status;
    return const CallLog(
      id: 'call-1',
      relationshipId: 'relationship-1',
      callerId: 'member-1',
      receiverId: 'coach-1',
      callType: 'VOICE',
      status: 'MISSED',
      initiatedAt: '2026-10-23T08:00:00Z',
      durationSeconds: 0,
    );
  }
}
