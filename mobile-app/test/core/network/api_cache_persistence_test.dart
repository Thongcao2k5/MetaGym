import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides? previousHttpOverrides;
  late Map<String, String> persistedStorageValues;

  setUp(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    persistedStorageValues = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(persistedStorageValues);
  });

  tearDown(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  group('Real HTTP + SecureApiCacheStore persistence', () {
    test(
      'persists real HTTP GET responses across server shutdown and cold app restart, then wipes on signOut',
      () async {
        var serverRequests = 0;
        final equipmentPayload = List<Map<String, dynamic>>.generate(
          25,
          (i) => <String, dynamic>{
            'id': 'equip-${i + 1}',
            'name': 'Thiết bị MetaGym số ${i + 1}',
            'muscleGroup': i.isEven ? 'CHEST' : 'BACK',
            'description':
                'Mô tả chi tiết thiết bị tập luyện chuyên nghiệp dòng ${i + 1} '
                'tại hệ thống phòng tập MetaGym với khung thép chịu lực.',
          },
        );

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          try {
            await server.close(force: true);
          } catch (_) {}
        });

        server.listen((HttpRequest request) async {
          serverRequests += 1;
          final path = request.uri.path;
          Object body;
          if (path == '/api/v1/users/me') {
            body = {
              'data': {
                'id': 'member-real-1',
                'email': 'member@metagym.local',
                'fullName': 'Nguyễn Minh Quân',
                'role': 'MEMBER',
                'status': 'ACTIVE',
              },
            };
          } else if (path == '/api/v1/gym-profile') {
            body = {
              'data': {
                'name': 'MetaGym Flagship',
                'hotline': '1900 6868',
              },
            };
          } else if (path == '/api/v1/membership-plans') {
            body = {
              'data': [
                {'id': 'plan-gold', 'name': 'Hạng Vàng 6 Tháng'},
                {'id': 'plan-diamond', 'name': 'Hạng Kim Cương 12 Tháng'},
              ],
            };
          } else if (path == '/api/v1/equipment') {
            body = {'data': equipmentPayload};
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(body));
          await request.response.close();
        });

        final baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
        final config = ApiConfig.fromValues(
          environment: 'local',
          baseUrlOverride: baseUrl,
        );
        const secureStorage = FlutterSecureStorage();

        // Phase 1: Online -> gọi HTTP thật và lưu xuống SecureStorage
        final status1 = ApiCacheStatusController();
        final store1 = SecureApiCacheStore();
        late SessionController session1;
        final client1 = ApiClient(
          config: config,
          accessTokenProvider: () => session1.accessToken,
          cacheStore: store1,
          cacheStatus: status1,
        );
        session1 = SessionController(
          const SecureTokenStorage(),
          AuthApi(client1).loadCurrentUser,
          cachedUserStorage: const SecureCachedUserStorage(),
          onClearCache: client1.clearCache,
        );

        const initialUser = AuthUser(
          id: 'member-real-1',
          email: 'member@metagym.local',
          fullName: 'Nguyễn Minh Quân',
          role: UserRole.member,
          status: 'ACTIVE',
        );
        await session1.authenticate(
          const AuthSession(accessToken: 'real-jwt-abc', user: initialUser),
        );

        await client1.get<AuthUser>('/users/me', decode: AuthUser.fromJson);
        final gym1 = await client1.get<Map<String, dynamic>>(
          '/gym-profile',
          decode: (v) => Map<String, dynamic>.from(v as Map),
        );
        final plans1 = await client1.get<List<Map<String, dynamic>>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
        final equip1 = await client1.get<List<Map<String, dynamic>>>(
          '/equipment',
          decode: (v) => (v as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );

        expect(serverRequests, 4);
        expect(status1.isShowingCachedData, isFalse);
        expect(gym1.data['name'], 'MetaGym Flagship');
        expect(plans1.data.length, 2);
        expect(equip1.data.length, 25);

        final savedEntries = await secureStorage.readAll();
        expect(savedEntries['meta_gym_access_token'], 'real-jwt-abc');
        expect(savedEntries.containsKey('meta_gym_cached_user_v1'), isTrue);
        expect(savedEntries.containsKey('meta_gym_api_cache_v1_index'), isTrue);
        final cacheKeys = savedEntries.keys
            .where((k) => k.startsWith('meta_gym_api_cache_v1:'))
            .toList();
        expect(cacheKeys.length, 4);

        // Phase 2: Tắt hoàn toàn server + khởi tạo app mới với RAM trống
        await server.close(force: true);
        status1.dispose();

        final status2 = ApiCacheStatusController();
        addTearDown(status2.dispose);
        final store2 = SecureApiCacheStore();
        late SessionController session2;
        final client2 = ApiClient(
          config: config,
          accessTokenProvider: () => session2.accessToken,
          cacheStore: store2,
          cacheStatus: status2,
        );
        session2 = SessionController(
          const SecureTokenStorage(),
          AuthApi(client2).loadCurrentUser,
          cachedUserStorage: const SecureCachedUserStorage(),
          onClearCache: client2.clearCache,
          onOfflineSessionRestored: status2.recordCacheFallback,
        );

        await session2.restore();
        expect(session2.status, SessionStatus.authenticated);
        expect(session2.user?.email, 'member@metagym.local');
        expect(session2.accessToken, 'real-jwt-abc');
        expect(status2.shouldShowBanner, isTrue);

        final gym2 = await client2.get<Map<String, dynamic>>(
          '/gym-profile',
          decode: (v) => Map<String, dynamic>.from(v as Map),
        );
        final plans2 = await client2.get<List<Map<String, dynamic>>>(
          '/membership-plans',
          decode: (v) => (v as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
        final equip2 = await client2.get<List<Map<String, dynamic>>>(
          '/equipment',
          decode: (v) => (v as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );

        expect(gym2.data['name'], 'MetaGym Flagship');
        expect(plans2.data.length, 2);
        expect(equip2.data.length, 25);
        expect(equip2.data.last['name'], 'Thiết bị MetaGym số 25');
        expect(status2.shouldShowBanner, isTrue);
        expect(status2.lastSyncedAt, isNotNull);

        // Phase 3: Đăng xuất -> xóa sạch token, user snapshot và toàn bộ API cache
        await session2.signOut();
        final afterSignOut = await secureStorage.readAll();
        expect(afterSignOut.containsKey('meta_gym_access_token'), isFalse);
        expect(afterSignOut.containsKey('meta_gym_cached_user_v1'), isFalse);
        expect(afterSignOut.containsKey('meta_gym_api_cache_v1_index'), isFalse);
        expect(
          afterSignOut.keys.any((k) => k.startsWith('meta_gym_api_cache_v1:')),
          isFalse,
        );

        await expectLater(
          () => client2.get<Map<String, dynamic>>(
            '/gym-profile',
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
      },
    );

    test(
      'SecureApiCacheStore evicts oldest persisted key beyond maxEntries across restart',
      () async {
        const secureStorage = FlutterSecureStorage();
        final now = DateTime.utc(2026, 11, 28, 12, 0, 0);
        final writerStore = SecureApiCacheStore(maxEntries: 2);

        await writerStore.write(
          'k1',
          CachedApiResponse(body: {'data': 'first'}, savedAt: now),
        );
        await writerStore.write(
          'k2',
          CachedApiResponse(body: {'data': 'second'}, savedAt: now),
        );
        await writerStore.write(
          'k3',
          CachedApiResponse(body: {'data': 'third'}, savedAt: now),
        );

        final persisted = await secureStorage.readAll();
        expect(persisted.containsKey('meta_gym_api_cache_v1:k1'), isFalse);
        expect(persisted.containsKey('meta_gym_api_cache_v1:k2'), isTrue);
        expect(persisted.containsKey('meta_gym_api_cache_v1:k3'), isTrue);

        // Đọc lại bằng instance mới hoàn toàn (mô phỏng cold start)
        final readerStore = SecureApiCacheStore(maxEntries: 2);
        expect(await readerStore.read('k1'), isNull);
        expect((await readerStore.read('k2'))?.body, {'data': 'second'});
        expect((await readerStore.read('k3'))?.body, {'data': 'third'});
      },
    );
  });
}
