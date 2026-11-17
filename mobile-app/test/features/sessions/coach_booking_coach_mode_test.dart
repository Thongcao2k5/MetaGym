import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:provider/provider.dart';

ResponseBody _jsonResponse(Object? data, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  testWidgets(
    'renders Coach booking dashboard, tabs, weekly schedule dialog, and booking actions at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _CoachBookingModeAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage(coachId: 'coach-1')),
        ),
      );
      await tester.pumpAndSettle();

      // Header & unread notification badge
      expect(find.text('Lịch Coach'), findsOneWidget);
      expect(find.byTooltip('Thông báo Coach'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Tải lại'), findsOneWidget);

      // Tabs
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Lịch tuần'), findsOneWidget);
      expect(find.text('Sắp tới'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);

      // Weekly schedule & blocked slot
      expect(find.text('Lịch làm việc hằng tuần'), findsOneWidget);
      expect(find.text('6/7 ngày'), findsOneWidget);
      expect(find.text('Cấu hình lịch tuần'), findsOneWidget);
      expect(find.text('Khóa giờ'), findsOneWidget);
      expect(find.text('Khung giờ đã khóa'), findsOneWidget);
      expect(find.text('Mở giờ'), findsOneWidget);

      // Upcoming booking card with CoachingGraphiteCard & CoachingAvatar
      expect(find.byType(CoachingGraphiteCard), findsWidgets);
      expect(find.byType(CoachingAvatar), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);

      // Open weekly schedule builder dialog and save
      await tester.tap(find.text('Cấu hình lịch tuần'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu lịch (6/6 ngày)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ca sáng sớm (07:00 – 13:00)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu lịch (6/6 ngày)'));
      await tester.pumpAndSettle();
      expect(adapter.savedDaysCount, 6);
      expect(tester.takeException(), isNull);

      // Switch to Upcoming tab and cancel upcoming booking with reason
      await tester.tap(find.text('Sắp tới'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch làm việc hằng tuần'), findsNothing);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      await tester.tap(find.text('Hủy buổi'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Coach bận lịch đột xuất',
      );
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(adapter.lastPatchAction, 'CANCEL');
      expect(adapter.lastPatchReason, 'Coach bận lịch đột xuất');
      expect(tester.takeException(), isNull);

      // Switch to History tab and mark past booking completed
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Trần Minh Bình'), findsOneWidget);
      await tester.tap(find.text('Hoàn thành'));
      await tester.pumpAndSettle();
      expect(adapter.lastPatchAction, 'COMPLETE');
      expect(tester.takeException(), isNull);
    },
  );
}

class _CoachBookingModeAdapter implements HttpClientAdapter {
  _CoachBookingModeAdapter() {
    final now = DateTime.now().toUtc();
    upcomingStartIso = now.add(const Duration(hours: 26)).toIso8601String();
    upcomingEndIso = now
        .add(const Duration(hours: 27, minutes: 30))
        .toIso8601String();
    pastStartIso = now.subtract(const Duration(hours: 4)).toIso8601String();
    pastEndIso = now
        .subtract(const Duration(hours: 2, minutes: 30))
        .toIso8601String();
    blockStartIso = now.add(const Duration(days: 2)).toIso8601String();
  }

  late final String upcomingStartIso;
  late final String upcomingEndIso;
  late final String pastStartIso;
  late final String pastEndIso;
  late final String blockStartIso;

  int? savedDaysCount;
  String? lastPatchAction;
  String? lastPatchReason;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' && options.path == '/coach/work-slots') {
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      savedDaysCount = (body['days'] as List).length;
      return _jsonResponse({'ok': true});
    }

    if (options.method == 'PATCH' &&
        options.path.startsWith('/coach-bookings/')) {
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      lastPatchAction = body['action'] as String?;
      lastPatchReason = body['reason'] as String?;
      return _jsonResponse({'ok': true});
    }

    final data = switch (options.path) {
      '/coach-bookings' => [
        {
          'id': 'b-upcoming',
          'memberName': 'Nguyễn Văn An',
          'startsAt': upcomingStartIso,
          'endsAt': upcomingEndIso,
          'status': 'BOOKED',
        },
        {
          'id': 'b-past',
          'memberName': 'Trần Minh Bình',
          'startsAt': pastStartIso,
          'endsAt': pastEndIso,
          'status': 'BOOKED',
        },
      ],
      '/coach-bookings/blocks' => [
        {'startsAt': blockStartIso, 'reason': 'Nghỉ phép chiều'},
      ],
      '/coaches/coach-1/work-slots' => {
        'configured': true,
        'days': [
          for (var wd = 1; wd <= 6; wd++)
            {
              'weekday': wd,
              'starts': ['08:00', '09:30', '11:00', '12:30'],
            },
        ],
      },
      '/coach-notifications' => [
        {'id': 'n-1', 'readAt': null},
        {'id': 'n-2', 'readAt': null},
        {'id': 'n-3', 'readAt': '2026-01-01T00:00:00Z'},
      ],
      _ => throw StateError('Unexpected path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}
