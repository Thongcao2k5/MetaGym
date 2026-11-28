import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/offline_sync_manager.dart';
import 'package:meta_gym_app/core/storage/api_cache_store.dart';
import 'package:meta_gym_app/core/storage/offline_mutation_queue.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_api.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/nutrition_tracking_api.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline mutation outbox + automatic sync', () {
    late _FakeServerAdapter adapter;
    late MemoryApiCacheStore cacheStore;
    late MemoryOfflineMutationQueue mutationQueue;
    late ApiCacheStatusController statusController;
    late StreamController<List<ConnectivityResult>> connectivityController;
    late SessionController sessionController;
    late ApiClient client;
    late OfflineSyncManager syncManager;
    late DateTime fakeNow;
    int refreshCalls = 0;

    const testUser = AuthUser(
      id: 'u-1',
      email: 'member@metagym.local',
      fullName: 'Minh Quân',
      role: UserRole.member,
      status: 'ACTIVE',
      profile: {'heightCm': 174},
    );

    setUp(() async {
      adapter = _FakeServerAdapter();
      cacheStore = MemoryApiCacheStore();
      mutationQueue = MemoryOfflineMutationQueue();
      statusController = ApiCacheStatusController();
      connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      fakeNow = DateTime.utc(2026, 11, 28, 13, 0, 0);
      refreshCalls = 0;

      client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
        accessTokenProvider: () => 'live-jwt-token',
        cacheStore: cacheStore,
        cacheStatus: statusController,
        mutationQueue: mutationQueue,
        isDeviceOffline: () => statusController.isDeviceOffline,
        cacheNow: () => fakeNow,
      );

      sessionController = SessionController(
        _MemoryTokenStorage(),
        (_) async => testUser,
        onClearCache: client.clearCache,
      );
      await sessionController.authenticate(
        const AuthSession(accessToken: 'live-jwt-token', user: testUser),
      );

      syncManager = OfflineSyncManager(
        apiClient: client,
        mutationQueue: mutationQueue,
        statusController: statusController,
        sessionController: sessionController,
        connectivityStream: connectivityController.stream,
        enableAutoSync: false,
        onRefreshControllers: () async {
          refreshCalls += 1;
        },
        now: () => fakeNow,
      );
      await syncManager.start();
    });

    tearDown(() async {
      syncManager.dispose();
      statusController.dispose();
      await connectivityController.close();
    });

    test(
      'queues safe mutations offline, updates cached GET immediately, and auto-replays FIFO when connectivity returns',
      () async {
        // 1. Nạp sẵn cache GET khi còn online
        adapter.offline = false;
        final profileApi = ProfileApi(client);
        final nutritionApi = NutritionTrackingApi(client);
        final selfTrainingApi = MemberSelfTrainingApi(client);
        final measurementApi = MemberMeasurementApi(client);
        final journalApi = MemberJournalApi(client);

        final onlineUser = await profileApi.getProfile();
        expect(onlineUser.fullName, 'Minh Quân');
        final onlineDay = await nutritionApi.day('2026-11-28');
        expect((onlineDay['entries'] as List), isEmpty);
        expect(await measurementApi.getPage(1), isEmpty);
        expect(await journalApi.getPage(1), isEmpty);

        // 2. Chuyển sang Offline tức thời -> thao tác vẫn thành công & phản ánh ngay vào cache
        connectivityController.add(const [ConnectivityResult.none]);
        await pumpEventQueue();
        expect(statusController.isDeviceOffline, isTrue);

        final updatedOfflineUser = await profileApi.updateProfile({
          'fullName': 'Minh Quân (Offline)',
          'fitnessGoal': 'Tăng cơ',
        });
        expect(updatedOfflineUser.fullName, 'Minh Quân (Offline)');
        expect(updatedOfflineUser.profile['fitnessGoal'], 'Tăng cơ');

        await nutritionApi.add({
          'eatenAt': '2026-11-28T12:00:00+07:00',
          'mealType': 'LUNCH',
          'mealName': 'Ức gà áp chảo',
          'quantity': 150,
          'unit': 'g',
        });

        final offlineMeasurement = await measurementApi.create({
          'measuredAt': '2026-11-28T12:15:00Z',
          'weightKg': 72.5,
        });
        expect(offlineMeasurement.weightKg, 72.5);

        final offlineJournal = await journalApi.create({
          'journalDate': '2026-11-28',
          'notes': 'Tập tốt khi mất mạng',
          'achievements': [
            {'title': 'Squat', 'result': '100kg'},
          ],
          'photoMediaIds': const <String>[],
        });
        expect(offlineJournal.notes, 'Tập tốt khi mất mạng');

        final offlineSelfTraining = await selfTrainingApi.save(
          day: '2026-11-28',
          title: 'Upper Offline',
          startTime: '18:00',
          notes: 'Ghi chú',
          exercises: const [
            SelfTrainingExercise(
              id: 'ex-1',
              name: 'Bench Press',
              sets: 4,
              reps: '8',
            ),
          ],
        );
        expect(offlineSelfTraining.title, 'Upper Offline');

        // Hàng đợi có 5 thao tác FIFO và cache GET đọc lại thấy ngay dữ liệu mới
        expect(statusController.pendingMutationCount, 5);
        expect((await mutationQueue.listAll()).length, 5);
        expect((await profileApi.getProfile()).fullName, 'Minh Quân (Offline)');
        final cachedDayAfterAdd = await nutritionApi.day('2026-11-28');
        expect((cachedDayAfterAdd['entries'] as List).length, 1);
        expect((await measurementApi.getPage(1)).length, 1);
        expect((await journalApi.getPage(1)).length, 1);
        expect(adapter.recordedMutations, isEmpty);

        // 3. Có mạng lại -> OfflineSyncManager tự động replay theo đúng thứ tự FIFO + refresh UI
        adapter.offline = false;
        fakeNow = DateTime.utc(2026, 11, 28, 13, 5, 0);
        connectivityController.add(const [ConnectivityResult.wifi]);
        await _pumpUntil(
          () => statusController.syncRevision > 0 && !statusController.isSyncing,
        );

        expect(statusController.isDeviceOffline, isFalse);
        expect(statusController.pendingMutationCount, 0);
        expect(statusController.isSyncing, isFalse);
        expect(statusController.shouldShowBanner, isFalse);
        expect(statusController.syncRevision, greaterThan(0));
        expect(refreshCalls, 1);
        expect(await mutationQueue.listAll(), isEmpty);

        expect(adapter.recordedMutations.map((m) => '${m.method} ${m.path}'), [
          'PATCH /users/me',
          'POST /member/nutrition/entries',
          'POST /body-measurements',
          'POST /journal',
          'PUT /member/self-training-days/2026-11-28',
        ]);
      },
    );

    test(
      'never queues sensitive endpoints or binary uploads while offline',
      () async {
        connectivityController.add(const [ConnectivityResult.none]);
        await pumpEventQueue();

        final profileApi = ProfileApi(client);
        await expectLater(
          () => profileApi.uploadAvatar(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiExceptionKind.network,
            ),
          ),
        );

        for (final path in const [
          '/auth/sessions',
          '/password-reset-requests',
          '/payments',
          '/ai-conversations',
          '/calls',
        ]) {
          await expectLater(
            () => client.post<Object?>(
              path,
              body: const {'sample': true},
              decode: (v) => v,
            ),
            throwsA(
              isA<ApiException>().having(
                (e) => e.kind,
                'kind',
                ApiExceptionKind.network,
              ),
            ),
          );
        }

        expect(await mutationQueue.listAll(), isEmpty);
        expect(statusController.pendingMutationCount, 0);
      },
    );

    test(
      'drops non-retryable 422 item during replay and retries temporary 503',
      () async {
        connectivityController.add(const [ConnectivityResult.none]);
        await pumpEventQueue();

        await client.post<Object?>(
          '/journal',
          body: const {'journalDate': '2026-11-28', 'badField': true},
          decode: (v) => v,
        );
        await client.patch<Object?>(
          '/users/me',
          body: const {'fullName': 'Tên hợp lệ'},
          decode: (v) => v,
        );
        expect((await mutationQueue.listAll()).length, 2);

        // Quay lại online: item 1 trả 422 (drop), item 2 trả 503 (giữ lại thử sau)
        adapter.offline = false;
        adapter.statusOverrides['POST /journal'] = 422;
        adapter.statusOverrides['PATCH /users/me'] = 503;

        connectivityController.add(const [ConnectivityResult.mobile]);
        await _pumpUntil(
          () => !statusController.isSyncing && adapter.statusOverrides.isNotEmpty && statusController.pendingMutationCount == 1,
        );

        final afterFirstPass = await mutationQueue.listAll();
        expect(afterFirstPass.length, 1);
        expect(afterFirstPass.first.path, '/users/me');
        expect(afterFirstPass.first.retryCount, 1);

        // Server phục hồi 200 -> syncNow() hoàn tất nốt item còn lại
        adapter.statusOverrides.remove('PATCH /users/me');
        final secondReport = await syncManager.syncNow();
        expect(secondReport.syncedCount, 1);
        expect(secondReport.remainingCount, 0);
        expect(statusController.pendingMutationCount, 0);
      },
    );

    test(
      'falls back to legacy PUT /member/self-training-days/:date when POST returns 404 with UUID exercises',
      () async {
        connectivityController.add(const [ConnectivityResult.none]);
        await pumpEventQueue();

        final selfTrainingApi = MemberSelfTrainingApi(client);
        await selfTrainingApi.createSession(
          day: '2026-11-28',
          title: 'Leg Day',
          startTime: '17:30',
          notes: 'Offline UUID',
          exercises: const [
            SelfTrainingExercise(
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Squat',
              sets: 4,
              reps: '10',
            ),
          ],
        );

        adapter.offline = false;
        adapter.statusOverrides['POST /member/self-training-days'] = 404;

        connectivityController.add(const [ConnectivityResult.wifi]);
        await _pumpUntil(
          () => statusController.syncRevision > 0 && !statusController.isSyncing,
        );

        expect(await mutationQueue.listAll(), isEmpty);
        expect(statusController.pendingMutationCount, 0);
        expect(statusController.syncWarningMessage, isNull);
        expect(
          adapter.recordedMutations.map((m) => '${m.method} ${m.path}'),
          ['PUT /member/self-training-days/2026-11-28'],
        );
      },
    );

    test(
      'surfaces warning banner when custom self-training session hits 404 on legacy server',
      () async {
        connectivityController.add(const [ConnectivityResult.none]);
        await pumpEventQueue();

        final selfTrainingApi = MemberSelfTrainingApi(client);
        await selfTrainingApi.createSession(
          day: '2026-11-28',
          title: 'Custom Offline',
          startTime: '18:00',
          notes: 'Manual',
          exercises: const [
            SelfTrainingExercise(
              id: 'custom-1',
              name: 'Push Up',
              sets: 3,
              reps: '15',
            ),
          ],
        );

        adapter.offline = false;
        adapter.statusOverrides['POST /member/self-training-days'] = 404;

        connectivityController.add(const [ConnectivityResult.wifi]);
        await _pumpUntil(
          () => statusController.syncRevision > 0 && !statusController.isSyncing,
        );

        expect(await mutationQueue.listAll(), isEmpty);
        expect(statusController.pendingMutationCount, 0);
        expect(
          statusController.syncWarningMessage,
          contains('Không thể đồng bộ lịch tự tập'),
        );
        expect(statusController.shouldShowBanner, isTrue);
      },
    );
  });

  group('SecureOfflineMutationQueue persistence', () {
    test('persists queued mutations across cold restart and wipes on clear()', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final writer = SecureOfflineMutationQueue();
      await writer.enqueue(
        QueuedApiMutation(
          id: 'mut-1',
          method: 'PATCH',
          path: '/users/me',
          body: const {'fullName': 'Persist User'},
          headers: const {'authorization': 'secret-must-strip', 'x-test': '1'},
          createdAt: DateTime.utc(2026, 11, 28, 12, 0),
        ),
      );

      final reader = SecureOfflineMutationQueue();
      final items = await reader.listAll();
      expect(items.length, 1);
      expect(items.first.id, 'mut-1');
      expect((items.first.body as Map)['fullName'], 'Persist User');

      await reader.clear();
      expect(await SecureOfflineMutationQueue().listAll(), isEmpty);
    });
  });
}

