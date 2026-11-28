// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/notifications/data/notifications_api.dart';

typedef FcmForegroundMessageHandler = void Function(Map<String, dynamic> data, String? title, String? body);
typedef FcmNotificationTapHandler = void Function(Map<String, dynamic> data);

abstract class FcmPushService {
  Future<void> initialize({
    FcmForegroundMessageHandler? onForegroundMessage,
    FcmNotificationTapHandler? onNotificationTap,
  });

  Future<void> syncToken(NotificationsApi api);
  Future<void> clearToken(NotificationsApi api);
  void dispose();
}

class NoopFcmPushService implements FcmPushService {
  const NoopFcmPushService();

  @override
  Future<void> initialize({
    FcmForegroundMessageHandler? onForegroundMessage,
    FcmNotificationTapHandler? onNotificationTap,
  }) async {}

  @override
  Future<void> syncToken(NotificationsApi api) async {}

  @override
  Future<void> clearToken(NotificationsApi api) async {}

  @override
  void dispose() {}
}

@pragma('vm:entry-point')
Future<void> metaGymFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class FirebaseFcmPushService implements FcmPushService {
  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _lastSyncedToken;
  NotificationsApi? _boundApi;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  @override
  Future<void> initialize({
    FcmForegroundMessageHandler? onForegroundMessage,
    FcmNotificationTapHandler? onNotificationTap,
  }) async {
    if (_initialized || MetaGymTheme.isFlutterTestEnvironment) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
    } catch (_) {
      // Missing google-services.json / GoogleService-Info.plist in dev environment:
      // degrade gracefully while keeping Realtime + Local Notifications active.
      _firebaseAvailable = false;
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        metaGymFirebaseMessagingBackgroundHandler,
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        final api = _boundApi;
        if (api != null && token.trim().isNotEmpty) {
          unawaited(_register(api, token));
        }
      });

      _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
        if (onForegroundMessage == null) return;
        onForegroundMessage(
          _normalizeData(message.data),
          message.notification?.title,
          message.notification?.body,
        );
      });

      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onNotificationTap?.call(_normalizeData(message.data));
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        onNotificationTap?.call(_normalizeData(initialMessage.data));
      }
    } catch (_) {
      // Non-blocking fallback if Firebase Messaging is unavailable on platform.
    }
  }

  @override
  Future<void> syncToken(NotificationsApi api) async {
    _boundApi = api;
    if (!_firebaseAvailable || MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _register(api, token);
      }
    } catch (_) {}
  }

  Future<void> _register(NotificationsApi api, String token) async {
    if (token == _lastSyncedToken) return;
    try {
      await api.registerDeviceToken(
        token: token,
        platform: _platformName(),
      );
      _lastSyncedToken = token;
    } catch (_) {}
  }

  @override
  Future<void> clearToken(NotificationsApi api) async {
    final token = _lastSyncedToken;
    _boundApi = null;
    _lastSyncedToken = null;
    if (token == null || MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      await api.unregisterDeviceToken(token);
    } catch (_) {}
  }

  String _platformName() {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS) return 'IOS';
    return 'ANDROID';
  }

  Map<String, dynamic> _normalizeData(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      final val = entry.value;
      if (val is String && (val.startsWith('{') || val.startsWith('['))) {
        try {
          out[entry.key] = jsonDecode(val);
          continue;
        } catch (_) {}
      }
      out[entry.key] = val;
    }
    return out;
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_onMessageSub?.cancel());
    unawaited(_onOpenedSub?.cancel());
  }
}
