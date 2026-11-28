import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    late _MockHttpClientAdapter adapter;
    late List<String> logs;
    late ApiClient client;

    setUp(() {
      adapter = _MockHttpClientAdapter();
      logs = [];
      client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
        logger: logs.add,
      );
    });

    test('configures base URL, JSON headers, and timeouts centrally', () async {
      adapter.respond(
        statusCode: 200,
        body: {
          'data': {'ok': true},
        },
      );

      await client.get<Object?>('/health', decode: (data) => data);

      final request = adapter.lastRequest!;
      expect(request.baseUrl, 'http://127.0.0.1:3000/api/v1');
      expect(request.connectTimeout, const Duration(seconds: 10));
      expect(request.sendTimeout, const Duration(seconds: 15));
      expect(request.receiveTimeout, const Duration(seconds: 15));
      expect(request.headers[Headers.acceptHeader], Headers.jsonContentType);
      expect(request.contentType, Headers.jsonContentType);
    });

    test('resolves signed media paths only on the configured API host', () {
      expect(
        client.resolveServerPath('/api/v1/media/images/id?signature=abc').host,
        '127.0.0.1',
      );
      expect(
        () => client.resolveServerPath('https://other.test/image'),
        throwsArgumentError,
      );
    });

    test('decodes a successful API envelope and pagination', () async {
      adapter.respond(
        statusCode: 200,
        body: {
          'data': [
            {'id': 'plan-1', 'name': 'Gói tháng'},
          ],
          'pagination': {'page': 1, 'totalItems': 1},
        },
      );

      final result = await client.get<List<String>>(
        '/membership-plans',
        decode: (data) => (data as List<Object?>)
            .map((item) => (item as Map<String, dynamic>)['name'] as String)
            .toList(),
      );

      expect(result.data, ['Gói tháng']);
      expect(result.pagination, {'page': 1, 'totalItems': 1});
    });

    test(
      'maps a 422 response to a validation exception with field details',
      () async {
        adapter.respond(
          statusCode: 422,
          body: {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Dữ liệu đăng nhập không hợp lệ',
              'details': {
                'fields': {
                  'email': ['Email không hợp lệ'],
                },
              },
            },
          },
        );

        await expectLater(
          client.post<Object?>(
            '/auth/sessions',
            body: {'email': 'sai', 'password': 'khong-duoc-log'},
            decode: (data) => data,
          ),
          throwsA(
            isA<ApiException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  ApiExceptionKind.validation,
                )
                .having((error) => error.statusCode, 'statusCode', 422)
                .having((error) => error.code, 'code', 'VALIDATION_ERROR')
                .having(
                  (error) => error.details['fields'],
                  'details.fields',
                  isA<Map<String, dynamic>>(),
                ),
          ),
        );
      },
    );

    test('maps a 401 response to a session-expired exception', () async {
      adapter.respond(
        statusCode: 401,
        body: {
          'error': {
            'code': 'INVALID_SESSION',
            'message': 'Phiên đăng nhập không hợp lệ',
            'details': <String, dynamic>{},
          },
        },
      );

      await expectLater(
        client.get<Object?>('/users/me', decode: (data) => data),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiExceptionKind.sessionExpired,
          ),
        ),
      );
    });

    test(
      'never writes authorization tokens or request bodies to logs',
      () async {
        adapter.respond(
          statusCode: 200,
          body: {
            'data': {'ok': true},
          },
        );

        await client.post<Object?>(
          '/auth/sessions',
          body: {'password': 'mat-khau-bi-mat'},
          headers: {'authorization': 'Bearer access-token-bi-mat'},
          decode: (data) => data,
        );

        final output = logs.join('\n');
        expect(output, isNot(contains('mat-khau-bi-mat')));
        expect(output, isNot(contains('access-token-bi-mat')));
        expect(output, isNot(contains('authorization')));
        expect(output, isNot(contains('password')));
      },
    );

    test('adds a stored bearer token and reports an expired session', () async {
      var expiryNotifications = 0;
      client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
        logger: logs.add,
        accessTokenProvider: () => 'secure-token',
        onSessionExpired: () async => expiryNotifications += 1,
      );
      adapter.respond(
        statusCode: 401,
        body: {
          'error': {
            'code': 'INVALID_SESSION',
            'message': 'Phiên hết hạn',
            'details': <String, dynamic>{},
          },
        },
      );

      await expectLater(
        client.get<Object?>('/users/me', decode: (data) => data),
        throwsA(isA<ApiException>()),
      );

      expect(
        adapter.lastRequest?.headers['authorization'],
        'Bearer secure-token',
      );
      expect(expiryNotifications, 1);
      expect(logs.join('\n'), isNot(contains('secure-token')));
    });

    test('supports PATCH and DELETE with the same response contract', () async {
      adapter.respond(
        statusCode: 200,
        body: {
          'data': {'updated': true},
        },
      );
      final updated = await client.patch<bool>(
        '/users/me',
        body: {'fullName': 'Tên mới'},
        decode: (data) => (data as Map<String, dynamic>)['updated'] as bool,
      );

      expect(updated.data, isTrue);
      expect(adapter.lastRequest?.method, 'PATCH');

      adapter.respond(
        statusCode: 200,
        body: {
          'data': {'deleted': true},
        },
      );
      final deleted = await client.delete<bool>(
        '/ai/conversations/conversation-1',
        decode: (data) => (data as Map<String, dynamic>)['deleted'] as bool,
      );

      expect(deleted.data, isTrue);
      expect(adapter.lastRequest?.method, 'DELETE');
    });

    test('disables local demo mode by default unless explicitly enabled', () {
      final liveClient = ApiClient(
        config: ApiConfig.fromValues(environment: 'local'),
      );
      expect(liveClient.isLocalDemoMode, isFalse);

      final demoClient = ApiClient(
        config: ApiConfig.fromValues(environment: 'local'),
        enableLocalDemoMode: true,
      );
      expect(demoClient.isLocalDemoMode, isTrue);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  ResponseBody? _response;
  RequestOptions? lastRequest;

  void respond({required int statusCode, required Object body}) {
    _response = ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return _response!;
  }

  @override
  void close({bool force = false}) {}
}
