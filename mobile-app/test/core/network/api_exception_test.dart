import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';

void main() {
  group('ApiException.fromDio', () {
    test('maps 403 to forbidden while preserving the safe API message', () {
      final exception = ApiException.fromDio(
        _responseError(
          403,
          code: 'ACCOUNT_DISABLED',
          message: 'Tài khoản đã bị khóa',
        ),
      );

      expect(exception.kind, ApiExceptionKind.forbidden);
      expect(exception.code, 'ACCOUNT_DISABLED');
      expect(exception.message, 'Tài khoản đã bị khóa');
    });

    test('maps 5xx to server and hides the upstream message', () {
      final exception = ApiException.fromDio(
        _responseError(
          503,
          code: 'DATABASE_UNAVAILABLE',
          message: 'postgres connection string leaked here',
        ),
      );

      expect(exception.kind, ApiExceptionKind.server);
      expect(exception.code, 'DATABASE_UNAVAILABLE');
      expect(exception.message, 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.');
      expect(exception.message, isNot(contains('postgres')));
    });

    test('maps connection failures and timeouts to network', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final exception = ApiException.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/health'),
            type: type,
          ),
        );

        expect(exception.kind, ApiExceptionKind.network, reason: type.name);
        expect(exception.statusCode, isNull, reason: type.name);
      }
    });
  });
}

DioException _responseError(
  int statusCode, {
  required String code,
  required String message,
}) {
  final request = RequestOptions(path: '/test');
  return DioException.badResponse(
    statusCode: statusCode,
    requestOptions: request,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: statusCode,
      data: {
        'error': {
          'code': code,
          'message': message,
          'details': <String, dynamic>{},
        },
      },
    ),
  );
}
