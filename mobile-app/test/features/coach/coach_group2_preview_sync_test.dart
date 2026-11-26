import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:provider/provider.dart';

void main() {
  DateTime fixedNow() => DateTime.utc(2026, 11, 26, 8, 2);

  Widget wrapScreen(
    Widget child, {
    required ThemeData theme,
    double textScale = 1.3,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: theme,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: inner!,
      ),
      home: child,
    );
  }

  Future<void> pumpViewportMatrix(
    WidgetTester tester,
    Widget Function() build, {
    required String label,
    FutureOr<void> Function(bool isDark)? verifyPerViewport,
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
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('$label-${size.width}x${size.height}-$isDark'),
            child: wrapScreen(
              build(),
              theme: theme,
              textScale: 1.3,
              disableAnimations: disableAnim,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '$label threw at ${size.width}x${size.height} dark=$isDark',
        );
        expect(find.byType(MetaGymBackground), findsWidgets);
        expect(find.byType(MetaGymIcon), findsWidgets);
        await verifyPerViewport?.call(isDark);
        expect(
          tester.takeException(),
          isNull,
          reason:
              '$label threw after scroll at ${size.width}x${size.height} dark=$isDark',
        );
      }
    }
  }

  group('Coach Group 1.4 & Group 2 (2.1 - 2.4) Full Sync & Dark/Light', () {
    testWidgets(
      '1.4 CoachNotificationsPage (Coach) shows Tổng tuần này and handles Dark/Light matrix',
      (tester) async {
        final adapter = _Group2CoachApiAdapter(nowUtc: fixedNow());
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => Provider<ApiClient>.value(
            value: api,
            child: CoachNotificationsPage(coachMode: true, now: fixedNow),
          ),
          label: '1.4 CoachNotificationsPage',
          verifyPerViewport: (isDark) {
            expect(find.text('META GYM · COACH'), findsOneWidget);
            expect(find.text('Thông báo'), findsOneWidget);
            expect(find.text('Tổng tuần này'), findsOneWidget);
            expect(find.text('Lịch dạy'), findsOneWidget);
            expect(find.text('Học viên'), findsOneWidget);
          },
        );
      },
    );

    testWidgets(
      '2.1 CoachSessionsPage renders 4 status tabs, Dark/Light matrix, check-in actions & navigates 2.2/2.3/2.4',
      (tester) async {
        final adapter = _Group2CoachApiAdapter(nowUtc: fixedNow());
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => Provider<ApiClient>.value(
            value: api,
            child: CoachSessionsPage(
              apiClient: api,
              coachId: 'coach-1',
              now: fixedNow,
            ),
          ),
          label: '2.1 CoachSessionsPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('META GYM · COACH'), findsOneWidget);
            expect(find.text('Lịch dạy'), findsOneWidget);
            expect(find.text('Hôm nay'), findsOneWidget);
            expect(find.text('Sắp tới'), findsOneWidget);
            expect(find.text('Đã xong'), findsOneWidget);
            expect(find.text('Đã hủy'), findsOneWidget);
            expect(find.text('Lịch làm việc hằng tuần'), findsOneWidget);
            expect(find.text('6/7 ngày'), findsOneWidget);

            await tester.scrollUntilVisible(
              find.text('Nguyễn Minh Quân'),
              140,
            );
            await tester.pumpAndSettle();
            expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          },
        );

        // Full interactive transitions at 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: wrapScreen(
              CoachSessionsPage(
                apiClient: api,
                coachId: 'coach-1',
                now: fixedNow,
              ),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tab 2: Sắp tới
        await tester.tap(find.byKey(const Key('sessions-tab-upcoming')));
        await tester.pumpAndSettle();
        expect(find.text('Phạm Quốc Bảo'), findsOneWidget);

        // Tab 3: Đã xong
        await tester.tap(find.byKey(const Key('sessions-tab-done')));
        await tester.pumpAndSettle();
        expect(find.text('Trần Thảo Vy'), findsOneWidget);

        // Tab 4: Đã hủy
        await tester.tap(find.byKey(const Key('sessions-tab-cancelled')));
        await tester.pumpAndSettle();
        expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
        expect(find.text('Hội viên vắng'), findsOneWidget);

        // Back to Hôm nay -> Hoàn thành ca
        await tester.tap(find.byKey(const Key('sessions-tab-today')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('session-action-complete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(adapter.lastPatchAction, 'COMPLETE');

        // Push 2.2 WorkWeek via Lịch tuần button
        await tester.tap(find.byKey(const Key('sessions-open-workweek-btn')));
        await tester.pumpAndSettle();
        expect(find.byType(CoachWorkWeekPage), findsOneWidget);
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();

        // Push 2.3 BlockedSlots via Chặn khung giờ button
        await tester.tap(find.byKey(const Key('sessions-open-blocks-btn')));
        await tester.pumpAndSettle();
        expect(find.byType(CoachBlockedSlotsPage), findsOneWidget);
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();

        // Push 2.4 BookingHistory via header Lịch sử buổi dạy
        await tester.tap(find.byTooltip('Lịch sử buổi dạy'));
        await tester.pumpAndSettle();
        expect(find.byType(CoachBookingHistoryPage), findsOneWidget);
        expect(find.text('Lịch sử buổi dạy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '2.2 CoachWorkWeekPage validates rules, applies presets, toggles day & handles 409 safely',
      (tester) async {
        final adapter = _Group2CoachApiAdapter(nowUtc: fixedNow());
        final realApi = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => CoachWorkWeekPage(
            apiClient: realApi,
            coachId: 'coach-1',
            hasActiveMembers: true,
          ),
          label: '2.2 CoachWorkWeekPage',
          verifyPerViewport: (isDark) {
            expect(find.text('THIẾT LẬP LỊCH DẠY'), findsOneWidget);
            expect(find.text('Lịch làm việc tuần'), findsOneWidget);
            expect(find.text('Quy chuẩn lịch Coach'), findsOneWidget);
            expect(find.text('6 / 7 ngày'), findsOneWidget);
          },
        );

        // Save interaction & 409 recovery
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          wrapScreen(
            CoachWorkWeekPage(
              apiClient: realApi,
              coachId: 'coach-1',
              hasActiveMembers: true,
            ),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        // Toggle Chủ nhật ON -> scroll back to hero to assert 7 / 7 ngày
        final sundayToggle = find.byKey(const Key('workweek-toggle-7'));
        await tester.ensureVisible(sundayToggle);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -180));
        await tester.pumpAndSettle();
        await tester.tap(sundayToggle);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 900));
        await tester.pumpAndSettle();
        expect(find.text('7 / 7 ngày'), findsOneWidget);

        // Save hits PUT /coach/work-slots
        await tester.tap(find.byKey(const Key('workweek-save-btn')));
        await tester.pumpAndSettle();
        expect(adapter.savedWorkSlotDaysCount, 7);

        // Wait for the floating success SnackBar to auto-dismiss before tapping Save again
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Simulate backend 409 error
        adapter.rejectWorkSlots409 = true;
        await tester.tap(find.byKey(const Key('workweek-save-btn')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Đang có học viên hiệu lực'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2.3 CoachBlockedSlotsPage locks and unlocks 90-minute slots across Dark/Light matrix',
      (tester) async {
        final adapter = _Group2CoachApiAdapter(nowUtc: fixedNow());
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => CoachBlockedSlotsPage(apiClient: api, coachId: 'coach-1'),
          label: '2.3 CoachBlockedSlotsPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('KHÓA LỊCH CÁ NHÂN'), findsOneWidget);
            expect(find.text('Chặn khung giờ bận'), findsOneWidget);
            expect(find.text('Khóa 1 ca 90 phút bận cá nhân'), findsOneWidget);
            final blockedSection = find.text('Các ca 90 phút đang khóa');
            final listScrollable = find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            );
            await tester.scrollUntilVisible(
              blockedSection,
              180,
              scrollable: listScrollable,
            );
            await tester.pumpAndSettle();
            expect(blockedSection, findsOneWidget);
          },
        );

        // Interactive lock + unlock
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          wrapScreen(
            CoachBlockedSlotsPage(apiClient: api, coachId: 'coach-1'),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('blocked-slot-reason')),
          'Đào tạo nội bộ Coach',
        );
        final listScrollable = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        final blockSubmit = find.byKey(const Key('blocked-slot-submit'));
        await tester.scrollUntilVisible(
          blockSubmit,
          140,
          scrollable: listScrollable,
        );
        await tester.ensureVisible(blockSubmit);
        await tester.pumpAndSettle();
        await tester.tap(blockSubmit);
        await tester.pumpAndSettle();
        expect(adapter.lastBlockRequest?['blocked'], isTrue);
        expect(adapter.lastBlockRequest?['reason'], 'Đào tạo nội bộ Coach');

        final blockDelete0 = find.byKey(const Key('blocked-slot-delete-0'));
        await tester.scrollUntilVisible(
          blockDelete0,
          140,
          scrollable: listScrollable,
        );
        await tester.ensureVisible(blockDelete0);
        await tester.pumpAndSettle();
        await tester.tap(blockDelete0);
        await tester.pumpAndSettle();
        expect(adapter.lastBlockRequest?['blocked'], isFalse);
      },
    );

    testWidgets(
      '2.4 CoachBookingHistoryPage (coachMode: true) renders KPI rate, filters & month groups across Dark/Light',
      (tester) async {
        await pumpViewportMatrix(
          tester,
          () => const CoachBookingHistoryPage(
            coachMode: true,
            previewMode: true,
          ),
          label: '2.4 CoachBookingHistoryPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('THỐNG KÊ GIẢNG DẠY'), findsOneWidget);
            expect(find.text('Lịch sử buổi dạy'), findsOneWidget);
            expect(find.text('Tổng hợp chuyên cần'), findsOneWidget);
            expect(find.text('50% hoàn thành'), findsOneWidget);
            expect(find.text('Đã hoàn thành'), findsOneWidget);
            expect(find.text('Đã hủy / HV vắng'), findsOneWidget);

            await tester.scrollUntilVisible(
              find.text('Nguyễn Minh Quân'),
              140,
            );
            await tester.pumpAndSettle();
            expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          },
        );

        // Filter tabs at 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          wrapScreen(
            const CoachBookingHistoryPage(coachMode: true, previewMode: true),
            theme: MetaGymTheme.light,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('history-filter-absent')));
        await tester.pumpAndSettle();
        expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
        expect(find.text('Nguyễn Minh Quân'), findsNothing);

        await tester.tap(find.byKey(const Key('history-filter-cancelled')));
        await tester.pumpAndSettle();
        expect(find.text('Phạm Quốc Bảo'), findsOneWidget);
        expect(find.text('Đỗ Khánh Linh'), findsNothing);

        await tester.tap(find.byKey(const Key('history-filter-completed')));
        await tester.pumpAndSettle();
        expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
        expect(find.text('Trần Thảo Vy'), findsOneWidget);
      },
    );
  });
}

