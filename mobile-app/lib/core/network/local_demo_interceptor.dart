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
  static const _storageKey = 'meta_gym_local_demo_state_v9';

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

    // 3d. Loyalty API routes with full validation & error parity (403/409/422)
    if (path.startsWith('/loyalty/')) {
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : const <String, dynamic>{};
      final idempKey = options.headers['idempotency-key']?.toString().trim();
      final result = _handleLoyalty(
        method: method,
        path: path,
        query: options.queryParameters,
        body: body,
        idempotencyKey: idempKey,
        store: store,
        isCoach: isCoach,
      );
      if (result != null) {
        if (result.$3 != null) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: result.$2,
                data: {'error': result.$3},
              ),
            ),
          );
        }
        if (method != 'GET') {
          await _persist(store);
        }
        return _ok(handler, options, result.$1, statusCode: result.$2);
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
      '/loyalty/rewards',
      '/loyalty/redemptions/me',
      '/loyalty/transactions/me',
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
    if (path == '/loyalty/me') {
      return _LocalDemoStore.buildLoyaltySummaryMap(
        availablePoints: 0,
        tierPoints: 0,
        unusedRedemptionsCount: 0,
      );
    }
    return null;
  }

  (Object?, int, Map<String, dynamic>?)? _handleLoyalty({
    required String method,
    required String path,
    required Map<String, dynamic> query,
    required Map<String, dynamic> body,
    required String? idempotencyKey,
    required _LocalDemoStore store,
    required bool isCoach,
  }) {
    if (path == '/loyalty/me' && method == 'GET') {
      if (isCoach) {
        return (
          null,
          403,
          const {
            'code': 'FORBIDDEN',
            'message': 'Chỉ Hội viên được xem thông tin Meta Points',
          },
        );
      }
      return (store.loyaltySummary(), 200, null);
    }
    if (path == '/loyalty/rewards' && method == 'GET') {
      final category = (query['category'] as String? ?? 'ALL').toUpperCase();
      final list = category == 'ALL'
          ? store.loyaltyRewards
          : store.loyaltyRewards
                .where((r) => (r['category'] as String?) == category)
                .toList();
      return (list, 200, null);
    }
    if (path == '/loyalty/redemptions/me' && method == 'GET') {
      if (isCoach) {
        return (
          null,
          403,
          const {
            'code': 'FORBIDDEN',
            'message': 'Chỉ Hội viên được xem ưu đãi đã đổi',
          },
        );
      }
      final status = (query['status'] as String? ?? 'ALL').toUpperCase();
      final list = status == 'ALL'
          ? store.loyaltyRedemptions
          : store.loyaltyRedemptions
                .where((r) => (r['status'] as String?) == status)
                .toList();
      return (list, 200, null);
    }
    if (path == '/loyalty/redemptions' && method == 'POST') {
      if (isCoach) {
        return (
          null,
          403,
          const {
            'code': 'FORBIDDEN',
            'message': 'Chỉ Hội viên được đổi ưu đãi',
          },
        );
      }
      final rewardId = (body['rewardId'] as String? ?? '').trim();
      return store.redeemLoyaltyReward(
        rewardId: rewardId,
        idempotencyKey: idempotencyKey,
      );
    }
    if (path.startsWith('/loyalty/redemptions/') &&
        path.endsWith('/use') &&
        method == 'POST') {
      final id = Uri.decodeComponent(path.split('/')[3]);
      return store.markLoyaltyRedemptionUsed(id);
    }
    if (path == '/loyalty/transactions/me' && method == 'GET') {
      if (isCoach) {
        return (
          null,
          403,
          const {
            'code': 'FORBIDDEN',
            'message': 'Chỉ Hội viên được xem lịch sử điểm',
          },
        );
      }
      final type = (query['type'] as String? ?? 'ALL').toUpperCase();
      final list = type == 'ALL'
          ? store.loyaltyTransactions
          : store.loyaltyTransactions
                .where((t) => (t['txType'] as String?) == type)
                .toList();
      return (list, 200, null);
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
      final voucherCode = (body['voucherCode'] as String?)?.trim().toUpperCase();
      final plan = store.membershipPlans.firstWhere(
        (item) => item['id'] == planId,
        orElse: () => store.membershipPlans.first,
      );
      final rawPrice = (plan['price'] as num?)?.toInt() ?? 0;
      var discountAmount = 0;
      String? voucherRedemptionId;
      if (voucherCode != null && voucherCode.isNotEmpty) {
        final matchedVoucher = store.loyaltyRedemptions.where((r) {
          return r['status'] == 'UNUSED' &&
              (r['voucherCode'] as String?)?.toUpperCase() == voucherCode &&
              r['category'] == 'VOUCHER' &&
              ((r['discountAmount'] as num?)?.toInt() ?? 0) > 0;
        }).firstOrNull;
        if (matchedVoucher != null) {
          voucherRedemptionId = matchedVoucher['id'] as String?;
          final rawDiscount =
              (matchedVoucher['discountAmount'] as num?)?.toInt() ?? 0;
          discountAmount = rawDiscount.clamp(
            0,
            rawPrice > 1000 ? rawPrice - 1000 : 0,
          );
        }
      }
      final paymentId = 'pay-demo-${DateTime.now().millisecondsSinceEpoch}';
      final created = <String, dynamic>{
        'id': paymentId,
        'status': 'PENDING',
        'planName': plan['name'],
        'amount': (rawPrice - discountAmount).clamp(0, rawPrice),
        'discountAmount': discountAmount,
        'loyaltyRedemptionId': ?voucherRedemptionId,
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
    if (path == '/coach-packages' && method == 'GET') {
      return (store.coachPackages, 200);
    }
    if (path == '/coach-payment-holds' && method == 'GET') {
      return (const <Object?>[], 200);
    }
    if (path == '/coach-bookings' && method == 'GET') {
      return (store.coachBookings, 200);
    }
    if (path == '/coach-entitlements' && method == 'GET') {
      return (store.coachEntitlements, 200);
    }
    if (path == '/coach-bookings/blocks' && method == 'GET') {
      return (store.coachBlockedSlots, 200);
    }
    if (path == '/coach-bookings' && method == 'POST') {
      return (store.createCoachBooking(body, currentUser), 201);
    }
    if (path == '/coach-bookings/blocks' && method == 'PUT') {
      final rawBlocks = body['blocks'];
      if (rawBlocks is List) {
        store.coachBlockedSlots
          ..clear()
          ..addAll(
            rawBlocks
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row)),
          );
      } else if (body['startsAt'] is String) {
        final startsAt = (body['startsAt'] as String).trim();
        final blocked = body['blocked'] == true;
        final reason = (body['reason'] as String? ?? '').trim();
        store.coachBlockedSlots.removeWhere(
          (row) => (row['startsAt'] as String? ?? '').trim() == startsAt,
        );
        if (blocked && startsAt.isNotEmpty) {
          store.coachBlockedSlots.insert(0, {
            'startsAt': startsAt,
            'reason': reason.isNotEmpty ? reason : 'Lịch bận cá nhân',
          });
        }
      }
      return ({'updated': true, 'blocks': store.coachBlockedSlots}, 200);
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
      final readAt = DateTime.now().toUtc().toIso8601String();
      for (final n in store.coachNotifications) {
        if (n['id'] == id) {
          n['isRead'] = true;
          n['readAt'] ??= readAt;
        }
      }
      return (const {'read': true}, 200);
    }
    if (path == '/coach/members' && method == 'GET') {
      return (store.coachMembers, 200);
    }
    if (path.startsWith('/coach/members/') && method == 'GET') {
      final memberId = Uri.decodeComponent(path.split('/')[3]);
      if (path.endsWith('/training-plans/current')) {
        return (store.activeTrainingPlanFor(memberId), 200);
      }
      if (path.endsWith('/training-plans')) {
        return (store.trainingPlansFor(memberId), 200);
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
        path.endsWith('/training-plans/current') &&
        method == 'PUT') {
      final memberId = Uri.decodeComponent(path.split('/')[3]);
      return (store.upsertCurrentTrainingPlan(memberId, body), 200);
    }
    if (path.startsWith('/coach/members/') &&
        path.endsWith('/training-plans') &&
        method == 'POST') {
      final memberId = Uri.decodeComponent(path.split('/')[3]);
      return (store.createTrainingPlan(memberId, body), 201);
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
    if (path.startsWith('/coach/meal-plans/') && method == 'GET') {
      final memberId = Uri.decodeComponent(path.split('/')[3]);
      return (store.mealPlanForMember(memberId), 200);
    }
    if (path.startsWith('/coach/meal-plans/') && method == 'PUT') {
      final memberId = Uri.decodeComponent(path.split('/')[3]);
      return (store.saveMealPlanForMember(memberId, body), 200);
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
      final id = Uri.decodeComponent(path.split('/').last);
      return (store.findTrainingPlanById(id), 200);
    }
    if (path.startsWith('/coach/training-plans/') &&
        path.endsWith('/publications') &&
        method == 'POST') {
      final id = Uri.decodeComponent(path.split('/')[3]);
      return (store.publishTrainingPlan(id), 200);
    }
    if (path.startsWith('/coach/training-plans/') &&
        (method == 'PATCH' || method == 'PUT' || method == 'POST')) {
      final id = Uri.decodeComponent(path.split('/')[3]);
      return (store.updateTrainingPlan(id, body), 200);
    }
    if (path == '/member/self-training-days' && method == 'GET') {
      final from = options.queryParameters['from'] as String?;
      final to = options.queryParameters['to'] as String?;
      return (store.selfTrainingRange(from: from, to: to), 200);
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
      final memberId = currentUser['id'] as String?;
      final existing = memberId == null ? null : store.coachMealPlans[memberId];
      if (existing != null && existing['id'] != null) {
        return (<Object?>[existing], 200);
      }
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
      final filtered = store.aiConversations
          .where(
            (c) => isCoach
                ? c['ownerRole'] == 'COACH'
                : c['ownerRole'] != 'COACH',
          )
          .toList();
      return (filtered, 200);
    }
    if (path == '/ai-conversations' && method == 'POST') {
      final defaultTitle = isCoach
          ? 'Tư vấn giáo án Coach'
          : 'Tư vấn cùng Meta AI';
      final title = (body['title'] as String? ?? defaultTitle).trim();
      return (
        store.createAiConversation(
          title,
          ownerRole: isCoach ? 'COACH' : 'MEMBER',
        ),
        201,
      );
    }
    if (path.startsWith('/ai-conversations/') && path.endsWith('/messages')) {
      final convId = path.split('/')[2];
      if (method == 'GET') {
        return (store.aiMessages[convId] ?? const <Object?>[], 200);
      }
      if (method == 'POST') {
        final content = (body['content'] as String? ?? '').trim();
        final reqId = body['clientRequestId'] as String?;
        return (
          store.sendAiMessage(
            convId,
            content,
            requestId: reqId,
            isCoach: isCoach,
          ),
          201,
        );
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
      final userId = currentUser['id'] as String?;
      final visible = userId == null
          ? store.conversations
          : store.conversations
              .where(
                (c) => c['memberId'] == userId || c['coachId'] == userId,
              )
              .toList();
      return (visible, 200);
    }
    if (path == '/conversations' && method == 'POST') {
      final targetMemberId = body['memberId'] as String?;
      final targetCoachId = body['coachId'] as String?;
      final userId = currentUser['id'] as String?;
      final conv = store.findOrCreateConversation(
        currentUser: currentUser,
        targetMemberId: targetMemberId,
        targetCoachId: targetCoachId,
        userId: userId,
      );
      return (conv, 200);
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
      final userId = currentUser['id'] as String?;
      final visible = userId == null
          ? store.calls
          : store.calls
              .where(
                (c) => c['callerId'] == userId || c['receiverId'] == userId,
              )
              .toList();
      return (visible, 200);
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
    required this.coachPackages,
    required this.coachBlockedSlots,
    required this.coachBookings,
    required this.coachNotifications,
    required this.coachTrainingPlans,
    required this.coachMealPlans,
    required this.calls,
    required this.loyaltyAccount,
    required this.loyaltyRewards,
    required this.loyaltyRedemptions,
    required this.loyaltyTransactions,
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
  final List<Map<String, dynamic>> coachPackages;
  final List<Map<String, dynamic>> coachBlockedSlots;
  final List<Map<String, dynamic>> coachBookings;
  final List<Map<String, dynamic>> coachNotifications;
  final Map<String, List<Map<String, dynamic>>> coachTrainingPlans;
  final Map<String, Map<String, dynamic>> coachMealPlans;
  final List<Map<String, dynamic>> calls;
  final Map<String, dynamic> loyaltyAccount;
  final List<Map<String, dynamic>> loyaltyRewards;
  final List<Map<String, dynamic>> loyaltyRedemptions;
  final List<Map<String, dynamic>> loyaltyTransactions;

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
            'specialties': ['Hypertrophy', 'Sức mạnh', 'Giảm mỡ'],
            'qualifications': 'CPT NASM · Chứng chỉ Dinh dưỡng Thể thao',
            'experienceYears': 6,
            'availabilityNote': 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
            'biography':
                'Chuyên gia huấn luyện tăng cơ nạc, chỉnh form compound và dinh dưỡng thể hình.',
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
          'specialties': ['Hypertrophy', 'Sức mạnh', 'Giảm mỡ'],
          'qualifications': 'CPT NASM · Chứng chỉ Dinh dưỡng Thể thao',
          'experienceYears': 6,
          'availabilityNote': 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
          'biography':
              'Chuyên gia huấn luyện tăng cơ nạc, chỉnh form compound và dinh dưỡng thể hình.',
          'rating': 4.9,
          'memberLimit': 8,
          'usedSlots': 2,
          'availableSlots': 6,
          'activeMemberCount': 2,
          'maxMemberCapacity': 8,
          'bio':
              'Chuyên gia huấn luyện tăng cơ nạc, chỉnh form compound và dinh dưỡng thể hình.',
        },
        {
          'id': '10000000-0000-4000-8000-000000000015',
          'fullName': 'Trần Thu Hà',
          'email': 'coach.ha@metagym.vn',
          'specialization': 'Fat Loss, Mobility & Pilates Core',
          'specialties': ['Giảm mỡ', 'Mobility', 'Pilates'],
          'qualifications': 'ACE CPT · Pilates Instructor',
          'experienceYears': 5,
          'availabilityNote': 'Thứ 2 – Thứ 7 · 08:00 – 19:00',
          'biography':
              'Đồng hành siết mỡ an toàn, phục hồi tư thế cột sống và tối ưu thực đơn văn phòng.',
          'rating': 4.8,
          'memberLimit': 8,
          'usedSlots': 5,
          'availableSlots': 3,
          'activeMemberCount': 5,
          'maxMemberCapacity': 8,
          'bio':
              'Đồng hành siết mỡ an toàn, phục hồi tư thế cột sống và tối ưu thực đơn văn phòng.',
        },
        {
          'id': '10000000-0000-4000-8000-000000000016',
          'fullName': 'Phạm Đức Minh',
          'email': 'coach.minh@metagym.vn',
          'specialization': 'Strength & Powerlifting',
          'specialties': ['Powerlifting', 'Sức mạnh', 'Compound'],
          'qualifications': 'CSCS · IPF Certified Coach',
          'experienceYears': 8,
          'availabilityNote': 'Thứ 2 – Thứ 7 · 06:00 – 21:00',
          'biography':
              'Huấn luyện viên sức mạnh Squat – Bench – Deadlift, tối ưu chu kỳ tăng tạ.',
          'rating': 5.0,
          'memberLimit': 8,
          'usedSlots': 4,
          'availableSlots': 4,
          'activeMemberCount': 4,
          'maxMemberCapacity': 8,
          'bio':
              'Huấn luyện viên sức mạnh Squat – Bench – Deadlift, tối ưu chu kỳ tăng tạ.',
        },
      ],
      coachMembers: [
        {
          'id': relationshipId,
          'relationshipId': relationshipId,
          'memberId': memberId,
          'coachId': coachId,
          'memberFullName': 'Nguyễn Minh Quân',
          'memberName': 'Nguyễn Minh Quân',
          'memberEmail': LocalDemoAccounts.memberEmail,
          'status': 'ACTIVE',
          'pauseReason': null,
          'startedAt': now.subtract(const Duration(days: 45)).toIso8601String(),
          'member': {
            'id': memberId,
            'fullName': 'Nguyễn Minh Quân',
            'email': LocalDemoAccounts.memberEmail,
            'fitnessGoal': 'Tăng cơ nạc & Siết mỡ bụng (6 tuần tập trung Upper Body)',
            'healthNotes': 'Huyết áp ổn định, ngủ đủ 7 giờ/đêm.',
            'injuryNotes': 'Tránh đẩy vai góc > 90° (Impingement nhẹ vai phải).',
            'heightCm': 176.0,
            'weightKg': 72.1,
            'bodyFatPercent': 17.5,
            'healthDeclarationCompletedAt':
                now.subtract(const Duration(days: 40)).toIso8601String(),
          },
        },
        {
          'id': 'rel-demo-002',
          'relationshipId': 'rel-demo-002',
          'memberId': '10000000-0000-4000-8000-000000000004',
          'coachId': coachId,
          'memberFullName': 'Trần Bảo Ngọc',
          'memberName': 'Trần Bảo Ngọc',
          'memberEmail': 'baongoc@metagym.vn',
          'status': 'ACTIVE',
          'pauseReason': null,
          'startedAt': now.subtract(const Duration(days: 20)).toIso8601String(),
          'member': {
            'id': '10000000-0000-4000-8000-000000000004',
            'fullName': 'Trần Bảo Ngọc',
            'email': 'baongoc@metagym.vn',
            'fitnessGoal': 'Giảm mỡ vòng eo, săn chắc thân dưới & cải thiện sức bền',
            'healthNotes': 'Không có tiền sử tim mạch.',
            'injuryNotes': null,
            'heightCm': 163.0,
            'weightKg': 55.4,
            'bodyFatPercent': 22.8,
            'healthDeclarationCompletedAt':
                now.subtract(const Duration(days: 19)).toIso8601String(),
          },
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
      ],
      exercises: [
        {
          'id': '90000000-0000-4000-8000-000000000021',
          'equipmentId': '90000000-0000-4000-8000-000000000011',
          'name': 'Barbell Bench Press',
          'category': 'Ngực · Đẩy',
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
          'id': '90000000-0000-4000-8000-000000000022',
          'equipmentId': '90000000-0000-4000-8000-000000000011',
          'name': 'Incline Dumbbell Press',
          'category': 'Ngực trên · Vai',
          'description': 'Đẩy tạ đơn trên ghế dốc 30 độ phát triển ngực trên.',
          'targetMuscles': ['Ngực trên', 'Vai trước', 'Tay sau'],
          'instructions': 'Ghế dốc 30 độ, ép chặt cơ ngực trên ở đỉnh.',
          'safetyNotes': 'Kiểm soát đường đi của tạ, không khóa cứng khớp khuỷu.',
          'difficulty': 'INTERMEDIATE',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000023',
          'equipmentId': '90000000-0000-4000-8000-000000000012',
          'name': 'Barbell Back Squat',
          'category': 'Chân · Compound',
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
          'category': 'Lưng xô',
          'description': 'Bài tập tạo hình lưng chữ V (V-taper) sắc nét.',
          'targetMuscles': ['Lưng xô', 'Tay trước'],
          'instructions': 'Kéo thanh đòn về phía ức ngực, ép chặt 2 bả vai.',
          'safetyNotes': 'Giữ thân người cố định.',
          'difficulty': 'BEGINNER',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000025',
          'equipmentId': '90000000-0000-4000-8000-000000000011',
          'name': 'Dumbbell Bicep Curl',
          'category': 'Tay trước',
          'description': 'Cuốn tạ đơn cô lập bắp tay trước cân đối hai bên.',
          'targetMuscles': ['Tay trước'],
          'instructions': 'Cuốn tạ cô lập bắp tay trước, hạ tạ chậm 2 giây.',
          'safetyNotes': 'Khép sát cùi chỏ vào thân, không lắc lưng.',
          'difficulty': 'BEGINNER',
          'status': 'ACTIVE',
        },
        {
          'id': '90000000-0000-4000-8000-000000000026',
          'equipmentId': '90000000-0000-4000-8000-000000000012',
          'name': 'Plank Siết Cơ Bụng & Core',
          'category': 'Bụng · Core',
          'description': 'Bài tập ổn định cơ trung tâm và thắt lưng.',
          'targetMuscles': ['Bụng', 'Core'],
          'instructions': 'Giữ thân người thẳng tắp, gồng chặt cơ bụng.',
          'safetyNotes': 'Không võng thắt lưng hoặc nhô hông quá cao.',
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
          'ownerRole': 'MEMBER',
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'updatedAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
        },
        {
          'id': 'ai-conv-coach-001',
          'title': 'Tối ưu giáo án bảo vệ vai',
          'ownerRole': 'COACH',
          'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          'updatedAt': now
              .subtract(const Duration(minutes: 25))
              .toIso8601String(),
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
        'ai-conv-coach-001': [
          {
            'id': 'ai-coach-msg-001',
            'conversationId': 'ai-conv-coach-001',
            'role': 'USER',
            'status': 'COMPLETED',
            'content':
                'Học viên 72kg đau nhẹ khớp vai phải khi đẩy Barbell Bench Press trên 80kg. Gợi ý giúp anh bài thay thế cùng nhóm cơ ngực trên nhé!',
            'createdAt': now
                .subtract(const Duration(minutes: 32))
                .toIso8601String(),
          },
          {
            'id': 'ai-coach-msg-002',
            'conversationId': 'ai-conv-coach-001',
            'role': 'ASSISTANT',
            'status': 'COMPLETED',
            'content':
                'Với học viên đau vai phải mức nhẹ, anh nên giảm biên độ mở vai & chuyển sang góc trung tính:\n• **Neutral-Grip Incline DB Press** (30°): 4×8–10, khuỷu tay khép 45°.\n• **Machine Chest Press**: ổn định khớp vai, tăng tải an toàn.\n• Khởi động **5 phút**: Band Pull-Apart 2×15 + External Rotation 2×12.',
            'createdAt': now
                .subtract(const Duration(minutes: 31))
                .toIso8601String(),
          },
          {
            'id': 'ai-coach-msg-003',
            'conversationId': 'ai-conv-coach-001',
            'role': 'USER',
            'status': 'COMPLETED',
            'content':
                'Gợi ý thực đơn khoảng 2.200 kcal/ngày cho học viên tập 4 buổi/tuần.',
            'createdAt': now
                .subtract(const Duration(minutes: 26))
                .toIso8601String(),
          },
          {
            'id': 'ai-coach-msg-004',
            'conversationId': 'ai-conv-coach-001',
            'role': 'ASSISTANT',
            'status': 'COMPLETED',
            'content':
                'Đề xuất định lượng ngày **~2.200 kcal**: **Bữa sáng** Yến mạch 70g + Trứng gà 180g (540 kcal) · **Bữa trưa** Ức gà 200g + Cơm gạo lứt 250g (795 kcal) · **Bữa tối** Cá hồi 180g + Khoai lang 200g (850 kcal).',
            'createdAt': now
                .subtract(const Duration(minutes: 25))
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
        {
          'id': 'conv-demo-002',
          'relationshipId': 'rel-demo-002',
          'memberId': '10000000-0000-4000-8000-000000000004',
          'coachId': coachId,
          'memberName': 'Trần Bảo Ngọc',
          'coachName': 'Lê Hoàng Nam',
          'status': 'ACTIVE',
          'lastMessageType': 'TEXT',
          'lastMessageContent':
              'Em đã hoàn thành 3 hiệp Glute Bridge, mai mình tăng thêm 5kg được không anh?',
          'lastMessageSenderId': '10000000-0000-4000-8000-000000000004',
          'lastMessageAt': now
              .subtract(const Duration(minutes: 42))
              .toIso8601String(),
          'unreadCount': 2,
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
        'rel-demo-002': [
          {
            'id': 'dm-bn-001',
            'conversationId': 'conv-demo-002',
            'senderId': coachId,
            'messageType': 'TEXT',
            'content':
                'Chào Bảo Ngọc! Tuần này giữ tạ RDL 35kg chậm 3 giây pha hạ để siết cơ mông đùi sau nhé.',
            'sentAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
          },
          {
            'id': 'dm-bn-002',
            'conversationId': 'conv-demo-002',
            'senderId': '10000000-0000-4000-8000-000000000004',
            'messageType': 'TEXT',
            'content':
                'Em đã hoàn thành 3 hiệp Glute Bridge, mai mình tăng thêm 5kg được không anh?',
            'sentAt': now
                .subtract(const Duration(minutes: 42))
                .toIso8601String(),
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
      coachPackages: [
        {
          'code': 'PT-12',
          'name': 'Gói PT 1:1 Khởi động 12 buổi',
          'description': 'Làm quen kỹ thuật nền tảng · Theo dõi giáo trình & thực đơn 4 tuần.',
          'sessionCount': 12,
          'durationDays': 45,
          'price': 4800000,
          'status': 'ACTIVE',
        },
        {
          'code': 'PT-24',
          'name': 'Gói PT 1:1 Chuyên sâu 24 buổi',
          'description': 'Tăng cơ giảm mỡ bài bản · Kèm giáo án cá nhân hóa & thực đơn 7 ngày.',
          'sessionCount': 24,
          'durationDays': 90,
          'price': 8455000,
          'status': 'ACTIVE',
          'isPopular': true,
        },
        {
          'code': 'PT-36',
          'name': 'Gói PT 1:1 VIP 36 buổi',
          'description': 'Đồng hành toàn diện 4 tháng · Điều chỉnh form, InBody & dinh dưỡng sát sao.',
          'sessionCount': 36,
          'durationDays': 120,
          'price': 11900000,
          'status': 'ACTIVE',
        },
      ],
      coachBlockedSlots: [
        {
          'id': 'blk-demo-001',
          'startsAt': '${_isoDate(now.add(const Duration(days: 1)))}T14:00:00+07:00',
          'endsAt': '${_isoDate(now.add(const Duration(days: 1)))}T15:30:00+07:00',
          'reason': 'Họp chuyên môn cùng đội ngũ HLV',
        },
      ],
      coachBookings: [
        {
          'id': 'bk-demo-today-001',
          'entitlementId': 'ent-demo-001',
          'relationshipId': relationshipId,
          'memberId': memberId,
          'memberName': 'Nguyễn Minh Quân',
          'coachId': coachId,
          'coachName': 'Lê Hoàng Nam',
          'startsAt': DateTime(now.year, now.month, now.day, 19, 30)
              .toUtc()
              .toIso8601String(),
          'endsAt': DateTime(now.year, now.month, now.day, 21, 0)
              .toUtc()
              .toIso8601String(),
          'status': 'BOOKED',
          'title': 'Upper Body & Core · Chỉnh form Bench Press',
        },
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
          'relationshipId': 'rel-demo-002',
          'memberId': '10000000-0000-4000-8000-000000000004',
          'memberName': 'Trần Bảo Ngọc',
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
          'title': 'Thân dưới · Squat & Mobility hông',
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
          'kind': 'BOOKED',
          'title': 'Lịch tập 1:1 hôm nay lúc 19:30',
          'message': 'Hội viên Nguyễn Minh Quân đã đặt khung giờ 19:30 – 21:00 hôm nay.',
          'isRead': false,
          'readAt': null,
          'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
        {
          'id': 'cnoti-002',
          'kind': 'PACKAGE_ACTIVE',
          'title': 'Học viên Trần Bảo Ngọc đã kích hoạt gói PT 24 buổi',
          'message': 'Quan hệ phụ trách 1:1 đang hoạt động. Bạn có thể thiết lập giáo trình và thực đơn ngay.',
          'isRead': false,
          'readAt': null,
          'createdAt': now.subtract(const Duration(hours: 5)).toIso8601String(),
        },
        {
          'id': 'cnoti-003',
          'kind': 'COMPLETED',
          'title': 'Hoàn thành buổi dạy Upper Body & Core',
          'message': 'Đã ghi nhận buổi tập hoàn thành của Nguyễn Minh Quân.',
          'isRead': true,
          'readAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
      ],
      coachTrainingPlans: {
        memberId: [
          {
            'id': '90000000-0000-4000-8000-000000000070',
            'relationshipId': relationshipId,
            'memberId': memberId,
            'coachId': coachId,
            'title': 'Làm quen kỹ thuật cơ bản (Nền tảng)',
            'goal': 'Chuẩn hóa tư thế khớp vai, cột sống và kiểm soát nhịp thở.',
            'status': 'ARCHIVED',
            'version': 1,
            'startDate': _isoDate(now.subtract(const Duration(days: 45))),
            'endDate': _isoDate(now.subtract(const Duration(days: 15))),
            'days': [
              {
                'dayNumber': 1,
                'title': 'Toàn thân Nền tảng',
                'scheduledDate': _isoDate(now.subtract(const Duration(days: 45))),
                'exercises': [
                  {
                    'exerciseId': '90000000-0000-4000-8000-000000000021',
                    'exerciseName': 'Barbell Bench Press',
                    'displayOrder': 1,
                    'sets': 3,
                    'reps': '12',
                    'restSeconds': 60,
                  },
                ],
                'meals': const <Object?>[],
              },
            ],
          },
        ],
        '10000000-0000-4000-8000-000000000004': [
          {
            'id': '90000000-0000-4000-8000-000000000072',
            'relationshipId': 'rel-demo-002',
            'memberId': '10000000-0000-4000-8000-000000000004',
            'coachId': coachId,
            'title': 'Giảm mỡ & Săn chắc Thân dưới 4 tuần',
            'goal': 'Đốt mỡ an toàn · Cải thiện Mobility vùng hông và Core.',
            'status': 'ACTIVE',
            'version': 1,
            'startDate': todayStr,
            'endDate': _isoDate(now.add(const Duration(days: 28))),
            'publishedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
            'days': [
              {
                'dayNumber': 1,
                'title': 'Lower Body · Chân & Mông',
                'scheduledDate': todayStr,
                'notes': 'Kiểm soát nhịp hạ 3 giây.',
                'exercises': [
                  {
                    'exerciseId': '90000000-0000-4000-8000-000000000023',
                    'exerciseName': 'Barbell Back Squat',
                    'displayOrder': 1,
                    'sets': 4,
                    'reps': '10-12',
                    'restSeconds': 90,
                    'weightGuidance': '35kg - 45kg',
                  },
                  {
                    'exerciseId': '90000000-0000-4000-8000-000000000026',
                    'exerciseName': 'Plank Siết Cơ Bụng & Core',
                    'displayOrder': 2,
                    'sets': 3,
                    'durationSeconds': 45,
                    'restSeconds': 45,
                  },
                ],
                'meals': const <Object?>[],
              },
            ],
          },
        ],
      },
      coachMealPlans: {
        memberId: {
          'id': 'meal-plan-demo-001',
          'title': 'Thực đơn Tăng Cơ Nạc 2.400 kcal',
          'status': 'ACTIVE',
          'notes':
              '• Ưu tiên chế biến hấp, luộc hoặc áp chảo ít dầu.\n'
              '• Uống đủ 2.5 - 3.0 lít nước mỗi ngày.\n'
              '• Bổ sung Whey Isolate trong vòng 45 phút sau buổi tập.',
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
        },
        '10000000-0000-4000-8000-000000000004': {'items': <Object?>[]},
      },
      calls: [
        {
          'id': 'call-demo-002',
          'relationshipId': 'rel-demo-002',
          'callerId': coachId,
          'receiverId': '10000000-0000-4000-8000-000000000004',
          'callerName': 'Lê Hoàng Nam',
          'receiverName': 'Trần Bảo Ngọc',
          'callType': 'VOICE',
          'status': 'ENDED',
          'initiatedAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
          'answeredAt': now
              .subtract(const Duration(hours: 4))
              .add(const Duration(seconds: 4))
              .toIso8601String(),
          'endedAt': now
              .subtract(const Duration(hours: 4))
              .add(const Duration(minutes: 7))
              .toIso8601String(),
          'durationSeconds': 416,
        },
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
        {
          'id': 'call-demo-003',
          'relationshipId': relationshipId,
          'callerId': memberId,
          'receiverId': coachId,
          'callerName': 'Nguyễn Minh Quân',
          'receiverName': 'Lê Hoàng Nam',
          'callType': 'VOICE',
          'status': 'MISSED',
          'initiatedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'durationSeconds': 0,
          'failureReason': 'Không bắt máy',
        },
      ],
      loyaltyAccount: {
        'availablePoints': 1240,
        'tierPoints': 2150,
      },
      loyaltyRewards: [
        {
          'id': 'a0000000-0000-4000-8000-000000000006',
          'code': 'rw-free-7days',
          'category': 'SERVICE',
          'title': 'Tặng +7 ngày tập miễn phí',
          'description':
              'Áp dụng thẳng ngay khi đổi: tự động cộng thêm 7 ngày vào hạn thẻ hội viên đang hoạt động.',
          'pointsCost': 250,
          'discountAmount': 0,
          'bonusDays': 7,
          'requiresStaffConfirm': false,
          'stockRemaining': null,
          'isOutOfStock': false,
          'validDays': 30,
          'terms': [
            'Áp dụng tự động ngay khi xác nhận đổi — cộng thẳng +7 ngày vào thẻ tập hiện tại.',
            'Không cần nhập mã, không cần đi qua bước thanh toán.',
            'Đổi ưu đãi chỉ trừ Điểm khả dụng, giữ nguyên Điểm xét hạng.',
          ],
          'status': 'ACTIVE',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000001',
          'code': 'rw-voucher-100',
          'category': 'VOUCHER',
          'title': 'Voucher giảm 100.000đ',
          'description':
              'Giảm trực tiếp 100.000đ khi gia hạn gói tập phòng gym hoặc áp dụng tại quầy.',
          'pointsCost': 300,
          'discountAmount': 100000,
          'requiresStaffConfirm': false,
          'stockRemaining': null,
          'isOutOfStock': false,
          'validDays': 30,
          'terms': [
            'Áp dụng 1 lần khi gia hạn hoặc đăng ký gói tập tại Meta Gym.',
            'Đổi ưu đãi chỉ trừ Điểm khả dụng, giữ nguyên Điểm xét hạng.',
            'Không quy đổi thành tiền mặt.',
          ],
          'status': 'ACTIVE',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000002',
          'code': 'rw-inbody',
          'category': 'SERVICE',
          'title': 'Một lần đo InBody',
          'description':
              'Phân tích tỷ lệ cơ, mỡ và nước cơ thể tại khu vực đo chỉ số của câu lạc bộ.',
          'pointsCost': 400,
          'discountAmount': 0,
          'requiresStaffConfirm': true,
          'stockRemaining': null,
          'isOutOfStock': false,
          'validDays': 30,
          'terms': [
            'Cần nhân viên tại quầy xác nhận trước khi thực hiện đo InBody.',
            'Áp dụng 1 lượt cho chính chủ tài khoản trong thời hạn hiệu lực.',
            'Khuyến nghị nhịn ăn nhẹ 2 giờ trước khi đo để số liệu ổn định.',
          ],
          'status': 'ACTIVE',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000003',
          'code': 'rw-pt-trial',
          'category': 'SERVICE',
          'title': 'Một buổi PT trải nghiệm',
          'description':
              'Một buổi tập 1:1 cùng Huấn luyện viên Meta Gym để đánh giá kỹ thuật và tư thế.',
          'pointsCost': 900,
          'discountAmount': 0,
          'requiresStaffConfirm': true,
          'stockRemaining': null,
          'isOutOfStock': false,
          'validDays': 30,
          'terms': [
            'Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khung giờ tập phù hợp.',
            'Áp dụng cho 1 hội viên chính chủ theo thông tin tài khoản.',
            'Đổi ưu đãi không làm giảm Điểm xét hạng.',
          ],
          'status': 'ACTIVE',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000004',
          'code': 'rw-vip-perk',
          'category': 'VOUCHER',
          'title': 'Ưu đãi cao cấp',
          'description':
              'Gói đặc quyền nâng cấp trải nghiệm và voucher dịch vụ cao cấp tại Meta Gym.',
          'pointsCost': 1500,
          'discountAmount': 300000,
          'requiresStaffConfirm': true,
          'stockRemaining': null,
          'isOutOfStock': false,
          'validDays': 45,
          'terms': [
            'Áp dụng tại quầy dịch vụ với xác nhận của nhân viên phụ trách.',
            'Không áp dụng cộng dồn với các chương trình giảm giá khác.',
          ],
          'status': 'ACTIVE',
        },
        {
          'id': 'a0000000-0000-4000-8000-000000000005',
          'code': 'rw-sold-out',
          'category': 'VOUCHER',
          'title': 'Quà tặng bình giữ nhiệt Meta Gym',
          'description':
              'Quà tặng lưu niệm phiên bản giới hạn tại quầy lễ tân câu lạc bộ.',
          'pointsCost': 600,
          'discountAmount': 0,
          'requiresStaffConfirm': true,
          'stockRemaining': 0,
          'isOutOfStock': true,
          'validDays': 30,
          'terms': [
            'Nhận trực tiếp tại quầy khi đợt phát hành có hàng trở lại.',
          ],
          'status': 'ACTIVE',
        },
      ],
      loyaltyRedemptions: [
        {
          'id': 'red-demo-001',
          'rewardId': 'a0000000-0000-4000-8000-000000000002',
          'rewardCode': 'rw-inbody',
          'category': 'SERVICE',
          'title': 'Một lần đo InBody',
          'pointsSpent': 400,
          'discountAmount': 0,
          'voucherCode': 'MG-INBODY26',
          'requiresStaffConfirm': true,
          'conditionText':
              'Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khi sử dụng tại câu lạc bộ.',
          'status': 'UNUSED',
          'redeemedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
          'expiresAt': now.add(const Duration(days: 25)).toIso8601String(),
          'usedAt': null,
        },
        {
          'id': 'red-demo-002',
          'rewardId': 'a0000000-0000-4000-8000-000000000001',
          'rewardCode': 'rw-voucher-100',
          'category': 'VOUCHER',
          'title': 'Voucher giảm 100.000đ',
          'pointsSpent': 300,
          'discountAmount': 100000,
          'voucherCode': 'MG-VCH100K',
          'requiresStaffConfirm': false,
          'conditionText':
              'Đã áp dụng trừ 100.000đ cho giao dịch gia hạn gói tập.',
          'status': 'USED',
          'redeemedAt': now.subtract(const Duration(days: 45)).toIso8601String(),
          'expiresAt': now.subtract(const Duration(days: 15)).toIso8601String(),
          'usedAt': now.subtract(const Duration(days: 32)).toIso8601String(),
        },
        {
          'id': 'red-demo-003',
          'rewardId': 'a0000000-0000-4000-8000-000000000003',
          'rewardCode': 'rw-pt-trial',
          'category': 'SERVICE',
          'title': 'Một buổi PT trải nghiệm',
          'pointsSpent': 900,
          'discountAmount': 0,
          'voucherCode': 'MG-PTTRIAL0',
          'requiresStaffConfirm': true,
          'conditionText':
              'Cần nhân viên/HLV xác nhận khi còn hiệu lực. Đã quá hạn sử dụng.',
          'status': 'EXPIRED',
          'redeemedAt': now.subtract(const Duration(days: 90)).toIso8601String(),
          'expiresAt': now.subtract(const Duration(days: 60)).toIso8601String(),
          'usedAt': null,
        },
      ],
      loyaltyTransactions: [
        {
          'id': 'ltx-demo-005',
          'txType': 'SPEND',
          'pointsDelta': -400,
          'tierPointsDelta': 0,
          'title': 'Trừ điểm đổi ưu đãi: Một lần đo InBody',
          'detail': 'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
          'referenceType': 'REWARD_REDEMPTION',
          'referenceId': 'red-demo-001',
          'statusLabel': 'Đã đổi ưu đãi',
          'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
        },
        {
          'id': 'ltx-demo-004',
          'txType': 'ADJUST',
          'pointsDelta': 190,
          'tierPointsDelta': 0,
          'title': 'Hoàn điểm điều chỉnh giao dịch tại quầy',
          'detail': 'Hoàn điểm vào số dư khả dụng do điều chỉnh dịch vụ',
          'referenceType': 'ADMIN_ADJUSTMENT',
          'referenceId': null,
          'statusLabel': 'Đã hoàn điểm',
          'createdAt': now.subtract(const Duration(days: 18)).toIso8601String(),
        },
        {
          'id': 'ltx-demo-003',
          'txType': 'EARN',
          'pointsDelta': 650,
          'tierPointsDelta': 650,
          'title': 'Cộng điểm khi gia hạn gói tập',
          'detail': 'Gói Tiêu chuẩn · 6 tháng · Cộng vào khả dụng & xét hạng',
          'referenceType': 'MEMBERSHIP_PAYMENT',
          'referenceId': 'pay-demo-001',
          'statusLabel': 'Thành công',
          'createdAt': now.subtract(const Duration(days: 32)).toIso8601String(),
        },
        {
          'id': 'ltx-demo-002',
          'txType': 'SPEND',
          'pointsDelta': -300,
          'tierPointsDelta': 0,
          'title': 'Trừ điểm đổi ưu đãi: Voucher giảm 100.000đ',
          'detail': 'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
          'referenceType': 'REWARD_REDEMPTION',
          'referenceId': 'red-demo-002',
          'statusLabel': 'Đã đổi ưu đãi',
          'createdAt': now.subtract(const Duration(days: 45)).toIso8601String(),
        },
        {
          'id': 'ltx-demo-001',
          'txType': 'EARN',
          'pointsDelta': 1500,
          'tierPointsDelta': 1500,
          'title': 'Cộng điểm khi đăng ký gói nâng cao kỳ trước',
          'detail': 'Đăng ký gói tập · Cộng vào khả dụng & xét hạng',
          'referenceType': 'MEMBERSHIP_PAYMENT',
          'referenceId': 'pay-demo-000',
          'statusLabel': 'Thành công',
          'createdAt': now.subtract(const Duration(days: 65)).toIso8601String(),
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
    if (account['role'] == 'COACH') {
      final coachIdx = coaches.indexWhere((c) => c['id'] == account['id']);
      if (coachIdx >= 0) {
        final coachProfile = Map<String, dynamic>.from(
          account['profile'] as Map? ?? const {},
        );
        coaches[coachIdx]['fullName'] = account['fullName'];
        if (coachProfile['biography'] != null) {
          coaches[coachIdx]['biography'] = coachProfile['biography'];
          coaches[coachIdx]['bio'] = coachProfile['biography'];
        }
        if (coachProfile['specialties'] is List) {
          coaches[coachIdx]['specialties'] = coachProfile['specialties'];
        }
        if (coachProfile['qualifications'] != null) {
          coaches[coachIdx]['qualifications'] = coachProfile['qualifications'];
        }
        if (coachProfile['experienceYears'] != null) {
          coaches[coachIdx]['experienceYears'] =
              coachProfile['experienceYears'];
        }
        if (coachProfile['availabilityNote'] != null) {
          coaches[coachIdx]['availabilityNote'] =
              coachProfile['availabilityNote'];
        }
      }
    }
  }

  List<Map<String, dynamic>> trainingPlansFor(String memberId) {
    final primaryMemberId = coachMembers.isEmpty
        ? null
        : coachMembers.first['memberId'] as String?;
    final list = <Map<String, dynamic>>[
      if (memberId == primaryMemberId) activeTrainingPlan,
      ...(coachTrainingPlans[memberId] ?? const []),
    ];
    return list;
  }

  Map<String, dynamic> activeTrainingPlanFor(String memberId) {
    final plans = trainingPlansFor(memberId);
    final active = plans.where((p) => p['status'] == 'ACTIVE').firstOrNull;
    if (active != null) return active;
    if (plans.isNotEmpty) return plans.first;
    return activeTrainingPlan;
  }

  Map<String, dynamic> findTrainingPlanById(String planId) {
    if (activeTrainingPlan['id'] == planId) return activeTrainingPlan;
    for (final list in coachTrainingPlans.values) {
      for (final plan in list) {
        if (plan['id'] == planId) return plan;
      }
    }
    return activeTrainingPlan;
  }

  List<Map<String, dynamic>> _normalizeDays(Object? rawDays) {
    if (rawDays is! List) return const [];
    final exerciseMap = <String, Map<String, dynamic>>{
      for (final e in exercises) e['id'].toString(): e,
    };
    return rawDays.whereType<Map>().map((rawDay) {
      final d = Map<String, dynamic>.from(rawDay);
      final rawEx = (d['exercises'] as List? ?? const []);
      final normalizedEx = rawEx.whereType<Map>().map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem);
        final cat = exerciseMap[item['exerciseId']?.toString() ?? ''];
        return {
          ...item,
          'exerciseName':
              item['exerciseName'] ?? cat?['name'] ?? 'Bài tập Meta Gym',
          'instructions': item['instructions'] ?? cat?['instructions'],
          'safetyNotes': item['safetyNotes'] ?? cat?['safetyNotes'],
        };
      }).toList();
      final rawMeals = (d['meals'] as List? ?? const []);
      return {
        ...d,
        'exercises': normalizedEx,
        'meals': rawMeals
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
      };
    }).toList();
  }

  Map<String, dynamic> upsertCurrentTrainingPlan(
    String memberId,
    Map<String, dynamic> body,
  ) {
    final primaryMemberId = coachMembers.isEmpty
        ? null
        : coachMembers.first['memberId'] as String?;
    final days = _normalizeDays(body['days']);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final targetList = coachTrainingPlans.putIfAbsent(memberId, () => []);

    if (memberId == primaryMemberId) {
      activeTrainingPlan['title'] =
          body['title'] ?? activeTrainingPlan['title'];
      activeTrainingPlan['goal'] = body['goal'] ?? activeTrainingPlan['goal'];
      activeTrainingPlan['startDate'] =
          body['startDate'] ?? activeTrainingPlan['startDate'];
      activeTrainingPlan['endDate'] =
          body['endDate'] ?? activeTrainingPlan['endDate'];
      activeTrainingPlan['status'] = 'ACTIVE';
      activeTrainingPlan['version'] =
          ((activeTrainingPlan['version'] as num?)?.toInt() ?? 1) + 1;
      activeTrainingPlan['publishedAt'] = nowIso;
      if (days.isNotEmpty) {
        activeTrainingPlan['days'] = days;
      }
      return activeTrainingPlan;
    }

    final existingIdx = targetList.indexWhere((p) => p['status'] == 'ACTIVE');
    if (existingIdx >= 0) {
      final existing = targetList[existingIdx];
      existing['title'] = body['title'] ?? existing['title'];
      existing['goal'] = body['goal'] ?? existing['goal'];
      existing['version'] = ((existing['version'] as num?)?.toInt() ?? 1) + 1;
      existing['publishedAt'] = nowIso;
      if (days.isNotEmpty) existing['days'] = days;
      return existing;
    }

    final created = <String, dynamic>{
      'id': 'plan-demo-${DateTime.now().millisecondsSinceEpoch}',
      'memberId': memberId,
      'title': body['title'] ?? 'Giáo trình mới',
      'goal': body['goal'],
      'status': 'ACTIVE',
      'version': 1,
      'startDate': body['startDate'] ?? _vnTodayStr(),
      'endDate': body['endDate'],
      'publishedAt': nowIso,
      'days': days,
    };
    targetList.insert(0, created);
    return created;
  }

  Map<String, dynamic> createTrainingPlan(
    String memberId,
    Map<String, dynamic> body,
  ) {
    final days = _normalizeDays(body['days']);
    final created = <String, dynamic>{
      'id': 'plan-demo-${DateTime.now().millisecondsSinceEpoch}',
      'memberId': memberId,
      'title': body['title'] ?? 'Bản nháp giáo trình',
      'goal': body['goal'],
      'status': 'DRAFT',
      'version': 1,
      'startDate': body['startDate'] ?? _vnTodayStr(),
      'endDate': body['endDate'],
      'days': days,
    };
    coachTrainingPlans.putIfAbsent(memberId, () => []).insert(0, created);
    return created;
  }

  Map<String, dynamic> updateTrainingPlan(
    String planId,
    Map<String, dynamic> body,
  ) {
    final plan = findTrainingPlanById(planId);
    if (body['title'] is String) plan['title'] = body['title'];
    if (body.containsKey('goal')) plan['goal'] = body['goal'];
    if (body.containsKey('startDate')) plan['startDate'] = body['startDate'];
    if (body.containsKey('endDate')) plan['endDate'] = body['endDate'];
    if (body.containsKey('notes')) plan['notes'] = body['notes'];
    if (body['days'] is List) {
      plan['days'] = _normalizeDays(body['days']);
    }
    return plan;
  }

  Map<String, dynamic> publishTrainingPlan(String planId) {
    final plan = findTrainingPlanById(planId);
    plan['status'] = 'ACTIVE';
    plan['publishedAt'] = DateTime.now().toUtc().toIso8601String();
    return plan;
  }

  Map<String, dynamic> mealPlanForMember(String memberId) {
    final existing = coachMealPlans[memberId];
    if (existing != null) return existing;
    return {'items': <Object?>[]};
  }

  Map<String, dynamic> saveMealPlanForMember(
    String memberId,
    Map<String, dynamic> body,
  ) {
    final foodMap = <String, Map<String, dynamic>>{
      for (final f in nutritionFoods) f['id'].toString(): f,
    };
    final rawItems = (body['items'] as List? ?? const []);
    final savedItems = rawItems.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final food = foodMap[item['foodId']?.toString() ?? ''];
      return {
        ...item,
        'foodName': item['foodName'] ?? food?['name'] ?? 'Thực phẩm',
        'kcalPer100g': item['kcalPer100g'] ?? food?['kcalPer100g'] ?? 100,
      };
    }).toList();
    final existing = coachMealPlans[memberId];
    final existingId = existing?['id'] as String?;
    final String? notes = body.containsKey('notes')
        ? (body['notes'] as String?)?.trim()
        : existing?['notes'] as String?;
    final saved = <String, dynamic>{
      'id': existingId ?? 'mp-demo-${DateTime.now().millisecondsSinceEpoch}',
      'title': body['title'] ?? 'Thực đơn 7 ngày Coach thiết kế',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'status': 'ACTIVE',
      'items': savedItems,
    };
    coachMealPlans[memberId] = saved;
    return saved;
  }

  Map<String, dynamic> gymVisitMonth() => {
    'visits': gymVisits,
    'visitedDays': gymVisits.length,
    'eligibleDays': 22,
    'entryCount': gymVisits.length,
  };

  Map<String, dynamic> addCheckIn() {
    final now = DateTime.now();
    final todayStr = _isoDate(now);
    final alreadyEarnedToday = loyaltyTransactions.any(
      (tx) =>
          tx['referenceType'] == 'GYM_CHECKIN' &&
          (tx['createdAt'] as String? ?? '').startsWith(todayStr),
    );
    final visit = <String, dynamic>{
      'day': todayStr,
      'checkedInAt': now.toIso8601String(),
      'gymName': 'Meta Gym Flagship Center',
      'gymAddress': '123 Nguyễn Thị Minh Khai, Quận 1, TP.HCM',
    };
    gymVisits.insert(0, visit);
    if (!alreadyEarnedToday) {
      final summary = loyaltySummary();
      final mult = (summary['pointsMultiplier'] as num?)?.toDouble() ?? 1.0;
      final pts = (10 * mult).round().clamp(10, 100);
      loyaltyAccount['availablePoints'] =
          ((loyaltyAccount['availablePoints'] as num?)?.toInt() ?? 0) + pts;
      loyaltyAccount['tierPoints'] =
          ((loyaltyAccount['tierPoints'] as num?)?.toInt() ?? 0) + pts;
      loyaltyTransactions.insert(0, {
        'id': 'ltx-checkin-${now.millisecondsSinceEpoch}',
        'txType': 'EARN',
        'pointsDelta': pts,
        'tierPointsDelta': pts,
        'title': 'Cộng điểm check-in phòng tập',
        'detail': 'Hệ số ${summary['tierLabel']} (×${mult.toStringAsFixed(1)}) · Mỗi ngày 1 lần',
        'referenceType': 'GYM_CHECKIN',
        'referenceId': null,
        'statusLabel': 'Thành công',
        'createdAt': now.toIso8601String(),
      });
      visit['loyaltyPointsEarned'] = pts;
    }
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
    if (explicitKcal is num) return explicitKcal.toDouble();
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
      explicitKcal: body['kcal'] ?? body['calories'],
    );
    final entry = <String, dynamic>{
      'id': 'entry-${DateTime.now().millisecondsSinceEpoch}',
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
    final voucherRedemptionId = payment['loyaltyRedemptionId'] as String?;
    if (voucherRedemptionId != null) {
      for (final red in loyaltyRedemptions) {
        if (red['id'] == voucherRedemptionId && red['status'] == 'UNUSED') {
          red['status'] = 'USED';
          red['usedAt'] = now.toIso8601String();
        }
      }
    }
    final bonusPts = duration >= 1000
        ? 5000
        : duration >= 300
        ? 1500
        : duration >= 150
        ? 650
        : duration >= 60
        ? 250
        : 100;
    loyaltyAccount['availablePoints'] =
        ((loyaltyAccount['availablePoints'] as num?)?.toInt() ?? 0) + bonusPts;
    loyaltyAccount['tierPoints'] =
        ((loyaltyAccount['tierPoints'] as num?)?.toInt() ?? 0) + bonusPts;
    loyaltyTransactions.insert(0, {
      'id': 'ltx-pay-${now.millisecondsSinceEpoch}',
      'txType': 'EARN',
      'pointsDelta': bonusPts,
      'tierPointsDelta': bonusPts,
      'title': 'Cộng điểm khi đăng ký / gia hạn gói tập',
      'detail': '$planName · Cộng vào khả dụng & xét hạng',
      'referenceType': 'MEMBERSHIP_PAYMENT',
      'referenceId': payment['id'],
      'statusLabel': 'Thành công',
      'createdAt': now.toIso8601String(),
    });
    return {'payment': payment, 'membership': activeMembership};
  }

  static const List<Map<String, dynamic>> _kLoyaltyTiers = [
    {
      'code': 'BRONZE',
      'name': 'Đồng',
      'tierLabel': 'Hạng Đồng',
      'minPoints': 0,
      'coachDiscountPercent': 0,
      'pointsMultiplier': 1.0,
      'inBodyLabel': 'Trả phí lẻ',
      'tagline': 'Khởi đầu hành trình tập luyện tại Meta Gym',
      'perks': [
        'Check-in QR/NFC không chạm tại phòng tập',
        'Tích điểm khả dụng & xét hạng khi đăng ký gói hoặc check-in',
        'Truy cập danh mục ưu đãi thành viên cơ bản',
      ],
    },
    {
      'code': 'SILVER',
      'name': 'Bạc',
      'tierLabel': 'Hạng Bạc',
      'minPoints': 800,
      'coachDiscountPercent': 3,
      'pointsMultiplier': 1.2,
      'inBodyLabel': '1 lần / quý',
      'tagline': 'Tăng nhịp ổn định cùng đặc quyền InBody & ưu đãi Coach',
      'perks': [
        'Giảm tự động 3% mọi gói Coach 1:1',
        'Hệ số tích điểm check-in ×1.2',
        'Đo chỉ số InBody chuyên sâu 1 lần / quý',
      ],
    },
    {
      'code': 'GOLD',
      'name': 'Vàng',
      'tierLabel': 'Hạng Vàng',
      'minPoints': 2000,
      'coachDiscountPercent': 5,
      'pointsMultiplier': 1.5,
      'inBodyLabel': 'Miễn phí / tháng',
      'tagline': 'Hội viên gắn bó với ưu đãi Coach 1:1 và InBody định kỳ',
      'perks': [
        'Giảm tự động 5% mọi gói Coach 1:1',
        'Đo chỉ số InBody chuyên sâu miễn phí hàng tháng',
        'Hệ số tích điểm check-in ×1.5 & mở khóa ưu đãi Vàng',
      ],
    },
    {
      'code': 'DIAMOND',
      'name': 'Kim Cương',
      'tierLabel': 'Hạng Kim Cương',
      'minPoints': 6000,
      'coachDiscountPercent': 10,
      'pointsMultiplier': 2.0,
      'inBodyLabel': 'Không giới hạn',
      'tagline': 'Hạng cao nhất dành cho hội viên đồng hành bền vững cùng Meta Gym',
      'perks': [
        'Giảm tự động 10% mọi gói Coach 1:1',
        'Đo chỉ số InBody chuyên sâu không giới hạn',
        'Hệ số tích điểm check-in ×2.0 & ưu tiên chăm sóc câu lạc bộ',
      ],
    },
  ];

  static Map<String, dynamic> buildLoyaltySummaryMap({
    required int availablePoints,
    required int tierPoints,
    required int unusedRedemptionsCount,
  }) {
    var currentIdx = 0;
    for (var i = 0; i < _kLoyaltyTiers.length; i++) {
      if (tierPoints >= (_kLoyaltyTiers[i]['minPoints'] as int)) {
        currentIdx = i;
      }
    }
    final current = _kLoyaltyTiers[currentIdx];
    final next = currentIdx < _kLoyaltyTiers.length - 1
        ? _kLoyaltyTiers[currentIdx + 1]
        : null;
    final remaining = next != null
        ? ((next['minPoints'] as int) - tierPoints).clamp(0, 999999)
        : 0;
    var progress = 1.0;
    if (next != null) {
      final span = ((next['minPoints'] as int) - (current['minPoints'] as int))
          .clamp(1, 999999);
      progress = ((tierPoints - (current['minPoints'] as int)) / span)
          .clamp(0.0, 1.0);
    }
    return {
      'availablePoints': availablePoints,
      'tierPoints': tierPoints,
      'tier': current['code'],
      'tierName': current['name'],
      'tierLabel': current['tierLabel'],
      'nextTier': next?['code'],
      'nextTierName': next?['name'],
      'nextTierLabel': next?['tierLabel'],
      'nextTierMinPoints': next?['minPoints'],
      'remainingToNextTier': remaining,
      'progressFraction': progress,
      'coachDiscountPercent': current['coachDiscountPercent'],
      'pointsMultiplier': current['pointsMultiplier'],
      'inBodyLabel': current['inBodyLabel'],
      'perks': current['perks'],
      'unusedRedemptionsCount': unusedRedemptionsCount,
      'tiers': _kLoyaltyTiers,
    };
  }

  Map<String, dynamic> loyaltySummary() {
    final unusedCount = loyaltyRedemptions
        .where((r) => r['status'] == 'UNUSED')
        .length;
    return buildLoyaltySummaryMap(
      availablePoints: (loyaltyAccount['availablePoints'] as num?)?.toInt() ?? 0,
      tierPoints: (loyaltyAccount['tierPoints'] as num?)?.toInt() ?? 0,
      unusedRedemptionsCount: unusedCount,
    );
  }

  (Object?, int, Map<String, dynamic>?) redeemLoyaltyReward({
    required String rewardId,
    String? idempotencyKey,
  }) {
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final prior = loyaltyRedemptions
          .where((r) => r['idempotencyKey'] == idempotencyKey)
          .firstOrNull;
      if (prior != null) {
        final tx = loyaltyTransactions
            .where((t) => t['referenceId'] == prior['id'])
            .firstOrNull;
        return (
          {
            'redemption': prior,
            'transaction': tx,
            'summary': loyaltySummary(),
          },
          200,
          null,
        );
      }
    }

    final reward = loyaltyRewards
        .where((r) => r['id'] == rewardId && r['status'] == 'ACTIVE')
        .firstOrNull;
    if (reward == null) {
      return (
        null,
        404,
        const {
          'code': 'NOT_FOUND',
          'message': 'Không tìm thấy ưu đãi đang mở đổi',
        },
      );
    }
    final stock = (reward['stockRemaining'] as num?)?.toInt();
    if (reward['isOutOfStock'] == true || (stock != null && stock <= 0)) {
      return (
        null,
        409,
        const {
          'code': 'REWARD_OUT_OF_STOCK',
          'message': 'Ưu đãi này đã hết lượt đổi trong đợt hiện tại',
        },
      );
    }
    final cost = (reward['pointsCost'] as num?)?.toInt() ?? 0;
    final available = (loyaltyAccount['availablePoints'] as num?)?.toInt() ?? 0;
    if (available < cost) {
      final missing = cost - available;
      return (
        null,
        409,
        {
          'code': 'INSUFFICIENT_POINTS',
          'message': 'Còn thiếu $missing điểm khả dụng để đổi ưu đãi này',
        },
      );
    }

    // Deduct availablePoints ONLY; tierPoints NEVER drops on reward redemption.
    loyaltyAccount['availablePoints'] = available - cost;
    if (stock != null) {
      final nextStock = (stock - 1).clamp(0, 999999);
      reward['stockRemaining'] = nextStock;
      reward['isOutOfStock'] = nextStock <= 0;
    }

    final now = DateTime.now();
    final redemptionId = 'red-demo-${now.millisecondsSinceEpoch}';
    final suffix = (now.millisecondsSinceEpoch % 1000000)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(5, '0');
    final requiresStaff = reward['requiresStaffConfirm'] == true;
    final bonusDays = (reward['bonusDays'] as num?)?.toInt() ?? 0;
    var appliedDirectNote = '';
    if (bonusDays > 0) {
      final parsedEnd =
          DateTime.tryParse((activeMembership['endDate'] as String?) ?? '') ??
          now;
      final extended = parsedEnd.add(Duration(days: bonusDays));
      final extendedIso = _isoDate(extended);
      activeMembership['endDate'] = extendedIso;
      for (final item in membershipHistory) {
        if (item['id'] == activeMembership['id'] ||
            item['status'] == 'ACTIVE') {
          item['endDate'] = extendedIso;
        }
      }
      appliedDirectNote =
          'Đã tự động cộng +$bonusDays ngày vào thẻ tập hiện tại (hạn mới: $extendedIso).';
    }
    final isInstantApplied = bonusDays > 0;
    final redemption = <String, dynamic>{
      'id': redemptionId,
      'rewardId': reward['id'],
      'rewardCode': reward['code'],
      'category': reward['category'],
      'title': reward['title'],
      'pointsSpent': cost,
      'discountAmount': reward['discountAmount'] ?? 0,
      'voucherCode': 'MG-$suffix',
      'requiresStaffConfirm': requiresStaff,
      'conditionText': isInstantApplied
          ? appliedDirectNote
          : requiresStaff
          ? 'Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khi sử dụng tại câu lạc bộ.'
          : 'Tự động áp dụng giảm giá khi bạn chọn thanh toán gia hạn/mua gói tập.',
      'status': isInstantApplied ? 'USED' : 'UNUSED',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotencyKey': idempotencyKey,
      'redeemedAt': now.toIso8601String(),
      'expiresAt': now
          .add(Duration(days: (reward['validDays'] as num?)?.toInt() ?? 30))
          .toIso8601String(),
      'usedAt': isInstantApplied ? now.toIso8601String() : null,
    };
    loyaltyRedemptions.insert(0, redemption);

    final tx = <String, dynamic>{
      'id': 'ltx-spend-${now.millisecondsSinceEpoch}',
      'txType': 'SPEND',
      'pointsDelta': -cost,
      'tierPointsDelta': 0,
      'title': 'Trừ điểm đổi ưu đãi: ${reward['title']}',
      'detail': 'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
      'referenceType': 'REWARD_REDEMPTION',
      'referenceId': redemptionId,
      'statusLabel': 'Đã đổi ưu đãi',
      'createdAt': now.toIso8601String(),
    };
    loyaltyTransactions.insert(0, tx);

    return (
      {
        'redemption': redemption,
        'transaction': tx,
        'summary': loyaltySummary(),
      },
      201,
      null,
    );
  }

  (Object?, int, Map<String, dynamic>?) markLoyaltyRedemptionUsed(String id) {
    final red = loyaltyRedemptions.where((r) => r['id'] == id).firstOrNull;
    if (red == null) {
      return (
        null,
        404,
        const {'code': 'NOT_FOUND', 'message': 'Không tìm thấy ưu đãi đã đổi'},
      );
    }
    if (red['requiresStaffConfirm'] == true) {
      return (
        null,
        403,
        const {
          'code': 'STAFF_CONFIRM_REQUIRED',
          'message':
              'Ưu đãi dịch vụ cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận tại quầy',
        },
      );
    }
    red['status'] = 'USED';
    red['usedAt'] = DateTime.now().toIso8601String();
    return (red, 200, null);
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

  List<Map<String, dynamic>> selfTrainingRange({String? from, String? to}) {
    return selfTrainingDays.where((d) {
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
  }

  Map<String, dynamic> upsertSelfTrainingDay(
    String planDate,
    Map<String, dynamic> body,
  ) {
    final idx = selfTrainingDays.indexWhere((d) => d['planDate'] == planDate);
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
      explicitKcal: body['kcal'] ?? body['calories'],
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

  Map<String, dynamic> createAiConversation(
    String title, {
    String ownerRole = 'MEMBER',
  }) {
    final nowIso = DateTime.now().toIso8601String();
    final conv = <String, dynamic>{
      'id': 'ai-conv-${DateTime.now().millisecondsSinceEpoch}',
      'title': title.isEmpty
          ? (ownerRole == 'COACH'
                ? 'Tư vấn giáo án mới'
                : 'Hội thoại mới với Meta AI')
          : title,
      'ownerRole': ownerRole,
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
    bool isCoach = false,
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
    final String replyContent;
    if (isCoach) {
      if (lower.contains('vai') || lower.contains('thay thế')) {
        replyContent =
            'Gợi ý thay thế bảo vệ khớp vai cho học viên:\n• **Incline Neutral-Grip DB Press**: 4×8–10 (giảm áp lực đầu xương cánh tay).\n• **Landmine Single-Arm Press**: 3×10/tay theo quỹ đạo chéo tự nhiên.\n• Lưu ý kết thúc buổi với **Face Pull** 3×15 để cân bằng vai sau.';
      } else if (lower.contains('deload')) {
        replyContent =
            'Khung **Lịch Deload Tuần 5** (4 buổi/tuần):\n• Giảm **35% tổng số hiệp** (giữ 2 hiệp chính/bài), giữ tạ ở mức **70–75% 1RM**.\n• Dừng mỗi hiệp trước ngưỡng mỏi (**RIR 3–4**) để phục hồi khớp & hệ thần kinh trung ương.';
      } else if (lower.contains('thực đơn') ||
          lower.contains('kcal') ||
          lower.contains('ăn') ||
          lower.contains('dinh dưỡng')) {
        replyContent =
            'Gợi ý chia macro **~2.200 kcal/ngày** (175g Đạm · 230g Carb · 64g Béo):\n• **Sáng**: Yến mạch 70g + 3 quả trứng (540 kcal).\n• **Trưa**: Ức gà 200g + Cơm gạo lứt 250g + Bông cải (795 kcal).\n• **Tối**: Cá hồi 180g + Khoai lang 200g + Salad (850 kcal).';
      } else {
        replyContent =
            'Trợ lý AI Coach đã ghi nhận yêu cầu "$content". Anh có thể điều chỉnh khối lượng tập ở mức **RPE 7.5–8**, ưu tiên kỹ thuật kiểm soát pha hạ 2–3 giây và theo dõi phản hồi khớp sau 48h cho học viên.';
      }
    } else {
      replyContent =
          lower.contains('ăn') ||
              lower.contains('dinh dưỡng') ||
              lower.contains('calo')
          ? 'Gợi ý dinh dưỡng từ Meta AI (chế độ Demo Offline):\n• Mục tiêu hôm nay: 2.400 kcal · 180g Protein.\n• Trước tập 60 phút: 150g khoai lang + 100g ức gà hoặc 1 muỗng Whey + chuối.\n• Sau tập 45 phút: bổ sung ngay 30g đạm nhanh và 500ml nước lọc.'
          : lower.contains('lịch') ||
                lower.contains('tập') ||
                lower.contains('ngực') ||
                lower.contains('chân')
          ? 'Gợi ý tập luyện từ Meta AI (chế độ Demo Offline):\n• Khởi động khớp vai & hông 8 phút.\n• Tập trung 4 hiệp chính ở mức RPE 8, nghỉ 90 giây giữa hiệp.\n• Ghi lại mức tạ sau buổi tập để theo dõi tiến độ tăng sức mạnh nhé!'
          : 'Meta AI đã nhận câu hỏi "$content". Dựa trên hồ sơ hiện tại của bạn (72.1kg · 17.5% mỡ · mục tiêu tăng cơ nạc), hãy duy trì đều 4 buổi/tuần, giữ kỹ thuật chuẩn và đạt đủ 180g protein hôm nay nhé!';
    }
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

  Map<String, dynamic> findOrCreateConversation({
    required Map<String, dynamic> currentUser,
    String? targetMemberId,
    String? targetCoachId,
    String? userId,
  }) {
    for (final c in conversations) {
      if (targetMemberId != null && c['memberId'] == targetMemberId) {
        return c;
      }
      if (targetCoachId != null && c['coachId'] == targetCoachId) {
        return c;
      }
    }
    if (targetMemberId != null) {
      final matchedMember = coachMembers.where(
        (m) => m['memberId'] == targetMemberId,
      ).firstOrNull;
      final relId = (matchedMember?['relationshipId'] as String?) ??
          'rel-$targetMemberId';
      final created = <String, dynamic>{
        'id': 'conv-$targetMemberId',
        'relationshipId': relId,
        'memberId': targetMemberId,
        'coachId': currentUser['id'] ?? relationship['coachId'],
        'memberName': matchedMember?['memberFullName'] ??
            matchedMember?['memberName'] ??
            'Hội viên',
        'coachName': currentUser['fullName'] ?? 'Lê Hoàng Nam',
        'status': 'ACTIVE',
        'lastMessageType': null,
        'lastMessageContent': null,
        'lastMessageSenderId': null,
        'lastMessageAt': null,
        'unreadCount': 0,
      };
      conversations.insert(0, created);
      directMessages.putIfAbsent(relId, () => []);
      return created;
    }
    return conversations.firstWhere(
      (c) => userId == null || c['memberId'] == userId || c['coachId'] == userId,
      orElse: () => conversations.first,
    );
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
    final memberName = (targetConv['memberName'] as String?)?.trim() ?? 'Em';
    final autoReplyText = senderId == targetConv['memberId']
        ? 'Coach Nam đã nhận tin nhắn "$content". Hẹn gặp bạn đúng giờ tại Meta Gym nhé!'
        : 'Dạ $memberName đã nhận thông tin từ Coach Nam ạ!';
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
    final relId = (body['relationshipId'] as String?) ??
        (relationship['id'] as String);
    final matchedConv = conversations.where(
      (c) => c['relationshipId'] == relId || c['id'] == relId,
    ).firstOrNull;
    final matchedCoachMember = coachMembers.where(
      (m) => m['relationshipId'] == relId || m['id'] == relId,
    ).firstOrNull;

    final memberAcc = findAccount(LocalDemoAccounts.memberEmail)!;
    final coachAcc = findAccount(LocalDemoAccounts.coachEmail)!;
    final String receiverId;
    final String receiverName;
    if (isCoachCaller) {
      receiverId = (matchedConv?['memberId'] as String?) ??
          (matchedCoachMember?['memberId'] as String?) ??
          (memberAcc['id'] as String);
      receiverName = (matchedConv?['memberName'] as String?) ??
          (matchedCoachMember?['memberFullName'] as String?) ??
          (memberAcc['fullName'] as String);
    } else {
      receiverId = (matchedConv?['coachId'] as String?) ??
          (coachAcc['id'] as String);
      receiverName = (matchedConv?['coachName'] as String?) ??
          (coachAcc['fullName'] as String);
    }
    final call = <String, dynamic>{
      'id': 'call-${now.millisecondsSinceEpoch}',
      'relationshipId': relId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': currentUser['fullName'],
      'receiverName': receiverName,
      'callType': body['callType'] ?? 'VOICE',
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
    'coachPackages': coachPackages,
    'coachBlockedSlots': coachBlockedSlots,
    'coachBookings': coachBookings,
    'coachNotifications': coachNotifications,
    'coachTrainingPlans': coachTrainingPlans,
    'coachMealPlans': coachMealPlans,
    'calls': calls,
    'loyaltyAccount': loyaltyAccount,
    'loyaltyRewards': loyaltyRewards,
    'loyaltyRedemptions': loyaltyRedemptions,
    'loyaltyTransactions': loyaltyTransactions,
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

    Map<String, Map<String, dynamic>>? readNestedMap(String key) {
      final raw = json[key];
      if (raw is! Map) return null;
      return raw.map(
        (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
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
      coachPackages: readList('coachPackages') ?? base.coachPackages,
      coachBlockedSlots:
          readList('coachBlockedSlots') ?? base.coachBlockedSlots,
      coachBookings: readList('coachBookings') ?? base.coachBookings,
      coachNotifications:
          readList('coachNotifications') ?? base.coachNotifications,
      coachTrainingPlans:
          readMapList('coachTrainingPlans') ?? base.coachTrainingPlans,
      coachMealPlans: readNestedMap('coachMealPlans') ?? base.coachMealPlans,
      calls: readList('calls') ?? base.calls,
      loyaltyAccount: readMap('loyaltyAccount') ?? base.loyaltyAccount,
      loyaltyRewards: readList('loyaltyRewards') ?? base.loyaltyRewards,
      loyaltyRedemptions:
          readList('loyaltyRedemptions') ?? base.loyaltyRedemptions,
      loyaltyTransactions:
          readList('loyaltyTransactions') ?? base.loyaltyTransactions,
    );
  }
}
