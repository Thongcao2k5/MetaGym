import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';

class NotificationsApi {
  const NotificationsApi(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> listNotifications({
    NotificationCategory category = NotificationCategory.all,
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      if (category != NotificationCategory.all &&
          category != NotificationCategory.unread)
        'category': category.apiValue,
      if (unreadOnly || category == NotificationCategory.unread)
        'unreadOnly': 'true',
    };
    final result = await _api.get<List<AppNotification>>(
      '/notifications',
      queryParameters: query,
      decode: (value) {
        final list = value as List? ?? const [];
        return list
            .whereType<Map>()
            .map(
              (row) => AppNotification.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList();
      },
    );
    return result.data;
  }

  Future<int> getUnreadCount() async {
    final result = await _api.get<int>(
      '/notifications/unread-count',
      decode: (value) {
        if (value is Map && value['unreadCount'] is num) {
          return (value['unreadCount'] as num).toInt();
        }
        return 0;
      },
    );
    return result.data;
  }

  Future<void> markRead(String id) async {
    await _api.patch<Object?>(
      '/notifications/$id/read',
      body: const <String, dynamic>{},
      decode: (value) => value,
    );
  }

  Future<int> markAllRead({NotificationCategory? category}) async {
    final body = <String, dynamic>{
      if (category != null &&
          category != NotificationCategory.all &&
          category != NotificationCategory.unread)
        'category': category.apiValue,
    };
    final result = await _api.patch<int>(
      '/notifications/read-all',
      body: body,
      decode: (value) {
        if (value is Map && value['updatedCount'] is num) {
          return (value['updatedCount'] as num).toInt();
        }
        return 0;
      },
    );
    return result.data;
  }

  Future<NotificationPreferences> getPreferences() async {
    final result = await _api.get<NotificationPreferences>(
      '/notifications/preferences',
      decode: (value) => value is Map
          ? NotificationPreferences.fromJson(Map<String, dynamic>.from(value))
          : NotificationPreferences.defaults,
    );
    return result.data;
  }

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final result = await _api.put<NotificationPreferences>(
      '/notifications/preferences',
      body: preferences.toJson(),
      decode: (value) => value is Map
          ? NotificationPreferences.fromJson(Map<String, dynamic>.from(value))
          : preferences,
    );
    return result.data;
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceLabel,
  }) async {
    await _api.post<Object?>(
      '/notifications/device-tokens',
      body: <String, dynamic>{
        'token': token,
        'platform': platform,
        if (deviceLabel != null && deviceLabel.trim().isNotEmpty)
          'deviceLabel': deviceLabel.trim(),
      },
      decode: (value) => value,
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _api.delete<Object?>(
      '/notifications/device-tokens',
      body: <String, dynamic>{'token': token},
      decode: (value) => value,
    );
  }
}
