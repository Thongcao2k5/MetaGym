import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() {
    OfflineDemoControl.mode.value = DemoUiStateMode.normal;
  });

  Future<({ApiClient client, AuthSession session})> loginAs({
    required String email,
  }) async {
    String? activeToken;
    final client = ApiClient(
      config: ApiConfig.fromValues(environment: 'local'),
      accessTokenProvider: () => activeToken,
    );
    final session = await AuthApi(client).login(
      email: email,
      password: LocalDemoAccounts.demoPassword,
    );
    activeToken = session.accessToken;
    return (client: client, session: session);
  }

  Widget wrapProviders(
    Widget child, {
    required ApiClient client,
    required ThemeData theme,
    double textScale = 1.3,
    bool disableAnimations = false,
  }) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        Provider<AiService>.value(value: AiApi(client)),
      ],
      child: MaterialApp(
        theme: theme,
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: inner!,
        ),
        home: child,
      ),
    );
  }

  Future<void> flushAsync(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> pumpViewportMatrix(
    WidgetTester tester,
    Widget Function() build, {
    required ApiClient client,
    FutureOr<void> Function(bool isDark)? verify,
  }) async {
    const viewports = <Size>[
      Size(375, 812),
      Size(768, 1024),
      Size(812, 375),
    ];
    for (final size in viewports) {
      for (final (theme, isDark, disableAnim) in [
        (MetaGymTheme.dark, true, false),
        (MetaGymTheme.light, false, true),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('$size-$isDark'),
            child: wrapProviders(
              build(),
              client: client,
              theme: theme,
              textScale: 1.3,
              disableAnimations: disableAnim,
            ),
          ),
        );
        await flushAsync(tester);
        expect(tester.takeException(), isNull);
        if (verify != null) {
          await verify(isDark);
        }
      }
    }
  }

  group('4.1 Trợ lý AI Coach Demo Data & Links', () {
    test('Coach & Member AI conversations are isolated and respond contextually', () async {
      final coachCtx = await loginAs(email: LocalDemoAccounts.coachEmail);
      final memberCtx = await loginAs(email: LocalDemoAccounts.memberEmail);

      final coachAi = AiApi(coachCtx.client);
      final coachConvs = await coachAi.getConversations(1);
      expect(coachConvs, isNotEmpty);
      expect(coachConvs.first.title, 'Tối ưu giáo án bảo vệ vai');

      final coachMsgs = await coachAi.getMessages(coachConvs.first.id, 1);
      expect(coachMsgs.length, 4);
      expect(
        coachMsgs[1].content,
        contains('Neutral-Grip Incline DB Press'),
      );

      final memberConvs = await AiApi(memberCtx.client).getConversations(1);
      expect(memberConvs.first.title, 'Tối ưu lịch tập Tăng Cơ 8 Tuần');

      final answer = await coachAi.sendQuestion(
        coachConvs.first.id,
        'Lịch Deload tuần 5',
        'coach-req-deload',
      );
      expect(answer.isComplete, isTrue);
      expect(answer.reply!.content, contains('Lịch Deload Tuần 5'));
    });
  });

  group('4.1 Trợ lý AI Coach UI Sync & Responsive Audit', () {
    testWidgets('renders 4.1 Trợ lý AI Coach across Dark/Light and 3 viewports at 1.3x without refresh button', (
      tester,
    ) async {
      final coachCtx = (await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      ))!;

      await pumpViewportMatrix(
        tester,
        () => const AiConversationsPage(
          coachMode: true,
          bottomPadding: 110,
        ),
        client: coachCtx.client,
        verify: (_) async {
          expect(find.byType(AiMessagesView), findsOneWidget);
          expect(find.text('META GYM · COACH'), findsOneWidget);
          expect(find.text('Tối ưu giáo án bảo vệ vai'), findsOneWidget);
          expect(find.text('Meta Kong · Trợ lý Huấn luyện AI'), findsOneWidget);
          expect(find.text('Bài thay thế vai yếu'), findsOneWidget);
          expect(find.text('Lịch Deload tuần 5'), findsOneWidget);
          expect(find.text('Gợi ý thực đơn 2.200 kcal'), findsOneWidget);
          expect(find.byTooltip('Hội thoại AI mới'), findsOneWidget);
          expect(find.byTooltip('Hỏi AI'), findsOneWidget);
          expect(find.byTooltip('Tải lại'), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsNothing);
          final list = find.descendant(
            of: find.byType(AiMessagesView),
            matching: find.byType(ListView),
          );
          await tester.dragUntilVisible(
            find.text('Trợ lý AI Coach'),
            list,
            const Offset(0, -150),
          );
          expect(find.text('Trợ lý AI Coach'), findsWidgets);
        },
      );
    });

    testWidgets('Coach can insert suggestion chip, send prompt, and create a new AI conversation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final coachCtx = (await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      ))!;

      await tester.pumpWidget(
        wrapProviders(
          const AiConversationsPage(coachMode: true),
          client: coachCtx.client,
          theme: MetaGymTheme.dark,
        ),
      );
      await flushAsync(tester);

      // Chạm gợi ý "Lịch Deload tuần 5" và gửi
      await tester.ensureVisible(find.text('Lịch Deload tuần 5'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Lịch Deload tuần 5'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Hỏi AI'));
      await flushAsync(tester);
      final chatList = find.descendant(
        of: find.byType(AiMessagesView),
        matching: find.byType(ListView),
      );
      await tester.dragUntilVisible(
        find.textContaining('Lịch Deload Tuần 5', findRichText: true),
        chatList,
        const Offset(0, -180),
      );
      expect(
        find.textContaining('Lịch Deload Tuần 5', findRichText: true),
        findsOneWidget,
      );

      // Bấm nút + trên header để tạo hội thoại AI mới
      await tester.tap(find.byTooltip('Hội thoại AI mới'));
      await flushAsync(tester);
      expect(find.text('Tư vấn giáo án Coach'), findsOneWidget);

      // Bấm vào tiêu đề để mở danh sách chuyển/sửa/xóa hội thoại
      await tester.tap(find.text('Tư vấn giáo án Coach'));
      await flushAsync(tester);
      expect(find.text('Hội thoại AI Coach'), findsOneWidget);
      expect(find.text('Tối ưu giáo án bảo vệ vai'), findsOneWidget);
    });
  });
}
