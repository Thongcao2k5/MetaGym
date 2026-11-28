import 'package:flutter/foundation.dart';

enum NotificationCategory {
  all,
  unread,
  coach,
  training,
  message,
  system;

  String get apiValue => switch (this) {
    NotificationCategory.all || NotificationCategory.unread => 'ALL',
    NotificationCategory.coach => 'COACH',
    NotificationCategory.training => 'TRAINING',
    NotificationCategory.message => 'MESSAGE',
    NotificationCategory.system => 'SYSTEM',
  };

  static NotificationCategory fromApi(String? raw) =>
      switch (raw?.toUpperCase()) {
        'TRAINING' => NotificationCategory.training,
        'MESSAGE' => NotificationCategory.message,
        'SYSTEM' => NotificationCategory.system,
        _ => NotificationCategory.coach,
      };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.category,
    this.subjectId,
    this.title,
    this.body,
    this.actionRoute,
    this.metadata = const {},
    this.eventAt,
    this.readAt,
  });

  final String id;
  final String kind;
  final NotificationCategory category;
  final String? subjectId;
  final String? title;
  final String? body;
  final String? actionRoute;
  final Map<String, dynamic> metadata;
  final String? eventAt;
  final String? readAt;

  bool get isUnread => readAt == null || readAt!.trim().isEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId == null ? '' : rawId.toString();
    final kind = (json['kind'] as String? ?? '').trim();
    final rawCategory = json['category'] as String?;
    final category = rawCategory != null && rawCategory.trim().isNotEmpty
        ? NotificationCategory.fromApi(rawCategory)
        : inferCategory(kind);
    final rawReadAt = json['readAt'] as String?;
    final legacyIsRead = json['isRead'] as bool?;
    final readAt = (rawReadAt != null && rawReadAt.trim().isNotEmpty)
        ? rawReadAt
        : (legacyIsRead == true ? 'read' : null);

    return AppNotification(
      id: id,
      kind: kind.isEmpty ? 'GENERAL' : kind,
      category: category,
      subjectId: json['subjectId']?.toString(),
      title: _nonEmpty(json['title'] as String?),
      body:
          _nonEmpty(json['body'] as String?) ??
          _nonEmpty(json['message'] as String?) ??
          _nonEmpty(json['description'] as String?),
      actionRoute: _nonEmpty(json['actionRoute'] as String?),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      eventAt:
          _nonEmpty(json['eventAt'] as String?) ??
          _nonEmpty(json['createdAt'] as String?),
      readAt: readAt,
    );
  }

  Map<String, dynamic> toRecord() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'category': category.apiValue,
    if (subjectId != null) 'subjectId': subjectId,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (actionRoute != null) 'actionRoute': actionRoute,
    if (metadata.isNotEmpty) 'metadata': metadata,
    if (eventAt != null) 'eventAt': eventAt,
    if (eventAt != null) 'createdAt': eventAt,
    'readAt': readAt,
  };

  AppNotification copyWith({String? readAt, bool clearReadAt = false}) =>
      AppNotification(
        id: id,
        kind: kind,
        category: category,
        subjectId: subjectId,
        title: title,
        body: body,
        actionRoute: actionRoute,
        metadata: metadata,
        eventAt: eventAt,
        readAt: clearReadAt ? null : (readAt ?? this.readAt),
      );

  static NotificationCategory inferCategory(String kind) {
    final k = kind.toUpperCase();
    if (k == 'TRAINING_PLAN_UPDATED' ||
        k == 'NUTRITION_UPDATED' ||
        k == 'MEAL_PLAN_UPDATED') {
      return NotificationCategory.training;
    }
    if (k == 'NEW_MESSAGE' || k == 'MISSED_CALL' || k == 'INCOMING_CALL') {
      return NotificationCategory.message;
    }
    if (k == 'ADMIN_BROADCAST' ||
        k == 'COACH_LOCKED' ||
        k == 'COACH_UNLOCKED_RESTORED' ||
        k == 'MEMBER_LOCKED' ||
        k == 'MEMBER_UNLOCKED_RESTORED') {
      return NotificationCategory.system;
    }
    return NotificationCategory.coach;
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.workoutRemindersEnabled = true,
    this.reminderTime = '17:30',
    this.ptBeforeMinutes = 30,
    this.nutritionRemindersEnabled = true,
    this.coachUpdatesEnabled = true,
    this.messagesEnabled = true,
    this.callsEnabled = true,
    this.adminBroadcastsEnabled = true,
  });

  static const defaults = NotificationPreferences();

  final bool workoutRemindersEnabled;
  final String reminderTime;
  final int ptBeforeMinutes;
  final bool nutritionRemindersEnabled;
  final bool coachUpdatesEnabled;
  final bool messagesEnabled;
  final bool callsEnabled;
  final bool adminBroadcastsEnabled;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final rawTime = (json['reminderTime'] as String? ?? '17:30').trim();
    final validTime = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(rawTime)
        ? rawTime
        : '17:30';
    final rawPt = (json['ptBeforeMinutes'] as num?)?.toInt() ?? 30;
    final validPt = const {0, 15, 30, 60}.contains(rawPt) ? rawPt : 30;
    return NotificationPreferences(
      workoutRemindersEnabled: json['workoutRemindersEnabled'] as bool? ?? true,
      reminderTime: validTime,
      ptBeforeMinutes: validPt,
      nutritionRemindersEnabled:
          json['nutritionRemindersEnabled'] as bool? ?? true,
      coachUpdatesEnabled: json['coachUpdatesEnabled'] as bool? ?? true,
      messagesEnabled: json['messagesEnabled'] as bool? ?? true,
      callsEnabled: json['callsEnabled'] as bool? ?? true,
      adminBroadcastsEnabled: json['adminBroadcastsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'workoutRemindersEnabled': workoutRemindersEnabled,
    'reminderTime': reminderTime,
    'ptBeforeMinutes': ptBeforeMinutes,
    'nutritionRemindersEnabled': nutritionRemindersEnabled,
    'coachUpdatesEnabled': coachUpdatesEnabled,
    'messagesEnabled': messagesEnabled,
    'callsEnabled': callsEnabled,
    'adminBroadcastsEnabled': adminBroadcastsEnabled,
  };

  NotificationPreferences copyWith({
    bool? workoutRemindersEnabled,
    String? reminderTime,
    int? ptBeforeMinutes,
    bool? nutritionRemindersEnabled,
    bool? coachUpdatesEnabled,
    bool? messagesEnabled,
    bool? callsEnabled,
    bool? adminBroadcastsEnabled,
  }) {
    return NotificationPreferences(
      workoutRemindersEnabled:
          workoutRemindersEnabled ?? this.workoutRemindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      ptBeforeMinutes: ptBeforeMinutes ?? this.ptBeforeMinutes,
      nutritionRemindersEnabled:
          nutritionRemindersEnabled ?? this.nutritionRemindersEnabled,
      coachUpdatesEnabled: coachUpdatesEnabled ?? this.coachUpdatesEnabled,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      callsEnabled: callsEnabled ?? this.callsEnabled,
      adminBroadcastsEnabled:
          adminBroadcastsEnabled ?? this.adminBroadcastsEnabled,
    );
  }
}
