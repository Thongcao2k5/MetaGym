import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Chế độ mô phỏng trạng thái UI toàn app khi chạy Demo Offline.
enum DemoUiStateMode {
  /// Dữ liệu đầy đủ, phản hồi tức thì.
  normal,

  /// Trả về danh sách rỗng để kiểm thử Empty State trên mọi màn hình.
  empty,

  /// Trễ 1.4 giây mỗi request GET để kiểm thử Loading / Skeleton.
  slowLoading,

  /// Giả lập lỗi 503 ở các API dữ liệu để kiểm thử Error Card & Thử lại.
  error,
}

/// Bộ điều khiển toàn cục cho chế độ Demo Offline (dùng chung giữa các màn hình).
abstract final class OfflineDemoControl {
  static final ValueNotifier<DemoUiStateMode> mode =
      ValueNotifier<DemoUiStateMode>(DemoUiStateMode.normal);

  static _LocalDemoStore? _sharedStore;
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'meta_gym_local_demo_state_v7';

  static String modeLabel(DemoUiStateMode value) => switch (value) {
    DemoUiStateMode.normal => 'Bình thường',
    DemoUiStateMode.empty => 'Trống',
    DemoUiStateMode.slowLoading => 'Đang tải',
    DemoUiStateMode.error => 'Lỗi mạng',
  };

  /// Đặt lại toàn bộ dữ liệu mẫu cục bộ về trạng thái ban đầu.
  static Future<void> resetData() async {
    _sharedStore = _LocalDemoStore.seeded();
    mode.value = DemoUiStateMode.normal;
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      try {
        await _storage.write(
          key: _storageKey,
          value: jsonEncode(_sharedStore!.toJson()),
        );
      } catch (_) {}
    }
  }
}

/// Tài khoản test cục bộ được nạp sẵn đầy đủ dữ liệu mẫu để kiểm thử trực tiếp
/// trên thiết bị/máy ảo mà không cần dựng PostgreSQL hay backend.
abstract final class LocalDemoAccounts {
  static const String memberEmail = 'minhquan@metagym.vn';
  static const String coachEmail = 'coach.nam@metagym.vn';
  static const String demoPassword = r'MetaGym@123';

  static const String memberToken = 'local-demo-member-token';
  static const String coachToken = 'local-demo-coach-token';

  static bool isDemoToken(String? token) =>
      token != null && token.startsWith('local-demo-');
}

