import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/offline_mutation_policy.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
import 'package:meta_gym_app/core/storage/offline_mutation_queue.dart';

const String apiCacheFromCacheExtraKey = 'fromApiCache';
const String apiCacheSavedAtExtraKey = 'apiCacheSavedAt';

/// Trạng thái toàn cục theo dõi kết nối mạng, dữ liệu cache, hàng đợi đồng bộ và nhịp làm mới UI.
class ApiCacheStatusController extends ChangeNotifier {
  bool _isShowingCachedData = false;
  DateTime? _lastSyncedAt;
  bool _isDismissed = false;
  bool _isDeviceOffline = false;
  bool _isSyncing = false;
  int _pendingMutationCount = 0;
  int _syncRevision = 0;

  bool get isShowingCachedData => _isShowingCachedData;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isDismissed => _isDismissed;
  bool get isDeviceOffline => _isDeviceOffline;
  bool get isSyncing => _isSyncing;
  int get pendingMutationCount => _pendingMutationCount;
  int get syncRevision => _syncRevision;

  bool get shouldShowBanner =>
      _isSyncing ||
      ((_isShowingCachedData || _isDeviceOffline || _pendingMutationCount > 0) &&
          !_isDismissed);

  void recordLiveSuccess(DateTime now) {
    final normalized = now.toUtc();
    final changed =
        _isShowingCachedData ||
        _isDeviceOffline ||
        _isDismissed ||
        _lastSyncedAt != normalized;
    _isShowingCachedData = false;
    _isDeviceOffline = false;
    _isDismissed = false;
    _lastSyncedAt = normalized;
    if (changed) {
      notifyListeners();
    }
  }

  void recordCacheFallback(DateTime savedAt) {
    final normalized = savedAt.toUtc();
    final transitionedFromOnline = !_isShowingCachedData;
    final nextDismissed = transitionedFromOnline ? false : _isDismissed;
    final changed =
        !_isShowingCachedData ||
        _lastSyncedAt != normalized ||
        _isDismissed != nextDismissed;
    _isShowingCachedData = true;
    _lastSyncedAt = normalized;
    _isDismissed = nextDismissed;
    if (changed) {
      notifyListeners();
    }
  }

  void setDeviceOffline(bool offline) {
    if (_isDeviceOffline == offline) return;
    _isDeviceOffline = offline;
    if (offline) {
      _isDismissed = false;
    }
    notifyListeners();
  }

  void setPendingMutationCount(int count) {
    final normalized = count < 0 ? 0 : count;
    final increased = normalized > _pendingMutationCount;
    if (_pendingMutationCount == normalized && (!increased || !_isDismissed)) {
      return;
    }
    _pendingMutationCount = normalized;
    if (increased) {
      _isDismissed = false;
    }
    notifyListeners();
  }

  void setSyncing(bool syncing) {
    if (_isSyncing == syncing) return;
    _isSyncing = syncing;
    notifyListeners();
  }

  void notifyDataSynced() {
    _syncRevision += 1;
    notifyListeners();
  }

  void dismissBanner() {
    if (_isDismissed) return;
    _isDismissed = true;
    notifyListeners();
  }

  void reset() {
    if (!_isShowingCachedData &&
        _lastSyncedAt == null &&
        !_isDismissed &&
        !_isDeviceOffline &&
        !_isSyncing &&
        _pendingMutationCount == 0) {
      return;
    }
    _isShowingCachedData = false;
    _lastSyncedAt = null;
    _isDismissed = false;
    _isDeviceOffline = false;
    _isSyncing = false;
    _pendingMutationCount = 0;
    notifyListeners();
  }
}

/// Dio Interceptor thực hiện Network-First, fallback cache ngoại tuyến cho GET
/// và xếp hàng đợi thao tác ghi ngoại tuyến khi mất mạng.
class ApiCacheInterceptor extends Interceptor {
  ApiCacheInterceptor({
    required this.store,
    this.statusController,
    this.mutationQueue,
    this.isDeviceOffline,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ApiCacheStore store;
  final ApiCacheStatusController? statusController;
  final OfflineMutationQueue? mutationQueue;
  final bool Function()? isDeviceOffline;
  final DateTime Function() _now;
  int _mutationSequence = 0;

  /// Chỉ cache GET JSON thông thường; loại trừ endpoint kiểm tra kết nối, realtime, đăng nhập và token tạm.
  bool isCacheable(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    if (options.responseType != ResponseType.json) return false;

    final path = _normalizePath(options.path);
    if (path.startsWith('/health') ||
        path.startsWith('/realtime') ||
        path.startsWith('/auth')) {
      return false;
    }
    if (path.endsWith('/room-access') || path.contains('/token')) {
      return false;
    }
    if (options.queryParameters.keys.any(
      (k) => k.toLowerCase().contains('token'),
    )) {
      return false;
    }
    final rawUri = options.path.toLowerCase();
    if (rawUri.contains('token=')) {
      return false;
    }
    return true;
  }

  /// Tạo khóa cache cô lập theo hash token xác thực, baseUrl, path và query đã sắp xếp.
  String buildCacheKey(RequestOptions options) => buildCacheKeyFor(
    baseUrl: options.baseUrl,
    path: options.path,
    queryParameters: options.queryParameters,
    authorizationHeader: _extractAuthorization(options),
  );

  String buildCacheKeyFor({
    required String baseUrl,
    required String path,
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    String? authorizationHeader,
  }) {
    final authScope = authorizationHeader == null
        ? 'anon'
        : _fnv1a64Hex(authorizationHeader);
    final normalizedPath = _normalizePath(path);
    final canonicalQuery = _canonicalizeQuery(queryParameters);
    return _fnv1a64Hex(
      '$authScope|$baseUrl|$normalizedPath|$canonicalQuery',
    );
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (isDeviceOffline?.call() != true ||
        options.extra[offlineReplayExtraKey] == true) {
      handler.next(options);
      return;
    }

    if (isCacheable(options)) {
      final cached = await _readCachedSafely(buildCacheKey(options));
      if (cached != null) {
        statusController?.recordCacheFallback(cached.savedAt);
        handler.resolve(_cachedResponse(options, cached));
        return;
      }
    } else if (mutationQueue != null && canQueueOffline(options)) {
      final response = await _enqueueAndBuildOptimisticResponse(options);
      handler.resolve(response);
      return;
    }

    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final nowUtc = _now().toUtc();
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      statusController?.recordLiveSuccess(nowUtc);
    }

    if (isCacheable(response.requestOptions) &&
        statusCode == 200 &&
        response.data is Map &&
        (response.data as Map).containsKey('data')) {
      final key = buildCacheKey(response.requestOptions);
      try {
        await store.write(
          key,
          CachedApiResponse(
            body: response.data,
            savedAt: nowUtc,
            statusCode: statusCode,
          ),
        );
      } catch (_) {
        // Non-fatal: cache write errors must never break API responses.
      }
    }

    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isOfflineOrGatewayFailure(err)) {
      handler.next(err);
      return;
    }

    if (isCacheable(err.requestOptions)) {
      final cached = await _readCachedSafely(buildCacheKey(err.requestOptions));
      if (cached != null) {
        statusController?.recordCacheFallback(cached.savedAt);
        handler.resolve(_cachedResponse(err.requestOptions, cached));
        return;
      }
    } else if (mutationQueue != null && canQueueOffline(err.requestOptions)) {
      final response = await _enqueueAndBuildOptimisticResponse(
        err.requestOptions,
      );
      handler.resolve(response);
      return;
    }

    handler.next(err);
  }

