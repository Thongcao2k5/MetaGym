import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';

const String offlineReplayExtraKey = 'isOfflineReplay';
const String offlineQueuedExtraKey = 'queuedOffline';

const Set<String> _queueableMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

/// Xác định request ghi có an toàn để lưu hàng đợi ngoại tuyến và phát lại khi có mạng hay không.
bool canQueueOffline(RequestOptions options) {
  if (options.extra[offlineReplayExtraKey] == true) return false;
  if (!_queueableMethods.contains(options.method.toUpperCase())) return false;

  // Không xếp hàng dữ liệu nhị phân / multipart (ảnh/video/file).
  final data = options.data;
  if (data is List<int> || data is FormData) return false;
  final contentType = (options.contentType ?? '').toLowerCase();
  if (contentType.startsWith('image/') ||
      contentType.startsWith('video/') ||
      contentType.startsWith('multipart/')) {
    return false;
  }

  final normalizedPath = _normalizeMutationPath(options.path);
  const excludedPrefixes = <String>[
    '/auth',
    '/password-reset',
    '/password-reset-requests',
    '/password-reset-verifications',
    '/password-resets',
    '/users/me/password',
    '/users/me/avatar',
    '/payments',
    '/memberships',
    '/calls',
    '/ai',
    '/ai-conversations',
    '/media',
    '/realtime',
    '/notifications/device-tokens',
  ];
  for (final prefix in excludedPrefixes) {
    if (normalizedPath == prefix || normalizedPath.startsWith('$prefix/')) {
      return false;
    }
  }
  return true;
}

