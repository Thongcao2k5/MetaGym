import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as rtc;
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';

void main() {
  testWidgets('VOICE call uses light theme surfaces and readable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final room = await tester.runAsync(() async => rtc.Room());
    addTearDown(() async => tester.runAsync(() async => room?.dispose()));
    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _StubCallsAdapter(callType: 'VOICE', status: 'RINGING'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.light,
        home: LiveCallPage(
          api: api,
          room: room,
          currentUserId: 'member-1',
          peerName: 'Coach Demo',
          call: const CallLog(
            id: 'call-1',
            relationshipId: 'rel-1',
            callerId: 'member-1',
            receiverId: 'coach-1',
            callType: 'VOICE',
            status: 'RINGING',
            initiatedAt: '2026-11-14T07:00:00Z',
            durationSeconds: 0,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final name = tester.widget<Text>(find.text('Coach Demo'));
    expect(scaffold.backgroundColor, MetaGymColors.light.canvas);
    expect(name.style!.color, MetaGymColors.light.textPrimary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('renders VOICE call layout cleanly at 375px width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final room = await tester.runAsync(() async => rtc.Room());
    addTearDown(() async => tester.runAsync(() async => room?.dispose()));

    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _StubCallsAdapter(callType: 'VOICE', status: 'RINGING'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: LiveCallPage(
          api: api,
          room: room,
          currentUserId: 'member-1',
          peerName: 'Coach Demo',
          call: const CallLog(
            id: 'call-1',
            relationshipId: 'rel-1',
            callerId: 'member-1',
            receiverId: 'coach-1',
            callType: 'VOICE',
            status: 'RINGING',
            initiatedAt: '2026-11-14T07:00:00Z',
            durationSeconds: 0,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Cuộc gọi thoại'), findsOneWidget);
    expect(find.text('Coach Demo'), findsOneWidget);
    expect(find.text('Đang đổ chuông…'), findsOneWidget);
    expect(find.text('Tắt tiếng'), findsOneWidget);
    expect(find.text('Loa ngoài'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('renders incoming VIDEO call layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final room = await tester.runAsync(() async => rtc.Room());
    addTearDown(() async => tester.runAsync(() async => room?.dispose()));

    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _StubCallsAdapter(callType: 'VIDEO', status: 'RINGING'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: LiveCallPage(
          api: api,
          room: room,
          currentUserId: 'coach-1',
          peerName: 'Member Demo',
          call: const CallLog(
            id: 'call-2',
            relationshipId: 'rel-1',
            callerId: 'member-1',
            receiverId: 'coach-1',
            callType: 'VIDEO',
            status: 'RINGING',
            initiatedAt: '2026-11-14T07:00:00Z',
            durationSeconds: 0,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Member Demo'), findsWidgets);
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Chấp nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('renders ANSWERED VOICE call in landscape cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final room = await tester.runAsync(() async => rtc.Room());
    addTearDown(() async => tester.runAsync(() async => room?.dispose()));

    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _StubCallsAdapter(callType: 'VOICE', status: 'ANSWERED'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: LiveCallPage(
          api: api,
          room: room,
          currentUserId: 'member-1',
          peerName: 'Coach Demo',
          call: const CallLog(
            id: 'call-3',
            relationshipId: 'rel-1',
            callerId: 'member-1',
            receiverId: 'coach-1',
            callType: 'VOICE',
            status: 'ANSWERED',
            initiatedAt: '2026-11-14T07:00:00Z',
            durationSeconds: 0,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Đang tắt mic'), findsOneWidget);
    expect(find.text('Loa ngoài'), findsOneWidget);
    expect(find.text('Kết thúc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('renders finished VOICE call with duration summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final room = await tester.runAsync(() async => rtc.Room());
    addTearDown(() async => tester.runAsync(() async => room?.dispose()));

    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _StubCallsAdapter(callType: 'VOICE', status: 'ENDED'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: LiveCallPage(
          api: api,
          room: room,
          currentUserId: 'member-1',
          peerName: 'Coach Demo',
          call: const CallLog(
            id: 'call-4',
            relationshipId: 'rel-1',
            callerId: 'member-1',
            receiverId: 'coach-1',
            callType: 'VOICE',
            status: 'ENDED',
            initiatedAt: '2026-11-14T07:00:00Z',
            durationSeconds: 10,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đã kết thúc • 00:10'), findsOneWidget);
    expect(find.text('Đóng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'displays callerName on incoming call without explicit peerName',
    (tester) async {
      final room = await tester.runAsync(() async => rtc.Room());
      addTearDown(() async => tester.runAsync(() async => room?.dispose()));

      final api = CallsApi(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: _StubCallsAdapter(callType: 'VOICE', status: 'RINGING'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: LiveCallPage(
            api: api,
            room: room,
            currentUserId: 'coach-1',
            call: CallLog.fromJson({
              'id': 'call-5',
              'relationshipId': 'rel-1',
              'callerId': 'member-1',
              'receiverId': 'coach-1',
              'callerName': 'Hội viên Tuấn',
              'receiverName': 'Coach Lan',
              'callType': 'VOICE',
              'status': 'RINGING',
              'initiatedAt': '2026-11-14T07:00:00Z',
              'durationSeconds': 0,
            }),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Hội viên Tuấn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}

class _StubCallsAdapter implements HttpClientAdapter {
  _StubCallsAdapter({required this.callType, required this.status});

  final String callType;
  final String status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'id': 'call-1',
          'relationshipId': 'rel-1',
          'callerId': 'member-1',
          'receiverId': 'coach-1',
          'callType': callType,
          'status': status,
          'initiatedAt': '2026-11-14T07:00:00Z',
          'durationSeconds': status == 'ENDED' ? 10 : 0,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
