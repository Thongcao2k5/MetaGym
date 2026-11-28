import 'dart:async';

import 'package:dio/dio.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/network/offline_mutation_policy.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
import 'package:meta_gym_app/core/storage/offline_mutation_queue.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

typedef ApiDecoder<T> = T Function(Object? data);
typedef ApiLogger = void Function(String message);
typedef ApiAccessTokenProvider = FutureOr<String?> Function();
typedef ApiSessionExpiredCallback = FutureOr<void> Function();

class ApiResult<T> {
  const ApiResult({required this.data, this.pagination});

  final T data;
  final Map<String, dynamic>? pagination;
}

class ApiClient {
  static const bool localDemoFromEnvironment = bool.fromEnvironment(
    'ENABLE_LOCAL_DEMO',
    defaultValue: false,
  );

  factory ApiClient({
    required ApiConfig config,
    ApiLogger? logger,
    ApiAccessTokenProvider? accessTokenProvider,
    ApiSessionExpiredCallback? onSessionExpired,
    bool enableLocalDemoMode = localDemoFromEnvironment,
    ApiCacheStore? cacheStore,
    ApiCacheStatusController? cacheStatus,
    OfflineMutationQueue? mutationQueue,
    bool Function()? isDeviceOffline,
    bool enableOfflineCache = true,
  }) {
    final effectiveStore = _resolveCacheStore(
      enableLocalDemoMode: enableLocalDemoMode,
      enableOfflineCache: enableOfflineCache,
      override: cacheStore,
    );
    final effectiveQueue = _resolveMutationQueue(
      enableLocalDemoMode: enableLocalDemoMode,
      enableOfflineCache: enableOfflineCache,
      override: mutationQueue,
    );
    return ApiClient._(
      _createDio(
        config,
        enableLocalDemoMode: enableLocalDemoMode,
        cacheStore: effectiveStore,
        cacheStatus: cacheStatus,
        mutationQueue: effectiveQueue,
        isDeviceOffline: isDeviceOffline,
      ),
      logger,
      accessTokenProvider,
      onSessionExpired,
      effectiveStore,
      cacheStatus,
      effectiveQueue,
      isLocalDemoMode: enableLocalDemoMode,
    );
  }

  ApiClient.withAdapter({
    required ApiConfig config,
    required HttpClientAdapter adapter,
    ApiLogger? logger,
    ApiAccessTokenProvider? accessTokenProvider,
    ApiSessionExpiredCallback? onSessionExpired,
    ApiCacheStore? cacheStore,
    ApiCacheStatusController? cacheStatus,
    OfflineMutationQueue? mutationQueue,
    bool Function()? isDeviceOffline,
    DateTime Function()? cacheNow,
  }) : this._(
         _createDio(
           config,
           cacheStore: cacheStore,
           cacheStatus: cacheStatus,
           mutationQueue: mutationQueue,
           isDeviceOffline: isDeviceOffline,
           cacheNow: cacheNow,
         )..httpClientAdapter = adapter,
         logger,
         accessTokenProvider,
         onSessionExpired,
         cacheStore,
         cacheStatus,
         mutationQueue,
         isLocalDemoMode: false,
       );

  ApiClient._(
    this._dio,
    this._logger,
    this._accessTokenProvider,
    this._onSessionExpired,
    this._cacheStore,
    this._cacheStatus,
    this._mutationQueue, {
    required this.isLocalDemoMode,
  });

  final bool isLocalDemoMode;
  final ApiCacheStore? _cacheStore;
  final ApiCacheStatusController? _cacheStatus;
  final OfflineMutationQueue? _mutationQueue;
  final Dio _dio;
  final ApiLogger? _logger;
  final ApiAccessTokenProvider? _accessTokenProvider;
  final ApiSessionExpiredCallback? _onSessionExpired;

  bool get isOfflineCacheEnabled => _cacheStore != null;
  OfflineMutationQueue? get mutationQueue => _mutationQueue;

  Future<void> clearCache() async {
    await _cacheStore?.clear();
    await _mutationQueue?.clear();
    _cacheStatus?.reset();
  }