/// Tạo JSON envelope lạc quan (`{'data': ...}`) và cập nhật ngay dữ liệu GET đã lưu trong cache
/// để màn hình phản ánh ngay thao tác người dùng ngay cả khi đang ngoại tuyến.
Future<Object> buildOptimisticEnvelopeAndPatchCache({
  required RequestOptions options,
  required String mutationId,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final method = options.method.toUpperCase();
  final path = _normalizeMutationPath(options.path);
  final rawBody = options.data;
  final bodyMap = rawBody is Map
      ? Map<String, dynamic>.from(jsonDecode(jsonEncode(rawBody)) as Map)
      : <String, dynamic>{};

  if (method == 'PATCH' && path == '/users/me') {
    return _optimisticUpdateUserProfile(
      bodyMap: bodyMap,
      options: options,
      cacheStore: cacheStore,
      buildGetCacheKey: buildGetCacheKey,
      nowUtc: nowUtc,
    );
  }

  if (path == '/member/nutrition/entries' ||
      path.startsWith('/member/nutrition/entries/')) {
    return _optimisticNutritionMutation(
      method: method,
      path: path,
      bodyMap: bodyMap,
      mutationId: mutationId,
      options: options,
      cacheStore: cacheStore,
      buildGetCacheKey: buildGetCacheKey,
      nowUtc: nowUtc,
    );
  }

  if (path == '/member/self-training-days' ||
      path.startsWith('/member/self-training-days/')) {
    return _optimisticSelfTrainingMutation(
      method: method,
      path: path,
      bodyMap: bodyMap,
      mutationId: mutationId,
      options: options,
      cacheStore: cacheStore,
      buildGetCacheKey: buildGetCacheKey,
      nowUtc: nowUtc,
    );
  }

  if (path == '/body-measurements' || path.startsWith('/body-measurements/')) {
    return _optimisticMeasurementMutation(
      method: method,
      path: path,
      bodyMap: bodyMap,
      mutationId: mutationId,
      options: options,
      cacheStore: cacheStore,
      buildGetCacheKey: buildGetCacheKey,
      nowUtc: nowUtc,
    );
  }

  if (path == '/journal' || path.startsWith('/journal/')) {
    return _optimisticJournalMutation(
      method: method,
      path: path,
      bodyMap: bodyMap,
      mutationId: mutationId,
      options: options,
      cacheStore: cacheStore,
      buildGetCacheKey: buildGetCacheKey,
      nowUtc: nowUtc,
    );
  }

  if (path == '/workout-logs' || path.startsWith('/workout-logs/')) {
    final segments = path.split('/');
    final existingId = segments.length > 2 ? segments.last : null;
    return <String, dynamic>{
      'data': <String, dynamic>{
        'id': existingId ?? mutationId,
        'performedAt': bodyMap['performedAt'] ?? nowUtc.toIso8601String(),
        'exercises': bodyMap['exercises'] ?? const <Object?>[],
        ...bodyMap,
        offlineQueuedExtraKey: true,
      },
    };
  }

  if (method == 'PATCH' && path == '/notifications/read-all') {
    return const <String, dynamic>{
      'data': <String, dynamic>{
        'updatedCount': 0,
        offlineQueuedExtraKey: true,
      },
    };
  }

  if (method == 'PUT' && path == '/notifications/preferences') {
    return <String, dynamic>{'data': bodyMap};
  }

  return <String, dynamic>{
    'data': rawBody is Map
        ? <String, dynamic>{
            'id': mutationId,
            ...bodyMap,
            offlineQueuedExtraKey: true,
          }
        : const <String, dynamic>{'ok': true, offlineQueuedExtraKey: true},
  };
}

Future<Object> _optimisticUpdateUserProfile({
  required Map<String, dynamic> bodyMap,
  required RequestOptions options,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final userCacheKey = buildGetCacheKey('/users/me', const {}, options);
  final existing = await _readMapData(cacheStore, userCacheKey);
  final current = existing ?? <String, dynamic>{
    'id': 'offline-user',
    'email': '',
    'fullName': '',
    'role': 'MEMBER',
    'status': 'ACTIVE',
    'profile': <String, dynamic>{},
  };
  final profile = current['profile'] is Map
      ? Map<String, dynamic>.from(current['profile'] as Map)
      : <String, dynamic>{};

  for (final entry in bodyMap.entries) {
    if (entry.key == 'fullName' || entry.key == 'phone') {
      current[entry.key] = entry.value;
    } else {
      profile[entry.key] = entry.value;
    }
  }
  current['profile'] = profile;

  await _writeCachedEnvelope(
    cacheStore: cacheStore,
    key: userCacheKey,
    data: current,
    nowUtc: nowUtc,
  );
  return <String, dynamic>{'data': current};
}

Future<Object> _optimisticNutritionMutation({
  required String method,
  required String path,
  required Map<String, dynamic> bodyMap,
  required String mutationId,
  required RequestOptions options,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final segments = path.split('/');
  final targetId = segments.length > 4 ? Uri.decodeComponent(segments.last) : null;
  final entryId = targetId ?? mutationId;
  final optimisticEntry = <String, dynamic>{
    'id': entryId,
    ...bodyMap,
    offlineQueuedExtraKey: true,
  };

  final dateKey = _extractDateKey(bodyMap['eatenAt']) ?? _todayVnKey(nowUtc);
  final dayCacheKey = buildGetCacheKey(
    '/member/nutrition/day',
    <String, dynamic>{'date': dateKey},
    options,
  );
  final dayData = await _readMapData(cacheStore, dayCacheKey);
  if (dayData != null) {
    final entries = (dayData['entries'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (method == 'POST') {
      entries.add(optimisticEntry);
    } else if (method == 'PATCH' && targetId != null) {
      final idx = entries.indexWhere((e) => e['id'] == targetId);
      if (idx != -1) {
        entries[idx] = <String, dynamic>{...entries[idx], ...optimisticEntry};
      }
    } else if (method == 'DELETE' && targetId != null) {
      entries.removeWhere((e) => e['id'] == targetId);
    }
    dayData['entries'] = entries;
    await _writeCachedEnvelope(
      cacheStore: cacheStore,
      key: dayCacheKey,
      data: dayData,
      nowUtc: nowUtc,
    );
  }

  return <String, dynamic>{'data': optimisticEntry};
}

Future<Object> _optimisticSelfTrainingMutation({
  required String method,
  required String path,
  required Map<String, dynamic> bodyMap,
  required String mutationId,
  required RequestOptions options,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final segments = path.split('/');
  String? planDate = bodyMap['planDate'] as String?;
  String sessionId = mutationId;
  if (segments.length == 4 && !path.contains('/sessions/')) {
    planDate ??= Uri.decodeComponent(segments.last);
  } else if (segments.length >= 5 && segments[3] == 'sessions') {
    sessionId = Uri.decodeComponent(segments.last);
  }
  planDate ??= _todayVnKey(nowUtc);

  final payload = <String, dynamic>{
    'id': sessionId,
    'planDate': planDate,
    'title': (bodyMap['title'] as String?) ?? 'Buổi tự tập',
    'startTime': bodyMap['startTime'],
    'notes': (bodyMap['notes'] as String?) ?? '',
    'exercises': bodyMap['exercises'] ?? const <Object?>[],
  };

  // Cập nhật các cache tuần/tháng thường gặp nếu có sẵn.
  final dayDate = DateTime.tryParse(planDate);
  if (dayDate != null) {
    final weekStart = dayDate.subtract(
      Duration(days: dayDate.weekday - DateTime.monday),
    );
    final weekFrom = _formatDate(weekStart);
    final weekTo = _formatDate(weekStart.add(const Duration(days: 6)));
    final rangeKey = buildGetCacheKey(
      '/member/self-training-days',
      <String, dynamic>{'from': weekFrom, 'to': weekTo},
      options,
    );
    final list = await _readListData(cacheStore, rangeKey);
    if (list != null) {
      if (method == 'DELETE') {
        list.removeWhere(
          (item) => item['id'] == sessionId || item['planDate'] == planDate,
        );
      } else {
        final idx = list.indexWhere((item) => item['id'] == sessionId);
        if (idx != -1) {
          list[idx] = payload;
        } else {
          list.add(payload);
        }
      }
      await _writeCachedEnvelope(
        cacheStore: cacheStore,
        key: rangeKey,
        data: list,
        nowUtc: nowUtc,
      );
    }
  }

  return <String, dynamic>{'data': payload};
}

Future<Object> _optimisticMeasurementMutation({
  required String method,
  required String path,
  required Map<String, dynamic> bodyMap,
  required String mutationId,
  required RequestOptions options,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final segments = path.split('/');
  final targetId = segments.length > 2 ? Uri.decodeComponent(segments.last) : null;
  final itemId = targetId ?? mutationId;
  final item = <String, dynamic>{
    'id': itemId,
    'measuredAt': bodyMap['measuredAt'] ?? nowUtc.toIso8601String(),
    'weightKg': bodyMap['weightKg'] ?? 0,
    ...bodyMap,
  };

  final page1Key = buildGetCacheKey(
    '/body-measurements',
    const <String, dynamic>{'page': 1, 'pageSize': 20},
    options,
  );
  final existingList = await _readListData(cacheStore, page1Key);
  if (existingList != null) {
    if (method == 'POST') {
      existingList.insert(0, item);
    } else if (method == 'PATCH' && targetId != null) {
      final idx = existingList.indexWhere((e) => e['id'] == targetId);
      if (idx != -1) {
        existingList[idx] = <String, dynamic>{...existingList[idx], ...item};
      }
    }
    await _writeCachedEnvelope(
      cacheStore: cacheStore,
      key: page1Key,
      data: existingList,
      nowUtc: nowUtc,
    );
  }
  return <String, dynamic>{'data': item};
}

Future<Object> _optimisticJournalMutation({
  required String method,
  required String path,
  required Map<String, dynamic> bodyMap,
  required String mutationId,
  required RequestOptions options,
  required ApiCacheStore cacheStore,
  required String Function(
    String path,
    Map<String, dynamic> query,
    RequestOptions source,
  )
  buildGetCacheKey,
  required DateTime nowUtc,
}) async {
  final segments = path.split('/');
  final targetId = segments.length > 2 ? Uri.decodeComponent(segments.last) : null;
  final itemId = targetId ?? mutationId;
  final item = <String, dynamic>{
    'id': itemId,
    'journalDate': bodyMap['journalDate'] ?? _todayVnKey(nowUtc),
    'achievements': bodyMap['achievements'] ?? const <Object?>[],
    'photoMediaIds': bodyMap['photoMediaIds'] ?? const <String>[],
    ...bodyMap,
  };

  final page1Key = buildGetCacheKey(
    '/journal',
    const <String, dynamic>{'page': 1, 'pageSize': 20},
    options,
  );
  final existingList = await _readListData(cacheStore, page1Key);
  if (existingList != null) {
    if (method == 'POST') {
      existingList.insert(0, item);
    } else if (method == 'PATCH' && targetId != null) {
      final idx = existingList.indexWhere((e) => e['id'] == targetId);
      if (idx != -1) {
        existingList[idx] = <String, dynamic>{...existingList[idx], ...item};
      }
    } else if (method == 'DELETE' && targetId != null) {
      existingList.removeWhere((e) => e['id'] == targetId);
    }
    await _writeCachedEnvelope(
      cacheStore: cacheStore,
      key: page1Key,
      data: existingList,
      nowUtc: nowUtc,
    );
  }
  return <String, dynamic>{'data': item};
}

Future<Map<String, dynamic>?> _readMapData(
  ApiCacheStore store,
  String key,
) async {
  try {
    final cached = await store.read(key);
    if (cached?.body case {'data': final Map data}) {
      return Map<String, dynamic>.from(data);
    }
  } catch (_) {}
  return null;
}

Future<List<Map<String, dynamic>>?> _readListData(
  ApiCacheStore store,
  String key,
) async {
  try {
    final cached = await store.read(key);
    if (cached?.body case {'data': final List list}) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  } catch (_) {}
  return null;
}

Future<void> _writeCachedEnvelope({
  required ApiCacheStore cacheStore,
  required String key,
  required Object data,
  required DateTime nowUtc,
}) async {
  try {
    await cacheStore.write(
      key,
      CachedApiResponse(
        body: <String, dynamic>{'data': data},
        savedAt: nowUtc,
        statusCode: 200,
      ),
    );
  } catch (_) {}
}

String _normalizeMutationPath(String path) {
  final parsed = Uri.tryParse(path);
  final rawPath = parsed != null && parsed.path.isNotEmpty ? parsed.path : path;
  final stripped = rawPath.replaceAll(RegExp(r'/+$'), '');
  return stripped.isEmpty ? '/' : stripped;
}

String? _extractDateKey(Object? eatenAt) {
  if (eatenAt is! String) return null;
  if (eatenAt.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(eatenAt)) {
    return eatenAt.substring(0, 10);
  }
  return null;
}

String _todayVnKey(DateTime nowUtc) =>
    _formatDate(nowUtc.toUtc().add(const Duration(hours: 7)));

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