  Future<Response<Object?>> _enqueueAndBuildOptimisticResponse(
    RequestOptions options,
  ) async {
    final nowUtc = _now().toUtc();
    _mutationSequence += 1;
    final mutationId = 'offline-${nowUtc.microsecondsSinceEpoch}-$_mutationSequence';
    final authHeader = _extractAuthorization(options);
    final authScope = authHeader == null ? 'anon' : _fnv1a64Hex(authHeader);

    final safeHeaders = <String, String>{};
    for (final entry in options.headers.entries) {
      final key = entry.key;
      if (key.toLowerCase() == 'authorization') continue;
      if (entry.value != null) {
        safeHeaders[key] = entry.value.toString();
      }
    }

    final mutation = QueuedApiMutation(
      id: mutationId,
      method: options.method.toUpperCase(),
      path: options.path,
      body: options.data,
      queryParameters: Map<String, dynamic>.from(options.queryParameters),
      headers: safeHeaders,
      authScope: authScope,
      createdAt: nowUtc,
    );

    final queue = mutationQueue!;
    await queue.enqueue(mutation);
    final pendingCount = (await queue.listAll()).length;
    statusController?.setPendingMutationCount(pendingCount);

    final optimisticEnvelope = await buildOptimisticEnvelopeAndPatchCache(
      options: options,
      mutationId: mutationId,
      cacheStore: store,
      buildGetCacheKey: (path, query, source) => buildCacheKeyFor(
        baseUrl: source.baseUrl,
        path: path,
        queryParameters: query,
        authorizationHeader: _extractAuthorization(source),
      ),
      nowUtc: nowUtc,
    );

    return Response<Object?>(
      requestOptions: options,
      data: optimisticEnvelope,
      statusCode: 202,
      extra: <String, dynamic>{
        ...options.extra,
        offlineQueuedExtraKey: true,
        apiCacheFromCacheExtraKey: true,
        apiCacheSavedAtExtraKey: nowUtc.toIso8601String(),
      },
    );
  }

  Future<CachedApiResponse?> _readCachedSafely(String key) async {
    try {
      return await store.read(key);
    } catch (_) {
      return null;
    }
  }

  Response<Object?> _cachedResponse(
    RequestOptions options,
    CachedApiResponse cached,
  ) => Response<Object?>(
    requestOptions: options,
    data: cached.body,
    statusCode: cached.statusCode,
    extra: <String, dynamic>{
      ...options.extra,
      apiCacheFromCacheExtraKey: true,
      apiCacheSavedAtExtraKey: cached.savedAt.toIso8601String(),
    },
  );

  bool _isOfflineOrGatewayFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }
    if (error.response != null) {
      return false;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  String _normalizePath(String path) {
    final parsed = Uri.tryParse(path);
    final rawPath = parsed != null && parsed.path.isNotEmpty ? parsed.path : path;
    final stripped = rawPath.replaceAll(RegExp(r'/+$'), '');
    return stripped.isEmpty ? '/' : stripped;
  }

  String _canonicalizeQuery(Map<String, dynamic> params) {
    if (params.isEmpty) return '';
    final keys = params.keys.toList()..sort();
    return keys
        .map((key) => '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent('${params[key]}')}')
        .join('&');
  }

  String? _extractAuthorization(RequestOptions options) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        final raw = entry.value?.toString().trim();
        if (raw != null && raw.isNotEmpty) {
          return raw;
        }
      }
    }
    return null;
  }

  static final BigInt _fnvOffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
  static final BigInt _fnvPrime = BigInt.parse('100000001b3', radix: 16);
  static final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;

  String _fnv1a64Hex(String input) {
    var hash = _fnvOffsetBasis;
    for (final byte in utf8.encode(input)) {
      hash = ((hash ^ BigInt.from(byte)) * _fnvPrime) & _mask64;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
