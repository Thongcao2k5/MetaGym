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
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:provider/provider.dart';

void main() {
  // Reference clock: 2026-11-23 18:02 GMT+7 (= 2026-11-23T11:02:00Z), matching 5.10 preview.
  DateTime fixedNow() => DateTime.utc(2026, 11, 23, 11, 2);

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

  group('5.10 Thông báo — Preview Sync & Warm Smoked Liquid Glass', () {
    testWidgets(
      'renders Dark & Light themes at 375px and 768px with 1.3x textScale without overflow',
      (tester) async {
        final adapter = _PreviewNotificationsAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        for (final size in const [Size(375, 812), Size(768, 1024)]) {
          for (final (theme, isDark, disableAnim) in [
            (MetaGymTheme.dark, true, false),
            (MetaGymTheme.light, false, true),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              Provider<ApiClient>.value(
                value: api,
                child: wrapScreen(
                  CoachNotificationsPage(now: fixedNow),
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
              reason:
                  '5.10 Thông báo threw at ${size.width}x${size.height} dark=$isDark',
            );

            // Preview header & sections
            expect(find.text('META GYM'), findsOneWidget);
            expect(find.text('Thông báo'), findsOneWidget);
            expect(find.text('Đọc tất cả'), findsOneWidget);
            expect(find.text('Hôm nay'), findsOneWidget);
            expect(find.text('Trước đó'), findsOneWidget);
            expect(find.text('2 chưa đọc'), findsOneWidget);

            // Preview relative & date timestamps (supports both createdAt & backend eventAt)
            expect(find.text('15 phút trước'), findsOneWidget);
            expect(find.text('2 giờ trước'), findsOneWidget);
            expect(find.text('20/11'), findsOneWidget);

            // Preview SVG icons & Warm Smoked Liquid Glass surfaces
            expect(find.byType(MetaGymBackground), findsOneWidget);
            expect(find.byType(MetaGymIcon), findsWidgets);
            expect(find.byType(MetaGymGlassCard), findsWidgets);
            expect(find.byType(MetaGymMetricPanel), findsNWidgets(2));

            // Warm Smoked Liquid Glass (Dark) vs Daylight Studio surface (Light)
            final cardFinder = find.byKey(const Key('notification-card-n-1'));
            expect(cardFinder, findsOneWidget);
            final container = tester.widget<Container>(
              find
                  .descendant(of: cardFinder, matching: find.byType(Container))
                  .first,
            );
            final decoration = container.decoration as BoxDecoration;
            if (isDark && !disableAnim) {
              expect(decoration.color, const Color(0xC42B2622));
            } else if (!isDark) {
              expect(decoration.color, const Color(0xFFFFFFFF));
            }
          }
        }
      },
    );

    testWidgets(
      'supports single mark-read, Đọc tất cả, category filters, and filtered-empty reset',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final adapter = _PreviewNotificationsAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: wrapScreen(
              CoachNotificationsPage(now: fixedNow),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 chưa đọc'), findsOneWidget);

        // Filter to Gói Coach: hides BOOKED session card, keeps nutrition & package cards
        final packagePill = find.byKey(const Key('notif-filter-package'));
        await tester.ensureVisible(packagePill);
        await tester.pumpAndSettle();
        await tester.tap(packagePill);
        await tester.pumpAndSettle();
        expect(find.text('Có lịch tập mới với Coach'), findsNothing);
        expect(find.text('Coach đã cập nhật thực đơn'), findsOneWidget);
        expect(find.text('Gói Coach đã kích hoạt'), findsOneWidget);

        // Return to Tất cả
        final allPill = find.byKey(const Key('notif-filter-all'));
        await tester.ensureVisible(allPill);
        await tester.pumpAndSettle();
        await tester.tap(allPill);
        await tester.pumpAndSettle();
        expect(find.text('Có lịch tập mới với Coach'), findsOneWidget);

        // Tap single unread notification -> marks n-1 as read
        await tester.tap(find.byKey(const Key('notification-card-n-1')));
        await tester.pumpAndSettle();
        expect(adapter.markedIds, ['n-1']);
        expect(find.text('1 chưa đọc'), findsOneWidget);

        // Tap Đọc tất cả -> marks remaining unread n-2 as read
        await tester.tap(find.byKey(const Key('notifications-mark-all-btn')));
        await tester.pumpAndSettle();
        expect(adapter.markedIds, ['n-1', 'n-2']);
        expect(
          find.byKey(const Key('notifications-unread-pill')),
          findsNothing,
        );
        expect(find.text('0'), findsOneWidget);

        // Filter to Chưa đọc (0) -> renders filtered-empty state and resets cleanly
        await tester.tap(find.byKey(const Key('notif-filter-unread')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('notifications-filtered-empty')),
          findsOneWidget,
        );
        await tester.tap(find.text('Xem tất cả'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('notification-card-n-1')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'preserves loaded notifications on refresh error and renders error/empty states in Dark & Light',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 1. Refresh error preserves loaded list
        final adapter = _PreviewNotificationsAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: wrapScreen(
              CoachNotificationsPage(now: fixedNow),
              theme: MetaGymTheme.dark,
              textScale: 1.3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        adapter.failNextGet = true;
        await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
        await tester.pumpAndSettle();
        expect(find.text('Có lịch tập mới với Coach'), findsOneWidget);
        expect(
          find.textContaining('Không thể kết nối máy chủ'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // 2. Initial error -> retry -> empty state (Light Mode 375px @ 1.3x)
        final emptyAdapter = _PreviewNotificationsAdapter(
          failFirst: true,
          empty: true,
        );
        final emptyApi = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: emptyAdapter,
        );
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: emptyApi,
            child: wrapScreen(
              CoachNotificationsPage(now: fixedNow),
              theme: MetaGymTheme.light,
              textScale: 1.3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thử lại'), findsOneWidget);
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notifications-empty-card')),
          findsOneWidget,
        );
        expect(find.text('Chưa có thông báo.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'handles missing ApiClient provider gracefully without throwing',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrapScreen(
            const CoachNotificationsPage(),
            theme: MetaGymTheme.dark,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Không tải được thông báo.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _PreviewNotificationsAdapter implements HttpClientAdapter {
  _PreviewNotificationsAdapter({this.failFirst = false, this.empty = false});

  final bool failFirst;
  final bool empty;
  bool failNextGet = false;
  int _gets = 0;
  final List<String> markedIds = [];

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'n-1',
      'kind': 'BOOKED',
      'readAt': null,
      // 15 minutes before 18:02 GMT+7 = 17:47 GMT+7 (= 10:47Z)
      'createdAt': '2026-11-23T10:47:00Z',
    },
    {
      'id': 'n-2',
      'kind': 'NUTRITION_UPDATED',
      'readAt': null,
      // Backend field name `eventAt`: 2 hours before 18:02 GMT+7 (= 09:02Z)
      'eventAt': '2026-11-23T09:02:00Z',
    },
    {
      'id': 'n-3',
      'kind': 'PACKAGE_ACTIVE',
      'readAt': '2026-11-20T05:00:00Z',
      // Earlier date: 20/11
      'eventAt': '2026-11-20T04:00:00Z',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/coach-notifications') {
      _gets++;
      if ((failFirst && _gets == 1) || failNextGet) {
        failNextGet = false;
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Offline',
        );
      }
      return _json(empty ? [] : _items);
    }

    final patchMatch = RegExp(r'^/coach-notifications/([^/]+)/read$')
        .firstMatch(options.path);
    if (options.method == 'PATCH' && patchMatch != null) {
      final id = patchMatch.group(1)!;
      markedIds.add(id);
      for (final item in _items) {
        if (item['id'] == id) {
          item['readAt'] = '2026-11-23T11:05:00Z';
          return _json(item);
        }
      }
    }

    throw StateError('Unhandled request: ${options.method} ${options.path}');
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