class _FakeServerAdapter implements HttpClientAdapter {
  bool offline = true;
  final Map<String, int> statusOverrides = <String, int>{};
  final List<({String method, String path, Object? body})> recordedMutations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Offline',
      );
    }

    final method = options.method.toUpperCase();
    final key = '$method ${options.path}';
    final override = statusOverrides[key];
    if (override != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'ERR_$override', 'message': 'Error $override'},
        }),
        override,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (method != 'GET') {
      recordedMutations.add((
        method: method,
        path: options.path,
        body: options.data,
      ));
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'ok': true},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    Object payload;
    if (options.path == '/users/me') {
      payload = {
        'id': 'u-1',
        'email': 'member@metagym.local',
        'fullName': 'Minh Quân',
        'role': 'MEMBER',
        'status': 'ACTIVE',
        'profile': {'heightCm': 174},
      };
    } else if (options.path == '/member/nutrition/day') {
      payload = {
        'canWrite': true,
        'hasActiveMembership': true,
        'entries': <Object?>[],
      };
    } else {
      payload = <Object?>[];
    }

    return ResponseBody.fromString(
      jsonEncode({'data': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}

Future<void> _pumpUntil(bool Function() predicate) async {
  for (var i = 0; i < 120; i++) {
    if (predicate()) return;
    await pumpEventQueue(times: 2);
  }
}
