import 'package:dio/dio.dart';

enum ApiExceptionKind {
  network,
  authentication,
  sessionExpired,
  forbidden,
  validation,
  server,
  request,
  invalidResponse,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.details = const {},
  });

  final ApiExceptionKind kind;
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic> details;

  factory ApiException.fromDio(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final error = _errorPayload(exception.response?.data);

    final kind = switch (statusCode) {
      401 when error.code == 'INVALID_CREDENTIALS' =>
        ApiExceptionKind.authentication,
      401 when error.code == 'INVALID_RESET_CODE' =>
        ApiExceptionKind.validation,
      401 => ApiExceptionKind.sessionExpired,
      403 => ApiExceptionKind.forbidden,
      422 => ApiExceptionKind.validation,
      final int code when code >= 500 => ApiExceptionKind.server,
      _ when _isNetworkFailure(exception) => ApiExceptionKind.network,
      _ => ApiExceptionKind.request,
    };

    final fallbackMessage = switch (kind) {
      ApiExceptionKind.network =>
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      ApiExceptionKind.authentication => 'Thông tin đăng nhập không chính xác.',
      ApiExceptionKind.sessionExpired =>
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      ApiExceptionKind.forbidden =>
        'Bạn không có quyền thực hiện thao tác này.',
      ApiExceptionKind.validation => 'Dữ liệu gửi lên không hợp lệ.',
      ApiExceptionKind.server =>
        'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
      _ => 'Yêu cầu không thể thực hiện.',
    };

    return ApiException(
      kind: kind,
      message: kind == ApiExceptionKind.server
          ? fallbackMessage
          : error.message ?? fallbackMessage,
      code: error.code,
      statusCode: statusCode,
      details: error.details,
    );
  }

  @override
  String toString() => 'ApiException($kind, $code, $statusCode)';
}

bool _isNetworkFailure(DioException exception) {
  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.unknown when exception.response == null => true,
    _ => false,
  };
}

({String? code, String? message, Map<String, dynamic> details}) _errorPayload(
  Object? body,
) {
  if (body case {'error': final Map error}) {
    final details = error['details'];
    return (
      code: error['code'] is String ? error['code'] as String : null,
      message: error['message'] is String ? error['message'] as String : null,
      details: details is Map
          ? Map<String, dynamic>.from(details)
          : const <String, dynamic>{},
    );
  }
  return (code: null, message: null, details: const <String, dynamic>{});
}