class _Group2CoachApiAdapter implements HttpClientAdapter {
  _Group2CoachApiAdapter({required this.nowUtc});

  final DateTime nowUtc;
  String? lastPatchAction;
  int? savedWorkSlotDaysCount;
  bool rejectWorkSlots409 = false;
  Map<String, dynamic>? lastBlockRequest;

  late final List<Map<String, dynamic>> _blocks = [
    {
      'startsAt': nowUtc.add(const Duration(days: 2)).toIso8601String(),
      'reason': 'Họp chuyên môn nội bộ',
    },
  ];

  late final List<Map<String, dynamic>> _days = [
    for (var wd = 1; wd <= 6; wd++)
      {
        'weekday': wd,
        'starts': ['06:00', '09:00', '14:00', '18:00'],
      },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH' &&
        options.path.startsWith('/coach-bookings/')) {
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      lastPatchAction = body['action'] as String?;
      return _json({'ok': true});
    }

    if (options.method == 'PUT' && options.path == '/coach/work-slots') {
      if (rejectWorkSlots409) {
        return ResponseBody.fromString(
          jsonEncode({
            'error': {
              'code': 'WORK_SLOTS_CONFLICT',
              'message':
                  'Đang có học viên hiệu lực nên chưa thể thay đổi lịch tuần (409).',
            },
          }),
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      final days = (body['days'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      savedWorkSlotDaysCount = days.length;
      _days
        ..clear()
        ..addAll(days);
      return _json({'ok': true});
    }

    if (options.method == 'PUT' && options.path == '/coach-bookings/blocks') {
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      lastBlockRequest = body;
      final startsAt = body['startsAt'] as String;
      if (body['blocked'] == true) {
        _blocks.insert(0, {
          'startsAt': startsAt,
          'reason': body['reason'] ?? 'Khóa lịch',
        });
      } else {
        _blocks.removeWhere((b) => b['startsAt'] == startsAt);
      }
      return _json({'ok': true});
    }

    final gymNow = nowUtc.add(const Duration(hours: 7));
    DateTime atGym(int deltaDays, int h, int m) =>
        DateTime.utc(gymNow.year, gymNow.month, gymNow.day, h, m)
            .add(Duration(days: deltaDays))
            .subtract(const Duration(hours: 7));

    final data = switch (options.path) {
      '/coach-notifications' => [
        {
          'id': 'n-1',
          'kind': 'BOOKED',
          'readAt': null,
          'createdAt': nowUtc
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
        },
        {
          'id': 'n-2',
          'kind': 'TERMINATION_REQUESTED',
          'readAt': null,
          'createdAt': nowUtc
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'id': 'n-3',
          'kind': 'PACKAGE_ACTIVE',
          'readAt': nowUtc.subtract(const Duration(days: 1)).toIso8601String(),
          'createdAt': nowUtc
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'b-1',
          'memberId': 'm-1',
          'memberName': 'Nguyễn Minh Quân',
          'startsAt': atGym(0, 18, 0).toIso8601String(),
          'endsAt': atGym(0, 19, 30).toIso8601String(),
          'status': 'BOOKED',
        },
        {
          'id': 'b-2',
          'memberId': 'm-3',
          'memberName': 'Phạm Quốc Bảo',
          'startsAt': atGym(1, 7, 30).toIso8601String(),
          'endsAt': atGym(1, 9, 0).toIso8601String(),
          'status': 'BOOKED',
        },
        {
          'id': 'b-3',
          'memberId': 'm-2',
          'memberName': 'Trần Thảo Vy',
          'startsAt': atGym(-1, 19, 45).toIso8601String(),
          'endsAt': atGym(-1, 21, 15).toIso8601String(),
          'status': 'COMPLETED',
        },
        {
          'id': 'b-4',
          'memberId': 'm-4',
          'memberName': 'Đỗ Khánh Linh',
          'startsAt': atGym(-2, 17, 0).toIso8601String(),
          'endsAt': atGym(-2, 18, 30).toIso8601String(),
          'status': 'NO_SHOW',
        },
      ],
      '/coaches/coach-1/work-slots' => {
        'configured': true,
        'days': _days,
      },
      '/coach-bookings/blocks' => _blocks,
      _ => throw StateError('Unexpected path: ${options.path}'),
    };
    return _json(data);
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
