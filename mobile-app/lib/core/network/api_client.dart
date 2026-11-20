import 'dart:async';

import 'package:dio/dio.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';

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
  ApiClient({
    required ApiConfig config,
    ApiLogger? logger,
    ApiAccessTokenProvider? accessTokenProvider,
    ApiSessionExpiredCallback? onSessionExpired,
  }) : this._(
         _createDio(config),
         logger,
         accessTokenProvider,
         onSessionExpired,
         config: config,
       );

  ApiClient.withAdapter({
    required ApiConfig config,
    required HttpClientAdapter adapter,
    ApiLogger? logger,
    ApiAccessTokenProvider? accessTokenProvider,
    ApiSessionExpiredCallback? onSessionExpired,
  }) : this._(
         _createDio(config)..httpClientAdapter = adapter,
         logger,
         accessTokenProvider,
         onSessionExpired,
         config: config,
         isCustomAdapter: true,
       );

  ApiClient._(
    this._dio,
    this._logger,
    this._accessTokenProvider,
    this._onSessionExpired, {
    this.config,
    this.isCustomAdapter = false,
  });

  final Dio _dio;
  final ApiLogger? _logger;
  final ApiAccessTokenProvider? _accessTokenProvider;
  final ApiSessionExpiredCallback? _onSessionExpired;
  final ApiConfig? config;
  final bool isCustomAdapter;

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
      final requestHeaders = Map<String, dynamic>.of(headers ?? const {});
      final token = await _accessTokenProvider?.call();
      final hasAuthorization = requestHeaders.keys.any(
        (key) => key.toLowerCase() == 'authorization',
      );
      if (!hasAuthorization && token != null && token.isNotEmpty) {
        requestHeaders['authorization'] = 'Bearer $token';
      }
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
      _logger?.call('API $method completed (${response.statusCode})');
      return result;
    } on DioException catch (error) {
      if (!isCustomAdapter &&
          config?.environment != AppEnvironment.production &&
          isNetworkFailure(error)) {
        final currentBase = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final candidates = [
          'http://127.0.0.1:3000/api/v1',
          'http://192.168.100.167:3000/api/v1',
          'http://10.0.2.2:3000/api/v1',
        ].where((url) => url != currentBase).toList();

        final requestHeaders = Map<String, dynamic>.of(headers ?? const {});
        final token = await _accessTokenProvider?.call();
        final hasAuthorization = requestHeaders.keys.any(
          (key) => key.toLowerCase() == 'authorization',
        );
        if (!hasAuthorization && token != null && token.isNotEmpty) {
          requestHeaders['authorization'] = 'Bearer $token';
        }

        for (final candidate in candidates) {
          try {
            _dio.options.baseUrl = candidate;
            final response = await _dio.request<Object?>(
              path,
              data: body,
              queryParameters: queryParameters,
              options: Options(
                method: method,
                headers: requestHeaders,
                receiveTimeout: receiveTimeout,
                sendTimeout: const Duration(seconds: 4),
              ),
            );
            final result = _decodeResult(response.data, decode);
            _logger?.call('API $method fallback to $candidate succeeded (${response.statusCode})');
            return result;
          } catch (_) {
            // Keep trying next candidate
          }
        }
        _dio.options.baseUrl = currentBase;
      }

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
      throw apiException;
    } on ApiException catch (error) {
      _logger?.call('API $method failed (${error.kind.name})');
      rethrow;
    }
  }
}

Dio _createDio(ApiConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.baseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
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
