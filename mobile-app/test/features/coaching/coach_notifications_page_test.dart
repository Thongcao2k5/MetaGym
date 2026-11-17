import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'shows notification summary, marks unread as read, and handles empty/retry at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _NotificationsAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: const MaterialApp(home: CoachNotificationsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông báo Coach'), findsOneWidget);
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Tổng thông báo'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Có lịch tập mới với Coach'), findsOneWidget);
      expect(find.text('Gói Coach đã kích hoạt'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Có lịch tập mới với Coach'));
      await tester.pumpAndSettle();

      expect(adapter.markedIds, ['notif-1']);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retries notification error and renders empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adapter = _NotificationsAdapter(failFirst: true, empty: true);
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: adapter,
    );

    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: const MaterialApp(home: CoachNotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thông báo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NotificationsAdapter implements HttpClientAdapter {
  _NotificationsAdapter({this.failFirst = false, this.empty = false});

  final bool failFirst;
  final bool empty;
  int gets = 0;
  final List<String> markedIds = [];
  final List<Map<String, dynamic>> _items = [
    {
      'id': 'notif-1',
      'kind': 'BOOKED',
      'readAt': null,
      'createdAt': '2026-11-16T08:00:00Z',
    },
    {
      'id': 'notif-2',
      'kind': 'PACKAGE_ACTIVE',
      'readAt': '2026-11-16T07:00:00Z',
      'createdAt': '2026-11-16T06:00:00Z',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/coach-notifications') {
      gets++;
      if (failFirst && gets == 1) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Offline',
        );
      }
      return _json(empty ? [] : _items);
    }
    if (options.method == 'PATCH' &&
        options.path == '/coach-notifications/notif-1/read') {
      markedIds.add('notif-1');
      _items[0]['readAt'] = '2026-11-16T09:00:00Z';
      return _json(_items[0]);
    }
    throw StateError('Unhandled path: ${options.method} ${options.path}');
  }

  ResponseBody _json(Object? data) => ResponseBody.fromString(
    jsonEncode({'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
