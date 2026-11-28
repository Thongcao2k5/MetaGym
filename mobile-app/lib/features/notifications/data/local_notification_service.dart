import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef LocalNotificationTapCallback = void Function(String? payload);

abstract class LocalNotificationService {
  Future<void> initialize({LocalNotificationTapCallback? onNotificationTap});
  Future<void> requestPermissionsIfNeeded();
  Future<void> syncDailyReminders(NotificationPreferences preferences);
  Future<void> syncBookingReminders(
    List<Map<String, dynamic>> bookings, {
    required int beforeMinutes,
  });
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'metagym_general',
  });
  Future<void> cancelAll();
}

class NoopLocalNotificationService implements LocalNotificationService {
  const NoopLocalNotificationService();

  @override
  Future<void> initialize({LocalNotificationTapCallback? onNotificationTap}) async {}

  @override
  Future<void> requestPermissionsIfNeeded() async {}

  @override
  Future<void> syncDailyReminders(NotificationPreferences preferences) async {}

  @override
  Future<void> syncBookingReminders(
    List<Map<String, dynamic>> bookings, {
    required int beforeMinutes,
  }) async {}

  @override
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'metagym_general',
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

class FlutterLocalNotificationService implements LocalNotificationService {
  static const int _workoutDailyId = 1001;
  static const int _nutritionLunchId = 1002;
  static const int _nutritionDinnerId = 1003;
  static const int _bookingBaseId = 2000;
  static const int _maxBookingIds = 50;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;
  bool _permissionRequested = false;

