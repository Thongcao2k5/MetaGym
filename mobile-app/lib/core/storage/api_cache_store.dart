import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';

/// Phản hồi JSON GET đã được lưu cục bộ kèm thời điểm đồng bộ gần nhất.
class CachedApiResponse {
  const CachedApiResponse({
    required this.body,
    required this.savedAt,
    this.statusCode = 200,
  });

  final Object? body;
  final DateTime savedAt;
  final int statusCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'body': body,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'statusCode': statusCode,
  };

  static CachedApiResponse? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final savedAtRaw = raw['savedAt'];
    if (savedAtRaw is! String) return null;
    final savedAt = DateTime.tryParse(savedAtRaw)?.toUtc();
    if (savedAt == null) return null;
    final statusCode = raw['statusCode'] is int ? raw['statusCode'] as int : 200;
    return CachedApiResponse(
      body: raw['body'],
      savedAt: savedAt,
      statusCode: statusCode,
    );
  }
}

/// Giao diện lưu trữ cache phản hồi API theo khóa.
abstract interface class ApiCacheStore {
  Future<CachedApiResponse?> read(String key);

  Future<void> write(String key, CachedApiResponse entry);

  Future<void> clear();
}

/// Bộ nhớ cache LRU trong RAM (dùng cho test hoặc tầng đệm nhanh).
class MemoryApiCacheStore implements ApiCacheStore {
  MemoryApiCacheStore({
    this.maxEntries = defaultMaxEntries,
    this.maxEntryBytes = defaultMaxEntryBytes,
  });

  static const int defaultMaxEntries = 80;
  static const int defaultMaxEntryBytes = 1048576;

  final int maxEntries;
  final int maxEntryBytes;
  final Map<String, CachedApiResponse> _entries = <String, CachedApiResponse>{};

  int get length => _entries.length;
  Iterable<String> get keys => _entries.keys;

  @override
  Future<CachedApiResponse?> read(String key) async {
    final existing = _entries.remove(key);
    if (existing == null) return null;
    // Cập nhật vị trí LRU gần nhất.
    _entries[key] = existing;
    return existing;
  }

  @override
  Future<void> write(String key, CachedApiResponse entry) async {
    try {
      final encoded = jsonEncode(entry.toJson());
      if (utf8.encode(encoded).length > maxEntryBytes) {
        return;
      }
    } catch (_) {
      return;
    }

    _entries.remove(key);
    _entries[key] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}

/// Bộ lưu cache phản hồi API bền vững bằng [FlutterSecureStorage] kèm bộ đệm RAM.
class SecureApiCacheStore implements ApiCacheStore {
  SecureApiCacheStore({
    FlutterSecureStorage? storage,
    this.maxEntries = MemoryApiCacheStore.defaultMaxEntries,
    this.maxEntryBytes = MemoryApiCacheStore.defaultMaxEntryBytes,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyPrefix = 'meta_gym_api_cache_v1:';
  static const String _indexKey = 'meta_gym_api_cache_v1_index';

  final FlutterSecureStorage _storage;
  final int maxEntries;
  final int maxEntryBytes;

  final Map<String, CachedApiResponse> _memory = <String, CachedApiResponse>{};
  List<String>? _indexOrder;

  Future<List<String>> _ensureIndex() async {
    if (_indexOrder != null) return _indexOrder!;
    try {
      final raw = await _storage.read(key: _indexKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _indexOrder = decoded.whereType<String>().toList();
          return _indexOrder!;
        }
      }
    } catch (_) {
      // Non-fatal: fallback to empty index.
    }
    _indexOrder = <String>[];
    return _indexOrder!;
  }

  @override
  Future<CachedApiResponse?> read(String key) async {
    final inMemory = _memory[key];
    if (inMemory != null) {
      return inMemory;
    }
    try {
      final raw = await _storage.read(key: '$_keyPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      final parsed = CachedApiResponse.fromJson(decoded);
      if (parsed == null) return null;
      _memory[key] = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, CachedApiResponse entry) async {
    String encoded;
    try {
      encoded = jsonEncode(entry.toJson());
      if (utf8.encode(encoded).length > maxEntryBytes) {
        return;
      }
    } catch (_) {
      return;
    }

    _memory[key] = entry;
    try {
      final index = await _ensureIndex();
      index.remove(key);
      index.add(key);

      final evicted = <String>[];
      while (index.length > maxEntries) {
        final oldest = index.removeAt(0);
        _memory.remove(oldest);
        evicted.add(oldest);
      }

      await _storage.write(key: '$_keyPrefix$key', value: encoded);
      await _storage.write(key: _indexKey, value: jsonEncode(index));
      for (final oldKey in evicted) {
        await _storage.delete(key: '$_keyPrefix$oldKey');
      }
    } catch (_) {
      // Non-fatal on keystore/storage errors.
    }
  }

  @override
  Future<void> clear() async {
    final trackedKeys = <String>{..._memory.keys};
    _memory.clear();
    try {
      final index = await _ensureIndex();
      trackedKeys.addAll(index);
      _indexOrder = <String>[];
      for (final key in trackedKeys) {
        await _storage.delete(key: '$_keyPrefix$key');
      }
      await _storage.delete(key: _indexKey);
    } catch (_) {
      _indexOrder = <String>[];
    }
  }
}

/// Ảnh chụp người dùng gần nhất phục vụ khôi phục phiên khi mất mạng lúc khởi động.
class CachedUserSnapshot {
  const CachedUserSnapshot({required this.user, required this.savedAt});

  final AuthUser user;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user': user.toJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  static CachedUserSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final savedAtRaw = raw['savedAt'];
    final userRaw = raw['user'];
    if (savedAtRaw is! String || userRaw is! Map) return null;
    final savedAt = DateTime.tryParse(savedAtRaw)?.toUtc();
    if (savedAt == null) return null;
    try {
      return CachedUserSnapshot(
        user: AuthUser.fromJson(userRaw),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lưu trữ ảnh chụp thông tin người dùng gần nhất.
abstract interface class CachedUserStorage {
  Future<CachedUserSnapshot?> read();

  Future<void> write(CachedUserSnapshot snapshot);

  Future<void> delete();
}

/// Lưu ảnh chụp người dùng gần nhất vào [FlutterSecureStorage].
class SecureCachedUserStorage implements CachedUserStorage {
  const SecureCachedUserStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _cachedUserKey = 'meta_gym_cached_user_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<CachedUserSnapshot?> read() async {
    try {
      final raw = await _storage.read(key: _cachedUserKey);
      if (raw == null || raw.isEmpty) return null;
      return CachedUserSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(CachedUserSnapshot snapshot) async {
    try {
      await _storage.write(
        key: _cachedUserKey,
        value: jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // Non-fatal on keystore/storage errors.
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: _cachedUserKey);
    } catch (_) {
      // Non-fatal on keystore/storage errors.
    }
  }
}
