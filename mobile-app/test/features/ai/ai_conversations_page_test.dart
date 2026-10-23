import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';

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
}

class _AiFixture implements AiService {
  _AiFixture({this.failFirst = false});
  final bool failFirst;
  AiConversation? conversation;
  bool deleted = false;
  int loads = 0;

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
