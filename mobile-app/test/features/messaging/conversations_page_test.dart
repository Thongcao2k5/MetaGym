import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

class _Fixture implements MessagingService {
  _Fixture({this.failFirst = false, this.empty = false});
  final bool failFirst;
  final bool empty;
  int loads = 0;

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    expect(relationshipId, 'relationship-1');
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
    return const [
      Conversation(
        id: 'conversation-1',
        relationshipId: 'relationship-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        status: 'ENDED',
        unreadCount: 2,
      ),
    ];
  }
}
