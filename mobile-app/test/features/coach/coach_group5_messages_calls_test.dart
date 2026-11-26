import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as rtc;
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(() {
    ConversationsPage.clearSessionCache();
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
        Provider<MessagingService>.value(value: MessagingApi(client)),
        Provider<CallsService>.value(value: CallsApi(client)),
        Provider<CoachMembersService>.value(value: CoachMembersApi(client)),
        Provider<CoachTrainingService>.value(value: CoachTrainingApi(client)),
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
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pump(const Duration(milliseconds: 60));
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

  group('Coach Group 5 Demo Data & Links', () {
    test('Coach & Member demo inboxes stay isolated and multi-student calls route correctly', () async {
      final coachCtx = await loginAs(email: LocalDemoAccounts.coachEmail);
      final memberCtx = await loginAs(email: LocalDemoAccounts.memberEmail);

      final coachConvs = await MessagingApi(coachCtx.client).getConversations(1);
      expect(coachConvs.length, 2);
      expect(
        coachConvs.map((c) => c.memberName),
        containsAll(['Nguyễn Minh Quân', 'Trần Bảo Ngọc']),
      );

      final memberConvs = await MessagingApi(memberCtx.client).getConversations(1);
      expect(memberConvs.length, 1);
      expect(memberConvs.first.coachName, 'Lê Hoàng Nam');

      final sent = await MessagingApi(coachCtx.client).sendText(
        'rel-demo-002',
        'Ngày mai giữ tạ nhẹ hơn 2kg nhé Ngọc.',
        'cmsg-demo-1',
      );
      expect(sent.senderId, coachCtx.session.user.id);
      final msgs = await MessagingApi(coachCtx.client).getMessages('rel-demo-002', 1);
      expect(msgs.any((m) => (m.content ?? '').contains('Trần Bảo Ngọc')), isTrue);

      final coachCalls = await CallsApi(coachCtx.client).getCalls(1);
      expect(coachCalls.length, 3);
      expect(coachCalls.any((c) => c.status == 'MISSED'), isTrue);
      expect(coachCalls.any((c) => c.callType == 'VOICE'), isTrue);
      expect(coachCalls.any((c) => c.callType == 'VIDEO'), isTrue);

      final createdCall = await CallsApi(coachCtx.client).createLiveCall(
        'rel-demo-002',
        'VIDEO',
      );
      expect(createdCall.receiverName, 'Trần Bảo Ngọc');
      final access = await CallsApi(coachCtx.client).getRoomAccess(createdCall.id);
      expect(access.token, 'local-demo-livekit-token');
    });
  });

  group('Coach Group 5 UI Preview Sync & Responsive Audit', () {
    testWidgets('5.1 Coach Conversations renders in Dark/Light across viewports without refresh button', (
      tester,
    ) async {
      final coachCtx = (await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      ))!;

      await pumpViewportMatrix(
        tester,
        () => ConversationsPage(
          currentUserId: coachCtx.session.user.id,
          coachMode: true,
        ),
        client: coachCtx.client,
        verify: (_) {
          expect(find.text('META GYM · COACH'), findsOneWidget);
          expect(find.text('Tin nhắn'), findsOneWidget);
          expect(find.byTooltip('Cuộc gọi 1:1'), findsOneWidget);
          expect(find.byTooltip('Tìm kiếm cuộc trò chuyện'), findsOneWidget);
          expect(find.byTooltip('Tải lại'), findsNothing);
          expect(find.byIcon(Icons.refresh_rounded), findsNothing);
          expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          expect(find.text('Trần Bảo Ngọc'), findsOneWidget);
          expect(find.text('Học viên (2)'), findsOneWidget);
          expect(find.text('Quản trị'), findsOneWidget);
        },
      );
    });

    testWidgets('5.1 header Cuộc gọi 1:1 links to CallsPage and tapping student opens ConversationDetailPage & MemberProfile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final coachCtx = await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      );

      await tester.pumpWidget(
        wrapProviders(
          ConversationsPage(
            currentUserId: coachCtx!.session.user.id,
            coachMode: true,
          ),
          client: coachCtx.client,
          theme: MetaGymTheme.dark,
        ),
      );
      await flushAsync(tester);

      // 5.1 -> 5.3 Cuộc gọi 1:1
      await tester.tap(find.byTooltip('Cuộc gọi 1:1'));
      await flushAsync(tester);
      expect(find.byType(CallsPage), findsOneWidget);
      expect(find.text('Cuộc gọi 1:1'), findsOneWidget);
      expect(find.byTooltip('Tải lại'), findsNothing);

      // Quay lại 5.1
      await tester.tap(find.byTooltip('Quay lại'));
      await flushAsync(tester);
      expect(find.text('Nguyễn Minh Quân'), findsOneWidget);

      // 5.1 -> 5.2 Chi tiết tin nhắn (Coach ↔ HV)
      await tester.tap(find.text('Nguyễn Minh Quân'));
      await flushAsync(tester);
      expect(find.byType(ConversationDetailPage), findsOneWidget);
      expect(find.byTooltip('Gọi thoại'), findsOneWidget);
      expect(find.byTooltip('Gọi video'), findsOneWidget);
      expect(find.text('Nhận xét form tập'), findsOneWidget);

      // Cuộn lên đầu hội thoại để thấy thẻ ngữ cảnh & nút tắt Giáo trình / Hồ sơ HV
      final chatList = find.descendant(
        of: find.byType(ConversationDetailPage),
        matching: find.byType(ListView),
      );
      await tester.drag(chatList, const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Hồ sơ HV'), findsOneWidget);
      expect(find.text('Giáo trình'), findsOneWidget);

      // 5.2 -> Hồ sơ HV
      await tester.tap(find.text('Hồ sơ HV'));
      await flushAsync(tester);
      expect(find.byType(CoachMemberDetailPage), findsOneWidget);
    });

    testWidgets('5.2 ConversationDetailPage adapts Dark/Light across viewports at 1.3x', (
      tester,
    ) async {
      final setup = await tester.runAsync(() async {
        final ctx = await loginAs(email: LocalDemoAccounts.coachEmail);
        final convs = await MessagingApi(ctx.client).getConversations(1);
        return (ctx: ctx, target: convs.first);
      });
      final coachCtx = setup!.ctx;
      final target = setup.target;

      await pumpViewportMatrix(
        tester,
        () => ConversationDetailPage(
          conversation: target,
          service: MessagingApi(coachCtx.client),
          currentUserId: coachCtx.session.user.id,
          picker: DeviceProgressPhotoPicker(),
          coachMode: true,
        ),
        client: coachCtx.client,
        verify: (_) {
          expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          expect(find.text('Đang hoạt động'), findsOneWidget);
          expect(find.text('Gửi'), findsOneWidget);
        },
      );
    });

    testWidgets('5.3 Coach CallsView renders Dark/Light, filters calls, and opens chat detail', (
      tester,
    ) async {
      final coachCtx = (await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      ))!;

      await pumpViewportMatrix(
        tester,
        () => CallsPage(
          currentUserId: coachCtx.session.user.id,
          coachMode: true,
        ),
        client: coachCtx.client,
        verify: (_) {
          expect(find.text('META GYM · CALLS'), findsOneWidget);
          expect(find.text('Cuộc gọi 1:1'), findsOneWidget);
          expect(find.text('TỔNG QUAN LIÊN LẠC'), findsOneWidget);
          expect(find.text('Cuộc gọi tuần này'), findsOneWidget);
          expect(find.text('Cuộc gọi nhỡ'), findsWidgets);
          expect(find.byTooltip('Tải lại'), findsNothing);
        },
      );

      // Interactive filter + open chat link check at 375x812
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        wrapProviders(
          CallsPage(
            currentUserId: coachCtx.session.user.id,
            coachMode: true,
          ),
          client: coachCtx.client,
          theme: MetaGymTheme.light,
        ),
      );
      await flushAsync(tester);

      await tester.ensureVisible(find.text('Gọi nhỡ').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Gọi nhỡ').first);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Không bắt máy'), findsOneWidget);

      await tester.ensureVisible(find.text('Mở tin nhắn').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Mở tin nhắn').first);
      await flushAsync(tester);
      expect(find.byType(ConversationDetailPage), findsOneWidget);
    });

    testWidgets('LiveCallPage VOICE and VIDEO screens render cleanly at 375x812 and 812x375 at 1.3x', (
      tester,
    ) async {
      final coachCtx = await tester.runAsync(
        () => loginAs(email: LocalDemoAccounts.coachEmail),
      );
      final api = CallsApi(coachCtx!.client);

      for (final (size, theme, callType, status) in [
        (const Size(375, 812), MetaGymTheme.dark, 'VOICE', 'RINGING'),
        (const Size(375, 812), MetaGymTheme.light, 'VIDEO', 'ANSWERED'),
        (const Size(812, 375), MetaGymTheme.dark, 'VOICE', 'ENDED'),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final room = await tester.runAsync(() async => rtc.Room());
        addTearDown(() async => tester.runAsync(() async => room?.dispose()));

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: LiveCallPage(
              api: api,
              room: room,
              currentUserId: coachCtx.session.user.id,
              peerName: 'Trần Bảo Ngọc',
              call: CallLog(
                id: 'call-demo-002',
                relationshipId: 'rel-demo-002',
                callerId: coachCtx.session.user.id,
                receiverId: '10000000-0000-4000-8000-000000000004',
                callerName: 'Lê Hoàng Nam',
                receiverName: 'Trần Bảo Ngọc',
                callType: callType,
                status: status,
                initiatedAt: '2026-11-26T10:00:00Z',
                durationSeconds: status == 'ENDED' ? 416 : 0,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.text('Trần Bảo Ngọc'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      }
    });
  });
}
