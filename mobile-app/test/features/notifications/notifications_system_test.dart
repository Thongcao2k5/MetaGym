import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/notifications/data/fcm_push_service.dart';
import 'package:meta_gym_app/features/notifications/data/local_notification_service.dart';
import 'package:meta_gym_app/features/notifications/data/notifications_api.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';
import 'package:meta_gym_app/features/notifications/presentation/in_app_notification_listener.dart';
import 'package:meta_gym_app/features/notifications/presentation/notification_router.dart';
import 'package:meta_gym_app/features/notifications/presentation/notifications_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_secondary_pages.dart';
import 'package:provider/provider.dart';

void main() {
  test('resolveNotificationRoute maps kinds and role-specific routes', () {
    const training = AppNotification(
      id: '1',
      kind: 'TRAINING_PLAN_UPDATED',
      category: NotificationCategory.training,
      actionRoute: '/member/features/training',
    );
    expect(
      resolveNotificationRoute(training, UserRole.member),
      '/member/features/training',
    );
    expect(
      resolveNotificationRoute(training, UserRole.coach),
      '/coach/features/training',
    );

    const booked = AppNotification(
      id: '2',
      kind: 'BOOKED',
      category: NotificationCategory.coach,
    );
    expect(
      resolveNotificationRoute(booked, UserRole.member),
      '/member/features/sessions',
    );
    expect(
      resolveNotificationRoute(booked, UserRole.coach),
      '/coach/features/sessions',
    );

    const broadcastNoRoute = AppNotification(
      id: '3',
      kind: 'ADMIN_BROADCAST',
      category: NotificationCategory.system,
      title: 'Thông báo chung',
      body: 'Bảo trì 23:00',
    );
    expect(resolveNotificationRoute(broadcastNoRoute, UserRole.member), isNull);
  });

  test(
    'NotificationsController loads feed, marks read/all, updates preferences, and syncs local reminders',
    () async {
      final adapter = _FakeNotificationsAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final session = await _createAuthenticatedSession();
      final localSpy = _SpyLocalNotificationService();
      final fcmSpy = _SpyFcmPushService();
      final controller = NotificationsController(
        api: NotificationsApi(api),
        session: session,
        localNotifications: localSpy,
        fcmPush: fcmSpy,
      );
      addTearDown(controller.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.items.length, 3);
      expect(controller.unreadCount, 2);
      expect(fcmSpy.synced, isTrue);
      expect(localSpy.dailySyncCount, greaterThanOrEqualTo(1));

      await controller.markRead('10');
      expect(controller.unreadCount, 1);
      expect(adapter.markedIds, contains('10'));

      final saved = await controller.updatePreferences(
        controller.preferences.copyWith(
          reminderTime: '18:00',
          ptBeforeMinutes: 15,
          messagesEnabled: false,
        ),
      );
      expect(saved, isTrue);
      expect(adapter.lastSavedPrefs?['reminderTime'], '18:00');
      expect(adapter.lastSavedPrefs?['ptBeforeMinutes'], 15);
      expect(localSpy.lastSyncedPrefs?.reminderTime, '18:00');

      await controller.syncUpcomingBookings([
        {
          'status': 'BOOKED',
          'startsAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .toIso8601String(),
          'coachName': 'Lê Hoàng Nam',
        },
      ]);
      expect(localSpy.lastBookingBeforeMinutes, 15);

      await controller.markAllRead();
      expect(controller.unreadCount, 0);
      expect(adapter.markedAllCount, 1);
    },
  );

  testWidgets(
    'CoachNotificationsPage integrates with NotificationsController, filters all categories, and routes on tap',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _FakeNotificationsAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final session = await _createAuthenticatedSession();
      final controller = NotificationsController(
        api: NotificationsApi(api),
        session: session,
        localNotifications: const NoopLocalNotificationService(),
        fcmPush: const NoopFcmPushService(),
      );
      addTearDown(controller.dispose);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final pushedRoutes = <String>[];
      final router = GoRouter(
        initialLocation: '/notifs',
        routes: [
          GoRoute(
            path: '/notifs',
            builder: (_, _) => const CoachNotificationsPage(),
          ),
          GoRoute(
            path: '/member/features/training',
            builder: (_, _) {
              pushedRoutes.add('/member/features/training');
              return const Scaffold(body: Text('Training Screen'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<NotificationsController>.value(
              value: controller,
            ),
          ],
          child: MaterialApp.router(
            theme: MetaGymTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tất cả cập nhật & nhắc lịch'), findsOneWidget);
      expect(find.byKey(const Key('notif-filter-training')), findsOneWidget);
      expect(find.byKey(const Key('notif-filter-message')), findsOneWidget);
      expect(find.byKey(const Key('notif-filter-system')), findsOneWidget);

      final trainingPill = find.byKey(const Key('notif-filter-training'));
      await tester.ensureVisible(trainingPill);
      await tester.pumpAndSettle();
      await tester.tap(trainingPill);
      await tester.pumpAndSettle();
      expect(find.text('Giáo trình tuần mới'), findsOneWidget);
      expect(find.text('Có lịch tập mới với Coach'), findsNothing);

      await tester.tap(find.text('Giáo trình tuần mới'));
      await tester.pumpAndSettle();

      expect(adapter.markedIds, contains('11'));
      expect(pushedRoutes, ['/member/features/training']);
      expect(find.text('Training Screen'), findsOneWidget);
    },
  );

  testWidgets(
    'AppSettingsDetailPage persists detailed notification preferences through NotificationsController',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _FakeNotificationsAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final session = await _createAuthenticatedSession();
      final controller = NotificationsController(
        api: NotificationsApi(api),
        session: session,
        localNotifications: const NoopLocalNotificationService(),
        fcmPush: const NoopFcmPushService(),
      );
      addTearDown(controller.dispose);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(
        ChangeNotifierProvider<NotificationsController>.value(
          value: controller,
          child: MaterialApp(
            theme: MetaGymTheme.dark,
            home: AppSettingsDetailPage(
              unitSystem: 'cm / kg',
              workoutReminderEnabled: true,
              reminderTime: '17:30',
              onSave: (_, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lead15 = find.byKey(const Key('app-settings-pt-lead-15'));
      await tester.ensureVisible(lead15);
      await tester.pumpAndSettle();
      await tester.tap(lead15);

      final saveBtn = find.byKey(const Key('app-settings-save-btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(adapter.lastSavedPrefs?['ptBeforeMinutes'], 15);
      expect(controller.preferences.ptBeforeMinutes, 15);
    },
  );

  testWidgets(
    'InAppNotificationListener renders floating banner on live event and opens target on tap',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _FakeNotificationsAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final session = await _createAuthenticatedSession();
      final fcmSpy = _SpyFcmPushService();
      final controller = NotificationsController(
        api: NotificationsApi(api),
        session: session,
        localNotifications: const NoopLocalNotificationService(),
        fcmPush: fcmSpy,
      );
      addTearDown(controller.dispose);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final navKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navKey,
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/member/features/messages',
            builder: (_, _) => const Scaffold(body: Text('Messages Target')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: MetaGymTheme.dark,
          routerConfig: router,
          builder: (context, child) => InAppNotificationListener(
            navigatorKey: navKey,
            controller: controller,
            session: session,
            router: router,
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      fcmSpy.triggerForeground(
        const {
          'id': '99',
          'kind': 'NEW_MESSAGE',
          'category': 'MESSAGE',
          'actionRoute': '/member/features/messages',
        },
        'Tin nhắn mới từ Coach',
        'Nhớ khởi động kỹ nhé!',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('in-app-notification-banner')),
        findsOneWidget,
      );
      expect(find.text('Tin nhắn mới từ Coach'), findsOneWidget);

      await tester.tap(find.byKey(const Key('in-app-notification-banner')));
      await tester.pumpAndSettle();

      expect(adapter.markedIds, contains('99'));
      expect(find.text('Messages Target'), findsOneWidget);
      // Let auto-dismiss timer settle cleanly if still pending
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

Future<SessionController> _createAuthenticatedSession() async {
  const demoUser = AuthUser(
    id: 'member-1',
    email: 'member@metagym.local',
    fullName: 'Nguyễn Minh Quân',
    role: UserRole.member,
    status: 'ACTIVE',
  );
  final storage = _MemoryTokenStorage();
  final session = SessionController(storage, (_) async => demoUser);
  await session.authenticate(
    const AuthSession(accessToken: 'tok-1', user: demoUser),
  );
  return session;
}

class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}

class _SpyLocalNotificationService implements LocalNotificationService {
  int dailySyncCount = 0;
  NotificationPreferences? lastSyncedPrefs;
  int? lastBookingBeforeMinutes;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> initialize({LocalNotificationTapCallback? onNotificationTap}) async {}

  @override
  Future<void> requestPermissionsIfNeeded() async {}

  @override
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'metagym_general',
  }) async {}

  @override
  Future<void> syncBookingReminders(
    List<Map<String, dynamic>> bookings, {
    required int beforeMinutes,
  }) async {
    lastBookingBeforeMinutes = beforeMinutes;
  }

  @override
  Future<void> syncDailyReminders(NotificationPreferences preferences) async {
    dailySyncCount++;
    lastSyncedPrefs = preferences;
  }
}

class _SpyFcmPushService implements FcmPushService {
  bool synced = false;
  FcmForegroundMessageHandler? _onForeground;

  @override
  Future<void> clearToken(NotificationsApi api) async {}

  @override
  void dispose() {}

  @override
  Future<void> initialize({
    FcmForegroundMessageHandler? onForegroundMessage,
    FcmNotificationTapHandler? onNotificationTap,
  }) async {
    _onForeground = onForegroundMessage;
  }

  void triggerForeground(
    Map<String, dynamic> data,
    String? title,
    String? body,
  ) {
    _onForeground?.call(data, title, body);
  }

  @override
  Future<void> syncToken(NotificationsApi api) async {
    synced = true;
  }
}

class _FakeNotificationsAdapter implements HttpClientAdapter {
  final List<String> markedIds = [];
  int markedAllCount = 0;
  Map<String, dynamic>? lastSavedPrefs;
  Map<String, dynamic> _prefs = {
    'workoutRemindersEnabled': true,
    'reminderTime': '17:30',
    'ptBeforeMinutes': 30,
    'nutritionRemindersEnabled': true,
    'coachUpdatesEnabled': true,
    'messagesEnabled': true,
    'callsEnabled': true,
    'adminBroadcastsEnabled': true,
  };
  final List<Map<String, dynamic>> _items = [
    {
      'id': '10',
      'kind': 'BOOKED',
      'category': 'COACH',
      'eventAt': '2026-11-28T08:00:00Z',
      'readAt': null,
    },
    {
      'id': '11',
      'kind': 'TRAINING_PLAN_UPDATED',
      'category': 'TRAINING',
      'title': 'Giáo trình tuần mới',
      'body': 'Đã cập nhật 4 buổi tập',
      'actionRoute': '/member/features/training',
      'eventAt': '2026-11-28T09:00:00Z',
      'readAt': null,
    },
    {
      'id': '12',
      'kind': 'ADMIN_BROADCAST',
      'category': 'SYSTEM',
      'title': 'Thông báo hệ thống',
      'body': 'Mở cửa lễ bình thường',
      'eventAt': '2026-11-27T09:00:00Z',
      'readAt': '2026-11-27T10:00:00Z',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/notifications') {
      return _json(_items);
    }
    if (options.method == 'GET' && options.path == '/notifications/preferences') {
      return _json(_prefs);
    }
    if (options.method == 'PUT' && options.path == '/notifications/preferences') {
      _prefs = Map<String, dynamic>.from(options.data as Map);
      lastSavedPrefs = _prefs;
      return _json(_prefs);
    }
    if (options.method == 'PATCH' && options.path == '/notifications/read-all') {
      markedAllCount++;
      for (final item in _items) {
        item['readAt'] ??= '2026-11-28T10:00:00Z';
      }
      return _json({'updatedCount': _items.length});
    }
    if (options.method == 'PATCH' &&
        options.path.startsWith('/notifications/') &&
        options.path.endsWith('/read')) {
      final id = options.path.split('/')[2];
      markedIds.add(id);
      for (final item in _items) {
        if (item['id'] == id) item['readAt'] = '2026-11-28T10:00:00Z';
      }
      return _json({'id': id, 'readAt': '2026-11-28T10:00:00Z'});
    }
    throw StateError('Unhandled ${options.method} ${options.path}');
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
