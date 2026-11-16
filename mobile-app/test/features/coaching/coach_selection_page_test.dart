import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';

void main() {
  testWidgets('Member can open a direct chat even when Coach has no slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final messaging = _DirectChatFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachDetailPage(
          coachId: 'coach-2',
          service: _CoachFixture(),
          messagingService: messaging,
          currentUserId: 'member-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã hết suất'), findsOneWidget);
    await tester.tap(find.byTooltip('Nhắn Coach'));
    await tester.pumpAndSettle();
    expect(messaging.coachId, 'coach-2');
    expect(messaging.messageKey, 'direct-chat-1');
    expect(find.text('Trò chuyện riêng tư'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists, searches, filters coaches and opens detail proof', (
    tester,
  ) async {
    final service = _CoachFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lê Hoàng Nam'), findsOneWidget);
    expect(find.text('Coach Minh'), findsOneWidget);
    expect(find.text('Còn 2 suất'), findsOneWidget);

    await tester.tap(find.text('Còn suất'));
    await tester.pumpAndSettle();
    expect(find.text('Lê Hoàng Nam'), findsOneWidget);
    expect(find.text('Coach Minh'), findsNothing);

    await tester.enterText(find.byKey(const Key('coach-search-input')), 'Nam');
    await tester.pumpAndSettle();
    expect(find.text('Lê Hoàng Nam'), findsOneWidget);

    await tester.tap(find.text('Lê Hoàng Nam'));
    await tester.pumpAndSettle();
    expect(service.loadedId, 'coach-1');
    expect(find.text('5 năm'), findsOneWidget);
    expect(find.text('Chứng chỉ PT'), findsOneWidget);
    expect(find.text('Xem lịch làm việc'), findsOneWidget);
  });

  testWidgets('retries list error and opens full coach detail', (tester) async {
    final service = _CoachFixture(failFirstList: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được Coach.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach Minh'));
    await tester.pumpAndSettle();
    expect(find.text('Đã hết suất'), findsOneWidget);
    expect(find.text('4 năm'), findsNothing);
  });

  testWidgets('shows empty list', (tester) async {
    final emptyService = _CoachFixture(emptyList: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: emptyService)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có Coach để lựa chọn.'), findsOneWidget);
  });
}

class _DirectChatFixture implements MessagingService {
  String? coachId;
  String? messageKey;

  @override
  Future<Conversation> startConversation({
    String? coachId,
    String? memberId,
  }) async {
    this.coachId = coachId;
    return const Conversation(
      id: 'direct-chat-1',
      relationshipId: null,
      memberId: 'member-1',
      coachId: 'coach-2',
      status: 'NONE',
      unreadCount: 0,
    );
  }

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    messageKey = relationshipId;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CoachFixture implements CoachSelectionService {
  _CoachFixture({this.failFirstList = false, this.emptyList = false});

  final bool failFirstList;
  final bool emptyList;
  int listLoads = 0;
  String? loadedId;

  static const coaches = [
    CoachProfile(
      id: 'coach-1',
      fullName: 'Lê Hoàng Nam',
      specialties: ['Tăng cơ', 'Sức mạnh'],
      qualifications: 'Chứng chỉ PT',
      experienceYears: 5,
      memberLimit: 8,
      usedSlots: 6,
      availableSlots: 2,
    ),
    CoachProfile(
      id: 'coach-2',
      fullName: 'Coach Minh',
      specialties: ['Cardio'],
      memberLimit: 4,
      usedSlots: 4,
      availableSlots: 0,
    ),
  ];

  @override
  Future<List<CoachProfile>> getCoaches() async {
    listLoads++;
    if (failFirstList && listLoads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được Coach.',
      );
    }
    return emptyList ? const [] : coaches;
  }

  @override
  Future<CoachProfile> getCoach(String id) async {
    loadedId = id;
    return coaches.firstWhere((coach) => coach.id == id);
  }

  @override
  Future<CoachRequest> sendRequest(String coachId, String? message) async =>
      const CoachRequest(id: 'request-1', status: 'PENDING');
}
