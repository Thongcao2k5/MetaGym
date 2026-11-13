import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';

void main() {
  testWidgets('Member can open a direct chat even when Coach has no slot',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final messaging = _DirectChatFixture();
    await tester.pumpWidget(MaterialApp(home: CoachDetailPage(
      coachId: 'coach-2', service: _CoachFixture(),
      messagingService: messaging, currentUserId: 'member-1',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Đã hết suất'), findsOneWidget);
    await tester.tap(find.text('Nhắn tin với Coach'));
    await tester.pumpAndSettle();
    expect(messaging.coachId, 'coach-2');
    expect(messaging.messageKey, 'direct-chat-1');
    expect(find.text('Trò chuyện riêng tư'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists coaches, opens detail and sends a trimmed message', (
    tester,
  ) async {
    final service = _CoachFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach Linh'), findsOneWidget);
    expect(find.text('Còn 2 suất'), findsOneWidget);
    await tester.tap(find.text('Coach Linh'));
    await tester.pumpAndSettle();
    expect(find.text('Chuyên môn: Yoga'), findsOneWidget);
    expect(service.loadedId, 'coach-1');

    await tester.enterText(
      find.byKey(const Key('coach-message')),
      '  Tôi muốn tập yoga  ',
    );
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(service.sentMessage, 'Tôi muốn tập yoga');
    expect(find.text('Yêu cầu đã được gửi.'), findsOneWidget);
  });

  testWidgets('disables request when no slot and shows list retry', (
    tester,
  ) async {
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
    expect(find.widgetWithText(FilledButton, 'Gửi yêu cầu'), findsNothing);
  });

  testWidgets('locks submit while pending and displays membership error', (
    tester,
  ) async {
    final service = _CoachFixture(pendingSubmit: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach Linh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Gửi yêu cầu'), findsNothing);
    service.completeSubmitError(
      'MEMBERSHIP_REQUIRED',
      'Cần gói tập đang hoạt động',
    );
    await tester.pumpAndSettle();
    expect(find.text('Cần gói tập đang hoạt động'), findsOneWidget);
  });

  testWidgets('shows empty list', (tester) async {
    final emptyService = _CoachFixture(emptyList: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: emptyService)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có Coach để lựa chọn.'), findsOneWidget);
  });

  testWidgets('shows existing-request conflict', (tester) async {
    final conflictService = _CoachFixture(requestError: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachSelectionPage(service: conflictService)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach Linh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã có Coach hoặc yêu cầu đang chờ'), findsOneWidget);
  });
}

class _DirectChatFixture implements MessagingService {
  String? coachId;
  String? messageKey;

  @override
  Future<Conversation> startConversation({String? coachId, String? memberId}) async {
    this.coachId = coachId;
    return const Conversation(id: 'direct-chat-1', relationshipId: null,
      memberId: 'member-1', coachId: 'coach-2', status: 'NONE', unreadCount: 0);
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
  _CoachFixture({
    this.failFirstList = false,
    this.pendingSubmit = false,
    this.emptyList = false,
    this.requestError = false,
  });

  final bool failFirstList;
  final bool pendingSubmit;
  final bool emptyList;
  final bool requestError;
  int listLoads = 0;
  String? loadedId;
  String? sentMessage;
  final submitCompleter = Completer<CoachRequest>();

  static const coaches = [
    CoachProfile(
      id: 'coach-1',
      fullName: 'Coach Linh',
      specialties: ['Yoga'],
      memberLimit: 5,
      usedSlots: 3,
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
  Future<CoachRequest> sendRequest(String coachId, String? message) {
    sentMessage = message;
    if (pendingSubmit) return submitCompleter.future;
    if (requestError) {
      throw const ApiException(
        kind: ApiExceptionKind.request,
        code: 'COACH_REQUEST_CONFLICT',
        message: 'Đã có Coach hoặc yêu cầu đang chờ',
      );
    }
    return Future.value(const CoachRequest(id: 'request-1', status: 'PENDING'));
  }

  void completeSubmitError(String code, String message) {
    submitCompleter.completeError(
      ApiException(
        kind: ApiExceptionKind.forbidden,
        code: code,
        message: message,
      ),
    );
  }
}
