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
       );

  ApiClient._(
    this._dio,
    this._logger,
    this._accessTokenProvider,
    this._onSessionExpired,
  );

  final Dio _dio;
  final ApiLogger? _logger;
  final ApiAccessTokenProvider? _accessTokenProvider;
  final ApiSessionExpiredCallback? _onSessionExpired;

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
  }) {
    return _request(
      'POST',
      path,
      decode: decode,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

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

  Future<ApiResult<T>> _request<T>(
    String method,
    String path, {
    required ApiDecoder<T> decode,
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
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
        options: Options(method: method, headers: requestHeaders),
      );
      final result = _decodeResult(response.data, decode);
      _logger?.call('API $method completed (${response.statusCode})');
      return result;
    } on DioException catch (error) {
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
