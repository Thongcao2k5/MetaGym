import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/admin/domain/admin_models.dart';

abstract class AdminService {
  Future<List<AdminUserItem>> getUsers({
    String? role,
    String? status,
    String? search,
  });

  Future<void> createCoach({
    required String email,
    required String fullName,
    required String password,
    required int memberLimit,
  });

  Future<void> updateUserStatus({
    required String userId,
    required String status,
    String? reason,
  });

  Future<List<AdminPlanItem>> getPlans();

  Future<void> createPlan({
    required String name,
    String? description,
    required int price,
    required int durationDays,
  });

  Future<void> updatePlanStatus({
    required String planId,
    required String status,
  });
}

class AdminApi implements AdminService {
  const AdminApi(this._client);

  final ApiClient _client;

  @override
  Future<List<AdminUserItem>> getUsers({
    String? role,
    String? status,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'pageSize': 100,
      if (role != null && role.isNotEmpty) 'role': role,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final result = await _client.get<List<AdminUserItem>>(
      '/api/v1/admin/users',
      queryParameters: params,
      decode: (data) {
        if (data is! List) return const [];
        return data
            .map((e) => AdminUserItem.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
    return result.data;
  }

  @override
  Future<void> createCoach({
    required String email,
    required String fullName,
    required String password,
    required int memberLimit,
  }) async {
    await _client.post<void>(
      '/api/v1/admin/coaches',
      body: {
        'email': email.trim().toLowerCase(),
        'fullName': fullName.trim(),
        'password': password,
        'memberLimit': memberLimit,
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> updateUserStatus({
    required String userId,
    required String status,
    String? reason,
  }) async {
    await _client.patch<void>(
      '/api/v1/admin/users/$userId/status',
      body: {
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<List<AdminPlanItem>> getPlans() async {
    final result = await _client.get<List<AdminPlanItem>>(
      '/api/v1/admin/membership-plans',
      queryParameters: {'pageSize': 100},
      decode: (data) {
        if (data is! List) return const [];
        return data
            .map((e) => AdminPlanItem.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
    return result.data;
  }

  @override
  Future<void> createPlan({
    required String name,
    String? description,
    required int price,
    required int durationDays,
  }) async {
    await _client.post<void>(
      '/api/v1/admin/membership-plans',
      body: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'price': price,
        'durationDays': durationDays,
        'status': 'ACTIVE',
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> updatePlanStatus({
    required String planId,
    required String status,
  }) async {
    await _client.patch<void>(
      '/api/v1/admin/membership-plans/$planId',
      body: {'status': status},
      decode: (_) {},
    );
  }
}
