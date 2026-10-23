import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';

void main() {
  test('conversation parses unread count and relationship status', () {
    final item = Conversation.fromJson({
      'id': 'conversation-1',
      'relationshipId': 'relationship-1',
      'memberId': 'member-1',
      'coachId': 'coach-1',
      'status': 'ENDED',
      'unreadCount': 2,
      'lastMessageAt': null,
    });
    expect(item.unreadCount, 2);
    expect(item.canSend, isFalse);
  });

  testWidgets(
    'opens the selected relationship and marks ended history read-only',
    (tester) async {
      final service = _Fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsPage(service: service, currentUserId: 'member-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 tin chưa đọc'), findsOneWidget);
      await tester.tap(find.text('Coach coach-1'));
      await tester.pumpAndSettle();
      expect(find.text('Quan hệ relationship-1'), findsOneWidget);
      expect(find.textContaining('chỉ đọc'), findsOneWidget);
      expect(find.text('Tin nhắn cũ'), findsOneWidget);
    },
  );

  testWidgets('shows error and retries to empty list', (tester) async {
    final service = _Fixture(failFirst: true, empty: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được cuộc trò chuyện.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có cuộc trò chuyện nào.'), findsOneWidget);
  });

  testWidgets('sends text once and displays the response', (tester) async {
    final service = _Fixture(active: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach coach-1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Xin chào Coach');
    await tester.tap(find.text('Gửi'));
    await tester.pump();
    await tester.tap(find.text('Gửi'));
    expect(service.sendCalls, 1);
    service.completeSend();
    await tester.pumpAndSettle();
    expect(find.text('Xin chào Coach'), findsOneWidget);
  });

  testWidgets('loads the next page of message history', (tester) async {
    final service = _Fixture(active: true, fullFirstPage: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach coach-1'));
    await tester.pumpAndSettle();
    expect(find.text('Tin 0'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Tải tin cũ'),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await tester.tap(find.text('Tải tin cũ'));
    await tester.pumpAndSettle();
    expect(service.messagePages, [1, 2]);
    expect(find.text('Tin cũ hơn'), findsOneWidget);
  });
}

class _Fixture implements MessagingService {
  _Fixture({
    this.failFirst = false,
    this.empty = false,
    this.active = false,
    this.fullFirstPage = false,
  });
  final bool failFirst;
  final bool empty;
  final bool active;
  final bool fullFirstPage;
  int loads = 0;
  int sendCalls = 0;
  final messagePages = <int>[];
  final _pendingSend = Completer<ChatMessage>();

  void completeSend() => _pendingSend.complete(
    const ChatMessage(
      id: 'sent-1',
      senderId: 'member-1',
      messageType: 'TEXT',
      content: 'Xin chào Coach',
      sentAt: '2026-10-23T08:01:00Z',
    ),
  );

  @override
  Future<ChatMessage> sendText(
    String relationshipId,
    String content,
    String clientMessageId,
  ) {
    expect(relationshipId, 'relationship-1');
    expect(content, 'Xin chào Coach');
    expect(
      clientMessageId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    sendCalls++;
    return _pendingSend.future;
  }

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    expect(relationshipId, 'relationship-1');
    messagePages.add(page);
    if (fullFirstPage && page == 1) {
      return List.generate(
        20,
        (index) => ChatMessage(
          id: 'message-$index',
          senderId: 'coach-1',
          messageType: 'TEXT',
          content: 'Tin $index',
          sentAt: '2026-10-23T08:00:00Z',
        ),
      );
    }
    if (page == 2) {
      return const [
        ChatMessage(
          id: 'old',
          senderId: 'coach-1',
          messageType: 'TEXT',
          content: 'Tin cũ hơn',
          sentAt: '2026-10-22T08:00:00Z',
        ),
      ];
    }
    return const [
      ChatMessage(
        id: 'message-1',
        senderId: 'coach-1',
        messageType: 'TEXT',
        content: 'Tin nhắn cũ',
        sentAt: '2026-10-23T08:00:00Z',
      ),
    ];
  }

  @override
  Future<List<Conversation>> getConversations(int page) async {
    loads++;
    if (failFirst && loads == 1) throw StateError('offline');
    if (empty) return [];
    return [
      Conversation(
        id: 'conversation-1',
        relationshipId: 'relationship-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        status: active ? 'ACTIVE' : 'ENDED',
        unreadCount: 2,
      ),
    ];
  }
}
