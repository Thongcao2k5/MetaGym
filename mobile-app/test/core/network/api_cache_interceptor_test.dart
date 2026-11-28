import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';

void main() {
  group('ApiCacheInterceptor & ApiClient cache fallback', () {
    late _QueuedHttpClientAdapter adapter;
    late MemoryApiCacheStore store;
    late ApiCacheStatusController status;
    late List<String> logs;
    late DateTime fakeNow;
    String? currentToken;
    late ApiClient client;

    setUp(() {
      adapter = _QueuedHttpClientAdapter();
      store = MemoryApiCacheStore();
      status = ApiCacheStatusController();
      logs = <String>[];
      fakeNow = DateTime.utc(2026, 11, 28, 10, 0, 0);
      currentToken = 'Bearer-User-A';
      client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
        logger: logs.add,
        accessTokenProvider: () => currentToken,
        cacheStore: store,
        cacheStatus: status,
        cacheNow: () => fakeNow,
      );
    });

    tearDown(() {
      status.dispose();
    });

    test(
      'saves GET JSON response and falls back on network/timeout/503 errors, then clears banner on live recovery',
      () async {
        adapter.enqueueResponse(
          statusCode: 200,
          body: {
            'data': [
              {'id': 'plan-1', 'name': 'Gói Vàng'},
            ],
          },
        );

        final liveResult = await client.get<List<String>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toList(),
        );
        expect(liveResult.data, ['Gói Vàng']);
        expect(status.isShowingCachedData, isFalse);
        expect(status.lastSyncedAt, fakeNow);

        // Lỗi mất mạng -> trả dữ liệu cache
        adapter.enqueueError(
          (opts) => DioException.connectionError(
            requestOptions: opts,
            reason: 'SocketException',
          ),
        );
        final cachedOnOffline = await client.get<List<String>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toList(),
        );
        expect(cachedOnOffline.data, ['Gói Vàng']);
        expect(status.isShowingCachedData, isTrue);
        expect(status.shouldShowBanner, isTrue);
        expect(logs.last, contains('[cached]'));

        // Lỗi timeout -> trả dữ liệu cache
        adapter.enqueueError(
          (opts) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 15),
            requestOptions: opts,
          ),
        );
        final cachedOnTimeout = await client.get<List<String>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toList(),
        );
        expect(cachedOnTimeout.data, ['Gói Vàng']);

        // Lỗi 503 -> trả dữ liệu cache
        adapter.enqueueResponse(
          statusCode: 503,
          body: {
            'error': {'code': 'SERVICE_UNAVAILABLE', 'message': 'Bảo trì'},
          },
        );
        final cachedOn503 = await client.get<List<String>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toList(),
        );
        expect(cachedOn503.data, ['Gói Vàng']);

        // Có mạng lại -> cập nhật dữ liệu mới và tắt trạng thái offline
        fakeNow = DateTime.utc(2026, 11, 28, 10, 5, 0);
        adapter.enqueueResponse(
          statusCode: 200,
          body: {
            'data': [
              {'id': 'plan-1', 'name': 'Gói Kim Cương'},
            ],
          },
        );
        final recovered = await client.get<List<String>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toList(),
        );
        expect(recovered.data, ['Gói Kim Cương']);
        expect(status.isShowingCachedData, isFalse);
        expect(status.shouldShowBanner, isFalse);
        expect(status.lastSyncedAt, fakeNow);
      },
    );

    test('never falls back to cache on 401/403/404/422 errors', () async {
      adapter.enqueueResponse(
        statusCode: 200,
        body: {
          'data': {'name': 'Nguyễn Minh Quân'},
        },
      );
      await client.get<Object?>('/users/me', decode: (v) => v);

      for (final statusCode in const [401, 403, 404, 422]) {
        adapter.enqueueResponse(
          statusCode: statusCode,
          body: {
            'error': {'code': 'ERR_$statusCode', 'message': 'Lỗi nghiệp vụ'},
          },
        );
        await expectLater(
          () => client.get<Object?>('/users/me', decode: (v) => v),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              statusCode,
            ),
          ),
        );
      }
    });

    test(
      'does not cache mutating methods or excluded endpoints (/health, /realtime, /auth, /room-access)',
      () async {
        adapter.enqueueResponse(
          statusCode: 200,
          body: {
            'data': {'ok': true},
          },
        );
        await client.post<Object?>('/workouts', body: {}, decode: (v) => v);
        expect(store.length, 0);

        for (final path in const [
          '/health',
          '/realtime/subscription',
          '/auth/session',
          '/calls/call-1/room-access',
          '/media/signed?token=secret',
        ]) {
          adapter.enqueueResponse(
            statusCode: 200,
            body: {
              'data': {'ok': true},
            },
          );
          await client.get<Object?>(path, decode: (v) => v);
        }
        expect(store.length, 0);
      },
    );

    test(
      'isolates cache keys per Bearer token and canonicalizes query parameter order',
      () async {
        // User A caches with query (?b=2&a=1)
        currentToken = 'token-user-A';
        adapter.enqueueResponse(
          statusCode: 200,
          body: {
            'data': {'owner': 'A'},
          },
        );
        final resA = await client.get<Map<String, dynamic>>(
          '/progress/summary',
          queryParameters: {'b': '2', 'a': '1'},
          decode: (v) => Map<String, dynamic>.from(v as Map),
        );
        expect(resA.data['owner'], 'A');

        // Same user with different query key order (?a=1&b=2) hits User A cache when offline
        adapter.enqueueError(
          (opts) => DioException.connectionError(
            requestOptions: opts,
            reason: 'offline',
          ),
        );
        final resACached = await client.get<Map<String, dynamic>>(
          '/progress/summary',
          queryParameters: {'a': '1', 'b': '2'},
          decode: (v) => Map<String, dynamic>.from(v as Map),
        );
        expect(resACached.data['owner'], 'A');

        // User B offline must NOT read User A's cached data
        currentToken = 'token-user-B';
        adapter.enqueueError(
          (opts) => DioException.connectionError(
            requestOptions: opts,
            reason: 'offline',
          ),
        );
        await expectLater(
          () => client.get<Map<String, dynamic>>(
            '/progress/summary',
            queryParameters: {'a': '1', 'b': '2'},
            decode: (v) => Map<String, dynamic>.from(v as Map),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiExceptionKind.network,
            ),
          ),
        );
        // Raw JWT token must never appear in cache keys
        for (final key in store.keys) {
          expect(key, isNot(contains('token-user-A')));
        }
      },
    );

    test(
      'clearCache empties cached entries and resets status controller',
      () async {
        adapter.enqueueResponse(
          statusCode: 200,
          body: {
            'data': {'weightKg': 72.1},
          },
        );
        await client.get<Object?>('/progress/summary', decode: (v) => v);
        adapter.enqueueError(
          (opts) => DioException.connectionError(
            requestOptions: opts,
            reason: 'offline',
          ),
        );
        await client.get<Object?>('/progress/summary', decode: (v) => v);
        expect(store.length, 1);
        expect(status.isShowingCachedData, isTrue);

        await client.clearCache();
        expect(store.length, 0);
        expect(status.isShowingCachedData, isFalse);
        expect(status.lastSyncedAt, isNull);
      },
    );
  });

  group('MemoryApiCacheStore limits', () {
    test('evicts least-recently-used entry beyond maxEntries and skips oversized payloads', () async {
      final bounded = MemoryApiCacheStore(maxEntries: 2, maxEntryBytes: 120);
      final now = DateTime.utc(2026, 11, 28);

      await bounded.write(
        'k1',
        CachedApiResponse(body: {'data': 'a'}, savedAt: now),
      );
      await bounded.write(
        'k2',
        CachedApiResponse(body: {'data': 'b'}, savedAt: now),
      );
      // Touch k1 so k2 becomes oldest
      expect((await bounded.read('k1'))?.body, {'data': 'a'});

      await bounded.write(
        'k3',
        CachedApiResponse(body: {'data': 'c'}, savedAt: now),
      );
      expect(await bounded.read('k2'), isNull);
      expect((await bounded.read('k1'))?.body, {'data': 'a'});
      expect((await bounded.read('k3'))?.body, {'data': 'c'});

      // Oversized payload is ignored without throwing
      await bounded.write(
        'big',
        CachedApiResponse(
          body: {'data': 'x' * 300},
          savedAt: now,
        ),
      );
      expect(await bounded.read('big'), isNull);
    });
  });
}

class _QueuedHttpClientAdapter implements HttpClientAdapter {
  final List<
    ({
      int? statusCode,
      Object? body,
      DioException Function(RequestOptions)? errorBuilder,
    })
  >
  _queue = [];

  void enqueueResponse({required int statusCode, required Object body}) {
    _queue.add((statusCode: statusCode, body: body, errorBuilder: null));
  }

  void enqueueError(DioException Function(RequestOptions) errorBuilder) {
    _queue.add((statusCode: null, body: null, errorBuilder: errorBuilder));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final next = _queue.removeAt(0);
    if (next.errorBuilder != null) {
      throw next.errorBuilder!(options);
    }
    return ResponseBody.fromString(
      jsonEncode(next.body),
      next.statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
