import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:meta_gym_app/core/network/api_exception.dart';
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
    expect(item.canSend, isTrue);
  });

  testWidgets(
    'opens an ended relationship and keeps messaging available',
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
      expect(find.text('Trò chuyện riêng tư'), findsOneWidget);
      expect(find.textContaining('tiếp tục nhắn tin'), findsOneWidget);
      expect(find.text('Gửi'), findsOneWidget);
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
    final scrollable = find.descendant(
      of: find.byType(ListView).last,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Tải tin cũ'),
      50.0,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
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

  testWidgets('keeps newly sent message after exiting and reopening thread', (
    tester,
  ) async {
    final service = _Fixture(
      active: true,
      coachName: 'Coach Lê Nam',
      memberName: 'Hội viên Minh',
      persistSentMessages: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationsPage(service: service, currentUserId: 'member-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coach Lê Nam'), findsOneWidget);
    await tester.tap(find.text('Coach Lê Nam'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tin mới nhất');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Tin mới nhất'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tin mới nhất'), findsOneWidget);
    await tester.tap(find.text('Coach Lê Nam'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ConversationDetailPage),
        matching: find.text('Tin mới nhất'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tin mới nhất'), findsOneWidget);
  });

  test('formats conversation preview and local timestamps accurately', () {
    final nowLocal = DateTime(2026, 11, 14, 16, 30);
    final todayUtc = DateTime(2026, 11, 14, 9, 5).toUtc().toIso8601String();
    final yesterdayUtc =
        DateTime(2026, 11, 13, 21, 15).toUtc().toIso8601String();
    final olderUtc = DateTime(2026, 10, 5, 8, 0).toUtc().toIso8601String();

    expect(formatConversationTimestamp(todayUtc, now: nowLocal), '09:05');
    expect(formatConversationTimestamp(yesterdayUtc, now: nowLocal), 'Hôm qua');
    expect(formatConversationTimestamp(olderUtc, now: nowLocal), '05/10');

    final imageConv = Conversation.fromJson({
      'id': 'c-img',
      'relationshipId': 'r-img',
      'memberId': 'm-1',
      'coachId': 'c-1',
      'status': 'ACTIVE',
      'unreadCount': 1,
      'lastMessageAt': todayUtc,
      'lastMessageType': 'IMAGE',
      'lastMessageContent': null,
    });
    final emptyConv = Conversation.fromJson({
      'id': 'c-empty',
      'relationshipId': 'r-empty',
      'memberId': 'm-1',
      'coachId': 'c-2',
      'status': 'ACTIVE',
      'unreadCount': 0,
      'lastMessageAt': null,
    });
    expect(imageConv.lastMessagePreview, 'Ảnh');
    expect(emptyConv.lastMessagePreview, 'Chưa có tin nhắn');
  });

  testWidgets(
    'sorts conversations by newest message and renders previews &unread counts',
    (tester) async {
      final now = DateTime.now();
      final todayIso = DateTime(
        now.year,
        now.month,
        now.day,
        8,
        15,
      ).toUtc().toIso8601String();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayIso = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        14,
        0,
      ).toUtc().toIso8601String();

      final service = _MultiConversationFixture([
        Conversation(
          id: 'conv-empty',
          relationshipId: 'rel-empty',
          memberId: 'member-1',
          coachId: 'coach-3',
          coachName: 'Coach Chưa Nhắn',
          status: 'ACTIVE',
          unreadCount: 0,
        ),
        Conversation(
          id: 'conv-older',
          relationshipId: 'rel-older',
          memberId: 'member-1',
          coachId: 'coach-2',
          coachName: 'Coach Hôm Qua',
          status: 'ACTIVE',
          unreadCount: 0,
          lastMessageAt: yesterdayIso,
          lastMessageType: 'IMAGE',
        ),
        Conversation(
          id: 'conv-newest',
          relationshipId: 'rel-newest',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Coach Mới Nhất',
          status: 'ACTIVE',
          unreadCount: 3,
          lastMessageAt: todayIso,
          lastMessageType: 'TEXT',
          lastMessageContent: 'Lịch tập chiều nay nhé',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsPage(service: service, currentUserId: 'member-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch tập chiều nay nhé'), findsOneWidget);
      expect(find.text('Ảnh'), findsOneWidget);
      expect(find.text('Chưa có tin nhắn'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('Hôm qua'), findsOneWidget);
      expect(find.text('3 tin chưa đọc'), findsOneWidget);

      final newestTop = tester.getTopLeft(find.text('Coach Mới Nhất')).dy;
      final olderTop = tester.getTopLeft(find.text('Coach Hôm Qua')).dy;
      final emptyTop = tester.getTopLeft(find.text('Coach Chưa Nhắn')).dy;
      expect(newestTop, lessThan(olderTop));
      expect(olderTop, lessThan(emptyTop));
    },
  );

  testWidgets(
    'merges incoming message while loading history without duplicates or scroll jump, and retries failed markRead',
    (tester) async {
      final service = _ConcurrentHistoryFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsPage(service: service, currentUserId: 'member-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coach coach-1'));
      await tester.pumpAndSettle();

      // First markRead attempt failed; _lastReadId must remain unset so next sync retries.
      expect(service.markReadAttempts, 1);
      expect(service.readMessageIds, isEmpty);

      final listFinder = find.byType(ListView).last;
      await tester.dragUntilVisible(
        find.text('Tải tin cũ'),
        listFinder,
        const Offset(0, 250),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: listFinder, matching: find.byType(Scrollable)),
      );
      final offsetBeforeLoadMore = scrollable.position.pixels;
      expect(offsetBeforeLoadMore, greaterThan(0));

      // Start loading page 2 (held open by completer)
      await tester.tap(find.text('Tải tin cũ'));
      await tester.pump();
      expect(find.text('Đang tải…'), findsOneWidget);

      // While page 2 is in flight, polling fires and brings a brand new message + duplicate Tin 0
      service.includeNewIncomingOnPage1 = true;
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      // Now complete page 2 (which also contains duplicate boundary message-19 + older message)
      service.completePage2();
      await tester.pumpAndSettle();

      // Scroll offset did not jump back to 0 when older history loaded
      expect(scrollable.position.pixels, closeTo(offsetBeforeLoadMore, 1.0));
      expect(find.text('Tin cũ hơn'), findsOneWidget);

      // Mark read retried and succeeded with the new incoming message ID
      expect(service.markReadAttempts, greaterThanOrEqualTo(2));
      expect(service.readMessageIds, contains('message-new'));

      // Scroll back to bottom (offset 0) to verify newest message is at index 0 without duplicates
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Tin mới vừa đến'), findsOneWidget);
      expect(find.text('Tin 0'), findsOneWidget);
    },
  );

  testWidgets(
    'clears cached data and ignores stale responses when switching accounts on same device',
    (tester) async {
      final service = _AccountSwitchFixture();
      final userIdNotifier = ValueNotifier<String>('member-1');

      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: userIdNotifier,
          builder: (_, userId, _) => MaterialApp(
            home: ConversationsPage(service: service, currentUserId: userId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coach Tài Khoản 1'), findsOneWidget);

      // Open member-1 conversation so its messages are cached
      await tester.tap(find.text('Coach Tài Khoản 1'));
      await tester.pumpAndSettle();
      expect(find.text('Tin riêng của member-1'), findsOneWidget);

      // Hold member-1's conversation reload on pageBack in flight, then switch to member-2
      service.holdMember1Refresh = true;
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      service.activeAccount = 'member-2';
      userIdNotifier.value = 'member-2';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Complete stale member-1 response AFTER member-2 is active
      service.completeStaleMember1Refresh();
      await tester.pumpAndSettle();

      expect(find.text('Coach Tài Khoản 1'), findsNothing);
      expect(find.text('Coach Tài Khoản 2'), findsOneWidget);

      // Open member-2 thread (even with same relationshipId) and verify member-1 cache was cleared
      await tester.tap(find.text('Coach Tài Khoản 2'));
      await tester.pumpAndSettle();
      expect(find.text('Tin riêng của member-1'), findsNothing);
      expect(find.text('Tin riêng của member-2'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping image message opens fullscreen zoom viewer and closes cleanly',
    (tester) async {
      final service = _Fixture(active: true, imageHistory: true);
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsPage(
            service: service,
            currentUserId: 'member-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach coach-1'));
      await tester.pumpAndSettle();

      final tapFinder = find.byKey(const Key('chat-image-tap-media-1'));
      expect(tapFinder, findsOneWidget);

      await tester.tap(tapFinder);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.text('Chụm 2 ngón hoặc chạm đúp để phóng to'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('fullscreen-image-close-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
    },
  );

  testWidgets(
    'shows inline Vietnamese banner on 403 RECIPIENT_ACCOUNT_DISABLED while preserving readable history',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final service = _Fixture(active: true, recipientDisabled: true);
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationsPage(service: service, currentUserId: 'member-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coach coach-1'));
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn cũ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Xin chào Coach');
      await tester.tap(find.text('Gửi'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat-recipient-disabled-banner')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa',
        ),
        findsOneWidget,
      );
      // Readable history must remain intact and visible.
      expect(find.text('Tin nhắn cũ'), findsOneWidget);
      expect(find.text('Thử gửi lại'), findsNothing);

      // Composer is disabled after RECIPIENT_ACCOUNT_DISABLED.
      final callsAfterDisable = service.sendCalls;
      await tester.tap(find.text('Gửi'));
      await tester.pump();
      expect(service.sendCalls, callsAfterDisable);
      expect(tester.takeException(), isNull);
    },
  );
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
    this.recipientDisabled = false,
    this.imageHistory = false,
    this.failImageUrlOnce = false,
    this.coachName,
    this.memberName,
    this.persistSentMessages = false,
  });
  final bool failFirst;
  final bool empty;
  final bool active;
  final bool fullFirstPage;
  final bool failSendOnce;
  final bool recipientDisabled;
  final bool imageHistory;
  final bool failImageUrlOnce;
  final String? coachName;
  final String? memberName;
  final bool persistSentMessages;
  int loads = 0;
  int sendCalls = 0;
  final messagePages = <int>[];
  final readMessageIds = <String>[];
  final sentIds = <String>[];
  final persistedMessages = <ChatMessage>[];
  int uploadCalls = 0;
  int imageSends = 0;
  int imageUrlLoads = 0;
  final _pendingSend = Completer<ChatMessage>();

  @override
  Future<Conversation> startConversation({String? coachId, String? memberId}) async =>
      throw UnimplementedError();

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
    if (!persistSentMessages) {
      expect(content, 'Xin chào Coach');
    }
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
    if (recipientDisabled) {
      return Future.error(
        const ApiException(
          kind: ApiExceptionKind.forbidden,
          statusCode: 403,
          code: 'RECIPIENT_ACCOUNT_DISABLED',
          message:
              'Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa',
        ),
      );
    }
    if (persistSentMessages) {
      final msg = ChatMessage(
        id: 'sent-$sendCalls',
        senderId: 'member-1',
        messageType: 'TEXT',
        content: content,
        sentAt: '2026-10-23T08:05:00Z',
      );
      persistedMessages.insert(0, msg);
      return Future.value(msg);
    }
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
    return [
      ...persistedMessages,
      const ChatMessage(
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
        memberName: memberName,
        coachName: coachName,
        status: active ? 'ACTIVE' : 'ENDED',
        unreadCount: 2,
      ),
    ];
  }
}

class _MultiConversationFixture extends _Fixture {
  _MultiConversationFixture(this.conversations);
  final List<Conversation> conversations;

  @override
  Future<List<Conversation>> getConversations(int page) async => conversations;
}

class _ConcurrentHistoryFixture extends _Fixture {
  _ConcurrentHistoryFixture() : super(active: true, fullFirstPage: true);

  final _page2Completer = Completer<List<ChatMessage>>();
  bool includeNewIncomingOnPage1 = false;
  int markReadAttempts = 0;

  void completePage2() {
    if (!_page2Completer.isCompleted) {
      _page2Completer.complete(const [
        ChatMessage(
          id: 'message-19',
          senderId: 'coach-1',
          messageType: 'TEXT',
          content: 'Tin 19',
          sentAt: '2026-10-23T08:00:00Z',
        ),
        ChatMessage(
          id: 'old-1',
          senderId: 'coach-1',
          messageType: 'TEXT',
          content: 'Tin cũ hơn',
          sentAt: '2026-10-22T08:00:00Z',
        ),
      ]);
    }
  }

  @override
  Future<void> markRead(String relationshipId, String messageId) async {
    markReadAttempts++;
    if (markReadAttempts == 1) {
      throw StateError('temporary network failure');
    }
    readMessageIds.add(messageId);
  }

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    messagePages.add(page);
    if (page == 2) {
      return _page2Completer.future;
    }
    final base = List.generate(
      20,
      (index) => ChatMessage(
        id: 'message-$index',
        senderId: 'coach-1',
        messageType: 'TEXT',
        content: 'Tin $index',
        sentAt: '2026-10-23T08:00:00Z',
      ),
    );
    if (includeNewIncomingOnPage1) {
      return [
        const ChatMessage(
          id: 'message-new',
          senderId: 'coach-1',
          messageType: 'TEXT',
          content: 'Tin mới vừa đến',
          sentAt: '2026-10-23T08:10:00Z',
        ),
        ...base.take(19),
      ];
    }
    return base;
  }
}

class _AccountSwitchFixture extends _Fixture {
  bool holdMember1Refresh = false;
  String activeAccount = 'member-1';
  final _staleMember1Completer = Completer<List<Conversation>>();

  void completeStaleMember1Refresh() {
    if (!_staleMember1Completer.isCompleted) {
      _staleMember1Completer.complete(const [
        Conversation(
          id: 'conv-m1',
          relationshipId: 'shared-rel',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Coach Tài Khoản 1',
          status: 'ACTIVE',
          unreadCount: 1,
          lastMessageContent: 'Tin riêng của member-1',
          lastMessageType: 'TEXT',
        ),
      ]);
    }
  }

  @override
  Future<List<Conversation>> getConversations(int page) async {
    if (holdMember1Refresh && activeAccount == 'member-1') {
      holdMember1Refresh = false;
      return _staleMember1Completer.future;
    }
    if (activeAccount == 'member-2') {
      return const [
        Conversation(
          id: 'conv-m2',
          relationshipId: 'shared-rel',
          memberId: 'member-2',
          coachId: 'coach-2',
          coachName: 'Coach Tài Khoản 2',
          status: 'ACTIVE',
          unreadCount: 0,
          lastMessageContent: 'Tin riêng của member-2',
          lastMessageType: 'TEXT',
        ),
      ];
    }
    return const [
      Conversation(
        id: 'conv-m1',
        relationshipId: 'shared-rel',
        memberId: 'member-1',
        coachId: 'coach-1',
        coachName: 'Coach Tài Khoản 1',
        status: 'ACTIVE',
        unreadCount: 1,
        lastMessageContent: 'Tin riêng của member-1',
        lastMessageType: 'TEXT',
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> getMessages(String relationshipId, int page) async {
    if (activeAccount == 'member-2') {
      return const [
        ChatMessage(
          id: 'msg-m2',
          senderId: 'coach-2',
          messageType: 'TEXT',
          content: 'Tin riêng của member-2',
          sentAt: '2026-10-23T09:00:00Z',
        ),
      ];
    }
    return const [
      ChatMessage(
        id: 'msg-m1',
        senderId: 'coach-1',
        messageType: 'TEXT',
        content: 'Tin riêng của member-1',
        sentAt: '2026-10-23T08:00:00Z',
      ),
    ];
  }
}