  /// Phát lại một thao tác ghi từ hàng đợi ngoại tuyến lên máy chủ bằng token phiên hiện tại.
  Future<void> replayQueuedMutation(QueuedApiMutation mutation) async {
    final method = mutation.method.toUpperCase();
    _logger?.call('API $method started [replay]');
    try {
      await _sendReplayRequest(
        method: method,
        path: mutation.path,
        body: mutation.body,
        queryParameters: mutation.queryParameters,
        headers: mutation.headers,
      );
    } on ApiException catch (error) {
      // Tương thích với máy chủ production (`origin/main`) chưa bật route POST nhiều buổi:
      // tự chuyển về PUT /member/self-training-days/:date nếu mọi bài tập đều có UUID thư viện.
      if (error.statusCode == 404 &&
          method == 'POST' &&
          mutation.path == '/member/self-training-days') {
        final fallback = _buildLegacySelfTrainingPut(mutation);
        if (fallback != null) {
          await _sendReplayRequest(
            method: 'PUT',
            path: fallback.path,
            body: fallback.body,
            queryParameters: const <String, dynamic>{},
            headers: mutation.headers,
          );
          return;
        }
      }
      rethrow;
    }
  }

  Future<void> _sendReplayRequest({
    required String method,
    required String path,
    required Object? body,
    required Map<String, dynamic> queryParameters,
    required Map<String, String> headers,
  }) async {
    try {
      final requestHeaders = await _buildRequestHeaders(headers);
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: requestHeaders,
          extra: const <String, dynamic>{offlineReplayExtraKey: true},
        ),
      );
      _logger?.call('API $method completed (${response.statusCode}) [replay]');
    } on DioException catch (error) {
      throw await _mapAndReportDioError(method, error);
    }
  }

  ({String path, Map<String, dynamic> body})? _buildLegacySelfTrainingPut(
    QueuedApiMutation mutation,
  ) {
    final body = mutation.body;
    if (body is! Map) return null;
    final planDate = body['planDate']?.toString().trim();
    final exercisesRaw = body['exercises'];
    if (planDate == null || planDate.isEmpty || exercisesRaw is! List) {
      return null;
    }
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    final exerciseIds = <String>[];
    for (final item in exercisesRaw) {
      if (item is! Map) return null;
      final id = item['id']?.toString().trim() ?? '';
      if (!uuidRegex.hasMatch(id)) {
        return null;
      }
      exerciseIds.add(id);
    }
    if (exerciseIds.isEmpty) return null;
    return (
      path: '/member/self-training-days/${Uri.encodeComponent(planDate)}',
      body: <String, dynamic>{
        'title': (body['title']?.toString() ?? 'Buổi tự tập').trim(),
        'startTime': body['startTime'],
        'notes': (body['notes']?.toString() ?? '').trim(),
        'exerciseIds': exerciseIds,
      },
    );
  }

  Uri resolveServerPath(String path) {
    final uri = Uri.parse(path);
    if (uri.hasScheme || uri.hasAuthority || !path.startsWith('/')) {
      throw ArgumentError.value(
        path,
        'path',
        'Cần đường dẫn tương đối cùng máy chủ',
      );
    }
    return Uri.parse(_dio.options.baseUrl).resolveUri(uri);
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    required ApiDecoder<T> decode,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) {
    return _request(
      'GET',
      path,
      decode: decode,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    required ApiDecoder<T> decode,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? receiveTimeout,
  }) {
    return _request(
      'POST',
      path,
      decode: decode,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
      receiveTimeout: receiveTimeout,
    );
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    required ApiDecoder<T> decode,
    required Object body,
  }) => _request('PUT', path, decode: decode, body: body);

  Future<ApiResult<T>> patch<T>(
    String path, {
    required ApiDecoder<T> decode,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) {
    return _request(
      'PATCH',
      path,
      decode: decode,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    required ApiDecoder<T> decode,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) {
    return _request(
      'DELETE',
      path,
      decode: decode,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<List<int>?> getBytes(String path) async {
    try {
      final token = await _accessTokenProvider?.call();
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['authorization'] = 'Bearer $token';
      }
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes, headers: headers),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildRequestHeaders(
    Map<String, dynamic>? headers,
  ) async {
    final requestHeaders = Map<String, dynamic>.of(headers ?? const {});
    final token = await _accessTokenProvider?.call();
    final hasAuthorization = requestHeaders.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
    if (!hasAuthorization && token != null && token.isNotEmpty) {
      requestHeaders['authorization'] = 'Bearer $token';
    }
    return requestHeaders;
  }

  Future<ApiException> _mapAndReportDioError(
    String method,
    DioException error,
  ) async {
    final apiException = ApiException.fromDio(error);
    if (apiException.kind == ApiExceptionKind.sessionExpired) {
      try {
        await _onSessionExpired?.call();
      } catch (_) {
        // Session cleanup must not replace the original API exception.
      }
    }
    _logger?.call(
      'API $method failed (${apiException.statusCode ?? 'network'}; '
      '${apiException.kind.name})',
    );
    return apiException;
  }

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    required ApiDecoder<T> decode,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? receiveTimeout,
  }) async {
    _logger?.call('API $method started');
    try {
      final requestHeaders = await _buildRequestHeaders(headers);
      final response = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: requestHeaders,
          receiveTimeout: receiveTimeout,
        ),
      );
      final result = _decodeResult(response.data, decode);
      final cachedSuffix = response.extra[apiCacheFromCacheExtraKey] == true
          ? ' [cached]'
          : '';
      _logger?.call(
        'API $method completed (${response.statusCode})$cachedSuffix',
      );
      return result;
    } on DioException catch (error) {
      throw await _mapAndReportDioError(method, error);
    } on ApiException catch (error) {
      _logger?.call('API $method failed (${error.kind.name})');
      rethrow;
    }
  }
}