/// Dio Interceptor cung cấp chế độ Demo Offline 100% không gọi API mạng,
/// dùng chung nguồn dữ liệu cục bộ lưu bền vững trên máy (`FlutterSecureStorage`).
class LocalDemoInterceptor extends Interceptor {
  LocalDemoInterceptor({
    FlutterSecureStorage? storage,
    this.offlineOnly = true,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final bool offlineOnly;
  _LocalDemoStore? _instanceStore;

  Future<_LocalDemoStore> _ensureStore() async {
    if (MetaGymTheme.isFlutterTestEnvironment) {
      _instanceStore ??= _LocalDemoStore.seeded();
      return _instanceStore!;
    }
    if (OfflineDemoControl._sharedStore != null) {
      return OfflineDemoControl._sharedStore!;
    }
    try {
      final raw = await _storage.read(key: OfflineDemoControl._storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          OfflineDemoControl._sharedStore = _LocalDemoStore.fromJson(decoded);
          return OfflineDemoControl._sharedStore!;
        }
      }
    } catch (_) {
      // Fallback to fresh seed if storage is unavailable.
    }
    OfflineDemoControl._sharedStore = _LocalDemoStore.seeded();
    await _persist(OfflineDemoControl._sharedStore!);
    return OfflineDemoControl._sharedStore!;
  }

  Future<void> _persist(_LocalDemoStore store) async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      await _storage.write(
        key: OfflineDemoControl._storageKey,
        value: jsonEncode(store.toJson()),
      );
    } catch (_) {
      // Non-fatal on environments without keystore.
    }
  }

  String? _extractToken(RequestOptions options) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        final value = entry.value?.toString() ?? '';
        if (value.startsWith('Bearer ')) {
          return value.substring(7).trim();
        }
      }
    }
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final method = options.method.toUpperCase();
    final path = options.path;
    final token = _extractToken(options);
    final demoMode = OfflineDemoControl.mode.value;

    // 0. Mô phỏng trạng thái Đang tải (Loading) khi người dùng bật mode slowLoading
    if (demoMode == DemoUiStateMode.slowLoading &&
        method == 'GET' &&
        !MetaGymTheme.isFlutterTestEnvironment) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    }

    // 1. Đăng nhập tài khoản test local (luôn offline khi offlineOnly = true)
    if (method == 'POST' && path == '/auth/sessions') {
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : const <String, dynamic>{};
      final email = (body['email'] as String? ?? '').trim().toLowerCase();
      final password = body['password'] as String? ?? '';
      final store = await _ensureStore();
      var account = store.findAccount(email);
      if (account == null && offlineOnly && email.contains('@')) {
        final isCoachEmail =
            email.contains('coach') || email.contains('hlv');
        account = store.registerMember(
          email: email,
          fullName: isCoachEmail
              ? 'HLV Demo (${email.split('@').first})'
              : 'Hội viên (${email.split('@').first})',
          password: password,
          role: isCoachEmail ? 'COACH' : 'MEMBER',
        );
        await _persist(store);
      }
      if (account != null) {
        if (account['password'] != password) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 401,
                data: const {
                  'error': {
                    'code': 'INVALID_CREDENTIALS',
                    'message':
                        'Email hoặc mật khẩu không đúng (gợi ý test: MetaGym@123).',
                  },
                },
              ),
            ),
          );
        }
        final role = account['role'] as String;
        final demoToken = role == 'COACH'
            ? LocalDemoAccounts.coachToken
            : 'local-demo-member-${account['id']}';
        return _ok(handler, options, {
          'accessToken': demoToken,
          'user': Map<String, dynamic>.from(account)..remove('password'),
        });
      }
      if (!offlineOnly) return handler.next(options);
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 401,
            data: const {
              'error': {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Vui lòng nhập email hợp lệ để đăng nhập demo.',
              },
            },
          ),
        ),
      );
    }

    // 2. Đăng ký tài khoản mới trên local (hỗ trợ mọi email ở chế độ offline)
    if (method == 'POST' && path == '/auth/registrations') {
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : const <String, dynamic>{};
      final email = (body['email'] as String? ?? '').trim().toLowerCase();
      if (offlineOnly ||
          email.endsWith('@metagym.vn') ||
          email.endsWith('@local')) {
        final store = await _ensureStore();
        final fullName = (body['fullName'] as String? ?? 'Hội viên Meta Gym')
            .trim();
        final password = body['password'] as String? ?? '';
        final created = store.registerMember(
          email: email,
          fullName: fullName,
          password: password,
        );
        await _persist(store);
        return _ok(
          handler,
          options,
          Map<String, dynamic>.from(created)..remove('password'),
          statusCode: 201,
        );
      }
      return handler.next(options);
    }

    // 2b. Quên mật khẩu offline (OTP mẫu: 123456)
    if (method == 'POST' && path == '/password-reset-requests') {
      return _ok(handler, options, const {
        'sent': true,
        'message': 'Đã gửi mã OTP demo (nhập 123456 để tiếp tục).',
      });
    }
    if (method == 'POST' && path == '/password-reset-verifications') {
      return _ok(handler, options, const {
        'verified': true,
        'resetToken': 'local-demo-reset-token',
      });
    }
    if (method == 'POST' && path == '/password-resets') {
      return _ok(handler, options, const {'reset': true});
    }

    // 3. Các API cần token: chặn 100% khi offlineOnly = true
    if (!offlineOnly && !LocalDemoAccounts.isDemoToken(token)) {
      return handler.next(options);
    }

    // 3b. Mô phỏng trạng thái Lỗi mạng trên các API dữ liệu (trừ /users/me)
    if (demoMode == DemoUiStateMode.error &&
        method == 'GET' &&
        path != '/users/me' &&
        path != '/calls/incoming') {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            data: const {
              'error': {
                'code': 'DEMO_SIMULATED_ERROR',
                'message':
                    'Chế độ test Lỗi: Mô phỏng sự cố kết nối để kiểm tra giao diện thông báo lỗi và nút Thử lại.',
              },
            },
          ),
        ),
      );
    }

    final store = await _ensureStore();
    final effectiveToken = token ?? LocalDemoAccounts.memberToken;
    final isCoach = effectiveToken == LocalDemoAccounts.coachToken;
    final currentUser = store.userForToken(effectiveToken);

    // 3c. Mô phỏng trạng thái Trống (Empty State) trên các API danh sách / active
    if (demoMode == DemoUiStateMode.empty &&
        method == 'GET' &&
        path != '/users/me' &&
        path != '/gym-profile') {
      final emptyResult = _emptyStateResponse(path);
      if (emptyResult != null) {
        return _ok(handler, options, emptyResult);
      }
    }

    final handled = _dispatch(
      method: method,
      path: path,
      options: options,
      store: store,
      currentUser: currentUser,
      isCoach: isCoach,
    );
    if (handled != null) {
      if (handled.$2 >= 400) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<Object?>(
              requestOptions: options,
              statusCode: handled.$2,
              data: handled.$1,
            ),
          ),
        );
      }
      if (method != 'GET') {
        await _persist(store);
      }
      return _ok(handler, options, handled.$1, statusCode: handled.$2);
    }

    // Fallback an toàn 100% offline cho các endpoint phụ chưa cần dữ liệu riêng
    return _ok(handler, options, method == 'GET' ? const <Object?>[] : const {});
  }

  Object? _emptyStateResponse(String path) {
    const emptyLists = <String>{
      '/memberships/me',
      '/memberships/me/history',
      '/payments/me',
      '/relationships/me/history',
      '/coach-requests/me',
      '/early-termination-requests/me',
      '/coaches',
      '/coach/members',
      '/coach/requests',
      '/training-sessions/me',
      '/coach/training-sessions',
      '/training-plans/me/history',
      '/member/self-training-days',
      '/nutrition-guides/me/history',
      '/meal-plans/me',
      '/member/nutrition/foods',
      '/nutrition-foods',
      '/body-measurements',
      '/journal',
      '/journal/charts',
      '/progress/me/charts',
      '/progress-photos',
      '/workout-logs',
      '/equipment',
      '/exercises',
      '/ai-conversations',
      '/conversations',
      '/calls',
      '/calls/incoming',
      '/coach-bookings',
      '/coach-entitlements',
      '/coach-notifications',
      '/notifications',
    };
    if (emptyLists.contains(path) ||
        path.endsWith('/messages') ||
        path.endsWith('/outcomes')) {
      return const <Object?>[];
    }
    if (path == '/notifications/unread-count') {
      return const {'unreadCount': 0};
    }
    if (path == '/notifications/preferences') {
      return const {
        'workoutRemindersEnabled': true,
        'reminderTime': '17:30',
        'ptBeforeMinutes': 30,
        'nutritionRemindersEnabled': true,
        'coachUpdatesEnabled': true,
        'messagesEnabled': true,
        'callsEnabled': true,
        'adminBroadcastsEnabled': true,
      };
    }
    if (path == '/relationships/me' ||
        path == '/training-plans/me/active' ||
        path == '/nutrition-guides/me/active') {
      return null;
    }
    if (path == '/gym-visits/me') {
      return const {
        'visits': <Object?>[],
        'visitedDays': 0,
        'eligibleDays': 22,
        'entryCount': 0,
      };
    }
    if (path == '/progress/me/summary') {
      return const {
        'workoutCount': 0,
        'mealCount': 0,
        'progressPhotoCount': 0,
        'latestMeasurement': null,
      };
    }
    if (path == '/member/nutrition/day') {
      return {
        'date': _LocalDemoStore._vnTodayStr(),
        'hasActiveMembership': true,
        'canWrite': true,
        'relationshipStatus': 'NONE',
        'plan': null,
        'entries': const <Object?>[],
      };
    }
    return null;
  }

  void _ok(
    RequestInterceptorHandler handler,
    RequestOptions options,
    Object? data, {
    int statusCode = 200,
  }) {
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: statusCode,
        data: <String, dynamic>{'data': data},
      ),
    );
  }

  (Object?, int)? _dispatch({
    required String method,
    required String path,
    required RequestOptions options,
    required _LocalDemoStore store,
    required Map<String, dynamic> currentUser,
    required bool isCoach,
  }) {
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : const <String, dynamic>{};

    // --- Profile ---
    if (path == '/users/me' && method == 'GET') {
      return (Map<String, dynamic>.from(currentUser)..remove('password'), 200);
    }
    if (path == '/users/me' && (method == 'PATCH' || method == 'PUT')) {
      store.updateUser(currentUser['email'] as String, body);
      final updated = store.findAccount(currentUser['email'] as String)!;
      return (Map<String, dynamic>.from(updated)..remove('password'), 200);
    }
    if (path == '/users/me/password' && method == 'PATCH') {
      return (const {'updated': true}, 200);
    }

    // --- Membership & Payments ---
    if (path == '/memberships/me' && method == 'GET') {
      return (<Object?>[store.activeMembership], 200);
    }
    if (path == '/memberships/me/history' && method == 'GET') {
      return (store.membershipHistory, 200);
    }
    if (path == '/membership-plans' && method == 'GET') {
      return (store.membershipPlans, 200);
    }
    if (path.startsWith('/membership-plans/') &&
        path.endsWith('/quote') &&
        method == 'GET') {
      final planId = path
          .substring('/membership-plans/'.length)
          .replaceFirst('/quote', '');
      final plan = store.membershipPlans.firstWhere(
        (item) => item['id'] == planId,
        orElse: () => store.membershipPlans.first,
      );
      final durationDays = (plan['durationDays'] as num?)?.toInt() ?? 30;
      final activeEnd = DateTime.tryParse(
        '${store.activeMembership['endDate'] ?? ''}T00:00:00Z',
      );
      final startDate = (activeEnd ?? DateTime.now()).add(
        const Duration(days: 1),
      );
      final endDate = startDate.add(Duration(days: durationDays));
      return (
        {
          'price': plan['price'],
          'durationDays': durationDays,
          'startDate': _LocalDemoStore._isoDate(startDate),
          'endDate': _LocalDemoStore._isoDate(endDate),
          'isRenewal': true,
        },
        200,
      );
    }
    if (path == '/payments' && method == 'POST') {
      final planId = body['planId'] as String?;
      final plan = store.membershipPlans.firstWhere(
        (item) => item['id'] == planId,
        orElse: () => store.membershipPlans.first,
      );
      final paymentId = 'pay-demo-${DateTime.now().millisecondsSinceEpoch}';
      final created = <String, dynamic>{
        'id': paymentId,
        'status': 'PENDING',
        'planName': plan['name'],
        'amount': plan['price'],
        'method': 'VNPAY',
        'qrPayload': 'VNPAY-METAGYM:$paymentId',
        'transactionCode': 'MG-DEMO-${paymentId.substring(paymentId.length - 4)}',
        'createdAt': DateTime.now().toIso8601String(),
      };
      store.payments.insert(0, created);
      return (created, 201);
    }
    if (path.startsWith('/payments/') &&
        (path.endsWith('/mock-confirmations') ||
            path.endsWith('/zalopay-status') ||
            path.endsWith('/momo-status') ||
            path.endsWith('/vnpay-status')) &&
        method == 'POST') {
      final paymentId = path.split('/')[2];
      final result = store.confirmPayment(paymentId);
      if (path.endsWith('/mock-confirmations')) {
        return (result, 200);
      }
      return (result['payment'], 200);
    }
    if (path.startsWith('/payments/') &&
        path.endsWith('/cancellations') &&
        method == 'POST') {
      final paymentId = path.split('/')[2];
      final payment = store.payments.firstWhere(
        (item) => item['id'] == paymentId,
        orElse: () => store.payments.first,
      );
      payment['status'] = 'CANCELLED';
      return (payment, 200);
    }
    if (path == '/payments/me' && method == 'GET') {
      return (store.payments, 200);
    }
    if (path.startsWith('/payments/') && method == 'GET') {
      final paymentId = path.split('/')[2];
      final payment = store.payments.firstWhere(
        (item) => item['id'] == paymentId,
        orElse: () => store.payments.first,
      );
      return (payment, 200);
    }

    // --- Coaching, Requests, Bookings, Work Slots & Notifications ---
    if (path == '/relationships/me' && method == 'GET') {
      return (store.relationship, 200);
    }
    if (path == '/relationships/me/history' && method == 'GET') {
      return (<Object?>[store.relationship], 200);
    }
    if (path == '/relationships/me/coach-lock-choice' &&
        (method == 'POST' || method == 'PATCH')) {
      return (store.relationship, 200);
    }
    if (path == '/coach-requests/me' && method == 'GET') {
      return (store.coachRequests, 200);
    }
    if (path == '/coach-requests' && method == 'POST') {
      return (store.createCoachRequest(body, currentUser), 201);
    }
    if (path.startsWith('/coach-requests/') && method == 'DELETE') {
      final id = path.split('/')[2];
      store.coachRequests.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }
    if (path == '/early-termination-requests/me' && method == 'GET') {
      return (store.earlyTerminationRequests, 200);
    }
    if (path.startsWith('/relationships/') &&
        path.endsWith('/early-termination-requests') &&
        method == 'POST') {
      final req = <String, dynamic>{
        'id': 'etr-${DateTime.now().millisecondsSinceEpoch}',
        'relationshipId': path.split('/')[2],
        'status': 'PENDING',
        'reason': body['reason'] ?? 'Thay đổi lịch sinh hoạt cá nhân',
        'createdAt': DateTime.now().toIso8601String(),
      };
      store.earlyTerminationRequests.insert(0, req);
      return (req, 201);
    }
    if (path.startsWith('/early-termination-requests/') &&
        path.endsWith('/respond') &&
        (method == 'POST' || method == 'PATCH')) {
      final id = path.split('/')[2];
      for (final req in store.earlyTerminationRequests) {
        if (req['id'] == id) {
          req['status'] = body['decision'] ?? body['status'] ?? 'ACCEPTED';
        }
      }
      return (const {'updated': true}, 200);
    }
    if (path == '/coaches' && method == 'GET') {
      return (store.coaches, 200);
    }
    if (path.startsWith('/coaches/') &&
        path.endsWith('/work-slots') &&
        method == 'GET') {
      return (store.coachWorkSlots, 200);
    }
    if (path.startsWith('/coaches/') &&
        path.endsWith('/outcomes') &&
        method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path.startsWith('/coaches/') && method == 'GET') {
      final id = path.split('/')[2];
      final coach = store.coaches.firstWhere(
        (c) => c['id'] == id,
        orElse: () => store.coaches.first,
      );
      return (coach, 200);
    }
    if (path == '/coach/work-slots' && method == 'PUT') {
      if (body['days'] is List) {
        store.coachWorkSlots['days'] = body['days'];
      }
      return (store.coachWorkSlots, 200);
    }
    if (path == '/coach-bookings' && method == 'GET') {
      return (store.coachBookings, 200);
    }
    if (path == '/coach-bookings/available-slots' && method == 'GET') {
      final date = options.queryParameters['date']?.toString();
      return (store.availableCoachSlots(date), 200);
    }
    if (path == '/coach-entitlements' && method == 'GET') {
      return (store.coachEntitlements, 200);
    }
    if (path == '/coach-bookings/blocks' && method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path == '/coach-bookings' && method == 'POST') {
      final startsAt = (body['startsAt'] ?? body['scheduledAt'])?.toString();
      if (store.isRestOrRecoveryStartsAt(startsAt)) {
        return (
          const {
            'error': {
              'code': 'REST_DAY_BOOKING_NOT_ALLOWED',
              'message':
                  'Ngày đã chọn là ngày nghỉ ngơi hồi phục. Lịch hẹn với Coach bắt buộc phải là ngày tập luyện.',
            },
          },
          409,
        );
      }
      return (store.createCoachBooking(body, currentUser), 201);
    }
    if (path == '/coach-bookings/blocks' && method == 'PUT') {
      return (const {'saved': true}, 200);
    }
    if (path.startsWith('/coach-bookings/') && method == 'PATCH') {
      final id = path.split('/')[2];
      final action = (body['action'] as String? ?? '').toUpperCase();
      if (action == 'RESCHEDULE' &&
          store.isRestOrRecoveryStartsAt(body['startsAt']?.toString())) {
        return (
          const {
            'error': {
              'code': 'REST_DAY_BOOKING_NOT_ALLOWED',
              'message':
                  'Ngày đã chọn là ngày nghỉ ngơi hồi phục. Lịch hẹn với Coach bắt buộc phải là ngày tập luyện.',
            },
          },
          409,
        );
      }
      return (store.updateCoachBooking(id, body), 200);
    }
    if (path == '/coach-notifications' && method == 'GET') {
      return (store.coachNotifications, 200);
    }
    if (path.startsWith('/coach-notifications/') &&
        path.endsWith('/read') &&
        method == 'PATCH') {
      final id = path.split('/')[2];
      final nowIso = DateTime.now().toUtc().toIso8601String();
      for (final n in store.coachNotifications) {
        if (n['id'].toString() == id) {
          n['isRead'] = true;
          n['readAt'] ??= nowIso;
        }
      }
      return ({'id': id, 'readAt': nowIso, 'read': true}, 200);
    }
    if (path == '/notifications' && method == 'GET') {
      final category = (options.queryParameters['category'] as String? ?? 'ALL')
          .toUpperCase();
      final unreadOnly =
          options.queryParameters['unreadOnly']?.toString() == 'true';
      final list = store.coachNotifications.where((n) {
        final itemCategory = (n['category'] as String? ?? 'COACH').toUpperCase();
        if (category != 'ALL' && itemCategory != category) return false;
        if (unreadOnly && n['readAt'] != null) return false;
        return true;
      }).toList();
      return (list, 200);
    }
    if (path == '/notifications/unread-count' && method == 'GET') {
      final unreadCount = store.coachNotifications
          .where((n) => n['readAt'] == null)
          .length;
      return ({'unreadCount': unreadCount}, 200);
    }
    if (path == '/notifications/read-all' && method == 'PATCH') {
      final category = (body['category'] as String? ?? 'ALL').toUpperCase();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      var updated = 0;
      for (final n in store.coachNotifications) {
        final itemCategory = (n['category'] as String? ?? 'COACH').toUpperCase();
        if (category != 'ALL' && itemCategory != category) continue;
        if (n['readAt'] == null) {
          n['readAt'] = nowIso;
          n['isRead'] = true;
          updated++;
        }
      }
      return ({'updatedCount': updated}, 200);
    }
    if (path.startsWith('/notifications/') &&
        path.endsWith('/read') &&
        method == 'PATCH') {
      final id = path.split('/')[2];
      final nowIso = DateTime.now().toUtc().toIso8601String();
      for (final n in store.coachNotifications) {
        if (n['id'].toString() == id) {
          n['readAt'] ??= nowIso;
          n['isRead'] = true;
        }
      }
      return ({'id': id, 'readAt': nowIso}, 200);
    }
    if (path == '/notifications/preferences' && method == 'GET') {
      return (store.notificationPreferences, 200);
    }
    if (path == '/notifications/preferences' && method == 'PUT') {
      store.notificationPreferences
        ..clear()
        ..addAll(body);
      return (store.notificationPreferences, 200);
    }
    if (path == '/notifications/device-tokens' && method == 'POST') {
      return ({'platform': body['platform'] ?? 'ANDROID', 'isActive': true}, 201);
    }
    if (path == '/notifications/device-tokens' && method == 'DELETE') {
      return (const {'removed': true}, 200);
    }
    if (path == '/admin/notifications/broadcasts' && method == 'GET') {
      return (store.adminBroadcasts, 200);
    }
    if (path == '/admin/notifications/broadcast' && method == 'POST') {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final broadcast = <String, dynamic>{
        'id': 'bcast-${DateTime.now().millisecondsSinceEpoch}',
        'title': body['title'] ?? 'Thông báo từ Meta Gym',
        'body': body['body'] ?? '',
        'audience': body['audience'] ?? 'ALL',
        'actionRoute': body['actionRoute'],
        'recipientCount': 2,
        'createdAt': nowIso,
      };
      store.adminBroadcasts.insert(0, broadcast);
      store.coachNotifications.insert(0, {
        'id': '${DateTime.now().millisecondsSinceEpoch}',
        'kind': 'ADMIN_BROADCAST',
        'category': 'SYSTEM',
        'subjectId': broadcast['id'],
        'title': broadcast['title'],
        'body': broadcast['body'],
        'actionRoute': broadcast['actionRoute'],
        'eventAt': nowIso,
        'createdAt': nowIso,
        'readAt': null,
      });
      return (broadcast, 201);
    }
    if (path == '/coach/members' && method == 'GET') {
      return (store.coachMembers, 200);
    }
    if (path.startsWith('/coach/members/') && method == 'GET') {
      final memberId = path.split('/')[3];
      if (path.endsWith('/training-plans/current')) {
        return (store.activeTrainingPlan, 200);
      }
      if (path.endsWith('/training-plans')) {
        return (<Object?>[store.activeTrainingPlan], 200);
      }
      if (path.endsWith('/nutrition-guides')) {
        return (<Object?>[store.activeNutritionGuide], 200);
      }
      if (path.endsWith('/outcomes')) {
        return (const <Object?>[], 200);
      }
      final member = store.coachMembers.firstWhere(
        (m) => m['memberId'] == memberId || m['id'] == memberId,
        orElse: () => store.coachMembers.first,
      );
      return (member, 200);
    }
    if (path.startsWith('/coach/members/') &&
        path.endsWith('/training-plans') &&
        method == 'POST') {
      store.activeTrainingPlan['title'] =
          body['title'] ?? store.activeTrainingPlan['title'];
      store.activeTrainingPlan['notes'] =
          body['notes'] ?? store.activeTrainingPlan['notes'];
      return (store.activeTrainingPlan, 201);
    }
    if (path.startsWith('/coach/members/') &&
        path.endsWith('/nutrition-guides') &&
        method == 'POST') {
      store.activeNutritionGuide['title'] =
          body['title'] ?? store.activeNutritionGuide['title'];
      store.activeNutritionGuide['content'] =
          body['content'] ?? store.activeNutritionGuide['content'];
      return (store.activeNutritionGuide, 201);
    }
    if (path == '/coach/requests' && method == 'GET') {
      return (store.coachRequests, 200);
    }
    if (path.startsWith('/coach/requests/') &&
        (method == 'PATCH' || method == 'POST')) {
      final id = path.split('/')[3];
      return (store.respondCoachRequest(id, body), 200);
    }

    // --- Training Sessions (CRUD cho cả Hội viên và HLV) ---
    if ((path == '/training-sessions/me' ||
            path == '/coach/training-sessions') &&
        method == 'GET') {
      return (store.sessions, 200);
    }
    if ((path == '/training-sessions/me' ||
            path == '/coach/training-sessions') &&
        method == 'POST') {
      return (store.addTrainingSession(body), 201);
    }
    if ((path.startsWith('/training-sessions/') ||
            path.startsWith('/coach/training-sessions/')) &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = path.split('/').last;
      return (store.updateTrainingSession(id, body), 200);
    }
    if ((path.startsWith('/training-sessions/') ||
            path.startsWith('/coach/training-sessions/')) &&
        method == 'DELETE') {
      final id = path.split('/').last;
      store.sessions.removeWhere((s) => s['id'] == id);
      return (const {'deleted': true}, 200);
    }

    // --- Training Plans & Self-Training ---
    if (path == '/training-plans/me/active' && method == 'GET') {
      return (store.activeTrainingPlan, 200);
    }
    if (path == '/training-plans/me/history' && method == 'GET') {
      return (<Object?>[store.activeTrainingPlan], 200);
    }
    if (path.startsWith('/training-plans/') && method == 'GET') {
      return (store.activeTrainingPlan, 200);
    }
    if (path.startsWith('/coach/training-plans/') &&
        (method == 'PATCH' || method == 'PUT' || method == 'POST')) {
      if (body['title'] is String) {
        store.activeTrainingPlan['title'] = body['title'];
      }
      if (body['notes'] is String) {
        store.activeTrainingPlan['notes'] = body['notes'];
      }
      return (store.activeTrainingPlan, 200);
    }
    if (path == '/member/self-training-days' && method == 'GET') {
      final from = options.queryParameters['from'] as String?;
      final to = options.queryParameters['to'] as String?;
      return (store.selfTrainingRange(from: from, to: to), 200);
    }
    if (path == '/member/self-training-days' && method == 'POST') {
      final created = store.createSelfTrainingSession(body);
      return (created, 201);
    }
    if (path.startsWith('/member/self-training-days/sessions/') &&
        (method == 'PUT' || method == 'PATCH')) {
      final id = Uri.decodeComponent(path.split('/').last);
      final updated = store.updateSelfTrainingSession(id, body);
      return updated != null
          ? (updated, 200)
          : (const {'message': 'Không tìm thấy buổi tập.'}, 404);
    }
    if (path.startsWith('/member/self-training-days/sessions/') &&
        method == 'DELETE') {
      final id = Uri.decodeComponent(path.split('/').last);
      store.selfTrainingDays.removeWhere((d) => d['id'] == id);
      return (const {'deleted': true}, 200);
    }
    if (path.startsWith('/member/self-training-days/') &&
        (method == 'PUT' || method == 'PATCH')) {
      final dayKey = Uri.decodeComponent(path.split('/').last);
      return (store.upsertSelfTrainingDay(dayKey, body), 200);
    }
    if (path.startsWith('/member/self-training-days/') && method == 'DELETE') {
      final dayKey = Uri.decodeComponent(path.split('/').last);
      store.selfTrainingDays.removeWhere((d) => d['planDate'] == dayKey);
      return (const {'deleted': true}, 200);
    }

    // --- Gym Visits ---
    if (path == '/gym-visits/me' && method == 'GET') {
      return (store.gymVisitMonth(), 200);
    }
    if (path == '/gym-visits/check-in' && method == 'POST') {
      return (store.addCheckIn(), 201);
    }

    // --- Nutrition (CRUD đầy đủ) ---
    if (path == '/nutrition-guides/me/active' && method == 'GET') {
      return (store.activeNutritionGuide, 200);
    }
    if (path == '/nutrition-guides/me/history' && method == 'GET') {
      return (<Object?>[store.activeNutritionGuide], 200);
    }
    if (path == '/meal-plans/me' && method == 'GET') {
      return (<Object?>[store.coachMealPlan()], 200);
    }
    if (path.startsWith('/coach/nutrition-guides/') &&
        (method == 'PATCH' || method == 'PUT')) {
      if (body['title'] is String) {
        store.activeNutritionGuide['title'] = body['title'];
      }
      if (body['content'] is String) {
        store.activeNutritionGuide['content'] = body['content'];
      }
      return (store.activeNutritionGuide, 200);
    }
    if (path == '/member/nutrition/day' && method == 'GET') {
      final date = options.queryParameters['date'] as String?;
      return (store.nutritionDay(date: date), 200);
    }
    if ((path == '/member/nutrition/foods' || path == '/nutrition-foods') &&
        method == 'GET') {
      return (store.nutritionFoods, 200);
    }
    if (path == '/member/nutrition/entries' && method == 'POST') {
      return (store.addNutritionEntry(body), 201);
    }
    if (path.startsWith('/member/nutrition/entries/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = Uri.decodeComponent(path.split('/').last);
      return (store.updateNutritionEntry(id, body), 200);
    }
    if (path.startsWith('/member/nutrition/entries/') && method == 'DELETE') {
      final id = Uri.decodeComponent(path.split('/').last);
      store.nutritionEntries.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }

    // --- Progress, Measurements, Journal, Photos, Workouts (CRUD đầy đủ) ---
    if (path == '/progress/me/summary' && method == 'GET') {
      return (store.progressSummary(), 200);
    }
    if (path == '/progress/me/charts' && method == 'GET') {
      final from = options.queryParameters['from'] as String?;
      final to = options.queryParameters['to'] as String?;
      return (store.progressCharts(from: from, to: to), 200);
    }
    if (path == '/progress-comments' && method == 'POST') {
      return (
        {
          'id': 'pc-${DateTime.now().millisecondsSinceEpoch}',
          'content': body['content'] ?? '',
          'createdAt': DateTime.now().toIso8601String(),
        },
        201,
      );
    }
    if (path == '/body-measurements' && method == 'GET') {
      return (store.measurements, 200);
    }
    if (path == '/body-measurements' && method == 'POST') {
      return (store.addMeasurement(body), 201);
    }
    if (path.startsWith('/body-measurements/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = path.split('/').last;
      return (store.updateById(store.measurements, id, body), 200);
    }
    if (path.startsWith('/body-measurements/') && method == 'DELETE') {
      final id = path.split('/').last;
      store.measurements.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }
    if (path == '/journal' && method == 'GET') {
      return (store.journalEntries, 200);
    }
    if (path == '/journal' && method == 'POST') {
      return (store.addJournalEntry(body), 201);
    }
    if (path == '/journal/charts' && method == 'GET') {
      return (store.journalCharts(), 200);
    }
    if (path.startsWith('/journal/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = Uri.decodeComponent(path.split('/').last);
      return (store.updateJournalEntry(id, body), 200);
    }
    if (path.startsWith('/journal/') && method == 'DELETE') {
      final id = path.split('/').last;
      store.journalEntries.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }
    if (path == '/progress-photos' && method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path == '/workout-logs' && method == 'GET') {
      return (store.workoutLogs, 200);
    }
    if (path == '/workout-logs' && method == 'POST') {
      return (store.addWorkoutLog(body), 201);
    }
    if (path.startsWith('/workout-logs/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = path.split('/').last;
      return (store.updateById(store.workoutLogs, id, body), 200);
    }
    if (path.startsWith('/workout-logs/') && method == 'DELETE') {
      final id = path.split('/').last;
      store.workoutLogs.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }

    // --- Catalog (hỗ trợ tìm kiếm offline) ---
    if (path == '/equipment' && method == 'GET') {
      final q = (options.queryParameters['search'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (q.isEmpty) return (store.equipment, 200);
      return (
        store.equipment.where((e) {
          final name = (e['name'] as String? ?? '').toLowerCase();
          final cat = (e['category'] as String? ?? '').toLowerCase();
          final muscles = ((e['targetMuscles'] as List?) ?? const [])
              .map((m) => m.toString().toLowerCase())
              .join(' ');
          return name.contains(q) || cat.contains(q) || muscles.contains(q);
        }).toList(),
        200,
      );
    }
    if (path.startsWith('/equipment/') && method == 'GET') {
      final id = path.split('/')[2];
      final item = store.equipment.firstWhere(
        (e) => e['id'] == id,
        orElse: () => store.equipment.first,
      );
      return (item, 200);
    }
    if (path == '/exercises' && method == 'GET') {
      final q = (options.queryParameters['search'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (q.isEmpty) return (store.exercises, 200);
      return (
        store.exercises.where((e) {
          final name = (e['name'] as String? ?? '').toLowerCase();
          final description = (e['description'] as String? ?? '').toLowerCase();
          final muscles = ((e['targetMuscles'] as List?) ?? const [])
              .map((m) => m.toString().toLowerCase())
              .join(' ');
          return name.contains(q) ||
              description.contains(q) ||
              muscles.contains(q);
        }).toList(),
        200,
      );
    }
    if (path == '/gym-profile' && method == 'GET') {
      return (store.gymProfile, 200);
    }

    // --- Media Upload (mô phỏng offline) ---
    if (path == '/media/images' && method == 'POST') {
      return (
        {'id': 'media-demo-${DateTime.now().millisecondsSinceEpoch}'},
        201,
      );
    }
    if (path.startsWith('/media/images/') &&
        path.endsWith('/access-url') &&
        method == 'GET') {
      final id = path.split('/')[3];
      return ({'url': '/api/v1/media/images/$id'}, 200);
    }

    // --- AI Conversations (CRUD + phản hồi mô phỏng theo chuẩn AiAnswerResult) ---
    if (path == '/ai-conversations' && method == 'GET') {
      return (store.aiConversations, 200);
    }
    if (path == '/ai-conversations' && method == 'POST') {
      final title = (body['title'] as String? ?? 'Tư vấn cùng Meta AI').trim();
      return (store.createAiConversation(title), 201);
    }
    if (path.startsWith('/ai-conversations/') && path.endsWith('/messages')) {
      final convId = path.split('/')[2];
      if (method == 'GET') {
        return (store.aiMessages[convId] ?? const <Object?>[], 200);
      }
      if (method == 'POST') {
        final content = (body['content'] as String? ?? '').trim();
        final reqId = body['clientRequestId'] as String?;
        return (store.sendAiMessage(convId, content, requestId: reqId), 201);
      }
    }
    if (path.startsWith('/ai-conversations/') && method == 'PATCH') {
      final convId = path.split('/')[2];
      final title = (body['title'] as String? ?? '').trim();
      return (store.renameAiConversation(convId, title), 200);
    }
    if (path.startsWith('/ai-conversations/') && method == 'DELETE') {
      final convId = path.split('/')[2];
      store.aiConversations.removeWhere((c) => c['id'] == convId);
      store.aiMessages.remove(convId);
      return (const {'deleted': true}, 200);
    }

    // --- Messaging (Chat 2 chiều giữa Hội viên & HLV) ---
    if (path == '/conversations' && method == 'GET') {
      return (store.conversations, 200);
    }
    if (path == '/conversations' && method == 'POST') {
      return (store.conversations.first, 200);
    }
    if (path.startsWith('/conversations/') && path.endsWith('/read-state')) {
      final key = path.split('/')[2];
      for (final c in store.conversations) {
        if (c['id'] == key || c['relationshipId'] == key) {
          c['unreadCount'] = 0;
        }
      }
      return (const {'ok': true}, 200);
    }
    if (path.startsWith('/conversations/') && path.endsWith('/messages')) {
      final key = path.split('/')[2];
      if (method == 'GET') {
        return (store.messagesForConversation(key), 200);
      }
      if (method == 'POST') {
        final content = (body['content'] as String? ?? '').trim();
        final msgType = (body['messageType'] as String? ?? 'TEXT');
        return (
          store.sendDirectMessage(
            key,
            senderId: currentUser['id'] as String,
            content: content.isEmpty && msgType == 'IMAGE' ? 'Ảnh đã gửi' : content,
            messageType: msgType,
            mediaId: body['mediaId'] as String?,
          ),
          201,
        );
      }
    }

    // --- Calls (Cuộc gọi thoại / video mô phỏng offline) ---
    if (path == '/calls' && method == 'GET') {
      return (store.calls, 200);
    }
    if (path == '/calls/incoming' && method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path == '/calls' && method == 'POST') {
      return (store.createCall(body, currentUser), 201);
    }
    if (path.startsWith('/calls/') &&
        path.endsWith('/access-tokens') &&
        method == 'POST') {
      return (
        const {
          'serverUrl': 'wss://offline-demo.metagym.local',
          'accessToken': 'local-demo-livekit-token',
        },
        200,
      );
    }
    if (path.startsWith('/calls/') && method == 'GET') {
      final callId = path.split('/')[2];
      return (store.getCallAndSimulateAnswer(callId), 200);
    }
    if (path.startsWith('/calls/') && method == 'PATCH') {
      final callId = path.split('/')[2];
      return (store.updateCallStatus(callId, body), 200);
    }

    return null;
  }
}

class _LocalDemoStore {
  _LocalDemoStore({
    required this.accounts,
    required this.activeMembership,
    required this.membershipHistory,
    required this.membershipPlans,
    required this.payments,
    required this.relationship,
    required this.coaches,
    required this.coachMembers,
    required this.sessions,
    required this.activeTrainingPlan,
    required this.selfTrainingDays,
    required this.gymVisits,
    required this.activeNutritionGuide,
    required this.nutritionFoods,
    required this.nutritionEntries,
    required this.measurements,
    required this.journalEntries,
    required this.workoutLogs,
    required this.equipment,
    required this.exercises,
    required this.gymProfile,
    required this.aiConversations,
    required this.aiMessages,
    required this.conversations,
    required this.directMessages,
    required this.coachRequests,
    required this.earlyTerminationRequests,
    required this.coachWorkSlots,
    required this.coachEntitlements,
    required this.coachBookings,
    required this.coachNotifications,
    required this.notificationPreferences,
    required this.adminBroadcasts,
    required this.calls,
  });

  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic> activeMembership;
  final List<Map<String, dynamic>> membershipHistory;
  final List<Map<String, dynamic>> membershipPlans;
  final List<Map<String, dynamic>> payments;
  final Map<String, dynamic> relationship;
  final List<Map<String, dynamic>> coaches;
  final List<Map<String, dynamic>> coachMembers;
  final List<Map<String, dynamic>> sessions;
  final Map<String, dynamic> activeTrainingPlan;
  final List<Map<String, dynamic>> selfTrainingDays;
  final List<Map<String, dynamic>> gymVisits;
  final Map<String, dynamic> activeNutritionGuide;
  final List<Map<String, dynamic>> nutritionFoods;
  final List<Map<String, dynamic>> nutritionEntries;
  final List<Map<String, dynamic>> measurements;
  final List<Map<String, dynamic>> journalEntries;
  final List<Map<String, dynamic>> workoutLogs;
  final List<Map<String, dynamic>> equipment;
  final List<Map<String, dynamic>> exercises;
  final Map<String, dynamic> gymProfile;
  final List<Map<String, dynamic>> aiConversations;
  final Map<String, List<Map<String, dynamic>>> aiMessages;
  final List<Map<String, dynamic>> conversations;
  final Map<String, List<Map<String, dynamic>>> directMessages;
  final List<Map<String, dynamic>> coachRequests;
  final List<Map<String, dynamic>> earlyTerminationRequests;
  final Map<String, dynamic> coachWorkSlots;
  final List<Map<String, dynamic>> coachEntitlements;
  final List<Map<String, dynamic>> coachBookings;
  final List<Map<String, dynamic>> coachNotifications;
  final Map<String, dynamic> notificationPreferences;
  final List<Map<String, dynamic>> adminBroadcasts;
  final List<Map<String, dynamic>> calls;

  static int _nutritionEntrySeq = 0;

  static DateTime _vnNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  static String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _vnTodayStr() => _isoDate(_vnNow());

  factory _LocalDemoStore.seeded() {
    final now = _vnNow();
    final todayStr = _isoDate(now);
    final yesterdayStr = _isoDate(now.subtract(const Duration(days: 1)));

    const memberId = '10000000-0000-4000-8000-000000000003';
    const coachId = '10000000-0000-4000-8000-000000000014';
    const relationshipId = '9e1e22d3-75a4-478b-a2d3-d0c2cb824adc';
    const directConvId = '3c799954-da82-47b6-981f-645e128acae9';
    const aiConvId = 'ai-conv-demo-001';

    return _LocalDemoStore(
      accounts: [
        {
          'id': memberId,
          'email': LocalDemoAccounts.memberEmail,
          'password': LocalDemoAccounts.demoPassword,
          'fullName': 'Nguyễn Minh Quân',
          'role': 'MEMBER',
          'status': 'ACTIVE',
          'phone': '0909 123 456',
          'avatarUrl': null,
          'profile': {
            'gender': 'MALE',
            'dateOfBirth': '1998-06-15',
            'heightCm': 176,
            'weightKg': 72.1,
            'fitnessGoal': 'Tăng cơ nạc & Siết mỡ bụng',
            'experienceLevel': 'INTERMEDIATE',
          },
        },
        {
          'id': coachId,
          'email': LocalDemoAccounts.coachEmail,
          'password': LocalDemoAccounts.demoPassword,
          'fullName': 'Lê Hoàng Nam',
          'role': 'COACH',
          'status': 'ACTIVE',
          'phone': '0908 888 222',
          'avatarUrl': null,
          'profile': {
            'specialization': 'Hypertrophy & Body Recomposition',
            'experienceYears': 6,
            'bio':
                'Chuyên gia huấn luyện tăng cơ nạc, chỉnh form compound và dinh dưỡng thể hình.',
          },
        },
      ],
      activeMembership: {
        'id': 'mem-demo-active-001',
        'startDate': _isoDate(now.subtract(const Duration(days: 138))),
        'endDate': _isoDate(now.add(const Duration(days: 41))),
        'status': 'ACTIVE',
        'sourcePaymentId': 'pay-demo-001',
        'planName': 'Hạng Vàng — Pro 6 Tháng',
      },
      membershipHistory: [
        {
          'id': 'mem-demo-expired-000',
          'startDate': _isoDate(now.subtract(const Duration(days: 168))),
          'endDate': _isoDate(now.subtract(const Duration(days: 138))),
          'status': 'EXPIRED',
          'sourcePaymentId': 'pay-demo-000',
          'planName': 'Hạng Đồng — 1 Tháng',
        },
      ],
      membershipPlans: [
        {
          'id': '90000000-0000-4000-8000-000000000033',
          'name': 'Kim Cương VIP',
          'description':
              'Thẻ Kim Cương NFC · InBody không giới hạn · Ưu tiên lịch Coach · 6 buổi PT 1:1',
          'price': 8490000,
          'durationDays': 365,
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000032',
          'name': 'Hạng Vàng — Pro 6 Tháng',
          'description':
              'Thẻ Vàng NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1 · MoMo / ZaloPay / VNPay',
          'price': 4490000,
          'durationDays': 180,
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000031',
          'name': 'Hạng Bạc — Plus',
          'description':
              'Thẻ Bạc NFC · Tập full khung giờ · 1 lần đo InBody & tư vấn lộ trình',
          'price': 2490000,
          'durationDays': 90,
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000030',
          'name': 'Hạng Đồng — Base',
          'description':
              'Thẻ Đồng NFC · Tập không giới hạn khu máy, Cardio & tủ Locker cá nhân',
          'price': 890000,
          'durationDays': 30,
          'status': 'ACTIVE',
        },
      ],
      payments: [
        {
          'id': 'pay-demo-coach-001',
          'status': 'SUCCESS',
          'planName': 'Gói Coach 24 buổi',
          'amount': 8455000,
          'method': 'VNPAY',
          'transactionCode': 'MG-261120',
          'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'confirmedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'membershipId': null,
        },
        {
          'id': 'pay-demo-001',
          'status': 'SUCCESS',
          'planName': 'Hạng Vàng — Pro 6 Tháng',
          'amount': 4290000,
          'method': 'MOMO',
          'transactionCode': 'MG-261022',
          'createdAt': now.subtract(const Duration(days: 32)).toIso8601String(),
          'confirmedAt': now
              .subtract(const Duration(days: 32))
              .toIso8601String(),
          'membershipId': 'mem-demo-active-001',
        },
        {
          'id': 'pay-demo-000',
          'status': 'SUCCESS',
          'planName': 'Hạng Đồng — 1 Tháng',
          'amount': 890000,
          'method': 'MOCK_QR',
          'transactionCode': 'MG-260920',
          'createdAt': now.subtract(const Duration(days: 64)).toIso8601String(),
          'confirmedAt': now
              .subtract(const Duration(days: 64))
              .toIso8601String(),
          'membershipId': 'mem-demo-expired-000',
        },
      ],
      relationship: {
        'id': relationshipId,
        'coachId': coachId,
        'status': 'ACTIVE',
        'coachName': 'Lê Hoàng Nam',
        'coachAvatarUrl': null,
        'startedAt': now.subtract(const Duration(days: 45)).toIso8601String(),
      },
      coaches: [
        {
          'id': coachId,
          'fullName': 'Lê Hoàng Nam',
          'email': LocalDemoAccounts.coachEmail,
          'specialization': 'Hypertrophy & Body Recomposition',
          'experienceYears': 6,
          'rating': 4.9,
          'activeMemberCount': 12,
          'maxMemberCapacity': 20,
          'bio':
              'Chuyên gia huấn luyện tăng cơ nạc, chỉnh form compound và dinh dưỡng thể hình.',
        },
        {
          'id': '10000000-0000-4000-8000-000000000015',
          'fullName': 'Trần Thu Hà',
          'email': 'coach.ha@metagym.vn',
          'specialization': 'Fat Loss, Mobility & Pilates Core',
          'experienceYears': 5,
          'rating': 4.8,
          'activeMemberCount': 10,
          'maxMemberCapacity': 18,
          'bio':
              'Đồng hành siết mỡ an toàn, phục hồi tư thế cột sống và tối ưu thực đơn văn phòng.',
        },
        {
          'id': '10000000-0000-4000-8000-000000000016',
          'fullName': 'Phạm Đức Minh',
          'email': 'coach.minh@metagym.vn',
          'specialization': 'Strength & Powerlifting',
          'experienceYears': 8,
          'rating': 5.0,
          'activeMemberCount': 9,
          'maxMemberCapacity': 15,
          'bio':
              'Huấn luyện viên sức mạnh Squat – Bench – Deadlift, tối ưu chu kỳ tăng tạ.',
        },
      ],
      coachMembers: [
        {
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'memberEmail': LocalDemoAccounts.memberEmail,
          'status': 'ACTIVE',
          'startedAt': now.subtract(const Duration(days: 45)).toIso8601String(),
        },
        {
          'relationshipId': 'rel-demo-002',
          'memberId': '10000000-0000-4000-8000-000000000004',
          'memberName': 'Trần Bảo Ngọc',
          'memberEmail': 'baongoc@metagym.vn',
          'status': 'ACTIVE',
          'startedAt': now.subtract(const Duration(days: 20)).toIso8601String(),
        },
      ],
      sessions: [
        {
          'id': 'sess-demo-001',
          'title': 'PT 1:1 — Ngực & Tay Sau (Bench Press PR)',
          'scheduledStartAt': DateTime(
            now.year,
            now.month,
            now.day,
            18,
            0,
          ).toUtc().toIso8601String(),
          'scheduledEndAt': DateTime(
            now.year,
            now.month,
            now.day,
            19,
            0,
          ).toUtc().toIso8601String(),
          'status': 'SCHEDULED',
          'memberId': memberId,
          'notes': 'Khởi động kỹ khớp vai 10 phút trước buổi tập.',
        },
        {
          'id': 'sess-demo-002',
          'title': 'PT 1:1 — Chân Đùi & Cơ Core',
          'scheduledStartAt': DateTime(
            now.year,
            now.month,
            now.day + 2,
            18,
            0,
          ).toUtc().toIso8601String(),
          'scheduledEndAt': DateTime(
            now.year,
            now.month,
            now.day + 2,
            19,
            0,
          ).toUtc().toIso8601String(),
          'status': 'SCHEDULED',
          'memberId': memberId,
          'notes': 'Kiểm tra form Back Squat 80kg.',
        },
        {
          'id': 'sess-demo-003',
          'title': 'PT 1:1 — Lưng Xô & Tay Trước',
          'scheduledStartAt': DateTime(
            now.year,
            now.month,
            now.day - 2,
            18,
            0,
          ).toUtc().toIso8601String(),
          'scheduledEndAt': DateTime(
            now.year,
            now.month,
            now.day - 2,
            19,
            0,
          ).toUtc().toIso8601String(),
          'status': 'COMPLETED',
          'memberId': memberId,
          'notes': 'Hoàn thành tốt 4 hiệp Lat Pulldown 55kg.',
        },
      ],
      activeTrainingPlan: {
        'id': '90000000-0000-4000-8000-000000000071',
        'relationshipId': relationshipId,
        'coachId': coachId,
        'title': 'Lộ Trình Tăng Cơ Nạc & Siết Cơ 8 Tuần',
        'goal':
            'Tăng 2kg cơ bắp nạc, giảm 3% mỡ cơ thể, xây dựng form chuẩn các động tác compound.',
        'status': 'ACTIVE',
        'version': 1,
        'startDate': todayStr,
        'endDate': _isoDate(now.add(const Duration(days: 56))),
        'publishedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
        'days': [
          {
            'dayNumber': 1,
            'title': 'Ngực & Tay Sau (Push A)',
            'notes': 'Tập trung phát lực từ cơ ngực và kiểm soát nhịp hạ tạ.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000021',
                'exerciseName': 'Barbell Bench Press',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8-10',
                'restSeconds': 90,
                'weightGuidance': '60kg - 70kg',
                'instructions': 'Hạ tạ chậm 2-3s chạm ngực dưới, đẩy dứt khoát.',
                'safetyNotes': 'Khóa cổ tay chắc chắn.',
                'notes': 'Khởi động 2 set nhẹ trước.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000022',
                'exerciseName': 'Incline Dumbbell Press',
                'displayOrder': 2,
                'sets': 4,
                'reps': '10-12',
                'restSeconds': 60,
                'weightGuidance': '20kg/tay',
                'instructions': 'Ghế dốc 30 độ, ép chặt cơ ngực trên ở đỉnh.',
                'safetyNotes': 'Kiểm soát đường đi của tạ.',
                'notes': 'Hít sâu khi hạ tạ.',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 2,
            'title': 'Lưng Xô & Tay Trước (Pull A)',
            'notes': 'Ưỡn ngực kéo vai về sau, gồng chặt xô 1 giây cuối động tác.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000024',
                'exerciseName': 'Lat Pulldown Kéo Xô Mặt Trước',
                'displayOrder': 1,
                'sets': 4,
                'reps': '10-12',
                'restSeconds': 60,
                'weightGuidance': '45kg - 55kg',
                'instructions': 'Kéo tạ xuống ngang xương ức, ép bả vai.',
                'safetyNotes': 'Không dùng đà đu người.',
                'notes': 'Giữ 1 giây siết cơ xô.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000025',
                'exerciseName': 'Dumbbell Bicep Curl',
                'displayOrder': 2,
                'sets': 3,
                'reps': '12',
                'restSeconds': 45,
                'weightGuidance': '12kg/tay',
                'instructions': 'Cuốn tạ cô lập bắp tay trước.',
                'safetyNotes': 'Khép sát cùi chỏ vào thân.',
                'notes': 'Tập chậm từng tay.',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 3,
            'title': 'Chân Đùi & Cơ Bụng (Legs & Core)',
            'notes': 'Khởi động kỹ khớp gối và hông trước khi gánh tạ.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000023',
                'exerciseName': 'Barbell Back Squat',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8',
                'restSeconds': 120,
                'weightGuidance': '70kg - 85kg',
                'instructions': 'Ngồi xổm đùi song song mặt sàn.',
                'safetyNotes': 'Lưng thẳng, không võng lưng.',
                'notes': 'Thắt đai bảo hộ lưng.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000026',
                'exerciseName': 'Plank Siết Cơ Bụng & Core',
                'displayOrder': 2,
                'sets': 3,
                'durationSeconds': 60,
                'restSeconds': 45,
                'weightGuidance': 'Trọng lượng cơ thể',
                'instructions': 'Giữ thân người thẳng tắp, gồng core.',
                'safetyNotes': 'Không võng thắt lưng.',
                'notes': 'Thở đều nhịp nhàng.',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 4,
            'title': 'Vai & Tay Sau (Push B)',
            'notes': 'Ưu tiên kiểm soát khớp vai và biên độ động tác.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000027',
                'exerciseName': 'Seated Dumbbell Shoulder Press',
                'displayOrder': 1,
                'sets': 4,
                'reps': '10',
                'restSeconds': 90,
                'weightGuidance': '16kg/tay',
                'instructions': 'Đẩy tạ qua đầu giữ lưng áp sát ghế.',
                'safetyNotes': 'Không khóa cứng khớp khuỷu tay.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000028',
                'exerciseName': 'Dumbbell Lateral Raise',
                'displayOrder': 2,
                'sets': 3,
                'reps': '15',
                'restSeconds': 45,
                'weightGuidance': '8kg/tay',
                'instructions': 'Nâng ngang ngang vai, hạ chậm có kiểm soát.',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 5,
            'title': 'Lưng Giữa & Core (Pull B)',
            'notes': 'Giữ cột sống trung tính trong suốt các bài kéo.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000029',
                'exerciseName': 'Seated Cable Row',
                'displayOrder': 1,
                'sets': 4,
                'reps': '10-12',
                'restSeconds': 75,
                'weightGuidance': '50kg',
                'instructions': 'Kéo tay cầm về bụng dưới, khép bả vai.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000030',
                'exerciseName': 'Hanging Leg Raise',
                'displayOrder': 2,
                'sets': 3,
                'reps': '12',
                'restSeconds': 45,
                'weightGuidance': 'Trọng lượng cơ thể',
                'instructions': 'Nâng chân kiểm soát không vung người.',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 6,
            'title': 'Mông Đùi Sau & Thể Lực (Legs B)',
            'notes': 'Siết chặt cơ mông đùi sau ở mỗi nhịp hạ hông.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000031',
                'exerciseName': 'Romanian Deadlift (RDL)',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8-10',
                'restSeconds': 105,
                'weightGuidance': '65kg',
                'instructions': 'Đẩy hông ra sau, giữ thanh đòn sát ống chân.',
                'safetyNotes': 'Luôn giữ lưng dưới phẳng.',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000032',
                'exerciseName': 'Dumbbell Walking Lunges',
                'displayOrder': 2,
                'sets': 3,
                'reps': '12/chân',
                'restSeconds': 60,
                'weightGuidance': '12kg/tay',
              },
            ],
            'meals': const <Object?>[],
          },
          {
            'dayNumber': 7,
            'title': 'Phục Hồi Chủ Động & Giãn Cơ',
            'notes': 'Thả lỏng cơ bắp, hỗ trợ tuần hoàn phục hồi cho tuần mới.',
            'exercises': [
              {
                'exerciseId': '90000000-0000-4000-8000-000000000033',
                'exerciseName': 'Foam Rolling & Giãn Cơ Toàn Thân',
                'displayOrder': 1,
                'sets': 1,
                'durationSeconds': 900,
                'weightGuidance': 'Cường độ nhẹ',
              },
              {
                'exerciseId': '90000000-0000-4000-8000-000000000034',
                'exerciseName': 'Đi Bộ Nghiêng Zone 2',
                'displayOrder': 2,
                'sets': 1,
                'durationSeconds': 1500,
                'weightGuidance': 'Nhịp tim 120-135 bpm',
              },
            ],
            'meals': const <Object?>[],
          },
        ],
      },
      selfTrainingDays: [
        {
          'id': 'self-demo-001',
          'planDate': todayStr,
          'title': 'Ngực & Tay sau · Tập tự do',
          'startTime': '18:00',
          'notes': 'Khởi động kỹ khớp vai 10 phút, giữ nhịp hạ tạ 3 giây.',
          'iconKey': 'chest,arms',
          'exercises': [
            {
              'id': '90000000-0000-4000-8000-000000000021',
              'name': 'Barbell Bench Press',
              'sets': 4,
              'reps': '8-10',
            },
            {
              'id': '90000000-0000-4000-8000-000000000022',
              'name': 'Incline Dumbbell Press',
              'sets': 3,
              'reps': '10-12',
            },
            {
              'id': 'self-ex-003',
              'name': 'Cable Triceps Pushdown',
              'sets': 3,
              'reps': '12-15',
            },
          ],
        },
        {
          'id': 'self-demo-002',
          'planDate': _isoDate(now.add(const Duration(days: 2))),
          'title': 'Lưng Xô & Tay trước',
          'startTime': '18:30',
          'notes': 'Kéo xô kiểm soát, giữ 1 giây cuối mỗi rep.',
          'iconKey': 'back,arms',
          'exercises': [
            {
              'id': '90000000-0000-4000-8000-000000000024',
              'name': 'Lat Pulldown Kéo Xô Mặt Trước',
              'sets': 4,
              'reps': '10-12',
            },
            {
              'id': '90000000-0000-4000-8000-000000000025',
              'name': 'Dumbbell Bicep Curl',
              'sets': 3,
              'reps': '12',
            },
          ],
        },
        {
          'id': 'self-demo-003',
          'planDate': _isoDate(now.subtract(const Duration(days: 2))),
          'title': 'Chân Đùi & Cơ Core',
          'startTime': '17:45',
          'notes': 'Hoàn thành 4 hiệp Back Squat form chuẩn.',
          'iconKey': 'legs,core',
          'exercises': [
            {
              'id': '90000000-0000-4000-8000-000000000023',
              'name': 'Barbell Back Squat',
              'sets': 4,
              'reps': '8',
            },
            {
              'id': 'self-ex-core-1',
              'name': 'Plank Core',
              'sets': 3,
              'reps': '60s',
            },
          ],
        },
      ],
      gymVisits: [
        for (final offset in [1, 3, 5, 7, 10])
          {
            'day': _isoDate(now.subtract(Duration(days: offset))),
            'checkedInAt': now
                .subtract(Duration(days: offset))
                .toIso8601String(),
            'gymName': 'Meta Gym Flagship Center',
            'gymAddress': '123 Nguyễn Thị Minh Khai, Quận 1, TP.HCM',
          },
      ],
      activeNutritionGuide: {
        'id': 'nutri-guide-demo-001',
        'title': 'Thực đơn Tăng Cơ Nạc 2.400 kcal/ngày',
        'content':
            'Mục tiêu: 2.400 kcal · 180g Protein · 250g Carbs · 65g Fat.\n'
            '• Uống đủ 3.0 lít nước mỗi ngày.\n'
            '• Bổ sung 30g đạm nhanh trong vòng 45 phút sau tập.',
        'status': 'ACTIVE',
        'version': 1,
        'publishedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      },
      nutritionFoods: [
        {
          'id': 'food-oats',
          'name': 'Yến mạch nguyên cám',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 380,
          'calories': 380,
          'proteinG': 13.5,
          'carbsG': 67,
          'fatG': 6.5,
        },
        {
          'id': 'food-001',
          'name': 'Ức gà áp chảo',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 165,
          'calories': 165,
          'proteinG': 31,
          'carbsG': 0,
          'fatG': 3.6,
        },
        {
          'id': 'food-002',
          'name': 'Cơm gạo lứt',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 123,
          'calories': 123,
          'proteinG': 2.7,
          'carbsG': 26,
          'fatG': 1.0,
        },
        {
          'id': 'food-003',
          'name': 'Cá hồi phi lê áp chảo',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 208,
          'calories': 208,
          'proteinG': 20,
          'carbsG': 0,
          'fatG': 13.4,
        },
        {
          'id': 'food-004',
          'name': 'Whey Protein Isolate',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 380,
          'calories': 380,
          'proteinG': 83,
          'carbsG': 6.5,
          'fatG': 3.0,
        },
        {
          'id': 'food-005',
          'name': 'Khoai lang hấp',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 86,
          'calories': 86,
          'proteinG': 1.6,
          'carbsG': 20,
          'fatG': 0.1,
        },
        {
          'id': 'food-006',
          'name': 'Trứng gà luộc',
          'servingSize': 100,
          'servingUnit': 'g',
          'kcalPer100g': 155,
          'calories': 155,
          'proteinG': 13,
          'carbsG': 1.1,
          'fatG': 11,
        },
      ],
      nutritionEntries: [
        {
          'id': 'entry-001',
          'mealType': 'BREAKFAST',
          'mealName': 'Yến mạch nguyên cám',
          'foodId': 'food-oats',
          'quantity': 80,
          'unit': 'g',
          'kcal': 304,
          'eatenAt': '${todayStr}T07:30:00+07:00',
          'notes': '',
          'imageMediaId': null,
        },
        {
          'id': 'entry-002',
          'mealType': 'LUNCH',
          'mealName': 'Ức gà áp chảo',
          'foodId': 'food-001',
          'quantity': 200,
          'unit': 'g',
          'kcal': 330,
          'eatenAt': '${todayStr}T12:15:00+07:00',
          'notes': '',
          'imageMediaId': null,
        },
        {
          'id': 'entry-003',
          'mealType': 'SNACK',
          'mealName': 'Whey Protein Isolate',
          'foodId': 'food-004',
          'quantity': 30,
          'unit': 'g',
          'kcal': 114,
          'eatenAt': '${todayStr}T16:20:00+07:00',
          'notes': '',
          'imageMediaId': null,
        },
        {
          'id': 'entry-yest-001',
          'mealType': 'BREAKFAST',
          'mealName': 'Trứng gà luộc',
          'foodId': 'food-006',
          'quantity': 150,
          'unit': 'g',
          'kcal': 233,
          'eatenAt': '${yesterdayStr}T07:45:00+07:00',
          'notes': '',
          'imageMediaId': null,
        },
        {
          'id': 'entry-yest-002',
          'mealType': 'LUNCH',
          'mealName': 'Cơm gạo lứt',
          'foodId': 'food-002',
          'quantity': 180,
          'unit': 'g',
          'kcal': 221,
          'eatenAt': '${yesterdayStr}T12:30:00+07:00',
          'notes': '',
          'imageMediaId': null,
        },
      ],
      measurements: [
        {
          'id': 'meas-000a',
          'measuredAt': now
              .subtract(const Duration(days: 28))
              .toIso8601String(),
          'weightKg': 74.9,
          'bodyFatPercent': 20.1,
          'chestCm': 95.5,
          'waistCm': 84.5,
          'hipsCm': 96.0,
          'armCm': 32.0,
          'thighCm': 55.5,
          'notes': 'Buổi đánh giá InBody đầu chu kỳ.',
        },
        {
          'id': 'meas-000b',
          'measuredAt': now
              .subtract(const Duration(days: 21))
              .toIso8601String(),
          'weightKg': 74.3,
          'bodyFatPercent': 19.6,
          'chestCm': 95.8,
          'waistCm': 83.4,
          'hipsCm': 95.5,
          'armCm': 32.2,
          'thighCm': 55.8,
          'notes': 'Nhịp tập ổn định 4 buổi/tuần.',
        },
        {
          'id': 'meas-001',
          'measuredAt': now
              .subtract(const Duration(days: 14))
              .toIso8601String(),
          'weightKg': 73.8,
          'bodyFatPercent': 19.2,
          'chestCm': 96.0,
          'waistCm': 82.5,
          'hipsCm': 95.0,
          'armCm': 32.5,
          'thighCm': 56.0,
          'notes': 'Đo định kỳ đầu tháng cùng Coach Nam.',
        },
        {
          'id': 'meas-002',
          'measuredAt': now.subtract(const Duration(days: 7)).toIso8601String(),
          'weightKg': 72.9,
          'bodyFatPercent': 18.3,
          'chestCm': 97.0,
          'waistCm': 80.5,
          'hipsCm': 94.5,
          'armCm': 33.0,
          'thighCm': 56.0,
          'notes': 'Vòng eo giảm tốt sau tuần ăn thâm hụt calo chuẩn.',
        },
        {
          'id': 'meas-003',
          'measuredAt': now.toIso8601String(),
          'weightKg': 72.1,
          'bodyFatPercent': 17.5,
          'chestCm': 98.0,
          'waistCm': 78.5,
          'hipsCm': 94.0,
          'armCm': 33.8,
          'thighCm': 56.5,
          'notes': 'Cơ ngực và bắp tay nét hơn rõ rệt.',
        },
      ],
      journalEntries: [
        {
          'id': 'jour-002',
          'journalDate': yesterdayStr,
          'notes':
              'Buổi tập Chân & Bụng với Coach Nam. Squat 80kg trọn vẹn 4 hiệp form chuẩn.',
          'chestCm': 98.0,
          'waistCm': 78.5,
          'hipsCm': 94.0,
          'achievements': [
            {'title': 'Squat', 'result': '80 kg × 4 hiệp'},
            {'title': 'Đẩy ngực', 'result': '65 kg × 10'},
          ],
          'photoMediaIds': <String>[],
        },
        {
          'id': 'jour-001',
          'journalDate': _isoDate(now.subtract(const Duration(days: 3))),
          'notes':
              'Buổi tập Ngực & Tay sau hoàn thành xuất sắc! Đẩy Bench Press lên mức 70kg x 8 reps.',
          'chestCm': 97.5,
          'waistCm': 79.5,
          'hipsCm': 94.0,
          'achievements': [
            {'title': 'Đẩy ngực', 'result': '70 kg × 8'},
            {'title': 'Kéo lưng', 'result': '60 kg × 10'},
          ],
          'photoMediaIds': <String>[],
        },
        {
          'id': 'jour-003',
          'journalDate': _isoDate(now.subtract(const Duration(days: 6))),
          'notes': 'Kéo xô kiểm soát nhịp âm, giữ form vai ổn định suốt buổi.',
          'chestCm': 97.0,
          'waistCm': 80.5,
          'hipsCm': 94.5,
          'achievements': [
            {'title': 'Kéo lưng', 'result': '55 kg × 12'},
          ],
          'photoMediaIds': <String>[],
        },
      ],
      workoutLogs: [
        {
          'id': 'wlog-001',
          'loggedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'title': 'Chân Đùi & Core',
          'durationMinutes': 58,
          'caloriesBurned': 420,
          'notes': 'Hoàn thành 100% giáo trình.',
        },
      ],
      equipment: [
        {
          'id': '90000000-0000-4000-8000-000000000011',
          'name': 'Ghế đẩy ngực Bench Press',
          'category': 'Tạ tự do & Kháng lực',
          'targetMuscles': ['Ngực', 'Tay sau', 'Vai trước'],
          'description': 'Ghế đẩy ngực phẳng tiêu chuẩn Olympic.',
          'usageSteps': [
            'Nằm ngửa lưng chạm ghế',
            'Hai chân chạm sàn vững vàng',
            'Nắm thanh đòn rộng hơn vai',
            'Hạ tạ có kiểm soát rồi đẩy dứt khoát lên',
          ],
          'safetyNotes': 'Luôn dùng chốt an toàn khi tập mức tạ nặng.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000012',
          'name': 'Khung gánh tạ Squat Rack',
          'category': 'Tạ tự do',
          'targetMuscles': ['Đùi trước', 'Mông', 'Đùi sau', 'Lưng dưới'],
          'description':
              'Khung tập gánh tạ đa năng tích hợp thanh bảo hộ an toàn.',
          'usageSteps': [
            'Chỉnh thanh đỡ ngang ngực',
            'Đặt đòn lên cầu vai',
            'Gồng core và hạ hông song song sàn',
          ],
          'safetyNotes': 'Không khóa khớp gối ở đỉnh động tác.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000013',
          'name': 'Máy kéo xô Lat Pulldown',
          'category': 'Máy khối',
          'targetMuscles': ['Lưng xô', 'Tay trước'],
          'description':
              'Máy kéo xô cáp chuyên dụng phát triển độ rộng của lưng.',
          'usageSteps': [
            'Chỉnh đệm đùi vừa vặn',
            'Ưỡn ngực kéo thanh đòn xuống xương đòn',
          ],
          'safetyNotes': 'Không dùng đà đu người ra sau.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000014',
          'name': 'Cable Crossover Dual',
          'category': 'Máy cáp',
          'targetMuscles': ['Ngực giữa', 'Vai trước', 'Tay sau'],
          'description':
              'Cụm ròng rọc kép linh hoạt, tối ưu độ căng cơ liên tục ở mọi góc kéo.',
          'usageSteps': [
            'Chỉnh chốt ròng rọc hai bên ngang tầm vai và cài mức tạ phù hợp.',
            'Bước nhẹ một chân lên trước, giữ lưng thẳng và hơi gập khuỷu tay.',
            'Ép hai tay về phía trước ngực, siết cơ 1 giây rồi trả chậm có kiểm soát.',
          ],
          'safetyNotes':
              'Kiểm tra chốt tạ đã cắm chặt trước khi kéo; không thả rơi tạ tự do gây đứt dây cáp.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000015',
          'name': 'Technogym Artis Run',
          'category': 'Cardio',
          'targetMuscles': ['Tim mạch', 'Đùi trước', 'Bắp chân'],
          'description':
              'Máy chạy bộ màn hình cảm ứng tích hợp theo dõi nhịp tim và đốt mỡ.',
          'usageSteps': [
            'Kẹp dây an toàn vào áo trước khi khởi động băng tải.',
            'Bắt đầu đi bộ làm nóng 3 phút rồi tăng tốc độ phù hợp.',
          ],
          'safetyNotes':
              'Đang bảo trì định kỳ băng tải; vui lòng sử dụng máy chạy kế bên.',
          'status': 'MAINTENANCE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001016',
          'name': 'Máy duỗi lưng M3-1016',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Lưng dưới'],
          'description':
              'Máy khối Realleader M3-1016 hỗ trợ tập cơ dựng sống và vùng lưng dưới có kiểm soát.',
          'usageSteps': [
            'Điều chỉnh đệm tựa lưng và chốt tạ phù hợp chiều cao cơ thể.',
            'Ngồi vững, gồng core rồi ngả thân người ra sau theo biên độ an toàn.',
            'Trả người về vị trí ban đầu chậm rãi, giữ kiểm soát dây cáp.',
          ],
          'safetyNotes':
              'Không giật đột ngột phần thắt lưng; chọn mức tạ khởi đầu vừa phải.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001017',
          'name': 'Máy ép ngực / vai sau M3-1017',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Ngực', 'Vai sau'],
          'description':
              'Máy tập hai chức năng Realleader M3-1017 hỗ trợ ép ngực (Pec Fly) và banh vai sau (Rear Delt).',
          'usageSteps': [
            'Chỉnh độ cao ghế và góc tay đòn tương ứng bài ép ngực hoặc vai sau.',
            'Giữ lưng áp sát đệm, kéo hoặc ép tay đòn mượt mà theo cung tròn.',
            'Siết cơ 1 giây ở điểm đỉnh trước khi thả tạ chậm về vị trí mở.',
          ],
          'safetyNotes':
              'Khóa chốt biên độ tay đòn chắc chắn trước khi lên tạ nặng.',
          'videoUrl': 'assets/videos/catalog/pec_deck_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001018',
          'name': 'Máy cuốn đùi sau ngồi M3-1018',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Đùi sau'],
          'description':
              'Máy Realleader M3-1018 cô lập nhóm cơ đùi sau ở tư thế ngồi vững chắc.',
          'usageSteps': [
            'Chỉnh đệm lưng sao cho khớp gối thẳng hàng với trục xoay của máy.',
            'Khóa đệm đè đùi và đặt gót chân lên đệm lăn dưới.',
            'Cuốn cẳng chân xuống hết biên độ rồi nhả tạ chậm rãi.',
          ],
          'safetyNotes':
              'Không nhấc hông khỏi ghế khi cuốn tạ; kiểm soát gối ở điểm duỗi.',
          'videoUrl': 'assets/videos/catalog/seated_leg_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001019',
          'name': 'Máy nhón bắp chân đứng M3-1019',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Bắp chân'],
          'description':
              'Máy khối Realleader M3-1019 phát triển toàn diện cơ bắp chân ở tư thế đứng.',
          'usageSteps': [
            'Chỉnh đệm vai vừa vặn và đứng mũi bàn chân lên bệ kê.',
            'Hạ gót chân xuống sâu để giãn cơ bắp chân.',
            'Nhón gót lên cao nhất có thể, giữ 1 giây rồi hạ xuống có kiểm soát.',
          ],
          'safetyNotes':
              'Giữ gối thẳng tự nhiên nhưng không khóa khớp quá mức.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001020',
          'name': 'Máy xà đơn / xà kép trợ lực M3-1020',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Lưng', 'Tay sau'],
          'description':
              'Máy trợ lực đối trọng Realleader M3-1020 cho bài kéo xà đơn và chống xà kép.',
          'usageSteps': [
            'Chọn mức tạ đối trọng (tạ càng nặng lực trợ giúp càng lớn).',
            'Bước lên bậc đỡ, đặt đầu gối lên đệm trợ lực và chọn tay cầm.',
            'Thực hiện động tác kéo xà hoặc nhún xà kép với nhịp thở đều.',
          ],
          'safetyNotes':
              'Bước ra khỏi đệm trợ lực cẩn thận sau khi đệm về vị trí thấp nhất.',
          'videoUrl': 'assets/videos/catalog/assisted_pull_up_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001021',
          'name': 'Máy xoay eo M3-1021',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Cơ bụng', 'Cơ liên sườn'],
          'description':
              'Máy Realleader M3-1021 tác động vào cơ bụng và cơ liên sườn qua chuyển động xoay thân.',
          'usageSteps': [
            'Chọn góc xoay khởi đầu của trục ngồi phù hợp bên trái hoặc phải.',
            'Cố định phần thân trên vào đệm ngực và tay nắm.',
            'Xoay phần hông dưới từ cơ liên sườn rồi trở về chậm rãi.',
          ],
          'safetyNotes':
              'Không vặn quá biên độ dễ chịu của cột sống thắt lưng.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001022',
          'name': 'Máy tập mông M3-1022',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Mông'],
          'description':
              'Máy tập mông Realleader dòng M3 model M3-1022 tối ưu chuyển động cô lập cơ mông.',
          'usageSteps': [
            'Cài chốt tạ phù hợp và điều chỉnh đệm tựa theo hướng dẫn trên khung máy M3-1022.',
            'Giữ thân người ổn định, thực hiện nhịp đẩy hoặc ép cơ mông mượt mà.',
            'Trả tạ về vị trí ban đầu có kiểm soát.',
          ],
          'safetyNotes':
              'Kiểm tra chốt an toàn và giữ lưng trung tính suốt bài tập.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000001023',
          'name': 'Máy tập mông M3-1023',
          'category': 'Máy Realleader M3',
          'targetMuscles': ['Mông'],
          'description':
              'Máy tập mông Realleader dòng M3 model M3-1023 với thiết kế khung máy riêng biệt cho nhóm cơ mông.',
          'usageSteps': [
            'Cài chốt tạ vừa sức và ổn định tư thế trên máy M3-1023.',
            'Phát lực từ nhóm cơ mông và giữ nhịp chuyển động đều đặn.',
            'Thả chậm có kiểm soát để giữ lực căng cơ.',
          ],
          'safetyNotes':
              'Tránh dùng đà bật người hoặc khóa khớp ở cuối biên độ.',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002001',
          'name': 'Máy ép ngực (Pec Deck)',
          'category': 'Thiết bị có video',
          'targetMuscles': ['Ngực'],
          'description':
              'Máy ép ngực khung vòm với hai tay đòn trước giúp cô lập cơ ngực lớn theo cung tròn ổn định, kèm video minh họa trực quan.',
          'usageSteps': [
            'Chỉnh chiều cao ghế sao cho tay cầm ngang giữa ngực và cài chốt tạ phù hợp.',
            'Ngồi tựa lưng sát đệm, mở ngực, hơi gập khuỷu tay khi nắm hai tay đòn.',
            'Thở ra và ép hai tay đòn vào giữa ngực, siết cơ ngực 1 giây ở điểm đỉnh.',
            'Hít vào và mở tay chậm rãi về vị trí ban đầu mà không thả rơi tạ.',
          ],
          'safetyNotes':
              'Không mở khuỷu tay quá sâu ra sau mặt phẳng vai để tránh căng khớp vai trước.',
          'videoUrl': 'assets/videos/catalog/pec_deck_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002002',
          'name': 'Máy mở vai sau (Reverse Fly)',
          'category': 'Thiết bị có video',
          'targetMuscles': ['Vai sau'],
          'description':
              'Máy mở vai sau với tay đòn treo cao giúp cô lập cơ vai sau và ổn định khớp vai, đi kèm video hướng dẫn kỹ thuật.',
          'usageSteps': [
            'Chỉnh ghế để ngực áp sát đệm tựa và tay cầm nằm ngang tầm vai.',
            'Ngồi quay mặt vào đệm ngực, duỗi tay về trước và hơi mềm khớp khuỷu.',
            'Thở ra, kéo mở hai tay đòn ra sau theo hình vòng cung bằng lực vai sau.',
            'Giữ 1 giây ở điểm co đỉnh rồi trả tay chậm có kiểm soát.',
          ],
          'safetyNotes':
              'Tránh nhún cầu vai hoặc dùng đà ngả lưng khi mở tay; ưu tiên mức tạ kiểm soát tốt.',
          'videoUrl': 'assets/videos/catalog/reverse_machine_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002003',
          'name': 'Máy cuốn đùi sau ngồi (Seated Leg Curl)',
          'category': 'Thiết bị có video',
          'targetMuscles': ['Đùi sau'],
          'description':
              'Máy cuốn đùi sau tư thế ngồi có tựa lưng nghiêng và trục cuốn chân thấp, giúp tập trung tối đa vào nhóm cơ đùi sau.',
          'usageSteps': [
            'Chỉnh tựa lưng sao cho khớp gối trùng với trục xoay của máy.',
            'Đặt gót chân lên đệm lăn dưới và hạ đệm cố định ôm sát phía trên đùi.',
            'Thở ra, cuốn cẳng chân xuống hết biên độ để siết chặt cơ đùi sau.',
            'Hít vào và duỗi chân lên chậm rãi, giữ căng cơ suốt chuyển động.',
          ],
          'safetyNotes':
              'Giữ hông và lưng dưới áp sát ghế; không giật mạnh hoặc khóa cứng khớp gối khi duỗi.',
          'videoUrl': 'assets/videos/catalog/seated_leg_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002004',
          'name': 'Máy kéo xà trợ lực (Assisted Pull-Up)',
          'category': 'Thiết bị có video',
          'targetMuscles': ['Lưng', 'Tay trước'],
          'description':
              'Máy kéo xà trợ lực đối trọng với hai cột dẫn hướng và đệm gối, hỗ trợ kiểm soát nhịp kéo xà chuẩn form cho mọi trình độ.',
          'usageSteps': [
            'Cài mức tạ đối trọng phù hợp (tạ càng nặng lực nâng hỗ trợ càng nhiều).',
            'Bước lên bậc kê, nắm chắc thanh xà trên cao rồi đặt hai đầu gối lên đệm trợ lực.',
            'Hạ vai, gồng core, thở ra và kéo người lên cho đến khi cằm ngang hoặc qua thanh xà.',
            'Hít vào và hạ người xuống chậm rãi cho tới khi cánh tay duỗi gần hết.',
          ],
          'safetyNotes':
              'Đợi đệm trợ lực hạ về vị trí thấp nhất rồi mới bước từng chân xuống để tránh bật đệm.',
          'videoUrl': 'assets/videos/catalog/assisted_pull_up_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003001',
          'name': 'Ghế duỗi lưng khung cong',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Lưng dưới'],
          'description':
              'Ghế duỗi lưng 45° khung cong hỗ trợ tập dựng sống lưng dưới và cơ mông gân kheo với video minh họa.',
          'usageSteps': [
            'Điều chỉnh đệm đỡ hông nằm ngay dưới xương chậu để gập hông tự do.',
            'Cài cổ chân chắc chắn vào chốt đệm sau rồi giữ lưng thẳng tự nhiên.',
            'Gập người về trước có kiểm soát và nâng thân lên thẳng hàng.',
          ],
          'safetyNotes':
              'Không ưỡn võng thắt lưng quá mức ở điểm cao nhất; giữ tốc độ chậm đều.',
          'videoUrl': 'assets/videos/catalog/lower_back_01_hyperextension_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003002',
          'name': 'Ghế duỗi lưng 45° khung tam giác',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Lưng dưới'],
          'description':
              'Ghế duỗi lưng 45° khung tam giác chắc chắn, phù hợp cả bài tay không và ôm tạ tăng kháng lực.',
          'usageSteps': [
            'Chỉnh đệm đùi ngang nếp gấp hông và cố định gót chân vững vàng.',
            'Đan tay trước ngực hoặc ôm bánh tạ sát ngực, giữ cột sống trung tính.',
            'Gập hông xuống 45–60° rồi siết cơ lưng dưới và mông để nâng thân lên.',
          ],
          'safetyNotes':
              'Bắt đầu bằng trọng lượng cơ thể trước khi ôm tạ đĩa; tránh giật lưng.',
          'videoUrl': 'assets/videos/catalog/lower_back_02_crossed_arms_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003003',
          'name': 'Máy kéo xô',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Lưng xô'],
          'description':
              'Máy kéo xô khối tạ xếp đa góc nắm (nắm thường, tay rộng, tay hẹp) với video hướng dẫn từng biến thể.',
          'usageSteps': [
            'Chỉnh đệm giữ đùi áp sát mặt trên đùi và chọn thanh kéo phù hợp.',
            'Hơi ưỡn ngực, kéo thanh tạ xuống ngang xương đòn bằng lực xô.',
            'Trả tay về vị trí giãn cao hết tầm một cách có kiểm soát.',
          ],
          'safetyNotes':
              'Không ngả lưng lấy đà sâu hoặc thả tạ va mạnh vào tháp tạ.',
          'videoUrl': 'assets/videos/catalog/lats_01_normal_grip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003004',
          'name': 'Máy Smith và ghế nâng hông',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Mông'],
          'description':
              'Cụm máy Smith kết hợp ghế nâng hông chuyên dụng giúp thiết lập quỹ đạo tạ thẳng đứng an toàn cho Hip Thrust.',
          'usageSteps': [
            'Đặt lưng trên tựa vững vào mép ghế và cố định hai bàn chân rộng bằng vai.',
            'Đặt thanh đòn máy Smith ngang hông kèm đệm lót, xoay cổ tay mở khóa an toàn.',
            'Đẩy hông lên cao sao cho đùi song song sàn, siết chặt mông 1 giây rồi hạ xuống.',
          ],
          'safetyNotes':
              'Xoay khóa chốt an toàn hai đầu trước khi rời vị trí tập; giữ cằm hơi cúi.',
          'videoUrl': 'assets/videos/catalog/glutes_01_smith_hip_thrust_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003005',
          'name': 'Máy cáp với dây cổ chân',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Mông'],
          'description':
              'Trụ cáp đơn kết hợp vòng đeo cổ chân (ankle strap) cho các bài đá chân sau và cô lập cơ mông.',
          'usageSteps': [
            'Hạ ròng rọc xuống vị trí thấp nhất và móc dây đeo vào cổ chân.',
            'Nắm trụ máy giữ thân hơi nghiêng, giữ lưng thẳng và gồng core.',
            'Đá chân tập ra sau chếch nhẹ, siết cơ mông 1 giây rồi thu về chậm.',
          ],
          'safetyNotes':
              'Không ưỡn thắt lưng khi đá chân lên; kiểm soát dây cáp khi trả về.',
          'videoUrl': 'assets/videos/catalog/glutes_02_cable_kickback_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003006',
          'name': 'Máy Multi Hip',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Mông'],
          'description':
              'Máy Multi Hip đa hướng với cánh tay xoay và đệm lăn giúp tập dạng hông (abduction) tác động cơ mông nhỡ.',
          'usageSteps': [
            'Chỉnh độ cao bàn đứng sao cho trục xoay máy ngang khớp hông.',
            'Đứng vững một chân, tựa nhẹ tay vào khung đỡ và đặt má ngoài đùi lên đệm lăn.',
            'Dạng chân sang ngang hết biên độ kiểm soát rồi đưa chân về vị trí đầu.',
          ],
          'safetyNotes':
              'Giữ thân thẳng đứng, tránh nghiêng người để mượn lực hông.',
          'videoUrl': 'assets/videos/catalog/glutes_03_multi_hip_abduction_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003007',
          'name': 'Máy ép ngực pec deck',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Ngực'],
          'description':
              'Máy ép ngực pec deck khung vòm giúp cô lập cơ ngực lớn theo cung tròn đều ở cả hai bên.',
          'usageSteps': [
            'Chỉnh ghế để tay cầm ngang giữa ngực và tựa sát lưng vào đệm.',
            'Hơi gập nhẹ khuỷu tay, ép hai tay đòn vào giữa trước ngực.',
            'Giữ 1 giây ở điểm co đỉnh rồi mở tay chậm rãi.',
          ],
          'safetyNotes':
              'Không mở khuỷu tay quá sâu ra sau vai; chọn chốt biên độ an toàn.',
          'videoUrl': 'assets/videos/catalog/chest_01_pec_deck_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003008',
          'name': 'Máy cáp đôi',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Ngực'],
          'description':
              'Hệ thống ròng rọc cáp đôi cho phép điều chỉnh chiều cao linh hoạt khi thực hiện ép ngực bằng cáp ngang.',
          'usageSteps': [
            'Đặt hai chốt ròng rọc ngang vai và cài cùng mức tạ ở cả hai tháp.',
            'Bước nhẹ một chân về trước giữ thăng bằng, ưỡn ngực tự nhiên.',
            'Ép hai tay cầm gặp nhau trước giữa ngực rồi mở ra chậm có kiểm soát.',
          ],
          'safetyNotes':
              'Kiểm tra chốt tạ hai bên bằng nhau và không buông tay cầm đột ngột.',
          'videoUrl': 'assets/videos/catalog/chest_02_cable_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003009',
          'name': 'Máy đẩy ngực',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Ngực'],
          'description':
              'Máy đẩy ngực khối tạ xếp dẫn hướng cố định, an toàn cho việc tập nặng và phát triển toàn bộ cơ ngực.',
          'usageSteps': [
            'Chỉnh chiều cao ghế sao cho tay cầm nằm ngang giữa ngực.',
            'Áp chặt hai bả vai vào đệm tựa, nhấn chân trụ vững trên sàn.',
            'Đẩy tay đòn về trước gần thẳng tay rồi hạ chậm để giãn cơ ngực.',
          ],
          'safetyNotes':
              'Không khóa cứng khớp khuỷu tay khi đẩy hết biên độ và không nhấc vai.',
          'videoUrl': 'assets/videos/catalog/chest_03_chest_press_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003010',
          'name': 'Máy dip ngồi',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Tay sau'],
          'description':
              'Máy dip tư thế ngồi với hai tay đòn đòn bẩy tập trung phát triển bắp tay sau và phần ngực dưới.',
          'usageSteps': [
            'Chỉnh ghế ngồi và đai giữ ổn định (nếu có), nắm chắc hai tay cầm bên hông.',
            'Thẳng lưng, nhấn mạnh hai tay đòn xuống cho tới khi cánh tay gần duỗi thẳng.',
            'Trả tay lên chậm theo phương thẳng đứng để giữ áp lực lên tay sau.',
          ],
          'safetyNotes':
              'Tránh nhún vai lên gần tai; giữ khuỷu tay ép sát về sau thân.',
          'videoUrl': 'assets/videos/catalog/triceps_01_seated_dip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003011',
          'name': 'Máy duỗi tay sau ngồi',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Tay sau'],
          'description':
              'Máy duỗi tay sau ngồi giúp cô lập hoàn toàn cơ tam đầu cánh tay mà không cần giữ thăng bằng khớp vai.',
          'usageSteps': [
            'Chỉnh đệm ngồi sao cho trục xoay máy thẳng hàng với khớp khuỷu tay.',
            'Tựa lưng vững, đặt hai bắp tay trên đệm và nắm chắc tay cầm.',
            'Duỗi cẳng tay tới trước hết tầm, siết 1 giây rồi gập chậm về.',
          ],
          'safetyNotes':
              'Chọn mức tạ vừa đủ kiểm soát để khuỷu tay không bật khỏi đệm.',
          'videoUrl': 'assets/videos/catalog/triceps_02_extension_machine_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003012',
          'name': 'Máy cáp với dây thừng',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Tay sau'],
          'description':
              'Trạm cáp ròng rọc cao gắn dây thừng kép giúp xoay cổ tay tự nhiên ở cuối nhịp đẩy dây thừng tay sau.',
          'usageSteps': [
            'Gắn dây thừng vào ròng rọc trên cao và đứng hơi nghiêng thân về trước.',
            'Khép hai khuỷu tay sát hai bên sườn cố định làm điểm tựa.',
            'Đẩy dây xuống và tách hai đầu dây ra ngoài, siết chặt tay sau 1 giây.',
          ],
          'safetyNotes':
              'Chỉ di chuyển khớp khuỷu tay, không đưa cùi chỏ ra trước/sau.',
          'videoUrl': 'assets/videos/catalog/triceps_03_rope_pushdown_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003013',
          'name': 'Máy cáp thấp với thanh thẳng',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Tay trước'],
          'description':
              'Trạm cáp thấp lắp thanh thẳng hỗ trợ cuốn tay trước nắm thường hoặc nắm rộng với lực căng liên tục.',
          'usageSteps': [
            'Chỉnh ròng rọc xuống thấp nhất và gắn thanh thẳng ngang.',
            'Nắm thanh thẳng lòng bàn tay ngửa (rộng bằng vai hoặc rộng hơn vai), khép cùi chỏ.',
            'Cuốn thanh tạ lên gần vai, siết cơ nhị đầu 1 giây rồi hạ xuống chậm.',
          ],
          'safetyNotes':
              'Không ngả lưng vung đà và không buông tạ chạm chồng tạ quá mạnh.',
          'videoUrl': 'assets/videos/catalog/biceps_01_low_cable_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003014',
          'name': 'Máy cáp và ghế preacher',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Tay trước'],
          'description':
              'Ghế dốc preacher đặt trước ròng rọc cáp thấp giúp cố định mặt sau cánh tay để cuốn tay trước cô lập tối đa.',
          'usageSteps': [
            'Ngồi vững trên ghế preacher, tựa sát hai cánh tay trên đệm dốc.',
            'Nắm thanh kéo gắn vào ròng rọc cáp thấp phía trước.',
            'Cuốn thanh kéo lên hướng vai rồi hạ xuống gần hết nhưng vẫn giữ căng cơ.',
          ],
          'safetyNotes':
              'Không thả duỗi khuỷu tay giật mạnh ở cuối biên độ hạ để bảo vệ gân nhị đầu.',
          'videoUrl': 'assets/videos/catalog/biceps_02_cable_preacher_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003015',
          'name': 'Máy duỗi đùi trước',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Đùi trước'],
          'description':
              'Máy duỗi đùi trước ngồi hỗ trợ tập cả hai chân hoặc từng chân độc lập, đi kèm video hướng dẫn chi tiết.',
          'usageSteps': [
            'Chỉnh đệm lưng sao cho khớp gối trùng với trục xoay của máy.',
            'Đặt cổ chân phía sau đệm lăn dưới và nắm tay cầm giữ hông ổn định.',
            'Duỗi thẳng cẳng chân lên, giữ 1 giây siết cơ đùi trước rồi hạ chậm.',
          ],
          'safetyNotes':
              'Không bật tạ bằng quán tính; giảm mức tạ khi chuyển sang tập một chân.',
          'videoUrl': 'assets/videos/catalog/quads_01_bilateral_extension_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003016',
          'name': 'Máy Smith',
          'category': 'Thiết bị 7 nhóm cơ',
          'targetMuscles': ['Đùi trước'],
          'description':
              'Khung máy Smith thanh đòn dẫn hướng thẳng có các móc khóa an toàn dọc trụ, hỗ trợ Squat đùi trước ổn định.',
          'usageSteps': [
            'Đặt thanh đòn ngang cầu vai trên, bước hai chân hơi chếch trước trục thanh.',
            'Xoay cổ tay mở móc khóa an toàn, gồng core và hạ hông sâu có kiểm soát.',
            'Đạp gót chân đứng lên về vị trí đầu và xoay cổ tay móc khóa khi xong hiệp.',
          ],
          'safetyNotes':
              'Luôn cài chốt chặn an toàn phía dưới ở độ sâu Squat thấp nhất.',
          'videoUrl': 'assets/videos/catalog/quads_03_smith_squat_480p.mp4',
          'status': 'ACTIVE',
        },
      ],
      exercises: [
        {
          'id': '90000000-0000-4000-8000-000000000021',
          'equipmentId': '90000000-0000-4000-8000-000000000011',
          'name': 'Barbell Bench Press',
          'description':
              'Bài tập nền tảng xây dựng cơ ngực vạm vỡ và sức mạnh thân trên.',
          'targetMuscles': ['Ngực', 'Tay sau'],
          'instructions':
              'Nằm ngửa, siết bả vai, hít sâu khi hạ tạ và thở mạnh khi đẩy lên.',
          'safetyNotes': 'Cổ tay thẳng, không uốn cong cổ tay.',
          'difficulty': 'INTERMEDIATE',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000023',
          'equipmentId': '90000000-0000-4000-8000-000000000012',
          'name': 'Barbell Back Squat',
          'description':
              'Vua của các bài tập chân đùi, phát triển toàn diện thân dưới.',
          'targetMuscles': ['Đùi trước', 'Mông', 'Lưng dưới'],
          'instructions': 'Chân rộng bằng vai, gồng core, hạ hông song song sàn.',
          'safetyNotes': 'Giữ lưng thẳng tự nhiên.',
          'difficulty': 'ADVANCED',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000024',
          'equipmentId': '90000000-0000-4000-8000-000000000013',
          'name': 'Lat Pulldown Kéo Xô Mặt Trước',
          'description': 'Bài tập tạo hình lưng chữ V (V-taper) sắc nét.',
          'targetMuscles': ['Lưng xô', 'Tay trước'],
          'instructions': 'Kéo thanh đòn về phía ức ngực, ép chặt 2 bả vai.',
          'safetyNotes': 'Giữ thân người cố định.',
          'difficulty': 'BEGINNER',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002101',
          'equipmentId': '90000000-0000-4000-8000-000000002001',
          'name': 'Ép ngực máy (Pec Deck Fly)',
          'description':
              'Bài tập cô lập cơ ngực lớn với quỹ đạo mượt và ổn định, phù hợp cả người mới lẫn giai đoạn siết cơ.',
          'targetMuscles': ['Ngực'],
          'instructions':
              'Tựa lưng sát đệm, giữ khuỷu tay hơi cong cố định rồi ép hai tay đòn về trước ngực và siết cơ 1 giây.',
          'usageSteps': [
            'Chỉnh ghế để tay nắm ngang giữa ngực và chọn mức tạ phù hợp.',
            'Ép hai cánh tay vào giữa theo cung tròn, thở ra ở điểm siết đỉnh.',
            'Mở tay chậm rãi trong 2–3 giây để giữ lực căng cơ ngực.',
          ],
          'safetyNotes':
              'Không nhấc vai về trước và không để tay đòn giật ngược quá sâu ra sau lưng.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/pec_deck_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002102',
          'equipmentId': '90000000-0000-4000-8000-000000002002',
          'name': 'Mở vai sau máy (Reverse Machine Fly)',
          'description':
              'Bài tập cô lập cơ vai sau giúp cân bằng khớp vai và cải thiện tư thế lưng trên.',
          'targetMuscles': ['Vai sau'],
          'instructions':
              'Áp ngực vào đệm tựa, kéo mở hai tay ra ngang vai bằng lực vai sau, giữ cổ và cầu vai thả lỏng.',
          'usageSteps': [
            'Điều chỉnh chiều cao ghế để tay cầm ngang tầm vai và ngực tựa vững.',
            'Mở rộng hai tay ra sau theo đường vòng cung, thở ra khi siết vai sau.',
            'Khép tay về trước chậm rãi có kiểm soát, không để tạ va mạnh.',
          ],
          'safetyNotes':
              'Giữ khuỷu tay mềm tự nhiên, tránh gồng cổ hoặc ngả thân người ra sau.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/reverse_machine_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002103',
          'equipmentId': '90000000-0000-4000-8000-000000002003',
          'name': 'Cuốn đùi sau ngồi (Seated Leg Curl)',
          'description':
              'Bài tập cô lập đùi sau ở tư thế ngồi giúp kéo giãn tốt và kiểm soát lực an toàn cho khớp gối.',
          'targetMuscles': ['Đùi sau'],
          'instructions':
              'Cố định đùi dưới đệm chắn, cuốn cẳng chân xuống hết biên độ rồi trả lên chậm rãi.',
          'usageSteps': [
            'Canh khớp gối thẳng trục xoay máy và cài chặt đệm cố định đùi.',
            'Cuốn chân xuống sâu, giữ 1 giây khi cơ đùi sau co tối đa.',
            'Trả chân lên có kiểm soát trong 2–3 giây mà không khóa cứng gối.',
          ],
          'safetyNotes':
              'Không nhấc mông khỏi ghế và tránh dùng đà hất tạ ở đầu chuyển động.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/seated_leg_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000002104',
          'equipmentId': '90000000-0000-4000-8000-000000002004',
          'name': 'Kéo xà trợ lực (Assisted Pull-Up)',
          'description':
              'Bài kéo thân trên hỗ trợ đối trọng giúp phát triển cơ lưng xô và tay trước với biên độ chuẩn.',
          'targetMuscles': ['Lưng', 'Tay trước'],
          'instructions':
              'Đặt gối lên đệm trợ lực, kéo khuỷu tay hướng xuống sườn để đưa ngực tiến gần thanh xà.',
          'usageSteps': [
            'Chọn mức tạ trợ lực phù hợp khả năng kéo đủ 8–12 lần chuẩn kỹ thuật.',
            'Hạ bả vai, gồng nhẹ bụng và kéo người lên mượt mà theo phương thẳng đứng.',
            'Hạ người xuống chậm rãi cho tới khi lưng xô giãn hết biên độ.',
          ],
          'safetyNotes':
              'Giữ thân ổn định, không đung đưa chân và bước xuống chậm sau khi đệm chạm đáy.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/assisted_pull_up_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003101',
          'equipmentId': '90000000-0000-4000-8000-000000003001',
          'name': 'Duỗi lưng trên ghế 45°',
          'description':
              'Bài tập nền tảng trên ghế duỗi lưng 45° khung cong giúp tăng sức mạnh cơ dựng sống lưng dưới và chuỗi cơ sau.',
          'targetMuscles': ['Lưng dưới'],
          'instructions':
              'Cố định hông dưới đệm đỡ, gập thân về trước giữ lưng phẳng rồi nâng lên thẳng hàng thân người.',
          'usageSteps': [
            'Chỉnh đệm đỡ hông ngay dưới xương chậu và gài chặt gót chân.',
            'Khoanh tay trước ngực hoặc đặt nhẹ sau đầu, hít vào gập hông xuống 45–60°.',
            'Thở ra, siết lưng dưới và mông nâng người về đường thẳng tự nhiên.',
          ],
          'safetyNotes':
              'Dừng ở đường thẳng thân người, tránh ngả ưỡn thắt lưng quá mức.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/lower_back_01_hyperextension_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003102',
          'equipmentId': '90000000-0000-4000-8000-000000003002',
          'name': 'Duỗi lưng, tay trước ngực',
          'description':
              'Bài duỗi lưng trên ghế 45° khung tam giác với hai tay bắt chéo trước ngực giúp kiểm soát nhịp chuyển động chuẩn.',
          'targetMuscles': ['Lưng dưới'],
          'instructions':
              'Bắt chéo hai tay trước ngực, gập hông chậm theo độ nghiêng ghế 45° rồi nâng thân về thẳng hàng.',
          'usageSteps': [
            'Tựa phần đùi trên lên đệm ghế, gót chân tì chắc vào giá đỡ.',
            'Đan tay trước ngực, gồng nhẹ core và gập người xuống có kiểm soát.',
            'Siết cơ dựng sống và mông kéo thân người lên ngang trục hông.',
          ],
          'safetyNotes':
              'Giữ cổ thẳng hàng cột sống, không ngẩng đầu nhìn gương gây mỏi cổ.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/lower_back_02_crossed_arms_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003103',
          'equipmentId': '90000000-0000-4000-8000-000000003002',
          'name': 'Duỗi lưng có tạ',
          'description':
              'Biến thể nâng cao trên ghế duỗi lưng 45° khung tam giác bằng cách ôm bánh tạ trước ngực để tăng tải lưng dưới.',
          'targetMuscles': ['Lưng dưới'],
          'instructions':
              'Ôm chặt bánh tạ sát ngực, giữ lưng thẳng suốt biên độ gập xuống và nâng lên trên ghế 45°.',
          'usageSteps': [
            'Chọn bánh tạ vừa sức và ôm sát vào giữa ngực bằng hai tay.',
            'Gập hông hạ người chậm rãi trong 2 giây nhưng vẫn giữ cột sống trung tính.',
            'Phát lực từ hông và lưng dưới nâng thân lên thẳng hàng rồi lặp lại.',
          ],
          'safetyNotes':
              'Tuyệt đối không cong lưng khi cầm thêm tạ; đặt tạ xuống sàn trước khi bước ra.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/lower_back_03_weighted_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003104',
          'equipmentId': '90000000-0000-4000-8000-000000003003',
          'name': 'Kéo xô tay nắm thường',
          'description':
              'Bài kéo xô cơ bản với cự ly tay rộng vừa phải giúp cân bằng độ dày và độ rộng cơ lưng xô.',
          'targetMuscles': ['Lưng xô'],
          'instructions':
              'Nắm thanh kéo rộng hơn vai một chút, hạ vai xuống trước rồi kéo thanh về phần ngực trên.',
          'usageSteps': [
            'Cố định hai đùi dưới đệm giữ và nắm thanh kéo với độ rộng vừa phải.',
            'Ưỡn nhẹ ngực, kéo cùi chỏ thẳng xuống hông để đưa thanh tới ngực trên.',
            'Thả thanh tạ lên chậm rãi cho đến khi lưng xô duỗi căng hết tầm.',
          ],
          'safetyNotes':
              'Không lắc người về sau lấy đà; giữ cổ tay thẳng hàng cẳng tay.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/lats_01_normal_grip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003105',
          'equipmentId': '90000000-0000-4000-8000-000000003003',
          'name': 'Kéo xô tay rộng',
          'description':
              'Biến thể cầm rộng trên máy kéo xô tập trung mở rộng xô hai bên tạo phom lưng chữ V.',
          'targetMuscles': ['Lưng xô'],
          'instructions':
              'Nắm phần cong ngoài của thanh kéo rộng hơn vai, hướng khuỷu tay sang hai bên và xuống thấp.',
          'usageSteps': [
            'Nắm hai đầu ngoài thanh kéo và ngồi thẳng thân tựa chắc dưới đệm đùi.',
            'Kéo thanh xuống ngang xương đòn, ép hai bả vai xuống và vào trong.',
            'Kiểm soát nhịp nhả thanh lên để cảm nhận cơ xô hai bên giãn rõ rệt.',
          ],
          'safetyNotes':
              'Không kéo thanh ra sau gáy để tránh gây áp lực xấu lên khớp vai.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/lats_02_wide_grip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003106',
          'equipmentId': '90000000-0000-4000-8000-000000003003',
          'name': 'Kéo xô tay hẹp',
          'description':
              'Bài kéo xô tay nắm hẹp tăng biên độ kéo sâu vào vùng xô dưới và lưng giữa.',
          'targetMuscles': ['Lưng xô'],
          'instructions':
              'Nắm tay hẹp hơn hoặc bằng vai, giữ khuỷu tay hướng về trước khi kéo thanh xuống ngực.',
          'usageSteps': [
            'Nắm thanh kéo cự ly hẹp trước mặt và hạ thấp hai vai khỏi tai.',
            'Kéo khuỷu tay hướng thẳng xuống sàn cho tới khi thanh gần chạm ngực trên.',
            'Siết lưng 1 giây rồi đưa thanh lên thẳng tay có kiểm soát.',
          ],
          'safetyNotes':
              'Tránh gù lưng trên ở điểm thả cao và không dùng quán tính lưng dưới.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/lats_03_close_grip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003107',
          'equipmentId': '90000000-0000-4000-8000-000000003004',
          'name': 'Nâng hông bằng máy Smith',
          'description':
              'Bài đẩy hông tải nặng cực kỳ ổn định trên máy Smith và ghế nâng hông giúp phát triển tối đa cơ mông lớn.',
          'targetMuscles': ['Mông'],
          'instructions':
              'Tựa lưng trên sát cạnh ghế, đặt thanh đòn Smith ngang hông rồi đạp gót chân đẩy hông lên cao.',
          'usageSteps': [
            'Điều chỉnh ghế chắc chắn và tựa phần dưới bả vai lên cạnh ghế.',
            'Đặt thanh tạ Smith ngay nếp gấp hông kèm đệm, chân gập 90° khi ở đỉnh.',
            'Đẩy hông thẳng lên cao siết chặt mông 1–2 giây rồi hạ hông chậm rãi.',
          ],
          'safetyNotes':
              'Giữ cằm thu nhẹ về ngực tránh võng thắt lưng; khóa chốt thanh khi kết thúc.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/glutes_01_smith_hip_thrust_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003108',
          'equipmentId': '90000000-0000-4000-8000-000000003005',
          'name': 'Đá chân sau bằng cáp',
          'description':
              'Bài cô lập cơ mông với dây cáp cổ chân giữ sức căng liên tục suốt toàn bộ chuyển động.',
          'targetMuscles': ['Mông'],
          'instructions':
              'Cài dây cổ chân vào ròng rọc thấp, giữ thân ổn định rồi đá chân thẳng ra sau siết cơ mông.',
          'usageSteps': [
            'Móc dây cổ chân vào cáp thấp và đứng cách trụ máy một sải tay.',
            'Nghiêng nhẹ thân trên, gồng chặt core và đặt chân trụ vững trên sàn.',
            'Đá chân tập về phía sau lên cao vừa tầm, siết mông 1 giây rồi trả về chậm.',
          ],
          'safetyNotes':
              'Không võng lưng dưới khi đá chân lên; tập đủ hai bên chân cân bằng.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/glutes_02_cable_kickback_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003109',
          'equipmentId': '90000000-0000-4000-8000-000000003006',
          'name': 'Dạng hông bằng máy Multi Hip',
          'description':
              'Bài dạng hông đứng trên máy Multi Hip giúp làm tròn và khỏe nhóm cơ mông ngoài (mông nhỡ).',
          'targetMuscles': ['Mông'],
          'instructions':
              'Đứng thẳng một chân trụ trên máy Multi Hip, dùng má ngoài đùi đẩy đệm lăn dạng chân sang ngang.',
          'usageSteps': [
            'Chỉnh chiều cao bệ đứng và tay đòn phù hợp chiều dài chân.',
            'Nắm hai tay vào khung trước giữ thân thẳng và cố định hông.',
            'Đẩy chân tập dạng rộng sang ngang hết tầm kiểm soát rồi khép về chậm.',
          ],
          'safetyNotes':
              'Không nghiêng vai sang bên đối diện để kéo thêm lực.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/glutes_03_multi_hip_abduction_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003110',
          'equipmentId': '90000000-0000-4000-8000-000000003007',
          'name': 'Ép ngực trên máy',
          'description':
              'Bài ép ngực cô lập trên máy pec deck với đường đi tay đòn cố định giúp siết sâu rãnh ngực giữa.',
          'targetMuscles': ['Ngực'],
          'instructions':
              'Tựa lưng sát ghế, mở ngực giữ khuỷu tay hơi cong rồi ép hai tay đòn chạm gần nhau trước ngực.',
          'usageSteps': [
            'Chỉnh ghế để tay nắm ngang giữa ngực và hai chân đặt vững.',
            'Thở ra ép hai tay vào giữa, giữ chặt cơ ngực 1 giây ở đỉnh.',
            'Hít vào mở tay ra chậm rãi đến khi ngực giãn vừa phải.',
          ],
          'safetyNotes':
              'Hạ vai xuống khỏi tai và không để khuỷu tay trôi quá xa ra sau lưng.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/chest_01_pec_deck_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003111',
          'equipmentId': '90000000-0000-4000-8000-000000003008',
          'name': 'Ép ngực bằng cáp ngang',
          'description':
              'Bài ép ngực đứng với máy cáp đôi ngang vai giữ lực căng đều trên từng sợi cơ ngực lớn.',
          'targetMuscles': ['Ngực'],
          'instructions':
              'Đặt hai ròng rọc ngang vai, bước một chân lên trước rồi ôm vòng hai tay cáp gặp nhau trước ngực.',
          'usageSteps': [
            'Chỉnh hai chốt ròng rọc ngang tầm vai và cầm chắc hai tay nắm.',
            'Bước nhẹ lên trước tạo trụ vững, hơi gập khuỷu tay và ưỡn ngực.',
            'Thở ra kéo vòng hai tay chạm nhau trước giữa ngực rồi trả về chậm rãi.',
          ],
          'safetyNotes':
              'Giữ góc gập khuỷu tay cố định suốt hiệp tập để không biến thành bài đẩy.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/chest_02_cable_fly_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003112',
          'equipmentId': '90000000-0000-4000-8000-000000003009',
          'name': 'Đẩy ngực trên máy',
          'description':
              'Bài đẩy ngực hợp lực an toàn trên máy đẩy ngực giúp tập trung phát lực cơ ngực mà không cần người đỡ.',
          'targetMuscles': ['Ngực'],
          'instructions':
              'Ngồi tựa lưng vững vào đệm, nắm tay cầm ngang ngực rồi đẩy thẳng về trước.',
          'usageSteps': [
            'Điều chỉnh ghế ngồi để tay nắm ngang giữa ngực, khép bả vai sát đệm.',
            'Thở ra đẩy hai tay đòn về trước gần thẳng tay bằng lực cơ ngực.',
            'Hít vào hạ tạ về chậm trong 2 giây nhưng không để tạ chạm chồng.',
          ],
          'safetyNotes':
              'Giữ cổ tay thẳng và không đẩy khớp vai nhô về trước đệm.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/chest_03_chest_press_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003113',
          'equipmentId': '90000000-0000-4000-8000-000000003010',
          'name': 'Dip trên máy ngồi',
          'description':
              'Bài nhấn dip ngồi trên máy tạo khối lượng tập lớn và an toàn cho cả ba đầu cơ tay sau.',
          'targetMuscles': ['Tay sau'],
          'instructions':
              'Ngồi tựa lưng thẳng, giữ khuỷu tay hướng ra sau rồi ấn mạnh hai tay đòn xuống hết tầm.',
          'usageSteps': [
            'Cài ghế vừa tầm để vai thả lỏng thoải mái khi nắm tay cầm.',
            'Khép khuỷu tay gần thân, nhấn hai tay cầm thẳng xuống dưới.',
            'Siết tay sau 1 giây ở điểm dưới cùng rồi nhả tay lên chậm.',
          ],
          'safetyNotes':
              'Không nhấc mông khỏi ghế hoặc nhún cổ vai theo nhịp hạ tay.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/triceps_01_seated_dip_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003114',
          'equipmentId': '90000000-0000-4000-8000-000000003011',
          'name': 'Duỗi tay sau trên máy',
          'description':
              'Bài duỗi tay sau ngồi cô lập bắp tay sau chính xác nhờ điểm tựa cố định trên đệm tay.',
          'targetMuscles': ['Tay sau'],
          'instructions':
              'Đặt hai bắp tay áp sát đệm, duỗi thẳng cẳng tay về phía trước để siết cơ tay sau.',
          'usageSteps': [
            'Điều chỉnh đệm ngồi sao cho trục khuỷu tay thẳng với trục xoay máy.',
            'Nắm chắc tay cầm và giữ cổ tay trung tính.',
            'Thở ra duỗi thẳng tay về trước rồi gập chậm về không để va tạ.',
          ],
          'safetyNotes':
              'Giữ nguyên bắp tay áp sát đệm trong suốt cả hiệp.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/triceps_02_extension_machine_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003115',
          'equipmentId': '90000000-0000-4000-8000-000000003012',
          'name': 'Đẩy dây thừng cáp xuống',
          'description':
              'Bài tập kinh điển với máy cáp và dây thừng giúp tách nét đầu ngoài và đầu dài cơ tay sau.',
          'targetMuscles': ['Tay sau'],
          'instructions':
              'Khép khuỷu tay cố định bên sườn, kéo dây thừng thẳng xuống và tách hai đầu dây ra hai bên đùi.',
          'usageSteps': [
            'Lắp dây thừng vào ròng rọc trên cao, hơi nghiêng thân trên 15°.',
            'Khép hai cùi chỏ sát sườn và đẩy dây thừng xuống hết tầm tay.',
            'Xoay tách nhẹ hai đầu dây sang hai bên ở đáy chuyển động rồi thu lên chậm.',
          ],
          'safetyNotes':
              'Không thả bung khuỷu tay lên quá ngực khiến mất lực căng tay sau.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/triceps_03_rope_pushdown_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003116',
          'equipmentId': '90000000-0000-4000-8000-000000003013',
          'name': 'Cuốn tay trước cáp thấp',
          'description':
              'Bài cuốn tay trước đứng với máy cáp thấp thanh thẳng giúp duy trì lực căng ngay từ điểm khởi đầu.',
          'targetMuscles': ['Tay trước'],
          'instructions':
              'Nắm thanh thẳng cự ly bằng vai ở ròng rọc thấp, khép cùi chỏ cố định và cuốn thanh lên ngang ngực.',
          'usageSteps': [
            'Đứng thẳng cách tháp cáp một bước nhỏ, lòng bàn tay ngửa nắm thanh thẳng.',
            'Giữ hai khuỷu tay sát hông, thở ra cuốn tạ lên siết cơ tay trước.',
            'Hạ tạ xuống chậm trong 2–3 giây cho đến khi tay gần thẳng.',
          ],
          'safetyNotes':
              'Không đẩy cùi chỏ về trước quá nhiều hoặc ngả lưng vung người.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/biceps_01_low_cable_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003117',
          'equipmentId': '90000000-0000-4000-8000-000000003014',
          'name': 'Cuốn tay trước trên ghế với cáp',
          'description':
              'Cuốn tay trước trên ghế dốc preacher kết hợp ròng rọc cáp thấp giúp loại bỏ hoàn toàn quán tính thân người.',
          'targetMuscles': ['Tay trước'],
          'instructions':
              'Tựa chắc hai bắp tay trên mặt dốc ghế preacher và cuốn thanh cáp thấp lên bằng bắp tay trước.',
          'usageSteps': [
            'Chỉnh ghế để phần nách tựa gọn trên mép đệm, hai bắp tay áp sát đệm dốc.',
            'Nắm thanh cáp thấp lòng bàn tay ngửa và giữ cổ tay thẳng.',
            'Cuốn thanh lên mượt mà siết bắp tay 1 giây rồi hạ xuống có kiểm soát.',
          ],
          'safetyNotes':
              'Không ngả thân trên ra sau để kéo thanh lên hoặc duỗi giật khớp khuỷu.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/biceps_02_cable_preacher_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003118',
          'equipmentId': '90000000-0000-4000-8000-000000003013',
          'name': 'Cuốn tay trước cáp thấp, tay rộng',
          'description':
              'Bài cuốn trên máy cáp thấp với thanh thẳng nắm tay rộng hơn vai nhằm nhấn mạnh đầu ngắn (mặt trong) bắp tay trước.',
          'targetMuscles': ['Tay trước'],
          'instructions':
              'Nắm thanh thẳng rộng hơn vai ở trạm cáp thấp, giữ khuỷu tay sát sườn và cuốn thanh lên trước ngực.',
          'usageSteps': [
            'Gắn thanh thẳng vào ròng rọc cáp thấp và nắm rộng hơn bề ngang vai.',
            'Giữ bả vai ổn định, cuốn thanh lên cao siết mạnh mặt trong tay trước.',
            'Hạ thanh tạ chậm về điểm duỗi gần hết mà vẫn giữ căng dây cáp.',
          ],
          'safetyNotes':
              'Tránh để cổ tay bẻ ngửa ra sau khi cầm tạ rộng; chọn mức tạ chuẩn form.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/biceps_03_wide_grip_cable_curl_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003119',
          'equipmentId': '90000000-0000-4000-8000-000000003015',
          'name': 'Duỗi đùi trước hai chân',
          'description':
              'Bài cô lập cơ tứ đầu đùi bằng cả hai chân trên máy duỗi đùi trước giúp cắt nét và tăng sức mạnh đùi trước.',
          'targetMuscles': ['Đùi trước'],
          'instructions':
              'Ngồi tựa lưng sát ghế, cố định cổ chân dưới đệm lăn và duỗi thẳng cả hai chân lên trước.',
          'usageSteps': [
            'Chỉnh đệm lưng và đệm cổ chân vừa khớp sao cho gối nằm ngang trục xoay.',
            'Nắm hai tay cầm bên hông giữ mông cố định trên mặt ghế.',
            'Duỗi hai chân lên thẳng hoàn toàn, giữ 1 giây rồi hạ xuống chậm.',
          ],
          'safetyNotes':
              'Không nhấc hông khỏi đệm và không giật tạ ở điểm bắt đầu.',
          'difficulty': 'BEGINNER',
          'videoUrl': 'assets/videos/catalog/quads_01_bilateral_extension_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003120',
          'equipmentId': '90000000-0000-4000-8000-000000003015',
          'name': 'Duỗi đùi trước một chân',
          'description':
              'Bài duỗi đùi trước từng chân một giúp khắc phục lệch sức mạnh hai bên đùi và cảm nhận cơ chính xác hơn.',
          'targetMuscles': ['Đùi trước'],
          'instructions':
              'Cài mức tạ nhẹ vừa sức, tập từng chân luân phiên với cùng số lần lặp và biên độ chuẩn.',
          'usageSteps': [
            'Đặt một cổ chân phía sau đệm lăn dưới, chân còn lại giữ thả lỏng trên sàn.',
            'Siết cơ đùi trước duỗi thẳng chân lên hết tầm trong nhịp thở ra.',
            'Hạ chân xuống chậm 2–3 giây rồi hoàn tất đủ reps trước khi đổi chân.',
          ],
          'safetyNotes':
              'Giảm mức tạ xuống khoảng một nửa so với bài hai chân để bảo vệ khớp gối.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/quads_02_single_leg_extension_480p.mp4',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000003121',
          'equipmentId': '90000000-0000-4000-8000-000000003016',
          'name': 'Squat bằng máy Smith',
          'description':
              'Bài Squat trên máy Smith giúp dồn áp lực tối đa vào nhóm cơ đùi trước nhờ quỹ đạo thẳng cố định.',
          'targetMuscles': ['Đùi trước'],
          'instructions':
              'Đặt thanh đòn lên cầu vai, đưa chân hơi tiến về trước trục thanh rồi ngồi xuống sâu và đạp lên.',
          'usageSteps': [
            'Mở khóa móc an toàn, giữ lưng thẳng và hít sâu gồng chặt vùng core.',
            'Hạ hông xuống sâu tới khi đùi song song hoặc thấp hơn mặt sàn nhẹ.',
            'Đạp mạnh qua lòng bàn chân đứng thẳng lên và xoay khóa chốt khi xong hiệp.',
          ],
          'safetyNotes':
              'Luôn đặt chốt chặn an toàn ở mức phù hợp trước khi tập mức tạ nặng.',
          'difficulty': 'INTERMEDIATE',
          'videoUrl': 'assets/videos/catalog/quads_03_smith_squat_480p.mp4',
          'status': 'ACTIVE',
        },
      ],
      gymProfile: {
        'name': 'Meta Gym Flagship Center',
        'address': '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM',
        'description':
            'Không gian tập luyện chuẩn quốc tế với đầy đủ khu Free Weight, Máy cáp và Cardio.',
        'phone': '1900 886 688',
        'rules':
            'Trả tạ về kệ sau khi tập · Lau ghế máy · Mang giày thể thao.',
        'openingHours': {
          'Thứ 2 – Thứ 6': '05:30 – 22:30',
          'Thứ 7 – CN': '06:00 – 21:30',
        },
      },
      aiConversations: [
        {
          'id': aiConvId,
          'title': 'Tối ưu lịch tập Tăng Cơ 8 Tuần',
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'updatedAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
        },
      ],
      aiMessages: {
        aiConvId: [
          {
            'id': 'ai-msg-001',
            'conversationId': aiConvId,
            'role': 'USER',
            'status': 'COMPLETED',
            'content': 'Hôm nay tập Ngực & Tay sau mình nên ăn gì trước tập 1 tiếng?',
            'createdAt': now
                .subtract(const Duration(hours: 4, minutes: 5))
                .toIso8601String(),
          },
          {
            'id': 'ai-msg-002',
            'conversationId': aiConvId,
            'role': 'ASSISTANT',
            'status': 'COMPLETED',
            'content':
                'Trước buổi tập Ngực & Tay sau 60 phút, bạn nên nạp khoảng 35–45g tinh bột hấp thu vừa + 25g đạm nhẹ bụng:\n• 1 muỗng Whey Isolate + 1 quả chuối chín, hoặc\n• 150g khoai lang hấp + 100g ức gà.\nĐừng quên uống 400ml nước trước khi vào phòng tập nhé!',
            'createdAt': now
                .subtract(const Duration(hours: 4))
                .toIso8601String(),
          },
        ],
      },
      conversations: [
        {
          'id': directConvId,
          'relationshipId': relationshipId,
          'memberId': memberId,
          'coachId': coachId,
          'memberName': 'Nguyễn Minh Quân',
          'coachName': 'Lê Hoàng Nam',
          'status': 'ACTIVE',
          'lastMessageType': 'TEXT',
          'lastMessageContent':
              'Hẹn gặp em lúc 18:00 chiều nay tại khu tạ tự do nhé!',
          'lastMessageSenderId': coachId,
          'lastMessageAt': now
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'unreadCount': 1,
        },
      ],
      directMessages: {
        relationshipId: [
          {
            'id': 'dm-001',
            'conversationId': directConvId,
            'senderId': coachId,
            'messageType': 'TEXT',
            'content':
                'Chào Quân! Anh đã cập nhật giáo trình 8 tuần mới nhất cho em rồi nhé.',
            'sentAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          },
          {
            'id': 'dm-002',
            'conversationId': directConvId,
            'senderId': memberId,
            'messageType': 'TEXT',
            'content':
                'Dạ em cảm ơn Coach Nam! Chiều nay 18:00 mình tập Ngực & Tay sau đúng không anh?',
            'sentAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
          },
          {
            'id': 'dm-003',
            'conversationId': directConvId,
            'senderId': coachId,
            'messageType': 'TEXT',
            'content': 'Hẹn gặp em lúc 18:00 chiều nay tại khu tạ tự do nhé!',
            'sentAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
          },
        ],
      },
      coachRequests: [
        {
          'id': 'creq-demo-001',
          'memberId': '10000000-0000-4000-8000-000000000005',
          'memberName': 'Hoàng Gia Huy',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'status': 'PENDING',
          'note': 'Mình muốn đăng ký gói PT 1:1 tăng cơ 3 buổi/tuần khung 19:00.',
          'createdAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
        },
      ],
      earlyTerminationRequests: [],
      coachWorkSlots: {
        'coachId': coachId,
        'days': [
          for (final weekday in [1, 2, 3, 4, 5, 6])
            {
              'weekday': weekday,
              'starts': ['07:00', '09:00', '14:00', '16:00', '18:00', '19:30'],
            },
        ],
      },
      coachEntitlements: [
        {
          'id': 'ent-demo-001',
          'relationshipId': relationshipId,
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'planName': 'Gói PT 24 buổi · Khung 90 phút',
          'totalSessions': 24,
          'remainingSessions': 14,
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'startsOn': _isoDate(now.subtract(const Duration(days: 45))),
          'endsOn': _isoDate(now.add(const Duration(days: 41))),
        },
      ],
      coachBookings: [
        {
          'id': 'bk-demo-001',
          'entitlementId': 'ent-demo-001',
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'startsAt': DateTime(now.year, now.month, now.day, 18, 0)
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime(now.year, now.month, now.day, 19, 30)
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
          'status': 'BOOKED',
          'title': 'Ngực & Tay sau — Chỉnh form Bench Press',
        },
        {
          'id': 'bk-demo-002',
          'entitlementId': 'ent-demo-001',
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'startsAt': DateTime(now.year, now.month, now.day, 18, 0)
              .add(const Duration(days: 3))
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime(now.year, now.month, now.day, 19, 30)
              .add(const Duration(days: 3))
              .toUtc()
              .toIso8601String(),
          'status': 'BOOKED',
          'title': 'Lưng Xô & Tay trước',
        },
        {
          'id': 'bk-demo-past-001',
          'entitlementId': 'ent-demo-001',
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'startsAt': DateTime(now.year, now.month, now.day, 18, 0)
              .subtract(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime(now.year, now.month, now.day, 19, 30)
              .subtract(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
          'status': 'COMPLETED',
          'title': 'Upper Body & Core',
        },
        {
          'id': 'bk-demo-past-002',
          'entitlementId': 'ent-demo-001',
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'startsAt': DateTime(now.year, now.month, now.day, 18, 0)
              .subtract(const Duration(days: 4))
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime(now.year, now.month, now.day, 19, 30)
              .subtract(const Duration(days: 4))
              .toUtc()
              .toIso8601String(),
          'status': 'COMPLETED',
          'title': 'Lower Body · Squat & RDL',
        },
      ],
      coachNotifications: [
        {
          'id': '101',
          'kind': 'BOOKED',
          'category': 'COACH',
          'title': 'Nhắc lịch PT 1:1 hôm nay lúc 18:00',
          'body':
              'Coach Lê Hoàng Nam đã chuẩn bị bài Ngực & Tay sau. Nhớ khởi động trước 10 phút.',
          'actionRoute': '/member/features/sessions',
          'readAt': null,
          'isRead': false,
          'eventAt': now.subtract(const Duration(minutes: 25)).toIso8601String(),
          'createdAt': now.subtract(const Duration(minutes: 25)).toIso8601String(),
        },
        {
          'id': '102',
          'kind': 'TRAINING_PLAN_UPDATED',
          'category': 'TRAINING',
          'title': 'Giáo trình 8 tuần đã được cập nhật',
          'body':
              'Mức tạ tuần mới đã sẵn sàng trong mục Tập luyện.',
          'actionRoute': '/member/features/training',
          'readAt': null,
          'isRead': false,
          'eventAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'id': '103',
          'kind': 'NUTRITION_UPDATED',
          'category': 'TRAINING',
          'title': 'Coach đã cập nhật thực đơn',
          'body':
              'Thực đơn 2.400 kcal đã sẵn sàng trong mục Dinh dưỡng.',
          'actionRoute': '/member/features/nutrition',
          'readAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
          'isRead': true,
          'eventAt': now.subtract(const Duration(hours: 8)).toIso8601String(),
          'createdAt': now.subtract(const Duration(hours: 8)).toIso8601String(),
        },
        {
          'id': '104',
          'kind': 'NEW_MESSAGE',
          'category': 'MESSAGE',
          'title': 'Tin nhắn mới từ Lê Hoàng Nam',
          'body': 'Hôm nay tập xong nhớ nhắn lại cảm nhận cơ ngực nhé!',
          'actionRoute': '/member/features/messages',
          'readAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'isRead': true,
          'eventAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
        {
          'id': '105',
          'kind': 'ADMIN_BROADCAST',
          'category': 'SYSTEM',
          'title': 'Lịch hoạt động cuối tuần tại Meta Gym',
          'body':
              'Phòng tập mở cửa bình thường từ 05:30 đến 22:00 tất cả các ngày trong tuần.',
          'readAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'isRead': true,
          'eventAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'id': '106',
          'kind': 'PACKAGE_ACTIVE',
          'category': 'COACH',
          'title': 'Gói Coach đã kích hoạt',
          'body':
              'Gói huấn luyện 1:1 12 buổi đã kích hoạt và sẵn sàng đặt lịch.',
          'actionRoute': '/member/features/my-coach',
          'readAt': now.subtract(const Duration(days: 4)).toIso8601String(),
          'isRead': true,
          'eventAt': now.subtract(const Duration(days: 4)).toIso8601String(),
          'createdAt': now.subtract(const Duration(days: 4)).toIso8601String(),
        },
      ],
      notificationPreferences: {
        'workoutRemindersEnabled': true,
        'reminderTime': '17:30',
        'ptBeforeMinutes': 30,
        'nutritionRemindersEnabled': true,
        'coachUpdatesEnabled': true,
        'messagesEnabled': true,
        'callsEnabled': true,
        'adminBroadcastsEnabled': true,
      },
      adminBroadcasts: [
        {
          'id': 'bcast-demo-001',
          'title': 'Lịch hoạt động cuối tuần tại Meta Gym',
          'body':
              'Phòng tập mở cửa bình thường từ 05:30 đến 22:00 tất cả các ngày trong tuần.',
          'audience': 'ALL',
          'actionRoute': null,
          'recipientCount': 2,
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
      ],
      calls: [
        {
          'id': 'call-demo-001',
          'relationshipId': relationshipId,
          'callerId': memberId,
          'receiverId': coachId,
          'callerName': 'Nguyễn Minh Quân',
          'receiverName': 'Lê Hoàng Nam',
          'callType': 'VIDEO',
          'status': 'ENDED',
          'initiatedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'answeredAt': now
              .subtract(const Duration(days: 1))
              .add(const Duration(seconds: 5))
              .toIso8601String(),
          'endedAt': now
              .subtract(const Duration(days: 1))
              .add(const Duration(minutes: 12))
              .toIso8601String(),
          'durationSeconds': 715,
        },
      ],
    );
  }

  Map<String, dynamic>? findAccount(String email) {
    final normalized = email.trim().toLowerCase();
    for (final a in accounts) {
      if ((a['email'] as String).toLowerCase() == normalized) return a;
    }
    return null;
  }

  Map<String, dynamic> userForToken(String token) {
    if (token == LocalDemoAccounts.coachToken) {
      return findAccount(LocalDemoAccounts.coachEmail)!;
    }
    if (token.startsWith('local-demo-member-')) {
      final id = token.substring('local-demo-member-'.length);
      for (final a in accounts) {
        if (a['id'] == id) return a;
      }
    }
    return findAccount(LocalDemoAccounts.memberEmail)!;
  }

  Map<String, dynamic> registerMember({
    required String email,
    required String fullName,
    required String password,
    String role = 'MEMBER',
  }) {
    final existing = findAccount(email);
    if (existing != null) return existing;
    final user = <String, dynamic>{
      'id': 'local-user-${DateTime.now().millisecondsSinceEpoch}',
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role,
      'status': 'ACTIVE',
      'phone': '0909 000 111',
      'avatarUrl': null,
      'profile': {
        'heightCm': 175,
        'weightKg': 70.0,
        'fitnessGoal': 'Tăng cơ giảm mỡ',
      },
    };
    accounts.add(user);
    return user;
  }

  void updateUser(String email, Map<String, dynamic> patch) {
    final account = findAccount(email);
    if (account == null) return;
    if (patch['fullName'] is String) account['fullName'] = patch['fullName'];
    if (patch['phone'] is String) account['phone'] = patch['phone'];
    if (patch['profile'] is Map) {
      final existingProfile = Map<String, dynamic>.from(
        account['profile'] as Map? ?? const {},
      );
      existingProfile.addAll(Map<String, dynamic>.from(patch['profile'] as Map));
      account['profile'] = existingProfile;
    }
  }

  Map<String, dynamic> gymVisitMonth() => {
    'visits': gymVisits,
    'visitedDays': gymVisits.length,
    'eligibleDays': 22,
    'entryCount': gymVisits.length,
  };

  Map<String, dynamic> addCheckIn() {
    final now = DateTime.now();
    final visit = <String, dynamic>{
      'day': _isoDate(now),
      'checkedInAt': now.toIso8601String(),
      'gymName': 'Meta Gym Flagship Center',
      'gymAddress': '123 Nguyễn Thị Minh Khai, Quận 1, TP.HCM',
    };
    gymVisits.insert(0, visit);
    return visit;
  }

  Map<String, dynamic> coachMealPlan() => {
    'id': 'meal-plan-demo-001',
    'title': 'Thực đơn Tăng Cơ Nạc 2.400 kcal',
    'status': 'ACTIVE',
    'items': [
      for (var day = 1; day <= 7; day++) ...[
        {
          'day': day,
          'meal': 'BREAKFAST',
          'foodId': 'food-oats',
          'foodName': 'Yến mạch nguyên cám',
          'kcalPer100g': 380,
          'grams': 100,
        },
        {
          'day': day,
          'meal': 'LUNCH',
          'foodId': 'food-001',
          'foodName': 'Ức gà áp chảo',
          'kcalPer100g': 165,
          'grams': 200,
        },
        {
          'day': day,
          'meal': 'LUNCH',
          'foodId': 'food-002',
          'foodName': 'Cơm gạo lứt',
          'kcalPer100g': 123,
          'grams': 150,
        },
        {
          'day': day,
          'meal': 'DINNER',
          'foodId': 'food-003',
          'foodName': 'Cá hồi phi lê áp chảo',
          'kcalPer100g': 208,
          'grams': 180,
        },
      ],
    ],
  };

  double? _computeEntryKcal(
    Object? foodId,
    Object? quantity,
    Object? unit, {
    Object? explicitKcal,
  }) {
    if (foodId is String && foodId.isNotEmpty && unit == 'g') {
      final qty = quantity is num
          ? quantity.toDouble()
          : double.tryParse(quantity?.toString() ?? '');
      if (qty != null && qty > 0) {
        for (final food in nutritionFoods) {
          if (food['id'] == foodId) {
            final per100g = food['kcalPer100g'];
            if (per100g is num && per100g > 0) {
              return double.parse(((per100g * qty) / 100.0).toStringAsFixed(1));
            }
          }
        }
      }
    }
    if (explicitKcal is num && explicitKcal.isFinite && explicitKcal >= 0) {
      return explicitKcal.toDouble();
    }
    return null;
  }

  Map<String, dynamic> nutritionDay({String? date}) {
    final todayStr = _vnTodayStr();
    final targetDate = (date != null && date.trim().isNotEmpty)
        ? date.trim()
        : todayStr;
    final isToday = targetDate == todayStr;
    final dayEntries = nutritionEntries
        .where((e) => (e['eatenAt'] as String? ?? '').startsWith(targetDate))
        .toList();
    final parsedDate = DateTime.tryParse(targetDate) ?? _vnNow();
    final weekday = parsedDate.weekday;
    final plan = coachMealPlan();
    final planItems = (plan['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((item) => item['day'] == weekday)
        .toList();

    final comparisons = <String, dynamic>{};
    for (final mealKey in const ['BREAKFAST', 'LUNCH', 'DINNER']) {
      final mealPlanItems =
          planItems.where((item) => item['meal'] == mealKey).toList();
      final mealEntries =
          dayEntries.where((entry) => entry['mealType'] == mealKey).toList();
      final differences = <Map<String, dynamic>>[];
      var hasMissingItem = mealPlanItems.isEmpty;
      for (final planned in mealPlanItems) {
        final fid = planned['foodId'];
        final suggested = (planned['grams'] as num?)?.toDouble() ?? 0;
        final matched = mealEntries
            .where((e) => e['foodId'] == fid && e['unit'] == 'g')
            .toList();
        if (matched.isEmpty) {
          hasMissingItem = true;
          continue;
        }
        final actual = matched.fold<double>(
          0,
          (sum, e) => sum + ((e['quantity'] as num?)?.toDouble() ?? 0),
        );
        differences.add({
          'foodId': fid,
          'foodName': planned['foodName'],
          'suggestedGrams': suggested,
          'actualGrams': actual,
          'deltaGrams': actual - suggested,
        });
      }
      comparisons[mealKey] = {
        'status': differences.isNotEmpty
            ? 'DIFFERENCES'
            : (hasMissingItem ? 'INSUFFICIENT' : 'MATCHED'),
        'differences': differences,
      };
    }
    comparisons['SNACK'] = const {
      'status': 'UNREGULATED',
      'differences': <Object?>[],
    };

    return {
      'date': targetDate,
      'hasActiveMembership': true,
      'canWrite': isToday,
      'relationshipStatus': relationship['status'] ?? 'ACTIVE',
      'plan': plan,
      'entries': dayEntries,
      'comparisons': comparisons,
    };
  }

  Map<String, dynamic> addNutritionEntry(Map<String, dynamic> body) {
    final foodId = body['foodId'] as String?;
    final unit = (body['unit'] as String? ?? 'g').trim();
    final quantity = body['quantity'] ?? 100;
    final mealName =
        (body['mealName'] ?? body['foodName'] ?? body['name'] ?? 'Món ăn tự nhập')
            .toString()
            .trim();
    final kcal = _computeEntryKcal(
      foodId,
      quantity,
      unit,
      explicitKcal:
          body['estimatedCalories'] ?? body['kcal'] ?? body['calories'],
    );
    final entry = <String, dynamic>{
      'id':
          'entry-${DateTime.now().millisecondsSinceEpoch}-${++_nutritionEntrySeq}',
      'mealType': body['mealType'] ?? 'SNACK',
      'mealName': mealName.isEmpty ? 'Món ăn tự nhập' : mealName,
      'foodId': (foodId != null && foodId.isNotEmpty) ? foodId : null,
      'imageMediaId': body['imageMediaId'],
      'quantity': quantity,
      'unit': unit,
      'kcal': kcal,
      'eatenAt': body['eatenAt'] ?? '${_vnTodayStr()}T12:00:00+07:00',
      'notes': (body['notes'] as String? ?? '').trim(),
    };
    nutritionEntries.add(entry);
    return entry;
  }

  Map<String, dynamic> addMeasurement(Map<String, dynamic> body) {
    final m = <String, dynamic>{
      'id': 'meas-${DateTime.now().millisecondsSinceEpoch}',
      'measuredAt': DateTime.now().toIso8601String(),
      ...body,
    };
    measurements.add(m);
    return m;
  }

  Map<String, dynamic> _normalizeJournalPayload(Map<String, dynamic> body) {
    final out = Map<String, dynamic>.from(body);
    if (body['achievements'] is List) {
      out['achievements'] = (body['achievements'] as List).map((item) {
        if (item is Map) {
          return <String, dynamic>{
            'title': (item['title'] ?? '').toString(),
            'result': (item['result'] ?? '').toString(),
          };
        }
        return <String, dynamic>{'title': item.toString(), 'result': ''};
      }).toList();
    }
    if (body['photoMediaIds'] is List) {
      out['photoMediaIds'] =
          (body['photoMediaIds'] as List).map((e) => e.toString()).toList();
    }
    return out;
  }

  Map<String, dynamic> addJournalEntry(Map<String, dynamic> body) {
    final normalized = _normalizeJournalPayload(body);
    final j = <String, dynamic>{
      'id': 'jour-${DateTime.now().millisecondsSinceEpoch}',
      'journalDate': normalized['journalDate'] ?? _vnTodayStr(),
      'notes': normalized['notes'],
      'chestCm': normalized['chestCm'],
      'waistCm': normalized['waistCm'],
      'hipsCm': normalized['hipsCm'],
      'achievements':
          normalized['achievements'] ?? const <Map<String, dynamic>>[],
      'photoMediaIds': normalized['photoMediaIds'] ?? const <String>[],
    };
    journalEntries.insert(0, j);
    return j;
  }

  Map<String, dynamic> updateJournalEntry(
    String id,
    Map<String, dynamic> body,
  ) {
    final normalized = _normalizeJournalPayload(body);
    final updated = updateById(journalEntries, id, normalized);
    updated['achievements'] ??= const <Map<String, dynamic>>[];
    updated['photoMediaIds'] ??= const <String>[];
    return updated;
  }

  Map<String, dynamic> progressSummary() {
    final latest = measurements.isNotEmpty ? measurements.last : const <String, dynamic>{};
    return {
      'workoutCount': workoutLogs.length + 11,
      'mealCount': nutritionEntries.length,
      'progressPhotoCount': 0,
      'latestMeasurement': latest.isEmpty
          ? null
          : {
              'measuredAt': latest['measuredAt'],
              'weightKg': latest['weightKg'],
              'bodyFatPercent': latest['bodyFatPercent'],
            },
    };
  }

  List<Map<String, dynamic>> progressCharts({String? from, String? to}) {
    final points = measurements
        .where((m) {
          final dateStr = (m['measuredAt'] as String? ?? '').split('T').first;
          if (from != null && from.isNotEmpty && dateStr.compareTo(from) < 0) {
            return false;
          }
          if (to != null && to.isNotEmpty && dateStr.compareTo(to) > 0) {
            return false;
          }
          return m['weightKg'] != null;
        })
        .map(
          (m) => <String, dynamic>{
            'measuredAt': m['measuredAt'],
            'weightKg': m['weightKg'],
            'bodyFatPercent': m['bodyFatPercent'],
          },
        )
        .toList()
      ..sort(
        (a, b) =>
            (a['measuredAt'] as String).compareTo(b['measuredAt'] as String),
      );
    return points;
  }

  List<Map<String, dynamic>> journalCharts() {
    final points = journalEntries
        .where(
          (j) =>
              j['chestCm'] != null ||
              j['waistCm'] != null ||
              j['hipsCm'] != null,
        )
        .map(
          (j) => <String, dynamic>{
            'journalDate': j['journalDate'],
            'chestCm': j['chestCm'],
            'waistCm': j['waistCm'],
            'hipsCm': j['hipsCm'],
          },
        )
        .toList()
      ..sort(
        (a, b) =>
            (a['journalDate'] as String).compareTo(b['journalDate'] as String),
      );
    return points;
  }

  Map<String, dynamic> confirmPayment(String paymentId) {
    final payment = payments.firstWhere(
      (item) => item['id'] == paymentId,
      orElse: () => payments.first,
    );
    payment['status'] = 'SUCCESS';
    payment['confirmedAt'] = DateTime.now().toIso8601String();
    final planName = (payment['planName'] as String?) ?? 'Hạng Vàng — Pro 6 Tháng';
    final matchedPlan = membershipPlans.firstWhere(
      (p) => p['name'] == planName,
      orElse: () => membershipPlans.first,
    );
    final duration = (matchedPlan['durationDays'] as num?)?.toInt() ?? 180;
    final now = DateTime.now();
    final updated = <String, dynamic>{
      'id': 'mem-demo-${now.millisecondsSinceEpoch}',
      'startDate': _isoDate(now),
      'endDate': _isoDate(now.add(Duration(days: duration))),
      'status': 'ACTIVE',
      'sourcePaymentId': payment['id'],
      'planName': planName,
    };
    activeMembership
      ..clear()
      ..addAll(updated);
    membershipHistory.insert(0, Map<String, dynamic>.from(updated));
    return {'payment': payment, 'membership': activeMembership};
  }

  Map<String, dynamic> createCoachRequest(
    Map<String, dynamic> body,
    Map<String, dynamic> currentUser,
  ) {
    final coachId = body['coachId'] as String? ?? coaches.first['id'] as String;
    final coach = coaches.firstWhere(
      (c) => c['id'] == coachId,
      orElse: () => coaches.first,
    );
    final req = <String, dynamic>{
      'id': 'creq-${DateTime.now().millisecondsSinceEpoch}',
      'memberId': currentUser['id'],
      'memberName': currentUser['fullName'],
      'coachId': coach['id'],
      'coachName': coach['fullName'],
      'status': 'PENDING',
      'note': body['note'] ?? 'Đăng ký tập 1:1 cùng Coach',
      'createdAt': DateTime.now().toIso8601String(),
    };
    coachRequests.insert(0, req);
    return req;
  }

  Map<String, dynamic> respondCoachRequest(
    String id,
    Map<String, dynamic> body,
  ) {
    final req = coachRequests.firstWhere(
      (e) => e['id'] == id,
      orElse: () => coachRequests.first,
    );
    final nextStatus =
        (body['status'] ?? body['decision'] ?? 'ACCEPTED').toString();
    req['status'] = nextStatus;
    return req;
  }

  static final RegExp _restDayTitlePattern = RegExp(
    r'(nghỉ|phục hồi|hồi phục|\brest\b|recovery|off\s*day)',
    caseSensitive: false,
  );

  bool isRestOrRecoveryStartsAt(String? startsAtStr) {
    if (startsAtStr == null || startsAtStr.trim().isEmpty) return false;
    final parsed = DateTime.tryParse(startsAtStr.trim());
    if (parsed == null) return false;
    final gym = parsed.toUtc().add(const Duration(hours: 7));
    return isRestOrRecoveryDate(DateTime(gym.year, gym.month, gym.day));
  }

  bool isRestOrRecoveryDate(DateTime gymDate) {
    final days = (activeTrainingPlan['days'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (days.isEmpty) return false;

    final iso = _isoDate(gymDate);
    Map<String, dynamic>? matched;
    for (final d in days) {
      final scheduled = d['scheduledDate']?.toString();
      if (scheduled != null &&
          scheduled.length >= 10 &&
          scheduled.substring(0, 10) == iso) {
        matched = d;
        break;
      }
    }
    matched ??= () {
      for (final d in days) {
        final scheduled = d['scheduledDate']?.toString();
        int weekday;
        if (scheduled != null && scheduled.trim().isNotEmpty) {
          final parsed = DateTime.tryParse(scheduled.trim());
          weekday = parsed?.weekday ?? (((d['dayNumber'] as int? ?? 1) - 1) % 7) + 1;
        } else {
          weekday = (((d['dayNumber'] as int? ?? 1) - 1) % 7) + 1;
        }
        if (weekday == gymDate.weekday) return d;
      }
      return null;
    }();

    if (matched == null) return true;
    final exercises = matched['exercises'] as List? ?? const [];
    if (exercises.isEmpty) return true;
    final title = matched['title']?.toString() ?? '';
    return _restDayTitlePattern.hasMatch(title);
  }

  List<Map<String, dynamic>> availableCoachSlots(String? dateKey) {
    if (dateKey == null || dateKey.trim().isEmpty) return const [];
    final parsed = DateTime.tryParse('${dateKey.trim()}T00:00:00');
    if (parsed == null) return const [];
    if (isRestOrRecoveryDate(parsed)) return const [];

    final workDays = (coachWorkSlots['days'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final daySlot = workDays
        .where((d) => d['weekday'] == parsed.weekday)
        .firstOrNull;
    final starts = (daySlot?['starts'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final nowUtc = DateTime.now().toUtc();

    final result = <Map<String, dynamic>>[];
    for (final hhmm in starts) {
      final startLocal = DateTime.tryParse('${dateKey.trim()}T$hhmm:00+07:00');
      if (startLocal == null) continue;
      if (!startLocal.toUtc().isAfter(nowUtc)) continue;
      result.add({
        'startsAt': startLocal.toUtc().toIso8601String(),
        'endsAt': startLocal
            .add(const Duration(minutes: 90))
            .toUtc()
            .toIso8601String(),
      });
    }
    return result;
  }

  Map<String, dynamic> createCoachBooking(
    Map<String, dynamic> body,
    Map<String, dynamic> currentUser,
  ) {
    final startsAtStr =
        (body['startsAt'] ?? body['scheduledAt'] ?? DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String())
            .toString();
    final parsedStart = DateTime.tryParse(startsAtStr) ?? DateTime.now();
    final bk = <String, dynamic>{
      'id': 'bk-${DateTime.now().millisecondsSinceEpoch}',
      'entitlementId': body['entitlementId'] ?? 'ent-demo-001',
      'relationshipId': relationship['id'],
      'memberId': currentUser['id'],
      'memberName': currentUser['fullName'],
      'coachId': relationship['coachId'],
      'coachName': relationship['coachName'],
      'startsAt': startsAtStr,
      'endsAt': parsedStart
          .add(const Duration(minutes: 90))
          .toUtc()
          .toIso8601String(),
      'status': 'BOOKED',
      'title': body['title'] ?? 'Buổi tập PT 1:1',
    };
    coachBookings.insert(0, bk);
    return bk;
  }

  Map<String, dynamic> updateCoachBooking(
    String id,
    Map<String, dynamic> body,
  ) {
    final bk = coachBookings.firstWhere(
      (e) => e['id'] == id,
      orElse: () => coachBookings.first,
    );
    final action = (body['action'] as String? ?? '').toUpperCase();
    if (action == 'COMPLETE') {
      bk['status'] = 'COMPLETED';
    } else if (action == 'CANCEL') {
      bk['status'] = 'CANCELLED';
    } else if (body['status'] is String) {
      bk['status'] = body['status'];
    }
    if (body['startsAt'] is String) {
      bk['startsAt'] = body['startsAt'];
      final parsed = DateTime.tryParse(body['startsAt'] as String);
      if (parsed != null) {
        bk['endsAt'] = parsed
            .add(const Duration(minutes: 90))
            .toUtc()
            .toIso8601String();
      }
    }
    return bk;
  }

  Map<String, dynamic> addTrainingSession(Map<String, dynamic> body) {
    final s = <String, dynamic>{
      'id': 'sess-${DateTime.now().millisecondsSinceEpoch}',
      'relationshipId': relationship['id'],
      'memberId': relationship['memberId'] ?? '10000000-0000-4000-8000-000000000003',
      'memberName': 'Nguyễn Minh Quân',
      'coachId': relationship['coachId'],
      'coachName': relationship['coachName'],
      'title': body['title'] ?? 'Buổi tập mới',
      'scheduledAt': body['scheduledAt'] ??
          DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'durationMinutes': body['durationMinutes'] ?? 60,
      'status': body['status'] ?? 'SCHEDULED',
      'notes': body['notes'] ?? '',
    };
    sessions.insert(0, s);
    return s;
  }

  Map<String, dynamic> updateTrainingSession(
    String id,
    Map<String, dynamic> body,
  ) {
    return updateById(sessions, id, body);
  }

  List<Map<String, dynamic>> selfTrainingRange({String? from, String? to}) {
    final filtered = selfTrainingDays.where((d) {
      final dateStr = d['planDate'] as String? ?? '';
      if (dateStr.isEmpty) return false;
      if (from != null && from.isNotEmpty && dateStr.compareTo(from) < 0) {
        return false;
      }
      if (to != null && to.isNotEmpty && dateStr.compareTo(to) > 0) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      final dateCmp = (a['planDate'] as String? ?? '').compareTo(
        b['planDate'] as String? ?? '',
      );
      if (dateCmp != 0) return dateCmp;
      return (a['startTime'] as String? ?? '99:99').compareTo(
        b['startTime'] as String? ?? '99:99',
      );
    });
    return filtered;
  }

  List<Map<String, dynamic>> _mapSelfTrainingExercises(
    String planDate,
    Map<String, dynamic> body,
  ) {
    final mappedExercises = <Map<String, dynamic>>[];
    if (body['exercises'] is List) {
      final rawList = body['exercises'] as List;
      for (var i = 0; i < rawList.length; i++) {
        final raw = rawList[i];
        if (raw is! Map) continue;
        final name = (raw['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final rawId = (raw['id'] ?? '').toString().trim();
        final rawSets = raw['sets'];
        final sets = rawSets is num
            ? rawSets.toInt()
            : int.tryParse(rawSets?.toString() ?? '');
        final reps = (raw['reps'] ?? '').toString().trim();
        mappedExercises.add({
          'id': rawId.isNotEmpty ? rawId : 'custom-$planDate-$i',
          'name': name,
          if (sets != null && sets > 0) 'sets': sets,
          if (reps.isNotEmpty) 'reps': reps,
        });
      }
    } else {
      final rawIds = (body['exerciseIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      for (final exId in rawIds) {
        final matched = exercises.where((e) => e['id'] == exId).firstOrNull;
        mappedExercises.add({
          'id': exId,
          'name': (matched?['name'] as String?) ?? 'Bài tập $exId',
        });
      }
    }
    return mappedExercises;
  }

  Map<String, dynamic> createSelfTrainingSession(Map<String, dynamic> body) {
    final planDate = (body['planDate'] as String? ?? '').trim();
    final mappedExercises = _mapSelfTrainingExercises(planDate, body);
    final created = <String, dynamic>{
      'id': 'self-$planDate-${DateTime.now().microsecondsSinceEpoch}',
      'planDate': planDate,
      'title': (body['title'] as String? ?? 'Buổi tự tập').trim(),
      'startTime': body['startTime'] as String?,
      'notes': (body['notes'] as String? ?? '').trim(),
      if (body['iconKey'] != null) 'iconKey': body['iconKey'],
      'exercises': mappedExercises,
    };
    selfTrainingDays.add(created);
    return created;
  }

  Map<String, dynamic>? updateSelfTrainingSession(
    String id,
    Map<String, dynamic> body,
  ) {
    final idx = selfTrainingDays.indexWhere((d) => d['id'] == id);
    if (idx < 0) return null;
    final existing = selfTrainingDays[idx];
    final planDate = existing['planDate'] as String? ?? '';
    final mappedExercises = _mapSelfTrainingExercises(planDate, body);
    final updated = <String, dynamic>{
      'id': id,
      'planDate': planDate,
      'title': (body['title'] as String? ?? 'Buổi tự tập').trim(),
      'startTime': body['startTime'] as String?,
      'notes': (body['notes'] as String? ?? '').trim(),
      if (body['iconKey'] != null || existing['iconKey'] != null)
        'iconKey': body['iconKey'] ?? existing['iconKey'],
      'exercises': mappedExercises.isNotEmpty
          ? mappedExercises
          : (existing['exercises'] ?? const <Object?>[]),
    };
    selfTrainingDays[idx] = updated;
    return updated;
  }

  Map<String, dynamic> upsertSelfTrainingDay(
    String planDate,
    Map<String, dynamic> body,
  ) {
    final idx = selfTrainingDays.indexWhere((d) => d['planDate'] == planDate);
    final mappedExercises = _mapSelfTrainingExercises(planDate, body);
    final existing = idx >= 0 ? selfTrainingDays[idx] : null;
    final updated = <String, dynamic>{
      'id': existing?['id'] ?? 'self-$planDate',
      'planDate': planDate,
      'title': (body['title'] as String? ?? 'Buổi tự tập').trim(),
      'startTime': body['startTime'] as String?,
      'notes': (body['notes'] as String? ?? '').trim(),
      if (body['iconKey'] != null || existing?['iconKey'] != null)
        'iconKey': body['iconKey'] ?? existing?['iconKey'],
      'exercises': mappedExercises.isNotEmpty
          ? mappedExercises
          : (existing?['exercises'] ?? const <Object?>[]),
    };
    if (idx >= 0) {
      selfTrainingDays[idx] = updated;
    } else {
      selfTrainingDays.add(updated);
    }
    return updated;
  }

  Map<String, dynamic> updateNutritionEntry(
    String id,
    Map<String, dynamic> body,
  ) {
    final idx = nutritionEntries.indexWhere((e) => e['id'] == id);
    final target = idx >= 0
        ? nutritionEntries[idx]
        : <String, dynamic>{'id': id};
    if (body.containsKey('mealType')) target['mealType'] = body['mealType'];
    if (body.containsKey('mealName') || body.containsKey('foodName')) {
      target['mealName'] =
          (body['mealName'] ?? body['foodName'] ?? target['mealName'])
              .toString();
    }
    if (body.containsKey('foodId')) target['foodId'] = body['foodId'];
    if (body.containsKey('imageMediaId')) {
      target['imageMediaId'] = body['imageMediaId'];
    }
    if (body.containsKey('quantity')) target['quantity'] = body['quantity'];
    if (body.containsKey('unit')) target['unit'] = body['unit'];
    if (body.containsKey('eatenAt')) target['eatenAt'] = body['eatenAt'];
    if (body.containsKey('notes')) target['notes'] = body['notes'];
    target['kcal'] = _computeEntryKcal(
      target['foodId'],
      target['quantity'],
      target['unit'],
      explicitKcal:
          body['estimatedCalories'] ?? body['kcal'] ?? body['calories'],
    );
    if (idx < 0) nutritionEntries.add(target);
    return target;
  }

  Map<String, dynamic> addWorkoutLog(Map<String, dynamic> body) {
    final log = <String, dynamic>{
      'id': 'wlog-${DateTime.now().millisecondsSinceEpoch}',
      'performedAt': body['performedAt'] ?? DateTime.now().toIso8601String(),
      'title': body['title'] ?? 'Buổi tập hoàn thành',
      'durationMinutes': body['durationMinutes'] ?? 55,
      'notes': body['notes'] ?? '',
      ...body,
    };
    workoutLogs.insert(0, log);
    return log;
  }

  Map<String, dynamic> updateById(
    List<Map<String, dynamic>> list,
    String id,
    Map<String, dynamic> patch,
  ) {
    for (final item in list) {
      if (item['id'] == id) {
        item.addAll(patch);
        return item;
      }
    }
    return list.isNotEmpty ? list.first : <String, dynamic>{'id': id, ...patch};
  }

  Map<String, dynamic> renameAiConversation(String convId, String title) {
    for (final c in aiConversations) {
      if (c['id'] == convId) {
        c['title'] = title;
        c['updatedAt'] = DateTime.now().toIso8601String();
        return c;
      }
    }
    return createAiConversation(title);
  }

  Map<String, dynamic> createAiConversation(String title) {
    final nowIso = DateTime.now().toIso8601String();
    final conv = <String, dynamic>{
      'id': 'ai-conv-${DateTime.now().millisecondsSinceEpoch}',
      'title': title.isEmpty ? 'Hội thoại mới với Meta AI' : title,
      'createdAt': nowIso,
      'updatedAt': nowIso,
    };
    aiConversations.insert(0, conv);
    aiMessages[conv['id'] as String] = [];
    return conv;
  }

  Map<String, dynamic> sendAiMessage(
    String convId,
    String content, {
    String? requestId,
  }) {
    final nowIso = DateTime.now().toIso8601String();
    final list = aiMessages.putIfAbsent(convId, () => []);
    final userMsg = <String, dynamic>{
      'id': 'ai-u-${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': convId,
      'role': 'USER',
      'status': 'COMPLETED',
      'content': content,
      'createdAt': nowIso,
    };
    final lower = content.toLowerCase();
    final replyContent = lower.contains('ăn') || lower.contains('dinh dưỡng') || lower.contains('calo')
        ? 'Gợi ý dinh dưỡng từ Meta AI (chế độ Demo Offline):\n• Mục tiêu hôm nay: 2.400 kcal · 180g Protein.\n• Trước tập 60 phút: 150g khoai lang + 120g ức gà hoặc 1 muỗng Whey + chuối.\n• Sau tập 45 phút: bổ sung ngay 30g đạm nhanh và 500ml nước lọc.'
        : lower.contains('lịch') || lower.contains('tập') || lower.contains('ngực') || lower.contains('chân')
        ? 'Gợi ý tập luyện từ Meta AI (chế độ Demo Offline):\n• Khởi động khớp vai & hông 8 phút.\n• Tập trung 4 hiệp chính ở mức RPE 8, nghỉ 90 giây giữa hiệp.\n• Ghi lại mức tạ sau buổi tập để theo dõi tiến độ tăng sức mạnh nhé!'
        : 'Meta AI đã nhận câu hỏi "$content". Dựa trên hồ sơ hiện tại của bạn (72.1kg · 17.5% mỡ · mục tiêu tăng cơ nạc), hãy duy trì đều 4 buổi/tuần, giữ kỹ thuật chuẩn và đạt đủ 180g protein hôm nay nhé!';
    final replyId = 'ai-a-${DateTime.now().millisecondsSinceEpoch + 1}';
    final replyAt = DateTime.now()
        .add(const Duration(milliseconds: 200))
        .toIso8601String();
    final replyMsg = <String, dynamic>{
      'id': replyId,
      'conversationId': convId,
      'role': 'ASSISTANT',
      'status': 'COMPLETED',
      'content': replyContent,
      'createdAt': replyAt,
    };
    list.addAll([userMsg, replyMsg]);
    return {
      'requestId': requestId ?? 'req-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'COMPLETED',
      'reply': {
        'id': replyId,
        'content': replyContent,
        'createdAt': replyAt,
      },
    };
  }

  List<Map<String, dynamic>> messagesForConversation(String key) {
    if (directMessages.containsKey(key)) return directMessages[key]!;
    for (final c in conversations) {
      if (c['id'] == key || c['relationshipId'] == key) {
        final relKey = (c['relationshipId'] ?? c['id']) as String;
        return directMessages.putIfAbsent(relKey, () => []);
      }
    }
    return directMessages.putIfAbsent(key, () => []);
  }

  Map<String, dynamic> sendDirectMessage(
    String convKey, {
    required String senderId,
    required String content,
    String messageType = 'TEXT',
    String? mediaId,
  }) {
    final nowIso = DateTime.now().toIso8601String();
    final targetConv = conversations.firstWhere(
      (c) => c['id'] == convKey || c['relationshipId'] == convKey,
      orElse: () => conversations.first,
    );
    final storageKey = (targetConv['relationshipId'] ?? targetConv['id']) as String;
    final msg = <String, dynamic>{
      'id': 'dm-${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': targetConv['id'],
      'senderId': senderId,
      'messageType': messageType,
      'content': content,
      'mediaId': mediaId,
      'sentAt': nowIso,
    };
    final list = directMessages.putIfAbsent(storageKey, () => []);
    list.add(msg);
    targetConv['lastMessageType'] = messageType;
    targetConv['lastMessageContent'] = content;
    targetConv['lastMessageSenderId'] = senderId;
    targetConv['lastMessageAt'] = nowIso;
    targetConv['unreadCount'] = 0;

    // Tự động thêm phản hồi mô phỏng từ đầu dây bên kia khi chat offline
    final peerId = senderId == targetConv['memberId']
        ? targetConv['coachId'] as String
        : targetConv['memberId'] as String;
    final autoReplyText = senderId == targetConv['memberId']
        ? 'Coach Nam đã nhận tin nhắn "$content". Hẹn gặp bạn đúng giờ tại Meta Gym nhé!'
        : 'Dạ em đã nhận thông tin từ Coach Nam ạ!';
    final replyAt = DateTime.now()
        .add(const Duration(milliseconds: 300))
        .toIso8601String();
    list.add({
      'id': 'dm-auto-${DateTime.now().millisecondsSinceEpoch + 1}',
      'conversationId': targetConv['id'],
      'senderId': peerId,
      'messageType': 'TEXT',
      'content': autoReplyText,
      'sentAt': replyAt,
    });
    targetConv['lastMessageContent'] = autoReplyText;
    targetConv['lastMessageSenderId'] = peerId;
    targetConv['lastMessageAt'] = replyAt;
    return msg;
  }

  Map<String, dynamic> createCall(
    Map<String, dynamic> body,
    Map<String, dynamic> currentUser,
  ) {
    final now = DateTime.now();
    final callerId = currentUser['id'] as String;
    final isCoachCaller = currentUser['role'] == 'COACH';
    final memberAcc = findAccount(LocalDemoAccounts.memberEmail)!;
    final coachAcc = findAccount(LocalDemoAccounts.coachEmail)!;
    final receiver = isCoachCaller ? memberAcc : coachAcc;
    final call = <String, dynamic>{
      'id': 'call-${now.millisecondsSinceEpoch}',
      'relationshipId': body['relationshipId'] ?? relationship['id'],
      'callerId': callerId,
      'receiverId': receiver['id'],
      'callerName': currentUser['fullName'],
      'receiverName': receiver['fullName'],
      'callType': body['callType'] ?? 'AUDIO',
      'status': 'RINGING',
      'initiatedAt': now.toIso8601String(),
      'durationSeconds': 0,
    };
    calls.insert(0, call);
    return call;
  }

  Map<String, dynamic> getCallAndSimulateAnswer(String callId) {
    final call = calls.firstWhere(
      (c) => c['id'] == callId,
      orElse: () => calls.first,
    );
    if (call['status'] == 'RINGING') {
      final initiated = DateTime.tryParse(call['initiatedAt'] as String? ?? '');
      if (initiated == null ||
          DateTime.now().difference(initiated).inMilliseconds >= 1200) {
        call['status'] = 'ANSWERED';
        call['answeredAt'] = DateTime.now().toIso8601String();
      }
    }
    return call;
  }

  Map<String, dynamic> updateCallStatus(
    String callId,
    Map<String, dynamic> body,
  ) {
    final call = calls.firstWhere(
      (c) => c['id'] == callId,
      orElse: () => calls.first,
    );
    final status = (body['status'] as String?) ?? 'ENDED';
    call['status'] = status;
    if (status == 'ANSWERED' && call['answeredAt'] == null) {
      call['answeredAt'] = DateTime.now().toIso8601String();
    }
    if (const {'ENDED', 'REJECTED', 'MISSED', 'FAILED'}.contains(status)) {
      final now = DateTime.now();
      call['endedAt'] = now.toIso8601String();
      final answered = DateTime.tryParse(call['answeredAt'] as String? ?? '');
      if (answered != null) {
        call['durationSeconds'] = now.difference(answered).inSeconds.clamp(0, 99999);
      }
    }
    return call;
  }

  Map<String, dynamic> toJson() => {
    'accounts': accounts,
    'activeMembership': activeMembership,
    'membershipHistory': membershipHistory,
    'payments': payments,
    'sessions': sessions,
    'activeTrainingPlan': activeTrainingPlan,
    'selfTrainingDays': selfTrainingDays,
    'gymVisits': gymVisits,
    'activeNutritionGuide': activeNutritionGuide,
    'nutritionEntries': nutritionEntries,
    'measurements': measurements,
    'journalEntries': journalEntries,
    'workoutLogs': workoutLogs,
    'aiConversations': aiConversations,
    'aiMessages': aiMessages,
    'conversations': conversations,
    'directMessages': directMessages,
    'coachRequests': coachRequests,
    'earlyTerminationRequests': earlyTerminationRequests,
    'coachWorkSlots': coachWorkSlots,
    'coachEntitlements': coachEntitlements,
    'coachBookings': coachBookings,
    'coachNotifications': coachNotifications,
    'notificationPreferences': notificationPreferences,
    'adminBroadcasts': adminBroadcasts,
    'calls': calls,
  };

  factory _LocalDemoStore.fromJson(Map<String, dynamic> json) {
    final base = _LocalDemoStore.seeded();
    List<Map<String, dynamic>>? readList(String key) {
      final raw = json[key];
      if (raw is! List) return null;
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    Map<String, dynamic>? readMap(String key) {
      final raw = json[key];
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    }

    Map<String, List<Map<String, dynamic>>>? readMapList(String key) {
      final raw = json[key];
      if (raw is! Map) return null;
      return raw.map(
        (k, v) => MapEntry(
          k.toString(),
          (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        ),
      );
    }

    return _LocalDemoStore(
      accounts: readList('accounts') ?? base.accounts,
      activeMembership: readMap('activeMembership') ?? base.activeMembership,
      membershipHistory: readList('membershipHistory') ?? base.membershipHistory,
      membershipPlans: base.membershipPlans,
      payments: readList('payments') ?? base.payments,
      relationship: base.relationship,
      coaches: base.coaches,
      coachMembers: base.coachMembers,
      sessions: readList('sessions') ?? base.sessions,
      activeTrainingPlan:
          readMap('activeTrainingPlan') ?? base.activeTrainingPlan,
      selfTrainingDays: readList('selfTrainingDays') ?? base.selfTrainingDays,
      gymVisits: readList('gymVisits') ?? base.gymVisits,
      activeNutritionGuide:
          readMap('activeNutritionGuide') ?? base.activeNutritionGuide,
      nutritionFoods: base.nutritionFoods,
      nutritionEntries: readList('nutritionEntries') ?? base.nutritionEntries,
      measurements: readList('measurements') ?? base.measurements,
      journalEntries: readList('journalEntries') ?? base.journalEntries,
      workoutLogs: readList('workoutLogs') ?? base.workoutLogs,
      equipment: base.equipment,
      exercises: base.exercises,
      gymProfile: base.gymProfile,
      aiConversations: readList('aiConversations') ?? base.aiConversations,
      aiMessages: readMapList('aiMessages') ?? base.aiMessages,
      conversations: readList('conversations') ?? base.conversations,
      directMessages: readMapList('directMessages') ?? base.directMessages,
      coachRequests: readList('coachRequests') ?? base.coachRequests,
      earlyTerminationRequests:
          readList('earlyTerminationRequests') ?? base.earlyTerminationRequests,
      coachWorkSlots: readMap('coachWorkSlots') ?? base.coachWorkSlots,
      coachEntitlements:
          readList('coachEntitlements') ?? base.coachEntitlements,
      coachBookings: readList('coachBookings') ?? base.coachBookings,
      coachNotifications:
          readList('coachNotifications') ?? base.coachNotifications,
      notificationPreferences:
          readMap('notificationPreferences') ?? base.notificationPreferences,
      adminBroadcasts: readList('adminBroadcasts') ?? base.adminBroadcasts,
      calls: readList('calls') ?? base.calls,
    );
  }
}
