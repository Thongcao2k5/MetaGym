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
  static const _storageKey = 'meta_gym_local_demo_state_v5';

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
      '/member/nutrition/foods',
      '/body-measurements',
      '/journal',
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
    };
    if (emptyLists.contains(path) ||
        path.endsWith('/messages') ||
        path.endsWith('/outcomes')) {
      return const <Object?>[];
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
    if (path == '/member/nutrition/day') {
      return {
        'date': _LocalDemoStore._isoDate(DateTime.now()),
        'target': {'calories': 2400, 'proteinG': 180, 'carbsG': 250, 'fatG': 65},
        'consumed': {'calories': 0, 'proteinG': 0, 'carbsG': 0, 'fatG': 0},
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
    if (path == '/coach-entitlements' && method == 'GET') {
      return (store.coachEntitlements, 200);
    }
    if (path == '/coach-bookings/blocks' && method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path == '/coach-bookings' && method == 'POST') {
      return (store.createCoachBooking(body, currentUser), 201);
    }
    if (path == '/coach-bookings/blocks' && method == 'PUT') {
      return (const {'saved': true}, 200);
    }
    if (path.startsWith('/coach-bookings/') && method == 'PATCH') {
      final id = path.split('/')[2];
      return (store.updateCoachBooking(id, body), 200);
    }
    if (path == '/coach-notifications' && method == 'GET') {
      return (store.coachNotifications, 200);
    }
    if (path.startsWith('/coach-notifications/') &&
        path.endsWith('/read') &&
        method == 'PATCH') {
      final id = path.split('/')[2];
      for (final n in store.coachNotifications) {
        if (n['id'] == id) n['isRead'] = true;
      }
      return (const {'read': true}, 200);
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
      return (store.selfTrainingDays, 200);
    }
    if (path.startsWith('/member/self-training-days/') &&
        (method == 'PUT' || method == 'PATCH')) {
      final dayNum = int.tryParse(path.split('/').last) ?? 1;
      return (store.upsertSelfTrainingDay(dayNum, body), 200);
    }
    if (path.startsWith('/member/self-training-days/') && method == 'DELETE') {
      final dayNum = int.tryParse(path.split('/').last) ?? 1;
      store.selfTrainingDays.removeWhere((d) => d['dayOfWeek'] == dayNum);
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
      return (store.nutritionDay(), 200);
    }
    if (path == '/member/nutrition/foods' && method == 'GET') {
      return (store.nutritionFoods, 200);
    }
    if (path == '/member/nutrition/entries' && method == 'POST') {
      return (store.addNutritionEntry(body), 201);
    }
    if (path.startsWith('/member/nutrition/entries/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = path.split('/').last;
      return (store.updateNutritionEntry(id, body), 200);
    }
    if (path.startsWith('/member/nutrition/entries/') && method == 'DELETE') {
      final id = path.split('/').last;
      store.nutritionEntries.removeWhere((e) => e['id'] == id);
      return (const {'deleted': true}, 200);
    }

    // --- Progress, Measurements, Journal, Photos, Workouts (CRUD đầy đủ) ---
    if (path == '/progress/me/summary' && method == 'GET') {
      return (store.progressSummary(), 200);
    }
    if (path == '/progress/me/charts' && method == 'GET') {
      return (store.progressCharts(), 200);
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
      return (store.progressCharts(), 200);
    }
    if (path.startsWith('/journal/') &&
        (method == 'PATCH' || method == 'PUT')) {
      final id = path.split('/').last;
      return (store.updateById(store.journalEntries, id, body), 200);
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
        store.equipment
            .where((e) => (e['name'] as String).toLowerCase().contains(q))
            .toList(),
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
        store.exercises
            .where((e) => (e['name'] as String).toLowerCase().contains(q))
            .toList(),
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
  final List<Map<String, dynamic>> calls;

  static String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  factory _LocalDemoStore.seeded() {
    final now = DateTime.now();
    final todayStr = _isoDate(now);

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
            'title': 'Upper Body & Core',
            'scheduledDate': todayStr,
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
            'meals': [
              {
                'displayOrder': 1,
                'mealType': 'BREAKFAST',
                'scheduledTime': '07:30',
                'title': 'Yến mạch, chuối & 3 lòng trắng trứng',
                'notes': '520 kcal · 34g Protein · 68g Carbs · 10g Fat',
              },
              {
                'displayOrder': 2,
                'mealType': 'LUNCH',
                'scheduledTime': '12:00',
                'title': 'Ức gà áp chảo 200g & Cơm gạo lứt',
                'notes': '680 kcal · 56g Protein · 75g Carbs · 14g Fat',
              },
              {
                'displayOrder': 3,
                'mealType': 'SNACK',
                'scheduledTime': '16:30',
                'title': 'Whey Isolate 1 muỗng & Táo xanh',
                'notes': '220 kcal · 26g Protein · 22g Carbs · 2g Fat',
              },
              {
                'displayOrder': 4,
                'mealType': 'DINNER',
                'scheduledTime': '19:45',
                'title': 'Cá hồi phi lê 180g & Khoai lang',
                'notes': '580 kcal · 42g Protein · 48g Carbs · 20g Fat',
              },
            ],
          },
          {
            'dayNumber': 2,
            'title': 'Lưng Xô & Tay Trước (Back & Biceps)',
            'scheduledDate': _isoDate(now.add(const Duration(days: 2))),
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
            'scheduledDate': _isoDate(now.add(const Duration(days: 4))),
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
        ],
      },
      selfTrainingDays: [
        {'dayOfWeek': 1, 'title': 'Ngực & Tay sau', 'muscleFocus': 'CHEST'},
        {'dayOfWeek': 2, 'title': 'Cardio phục hồi', 'muscleFocus': 'CARDIO'},
        {'dayOfWeek': 3, 'title': 'Lưng xô & Tay trước', 'muscleFocus': 'BACK'},
        {'dayOfWeek': 4, 'title': 'Nghỉ phục hồi', 'muscleFocus': 'REST'},
        {'dayOfWeek': 5, 'title': 'Chân đùi & Core', 'muscleFocus': 'LEGS'},
        {'dayOfWeek': 6, 'title': 'Vai & Tay', 'muscleFocus': 'SHOULDERS'},
        {'dayOfWeek': 7, 'title': 'Nghỉ phục hồi', 'muscleFocus': 'REST'},
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
          'id': 'food-001',
          'name': 'Ức gà áp chảo',
          'servingSize': 100,
          'servingUnit': 'g',
          'calories': 165,
          'proteinG': 31,
          'carbsG': 0,
          'fatG': 3.6,
        },
        {
          'id': 'food-002',
          'name': 'Cơm gạo lứt',
          'servingSize': 150,
          'servingUnit': 'g',
          'calories': 185,
          'proteinG': 4,
          'carbsG': 39,
          'fatG': 1.5,
        },
        {
          'id': 'food-003',
          'name': 'Cá hồi phi lê áp chảo',
          'servingSize': 150,
          'servingUnit': 'g',
          'calories': 312,
          'proteinG': 30,
          'carbsG': 0,
          'fatG': 20,
        },
        {
          'id': 'food-004',
          'name': 'Whey Protein Isolate (1 muỗng)',
          'servingSize': 30,
          'servingUnit': 'g',
          'calories': 120,
          'proteinG': 25,
          'carbsG': 2,
          'fatG': 1,
        },
      ],
      nutritionEntries: [
        {
          'id': 'entry-001',
          'mealType': 'BREAKFAST',
          'foodName': 'Yến mạch + Chuối + 3 lòng trắng trứng',
          'calories': 520,
          'proteinG': 34,
          'carbsG': 68,
          'fatG': 10,
          'loggedAt': DateTime(
            now.year,
            now.month,
            now.day,
            7,
            30,
          ).toIso8601String(),
        },
        {
          'id': 'entry-002',
          'mealType': 'LUNCH',
          'foodName': '200g Ức gà áp chảo & Cơm gạo lứt',
          'calories': 680,
          'proteinG': 56,
          'carbsG': 75,
          'fatG': 14,
          'loggedAt': DateTime(
            now.year,
            now.month,
            now.day,
            12,
            15,
          ).toIso8601String(),
        },
        {
          'id': 'entry-003',
          'mealType': 'SNACK',
          'foodName': 'Whey Isolate + Táo xanh',
          'calories': 220,
          'proteinG': 26,
          'carbsG': 22,
          'fatG': 2,
          'loggedAt': DateTime(
            now.year,
            now.month,
            now.day,
            16,
            20,
          ).toIso8601String(),
        },
      ],
      measurements: [
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
          'id': 'jour-001',
          'journalDate': _isoDate(now.subtract(const Duration(days: 3))),
          'notes':
              'Buổi tập Ngực & Tay sau hoàn thành xuất sắc! Đẩy Bench Press lên mức 70kg x 8 reps.',
          'chestCm': 97.5,
          'waistCm': 79.5,
          'hipsCm': 94.0,
          'achievements': ['PR Bench Press 70kg', 'Năng lượng tập luyện cao'],
        },
        {
          'id': 'jour-002',
          'journalDate': _isoDate(now.subtract(const Duration(days: 1))),
          'notes':
              'Buổi tập Chân & Bụng với Coach Nam. Squat 80kg trọn vẹn 4 hiệp form chuẩn.',
          'chestCm': 98.0,
          'waistCm': 78.5,
          'hipsCm': 94.0,
          'achievements': ['Squat 80kg x 4 sets', 'Coach feedback: Form chuẩn'],
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
      ],
      gymProfile: {
        'name': 'Meta Gym Flagship Center',
        'address': '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM',
        'phone': '1900 886 688',
        'openingHours': '05:30 - 22:30 (Hàng ngày)',
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
          'id': 'cnoti-001',
          'title': 'Buổi tập 18:00 hôm nay',
          'message': 'Hội viên Nguyễn Minh Quân đã xác nhận lịch tập Ngực & Tay sau.',
          'isRead': false,
          'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
        {
          'id': 'cnoti-002',
          'title': 'Yêu cầu Coach mới',
          'message': 'Hoàng Gia Huy vừa gửi yêu cầu tập 1:1 cùng bạn.',
          'isRead': false,
          'createdAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
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

  Map<String, dynamic> nutritionDay() {
    num totalKcal = 0, totalP = 0, totalC = 0, totalF = 0;
    for (final e in nutritionEntries) {
      totalKcal += (e['calories'] as num? ?? 0);
      totalP += (e['proteinG'] as num? ?? 0);
      totalC += (e['carbsG'] as num? ?? 0);
      totalF += (e['fatG'] as num? ?? 0);
    }
    return {
      'date': _isoDate(DateTime.now()),
      'target': {
        'calories': 2400,
        'proteinG': 180,
        'carbsG': 250,
        'fatG': 65,
      },
      'consumed': {
        'calories': totalKcal,
        'proteinG': totalP,
        'carbsG': totalC,
        'fatG': totalF,
      },
      'entries': nutritionEntries,
    };
  }

  Map<String, dynamic> addNutritionEntry(Map<String, dynamic> body) {
    final entry = <String, dynamic>{
      'id': 'entry-${DateTime.now().millisecondsSinceEpoch}',
      'mealType': body['mealType'] ?? 'SNACK',
      'foodName': body['foodName'] ?? body['name'] ?? 'Món ăn tự nhập',
      'calories': body['calories'] ?? 250,
      'proteinG': body['proteinG'] ?? 20,
      'carbsG': body['carbsG'] ?? 25,
      'fatG': body['fatG'] ?? 6,
      'loggedAt': DateTime.now().toIso8601String(),
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

  Map<String, dynamic> addJournalEntry(Map<String, dynamic> body) {
    final j = <String, dynamic>{
      'id': 'jour-${DateTime.now().millisecondsSinceEpoch}',
      'journalDate': body['journalDate'] ?? _isoDate(DateTime.now()),
      ...body,
    };
    journalEntries.insert(0, j);
    return j;
  }

  Map<String, dynamic> progressSummary() {
    final latest = measurements.isNotEmpty ? measurements.last : const {};
    return {
      'latestWeightKg': latest['weightKg'] ?? 72.1,
      'latestBodyFatPercent': latest['bodyFatPercent'] ?? 17.5,
      'workoutCount': workoutLogs.length + 11,
      'visitCount': gymVisits.length,
    };
  }

  Map<String, dynamic> progressCharts() => {
    'weightSeries': measurements
        .map(
          (m) => {
            'date': (m['measuredAt'] as String).split('T').first,
            'value': m['weightKg'],
          },
        )
        .toList(),
    'bodyFatSeries': measurements
        .map(
          (m) => {
            'date': (m['measuredAt'] as String).split('T').first,
            'value': m['bodyFatPercent'],
          },
        )
        .toList(),
  };

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

  Map<String, dynamic> upsertSelfTrainingDay(
    int dayOfWeek,
    Map<String, dynamic> body,
  ) {
    final idx = selfTrainingDays.indexWhere((d) => d['dayOfWeek'] == dayOfWeek);
    final updated = <String, dynamic>{
      'dayOfWeek': dayOfWeek,
      'title': body['title'] ?? 'Buổi tự tập',
      'muscleFocus': body['muscleFocus'] ?? 'FULL_BODY',
      ...body,
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
    return updateById(nutritionEntries, id, body);
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
      calls: readList('calls') ?? base.calls,
    );
  }
}
