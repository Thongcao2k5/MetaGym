import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows a paused package and keeps booking access disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _BookingAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gói 10 buổi'), findsOneWidget);
    expect(find.textContaining('Tạm dừng'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Thông báo Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Gói Coach còn tối đa 7 ngày'), findsOneWidget);
  });
}

class _BookingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'PAUSED',
          'remainingSessions': 8,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [],
      '/coach-notifications' => [
        {'id': '1', 'kind': 'PACKAGE_EXPIRING'},
      ],
      _ => throw StateError('Path: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
