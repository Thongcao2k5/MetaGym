import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/domain/ai_message.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';

void main() {
  test('parses AI conversation owned by the current API session', () {
    final item = AiConversation.fromJson({
      'id': 'ai-1',
      'title': 'Tập luyện',
      'createdAt': '2026-10-23T08:00:00Z',
      'updatedAt': '2026-10-23T08:00:00Z',
    });
    expect(item.title, 'Tập luyện');
  });

  testWidgets('creates, renames and confirms deletion', (tester) async {
    final service = _AiFixture();
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo hội thoại'));
    await tester.pumpAndSettle();
    expect(find.text('Cuộc trò chuyện mới'), findsOneWidget);
    await tester.tap(find.byTooltip('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kế hoạch mới');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Kế hoạch mới'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa hội thoại'));
    await tester.pumpAndSettle();
    expect(service.deleted, isFalse);
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    expect(service.deleted, isTrue);
    expect(find.text('Bạn chưa có hội thoại AI nào.'), findsOneWidget);
  });

  testWidgets('shows error then empty state after retry', (tester) async {
    final service = _AiFixture(failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được hội thoại AI.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có hội thoại AI nào.'), findsOneWidget);
  });

  testWidgets('retries the AI question with one stable request ID', (
    tester,
  ) async {
    final service = _AiFixture(failAnswerOnce: true);
    service.conversation = const AiConversation(
      id: 'ai-1',
      title: 'Tập luyện',
      createdAt: '2026-10-23T08:00:00Z',
      updatedAt: '2026-10-23T08:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập luyện'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chỉ để tham khảo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tôi nên tập gì?');
    await tester.tap(find.text('Hỏi AI'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại câu hỏi'), findsOneWidget);
    await tester.tap(find.text('Thử lại câu hỏi'));
    await tester.pumpAndSettle();
    expect(service.requestIds, hasLength(2));
    expect(service.requestIds[0], service.requestIds[1]);
    expect(find.text('Tập nhẹ hôm nay.'), findsOneWidget);
  });

  testWidgets('does not present a processing reply as completed', (
    tester,
  ) async {
    final service = _AiFixture(processing: true);
    service.conversation = const AiConversation(
      id: 'ai-1',
      title: 'Tập luyện',
      createdAt: '2026-10-23T08:00:00Z',
      updatedAt: '2026-10-23T08:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập luyện'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tôi nên tập gì?');
    await tester.tap(find.text('Hỏi AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đang xử lý'), findsOneWidget);
    expect(find.text('Tập nhẹ hôm nay.'), findsNothing);
  });

  testWidgets('explains unavailable AI provider and offers retry', (
    tester,
  ) async {
    final service = _AiFixture(providerUnavailable: true);
    service.conversation = const AiConversation(
      id: 'ai-1',
      title: 'Tập luyện',
      createdAt: '2026-10-23T08:00:00Z',
      updatedAt: '2026-10-23T08:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập luyện'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tôi nên tập gì?');
    await tester.tap(find.text('Hỏi AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dịch vụ AI chưa sẵn sàng'), findsOneWidget);
    expect(find.text('Thử lại câu hỏi'), findsOneWidget);
  });

  testWidgets('uses a new request ID after backend marks the old one failed', (
    tester,
  ) async {
    final service = _AiFixture(failedResultOnce: true);
    service.conversation = const AiConversation(
      id: 'ai-1',
      title: 'Tập luyện',
      createdAt: '2026-10-23T08:00:00Z',
      updatedAt: '2026-10-23T08:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tập luyện'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tôi nên tập gì?');
    await tester.tap(find.text('Hỏi AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đã thất bại'), findsOneWidget);
    await tester.tap(find.text('Thử lại câu hỏi'));
    await tester.pumpAndSettle();
    expect(service.requestIds, hasLength(2));
    expect(service.requestIds[0], isNot(service.requestIds[1]));
    expect(find.text('Tập nhẹ hôm nay.'), findsOneWidget);
  });

  for (final isLight in [false, true]) {
    testWidgets(
      'AI Companion hero, quick prompt chip, and alternating chat bubbles render cleanly at 375x812 1.3x (${isLight ? "Light" : "Dark"})',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _AiFixture(
          presetMessages: const [
            AiMessage(
              id: 'u-1',
              role: 'USER',
              content: 'Tối nay mình tập Upper Body xong ăn thêm gì?',
              status: 'COMPLETED',
              createdAt: '2026-11-27T11:00:00Z',
            ),
            AiMessage(
              id: 'a-1',
              role: 'ASSISTANT',
              content: 'Sau tập chỉ cần thêm 20–25g đạm từ Whey hoặc ức gà.',
              status: 'COMPLETED',
              createdAt: '2026-11-27T11:01:00Z',
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: isLight ? MetaGymTheme.light : MetaGymTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: AiConversationsPage(service: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trợ lý AI'), findsOneWidget);
        expect(find.text('Meta Kong · Trợ lý AI Meta Gym'), findsOneWidget);
        expect(find.text('Tạo hội thoại'), findsOneWidget);
        expect(find.text('Gợi ý bữa phụ 25g đạm'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Gợi ý bữa phụ 25g đạm'));
        await tester.pumpAndSettle();

        expect(find.byType(AiMessagesPage), findsOneWidget);
        expect(find.text('Trợ lý AI Meta Gym'), findsNWidgets(2));
        expect(
          find.text('Tối nay mình tập Upper Body xong ăn thêm gì?'),
          findsOneWidget,
        );
        expect(
          find.text('Sau tập chỉ cần thêm 20–25g đạm từ Whey hoặc ức gà.'),
          findsOneWidget,
        );
        expect(find.text('Gợi ý bữa phụ 25g đạm'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _AiFixture implements AiService {
  _AiFixture({
    this.failFirst = false,
    this.failAnswerOnce = false,
    this.processing = false,
    this.providerUnavailable = false,
    this.failedResultOnce = false,
    this.presetMessages = const [],
  });
  final bool failFirst;
  final bool failAnswerOnce;
  final bool processing;
  final bool providerUnavailable;
  final bool failedResultOnce;
  final List<AiMessage> presetMessages;
  AiConversation? conversation;
  bool deleted = false;
  int loads = 0;
  final requestIds = <String>[];

  @override
  Future<List<AiMessage>> getMessages(String conversationId, int page) async =>
      presetMessages;

  @override
  Future<AiAnswerResult> sendQuestion(
    String conversationId,
    String content,
    String clientRequestId,
  ) async {
    requestIds.add(clientRequestId);
    if (providerUnavailable) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        statusCode: 503,
        message: 'Máy chủ đang gặp sự cố.',
      );
    }
    if (failedResultOnce && requestIds.length == 1) {
      return const AiAnswerResult(requestId: 'request-1', status: 'FAILED');
    }
    if (failAnswerOnce && requestIds.length == 1) throw StateError('offline');
    return AiAnswerResult(
      requestId: 'request-1',
      status: processing ? 'PROCESSING' : 'COMPLETED',
      reply: processing
          ? null
          : const AiReply(
              id: 'reply-1',
              content: 'Tập nhẹ hôm nay.',
              createdAt: '2026-10-23T08:02:00Z',
            ),
    );
  }

  @override
  Future<List<AiConversation>> getConversations(int page) async {
    loads++;
    if (failFirst && loads == 1) throw StateError('offline');
    return conversation == null ? [] : [conversation!];
  }

  @override
  Future<AiConversation> create() async => conversation = const AiConversation(
    id: 'ai-1',
    title: 'Cuộc trò chuyện mới',
    createdAt: '2026-10-23T08:00:00Z',
    updatedAt: '2026-10-23T08:00:00Z',
  );

  @override
  Future<AiConversation> rename(String id, String title) async =>
      conversation = AiConversation(
        id: id,
        title: title,
        createdAt: '2026-10-23T08:00:00Z',
        updatedAt: '2026-10-23T08:00:00Z',
      );

  @override
  Future<void> delete(String id) async {
    deleted = true;
    conversation = null;
  }
}
