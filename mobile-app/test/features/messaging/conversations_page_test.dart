import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

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

  testWidgets('marks received message read and stops polling after exit', (
    tester,
  ) async {
    final service = _Fixture(active: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach coach-1'));
    await tester.pumpAndSettle();
    expect(service.readMessageIds, ['message-1']);
    final before = service.messagePages.length;
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(service.messagePages.length, greaterThan(before));
    await tester.pageBack();
    await tester.pumpAndSettle();
    final afterExit = service.messagePages.length;
    await tester.pump(const Duration(seconds: 11));
    expect(service.messagePages.length, afterExit);
  });

  testWidgets('retries a failed text with the original client ID', (
    tester,
  ) async {
    final service = _Fixture(active: true, failSendOnce: true);
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
    await tester.pumpAndSettle();
    expect(find.text('Thử gửi lại'), findsOneWidget);
    await tester.tap(find.text('Thử gửi lại'));
    await tester.pumpAndSettle();
    expect(service.sentIds, hasLength(2));
    expect(service.sentIds[0], service.sentIds[1]);
    expect(find.text('Xin chào Coach'), findsOneWidget);
  });

  testWidgets('uploads an image and sends an image message', (tester) async {
    final service = _Fixture(active: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(
          service: service,
          currentUserId: 'member-1',
          picker: _ImageFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach coach-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi ảnh'));
    await tester.pumpAndSettle();
    expect(service.uploadCalls, 1);
    expect(service.imageSends, 1);
    expect(service.imageUrlLoads, greaterThan(0));
  });

  testWidgets('retries a failed signed image URL', (tester) async {
    final service = _Fixture(
      active: true,
      imageHistory: true,
      failImageUrlOnce: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach coach-1'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được ảnh.'), findsOneWidget);
    await tester.tap(find.text('Tải lại ảnh'));
    await tester.pumpAndSettle();
    expect(service.imageUrlLoads, 2);
  });
}

class _ImageFixture implements ProgressPhotoPicker {
  @override
  Future<SelectedProgressImage?> pick() async => SelectedProgressImage(
    name: 'chat.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
  );
}

class _Fixture implements MessagingService {
  _Fixture({
    this.failFirst = false,
    this.empty = false,
    this.active = false,
    this.fullFirstPage = false,
    this.failSendOnce = false,
    this.imageHistory = false,
    this.failImageUrlOnce = false,
  });
  final bool failFirst;
  final bool empty;
  final bool active;
  final bool fullFirstPage;
  final bool failSendOnce;
  final bool imageHistory;
  final bool failImageUrlOnce;
  int loads = 0;
  int sendCalls = 0;
  final messagePages = <int>[];
  final readMessageIds = <String>[];
  final sentIds = <String>[];
  int uploadCalls = 0;
  int imageSends = 0;
  int imageUrlLoads = 0;
  final _pendingSend = Completer<ChatMessage>();

  @override
  Future<String> uploadImage(SelectedProgressImage image) async {
    uploadCalls++;
    return 'media-1';
  }

  @override
  Future<ChatMessage> sendImage(
    String relationshipId,
    String mediaId,
    String clientMessageId,
  ) async {
    expect(relationshipId, 'relationship-1');
    expect(mediaId, 'media-1');
    imageSends++;
    return const ChatMessage(
      id: 'image-1',
      senderId: 'member-1',
      messageType: 'IMAGE',
      mediaId: 'media-1',
      sentAt: '2026-10-23T08:02:00Z',
    );
  }

  @override
  Future<Uri> getImageAccessUrl(String mediaId) async {
    imageUrlLoads++;
    if (failImageUrlOnce && imageUrlLoads == 1) throw StateError('expired');
    return Uri.parse('https://example.invalid/chat.png');
  }

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
    sentIds.add(clientMessageId);
    if (failSendOnce) {
      if (sendCalls == 1) throw StateError('offline');
      return Future.value(
        const ChatMessage(
          id: 'sent-1',
          senderId: 'member-1',
          messageType: 'TEXT',
          content: 'Xin chào Coach',
          sentAt: '2026-10-23T08:01:00Z',
        ),
      );
    }
    return _pendingSend.future;
  }

  @override
  Future<void> markRead(String relationshipId, String messageId) async {
    expect(relationshipId, 'relationship-1');
    readMessageIds.add(messageId);
  }

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    expect(relationshipId, 'relationship-1');
    messagePages.add(page);
    if (imageHistory) {
      return const [
        ChatMessage(
          id: 'image-1',
          senderId: 'coach-1',
          messageType: 'IMAGE',
          mediaId: 'media-1',
          sentAt: '2026-10-23T08:00:00Z',
        ),
      ];
    }
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
