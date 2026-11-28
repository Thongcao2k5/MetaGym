import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';

const String apiCacheFromCacheExtraKey = 'fromApiCache';
const String apiCacheSavedAtExtraKey = 'apiCacheSavedAt';

/// Trạng thái toàn cục theo dõi ứng dụng đang dùng dữ liệu máy chủ mới hay bản lưu cache.
class ApiCacheStatusController extends ChangeNotifier {
  bool _isShowingCachedData = false;
  DateTime? _lastSyncedAt;
  bool _isDismissed = false;

  bool get isShowingCachedData => _isShowingCachedData;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isDismissed => _isDismissed;
  bool get shouldShowBanner => _isShowingCachedData && !_isDismissed;

  void recordLiveSuccess(DateTime now) {
    final normalized = now.toUtc();
    final changed =
        _isShowingCachedData || _isDismissed || _lastSyncedAt != normalized;
    _isShowingCachedData = false;
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

  void dismissBanner() {
    if (_isDismissed) return;
    _isDismissed = true;
    notifyListeners();
  }

  void reset() {
    if (!_isShowingCachedData && _lastSyncedAt == null && !_isDismissed) {
      return;
    }
    _isShowingCachedData = false;
    _lastSyncedAt = null;
    _isDismissed = false;
    notifyListeners();
  }
}

/// Dio Interceptor thực hiện Network-First kèm fallback cache ngoại tuyến cho các API GET JSON.
class ApiCacheInterceptor extends Interceptor {
  ApiCacheInterceptor({
    required this.store,
    this.statusController,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ApiCacheStore store;
  final ApiCacheStatusController? statusController;
  final DateTime Function() _now;

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
  String buildCacheKey(RequestOptions options) {
    final authHeader = _extractAuthorization(options);
    final authScope = authHeader == null ? 'anon' : _fnv1a64Hex(authHeader);
    final normalizedPath = _normalizePath(options.path);
    final canonicalQuery = _canonicalizeQuery(options.queryParameters);
    return _fnv1a64Hex(
      '$authScope|${options.baseUrl}|$normalizedPath|$canonicalQuery',
    );
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
    if (!isCacheable(err.requestOptions) || !_isOfflineOrGatewayFailure(err)) {
      handler.next(err);
      return;
    }

    final key = buildCacheKey(err.requestOptions);
    CachedApiResponse? cached;
    try {
      cached = await store.read(key);
    } catch (_) {
      cached = null;
    }

    if (cached != null) {
      statusController?.recordCacheFallback(cached.savedAt);
      handler.resolve(
        Response<Object?>(
          requestOptions: err.requestOptions,
          data: cached.body,
          statusCode: cached.statusCode,
          extra: <String, dynamic>{
            ...err.requestOptions.extra,
            apiCacheFromCacheExtraKey: true,
            apiCacheSavedAtExtraKey: cached.savedAt.toIso8601String(),
          },
        ),
      );
      return;
    }

    handler.next(err);
  }

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
