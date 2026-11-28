import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Yêu cầu ghi (`POST`/`PUT`/`PATCH`/`DELETE`) được xếp hàng khi ngoại tuyến.
///
/// Tuyệt đối không lưu `authorization` header hay JWT thô trong hàng đợi;
/// khi đồng bộ lại sẽ dùng token phiên hiện tại và scope băm [authScope].
class QueuedApiMutation {
  const QueuedApiMutation({
    required this.id,
    required this.method,
    required this.path,
    required this.createdAt,
    this.body,
    this.queryParameters = const <String, dynamic>{},
    this.headers = const <String, String>{},
    this.authScope = 'anon',
    this.retryCount = 0,
  });

  final String id;
  final String method;
  final String path;
  final Object? body;
  final Map<String, dynamic> queryParameters;
  final Map<String, String> headers;
  final String authScope;
  final DateTime createdAt;
  final int retryCount;

  QueuedApiMutation copyWith({int? retryCount}) => QueuedApiMutation(
    id: id,
    method: method,
    path: path,
    createdAt: createdAt,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
    authScope: authScope,
    retryCount: retryCount ?? this.retryCount,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'method': method,
    'path': path,
    'body': body,
    'queryParameters': queryParameters,
    'headers': headers,
    'authScope': authScope,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'retryCount': retryCount,
  };

  static QueuedApiMutation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final method = raw['method'];
    final path = raw['path'];
    final createdAtRaw = raw['createdAt'];
    if (id is! String ||
        method is! String ||
        path is! String ||
        createdAtRaw is! String) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAt == null) return null;

    final query = raw['queryParameters'] is Map
        ? Map<String, dynamic>.from(raw['queryParameters'] as Map)
        : const <String, dynamic>{};
    final headers = <String, String>{};
    if (raw['headers'] is Map) {
      for (final entry in (raw['headers'] as Map).entries) {
        final key = entry.key.toString();
        if (key.toLowerCase() == 'authorization') continue;
        if (entry.value != null) {
          headers[key] = entry.value.toString();
        }
      }
    }
    return QueuedApiMutation(
      id: id,
      method: method.toUpperCase(),
      path: path,
      body: raw['body'],
      queryParameters: query,
      headers: headers,
      authScope: raw['authScope'] is String ? raw['authScope'] as String : 'anon',
      createdAt: createdAt,
      retryCount: raw['retryCount'] is int ? raw['retryCount'] as int : 0,
    );
  }
}

/// Hàng đợi FIFO bền vững cho các thao tác ngoại tuyến chờ đồng bộ lên server.
abstract interface class OfflineMutationQueue {
  Future<List<QueuedApiMutation>> listAll();

  Future<void> enqueue(QueuedApiMutation mutation);

  Future<void> remove(String id);

  Future<void> incrementRetry(String id);

  Future<void> clear();
}

/// Hàng đợi trong RAM phục vụ unit test hoặc fallback tối giản.
class MemoryOfflineMutationQueue implements OfflineMutationQueue {
  MemoryOfflineMutationQueue({this.maxItems = defaultMaxItems});

  static const int defaultMaxItems = 100;

  final int maxItems;
  final List<QueuedApiMutation> _items = <QueuedApiMutation>[];

  @override
  Future<List<QueuedApiMutation>> listAll() async =>
      List<QueuedApiMutation>.unmodifiable(_items);

  @override
  Future<void> enqueue(QueuedApiMutation mutation) async {
    _items.removeWhere((item) => item.id == mutation.id);
    _items.add(mutation);
    while (_items.length > maxItems) {
      _items.removeAt(0);
    }
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> incrementRetry(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(
      retryCount: _items[index].retryCount + 1,
    );
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}

/// Hàng đợi outbox lưu bền vững trong [FlutterSecureStorage] kèm bản đệm RAM.
class SecureOfflineMutationQueue implements OfflineMutationQueue {
  SecureOfflineMutationQueue({
    FlutterSecureStorage? storage,
    this.maxItems = MemoryOfflineMutationQueue.defaultMaxItems,
    this.maxTotalBytes = defaultMaxTotalBytes,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'meta_gym_offline_outbox_v1';
  static const int defaultMaxTotalBytes = 1048576;

  final FlutterSecureStorage _storage;
  final int maxItems;
  final int maxTotalBytes;
  List<QueuedApiMutation>? _memory;

  Future<List<QueuedApiMutation>> _ensureLoaded() async {
    if (_memory != null) return _memory!;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _memory = decoded
              .map(QueuedApiMutation.fromJson)
              .whereType<QueuedApiMutation>()
              .toList();
          return _memory!;
        }
      }
    } catch (_) {
      // Non-fatal: fallback to empty queue.
    }
    _memory = <QueuedApiMutation>[];
    return _memory!;
  }

  Future<void> _persist(List<QueuedApiMutation> items) async {
    try {
      while (items.length > maxItems) {
        items.removeAt(0);
      }
      var encoded = jsonEncode(items.map((e) => e.toJson()).toList());
      while (items.isNotEmpty && utf8.encode(encoded).length > maxTotalBytes) {
        items.removeAt(0);
        encoded = jsonEncode(items.map((e) => e.toJson()).toList());
      }
      if (items.isEmpty) {
        await _storage.delete(key: _storageKey);
      } else {
        await _storage.write(key: _storageKey, value: encoded);
      }
    } catch (_) {
      // Non-fatal on keystore/storage errors.
    }
  }

  @override
  Future<List<QueuedApiMutation>> listAll() async {
    final items = await _ensureLoaded();
    return List<QueuedApiMutation>.unmodifiable(items);
  }

  @override
  Future<void> enqueue(QueuedApiMutation mutation) async {
    final items = await _ensureLoaded();
    items.removeWhere((item) => item.id == mutation.id);
    items.add(mutation);
    await _persist(items);
  }

  @override
  Future<void> remove(String id) async {
    final items = await _ensureLoaded();
    final before = items.length;
    items.removeWhere((item) => item.id == id);
    if (items.length != before) {
      await _persist(items);
    }
  }

  @override
  Future<void> incrementRetry(String id) async {
    final items = await _ensureLoaded();
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    items[index] = items[index].copyWith(retryCount: items[index].retryCount + 1);
    await _persist(items);
  }

  @override
  Future<void> clear() async {
    _memory = <QueuedApiMutation>[];
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {
      // Non-fatal.
    }
  }
}
