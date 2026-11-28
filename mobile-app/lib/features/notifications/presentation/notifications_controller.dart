import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/notifications/data/fcm_push_service.dart';
import 'package:meta_gym_app/features/notifications/data/local_notification_service.dart';
import 'package:meta_gym_app/features/notifications/data/notifications_api.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required NotificationsApi api,
    required SessionController session,
    MetaGymRealtime? realtime,
    LocalNotificationService? localNotifications,
    FcmPushService? fcmPush,
  }) : _apiClient = api,
       _sessionController = session,
       _realtimeClient = realtime,
       _localNotifications =
           localNotifications ??
           (MetaGymTheme.isFlutterTestEnvironment
               ? const NoopLocalNotificationService()
               : FlutterLocalNotificationService()),
       _fcmPush =
           fcmPush ??
           (MetaGymTheme.isFlutterTestEnvironment
               ? const NoopFcmPushService()
               : FirebaseFcmPushService()) {
    _sessionController.addListener(_handleSessionChanged);
    _realtimeSub = _realtimeClient?.notifications.listen(_handleRealtimePayload);
    _initServices();
    _handleSessionChanged();
  }

  final NotificationsApi _apiClient;
  final SessionController _sessionController;
  final MetaGymRealtime? _realtimeClient;
  final LocalNotificationService _localNotifications;
  final FcmPushService _fcmPush;

  final _bannerEvents = StreamController<AppNotification>.broadcast();
  final _tapEvents = StreamController<AppNotification>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  String? _activeUserId;
  bool _disposed = false;

  List<AppNotification> _items = const [];
  int _unreadCount = 0;
  NotificationPreferences _preferences = NotificationPreferences.defaults;
  bool _isLoading = false;
  bool _isSavingPreferences = false;
  String? _error;

  List<AppNotification> get items => _items;
  int get unreadCount => _unreadCount;
  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  bool get isSavingPreferences => _isSavingPreferences;
  String? get error => _error;
  Stream<AppNotification> get bannerEvents => _bannerEvents.stream;
  Stream<AppNotification> get tapEvents => _tapEvents.stream;

  void _initServices() {
    unawaited(
      _localNotifications.initialize(
        onNotificationTap: (payload) {
          if (payload != null && payload.trim().isNotEmpty && !_disposed) {
            _tapEvents.add(
              AppNotification(
                id: 'local-${DateTime.now().millisecondsSinceEpoch}',
                kind: 'LOCAL_REMINDER',
                category: NotificationCategory.training,
                actionRoute: payload.trim(),
              ),
            );
          }
        },
      ),
    );
    unawaited(
      _fcmPush.initialize(
        onForegroundMessage: (data, title, body) {
          if (_disposed) return;
          final item = AppNotification.fromJson({
            ...data,
            'title': ?title,
            'body': ?body,
            if (data['id'] == null)
              'id': 'fcm-${DateTime.now().millisecondsSinceEpoch}',
          });
          _ingestLiveNotification(item);
        },
        onNotificationTap: (data) {
          if (_disposed) return;
          final item = AppNotification.fromJson({
            ...data,
            if (data['id'] == null)
              'id': 'fcm-tap-${DateTime.now().millisecondsSinceEpoch}',
          });
          _tapEvents.add(item);
        },
      ),
    );
  }

  void _handleSessionChanged() {
    final user = _sessionController.user;
    final nextUserId =
        _sessionController.status == SessionStatus.authenticated &&
            (user?.role == UserRole.member || user?.role == UserRole.coach)
        ? user?.id
        : null;

    if (nextUserId == _activeUserId) return;
    final previousUserId = _activeUserId;
    _activeUserId = nextUserId;

    if (nextUserId == null) {
      if (previousUserId != null) {
        unawaited(_fcmPush.clearToken(_apiClient));
        unawaited(_localNotifications.cancelAll());
      }
      _items = const [];
      _unreadCount = 0;
      _preferences = NotificationPreferences.defaults;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    unawaited(_bootstrapForUser(nextUserId));
  }

  Future<void> _bootstrapForUser(String userId) async {
    await Future.wait([
      refresh(initial: true),
      loadPreferences(),
      _fcmPush.syncToken(_apiClient),
    ]);
    if (!_disposed && _activeUserId == userId) {
      await _localNotifications.syncDailyReminders(_preferences);
    }
  }

  void _handleRealtimePayload(Map<String, dynamic> payload) {
    if (_disposed || _activeUserId == null) return;
    final item = AppNotification.fromJson(payload);
    _ingestLiveNotification(item);
  }

  void _ingestLiveNotification(AppNotification item) {
    if (item.id.isNotEmpty && _items.any((existing) => existing.id == item.id)) {
      return;
    }
    _items = [item, ..._items];
    if (item.isUnread) {
      _unreadCount += 1;
    }
    notifyListeners();
    if (!_bannerEvents.isClosed) {
      _bannerEvents.add(item);
    }
  }

  Future<void> refresh({bool initial = false}) async {
    if (_activeUserId == null) return;
    if (initial || _items.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final list = await _apiClient.listNotifications(limit: 80);
      if (_disposed || _activeUserId == null) return;
      _items = list;
      _unreadCount = list.where((item) => item.isUnread).length;
      _error = null;
    } catch (e) {
      if (_disposed) return;
      if (_items.isEmpty) {
        _error = 'Không tải được thông báo.';
      }
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshUnreadCount() async {
    if (_activeUserId == null) return;
    try {
      final count = await _apiClient.getUnreadCount();
      if (_disposed) return;
      _unreadCount = count;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadPreferences() async {
    if (_activeUserId == null) return;
    try {
      final loaded = await _apiClient.getPreferences();
      if (_disposed) return;
      _preferences = loaded;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updatePreferences(NotificationPreferences next) async {
    final previous = _preferences;
    _preferences = next;
    _isSavingPreferences = true;
    notifyListeners();

    if (next.workoutRemindersEnabled || next.nutritionRemindersEnabled) {
      await _localNotifications.requestPermissionsIfNeeded();
    }

    try {
      final saved = await _apiClient.updatePreferences(next);
      if (_disposed) return true;
      _preferences = saved;
      await _localNotifications.syncDailyReminders(saved);
      return true;
    } catch (_) {
      if (_disposed) return false;
      _preferences = previous;
      return false;
    } finally {
      if (!_disposed) {
        _isSavingPreferences = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || !_items[index].isUnread) return;
    final previousItems = _items;
    final previousUnread = _unreadCount;

    final updated = List<AppNotification>.of(_items);
    updated[index] = updated[index].copyWith(
      readAt: DateTime.now().toUtc().toIso8601String(),
    );
    _items = updated;
    _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    notifyListeners();

    try {
      await _apiClient.markRead(id);
    } catch (_) {
      if (_disposed) return;
      _items = previousItems;
      _unreadCount = previousUnread;
      notifyListeners();
    }
  }

  Future<void> markAllRead({NotificationCategory? category}) async {
    if (_unreadCount == 0 && _items.every((item) => !item.isUnread)) return;
    final previousItems = _items;
    final previousUnread = _unreadCount;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    _items = [
      for (final item in _items)
        if (category == null ||
            category == NotificationCategory.all ||
            category == NotificationCategory.unread ||
            item.category == category)
          item.isUnread ? item.copyWith(readAt: nowIso) : item
        else
          item,
    ];
    _unreadCount = _items.where((item) => item.isUnread).length;
    notifyListeners();

    try {
      await _apiClient.markAllRead(category: category);
    } catch (_) {
      if (_disposed) return;
      _items = previousItems;
      _unreadCount = previousUnread;
      notifyListeners();
    }
  }

  Future<void> syncUpcomingBookings(List<Map<String, dynamic>> bookings) async {
    if (_activeUserId == null) return;
    await _localNotifications.syncBookingReminders(
      bookings,
      beforeMinutes: _preferences.ptBeforeMinutes,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionController.removeListener(_handleSessionChanged);
    unawaited(_realtimeSub?.cancel());
    unawaited(_bannerEvents.close());
    unawaited(_tapEvents.close());
    _fcmPush.dispose();
    super.dispose();
  }
}
