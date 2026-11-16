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

  testWidgets('disables booking button when remaining sessions count is 0', (
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
      adapter: _ZeroSessionsAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gói VIP 0 buổi'), findsOneWidget);
    expect(find.textContaining('Đã hết số buổi tập'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides reschedule button when relationship is PAUSED', (
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
      adapter: _PausedBookingAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    // Booking is in future, but relationship is PAUSED -> 'Đổi giờ' should NOT be shown
    expect(find.text('Đổi giờ'), findsNothing);
    // Cancellation is still allowed
    expect(find.text('Hủy buổi'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _ZeroSessionsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-0',
          'planName': 'Gói VIP 0 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 0,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [],
      '/coach-notifications' => [],
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

class _PausedBookingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-paused',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'PAUSED',
          'remainingSessions': 5,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'booking-1',
          'entitlementId': 'pack-paused',
          'coachName': 'Alex Nguyen',
          'startsAt': '2030-01-01T10:00:00.000Z',
          'endsAt': '2030-01-01T11:30:00.000Z',
          'status': 'BOOKED',
        },
      ],
      '/coach-notifications' => [],
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