  @override
  Future<void> initialize({
    LocalNotificationTapCallback? onNotificationTap,
  }) async {
    if (_initialized || MetaGymTheme.isFlutterTestEnvironment || kIsWeb) {
      return;
    }
    _ensureTimezone();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTap?.call(response.payload);
        },
      );
      await _createAndroidChannels();
      _initialized = true;
    } catch (_) {
      // Degrade silently on unsupported desktop/test hosts.
    }
  }

  void _ensureTimezone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    _tzInitialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    const channels = [
      AndroidNotificationChannel(
        'metagym_general',
        'Thông báo Meta Gym',
        description: 'Thông báo chung từ hệ thống và Coach',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'metagym_reminders',
        'Nhắc lịch tập & Dinh dưỡng',
        description: 'Nhắc nhở giờ tập luyện, dinh dưỡng và lịch PT 1:1',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'metagym_messages',
        'Tin nhắn & Cuộc gọi nhỡ',
        description: 'Tin nhắn mới giữa Hội viên và Coach',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'metagym_calls',
        'Cuộc gọi đến',
        description: 'Cảnh báo cuộc gọi video và thoại trực tiếp',
        importance: Importance.max,
      ),
    ];
    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  @override
  Future<void> requestPermissionsIfNeeded() async {
    if (_permissionRequested ||
        MetaGymTheme.isFlutterTestEnvironment ||
        kIsWeb) {
      return;
    }
    _permissionRequested = true;
    if (!_initialized) await initialize();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  @override
  Future<void> syncDailyReminders(NotificationPreferences preferences) async {
    if (MetaGymTheme.isFlutterTestEnvironment || kIsWeb) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;

    try {
      await _plugin.cancel(id: _workoutDailyId);
      await _plugin.cancel(id: _nutritionLunchId);
      await _plugin.cancel(id: _nutritionDinnerId);

      if (!preferences.workoutRemindersEnabled &&
          !preferences.nutritionRemindersEnabled) {
        return;
      }

      if (preferences.workoutRemindersEnabled) {
        final parts = preferences.reminderTime.split(':');
        final hour = int.tryParse(parts.first) ?? 17;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 30;
        await _plugin.zonedSchedule(
          id: _workoutDailyId,
          title: 'Đến giờ tập luyện cùng Meta Gym',
          body: 'Khởi động nhẹ và bắt đầu buổi tập hôm nay để giữ vững nhịp độ.',
          scheduledDate: _nextInstanceOfTime(hour, minute),
          notificationDetails: _detailsForChannel('metagym_reminders'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/member/features/training',
        );
      }

      if (preferences.nutritionRemindersEnabled) {
        await _plugin.zonedSchedule(
          id: _nutritionLunchId,
          title: 'Nhắc dinh dưỡng bữa trưa',
          body: 'Đừng quên ghi lại bữa trưa và bổ sung đủ nước hôm nay.',
          scheduledDate: _nextInstanceOfTime(12, 0),
          notificationDetails: _detailsForChannel('metagym_reminders'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/member/features/nutrition',
        );
        await _plugin.zonedSchedule(
          id: _nutritionDinnerId,
          title: 'Tổng kết dinh dưỡng buổi tối',
          body: 'Kiểm tra lượng kcal và protein còn lại trong ngày.',
          scheduledDate: _nextInstanceOfTime(18, 30),
          notificationDetails: _detailsForChannel('metagym_reminders'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/member/features/nutrition',
        );
      }
    } catch (_) {
      // Non-blocking on platforms where exact/inexact scheduling is restricted.
    }
  }

  @override
  Future<void> syncBookingReminders(
    List<Map<String, dynamic>> bookings, {
    required int beforeMinutes,
  }) async {
    if (MetaGymTheme.isFlutterTestEnvironment || kIsWeb) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;

    try {
      for (var i = 0; i < _maxBookingIds; i++) {
        await _plugin.cancel(id: _bookingBaseId + i);
      }
      if (beforeMinutes <= 0) return;

      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      var slotIndex = 0;

      for (final booking in bookings) {
        if (slotIndex >= _maxBookingIds) break;
        final status = (booking['status'] as String? ?? '').toUpperCase();
        if (status != 'BOOKED' && status != 'SCHEDULED') continue;
        final rawStart = booking['startsAt'] as String?;
        if (rawStart == null) continue;
        final parsed = DateTime.tryParse(rawStart);
        if (parsed == null) continue;

        final fireAt = tz.TZDateTime.from(
          parsed.subtract(Duration(minutes: beforeMinutes)),
          location,
        );
        if (!fireAt.isAfter(now)) continue;

        final coachName = (booking['coachName'] as String?)?.trim();
        final memberName = (booking['memberName'] as String?)?.trim();
        final peer = coachName?.isNotEmpty == true
            ? 'Coach $coachName'
            : (memberName?.isNotEmpty == true ? memberName! : 'lịch hẹn 1:1');

        await _plugin.zonedSchedule(
          id: _bookingBaseId + slotIndex,
          title: 'Sắp đến buổi tập PT ($beforeMinutes phút nữa)',
          body: 'Buổi tập cùng $peer sắp bắt đầu. Hãy chuẩn bị sẵn sàng nhé!',
          scheduledDate: fireAt,
          notificationDetails: _detailsForChannel('metagym_reminders'),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '/member/features/sessions',
        );
        slotIndex++;
      }
    } catch (_) {}
  }

  @override
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'metagym_general',
  }) async {
    if (MetaGymTheme.isFlutterTestEnvironment || kIsWeb) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _detailsForChannel(channelId),
        payload: payload,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancelAll() async {
    if (MetaGymTheme.isFlutterTestEnvironment || kIsWeb || !_initialized) {
      return;
    }
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  NotificationDetails _detailsForChannel(String channelId) {
    final (name, importance, priority) = switch (channelId) {
      'metagym_calls' => ('Cuộc gọi đến', Importance.max, Priority.max),
      'metagym_messages' => (
        'Tin nhắn & Cuộc gọi nhỡ',
        Importance.high,
        Priority.high,
      ),
      'metagym_reminders' => (
        'Nhắc lịch tập & Dinh dưỡng',
        Importance.high,
        Priority.high,
      ),
      _ => ('Thông báo Meta Gym', Importance.defaultImportance, Priority.defaultPriority),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        name,
        importance: importance,
        priority: priority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