ApiCacheStore? _resolveCacheStore({
  required bool enableLocalDemoMode,
  required bool enableOfflineCache,
  ApiCacheStore? override,
}) {
  if (enableLocalDemoMode || !enableOfflineCache) return null;
  if (override != null) return override;
  return MetaGymTheme.isFlutterTestEnvironment ? null : SecureApiCacheStore();
}

OfflineMutationQueue? _resolveMutationQueue({
  required bool enableLocalDemoMode,
  required bool enableOfflineCache,
  OfflineMutationQueue? override,
}) {
  if (enableLocalDemoMode || !enableOfflineCache) return null;
  if (override != null) return override;
  return MetaGymTheme.isFlutterTestEnvironment
      ? null
      : SecureOfflineMutationQueue();
}

Dio _createDio(
  ApiConfig config, {
  bool enableLocalDemoMode = false,
  ApiCacheStore? cacheStore,
  ApiCacheStatusController? cacheStatus,
  OfflineMutationQueue? mutationQueue,
  bool Function()? isDeviceOffline,
  DateTime Function()? cacheNow,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  if (enableLocalDemoMode) {
    dio.interceptors.add(LocalDemoInterceptor());
  } else if (cacheStore != null) {
    dio.interceptors.add(
      ApiCacheInterceptor(
        store: cacheStore,
        statusController: cacheStatus,
        mutationQueue: mutationQueue,
        isDeviceOffline: isDeviceOffline,
        now: cacheNow,
      ),
    );
  }
  return dio;
}

ApiResult<T> _decodeResult<T>(Object? body, ApiDecoder<T> decode) {
  if (body is! Map || !body.containsKey('data')) {
    throw const ApiException(
      kind: ApiExceptionKind.invalidResponse,
      message: 'Máy chủ trả về dữ liệu không hợp lệ.',
    );
  }

  final pagination = body['pagination'];
  if (pagination != null && pagination is! Map) {
    throw const ApiException(
      kind: ApiExceptionKind.invalidResponse,
      message: 'Máy chủ trả về thông tin phân trang không hợp lệ.',
    );
  }

  try {
    return ApiResult(
      data: decode(body['data']),
      pagination: pagination == null
          ? null
          : Map<String, dynamic>.from(pagination),
    );
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException(
      kind: ApiExceptionKind.invalidResponse,
      message: 'Máy chủ trả về dữ liệu không đúng định dạng.',
    );
  }
}
