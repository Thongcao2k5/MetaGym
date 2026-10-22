import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

class MembershipApi implements MembershipService {
  const MembershipApi(this._client);

  final ApiClient _client;

  @override
  Future<List<MembershipPlan>> getPlans() =>
      _list('/membership-plans', MembershipPlan.fromJson);

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async => (await _client.post<Payment>(
    '/payments',
    headers: {'idempotency-key': idempotencyKey},
    body: {'planId': planId},
    decode: Payment.fromJson,
  )).data;

  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) async =>
      (await _client.post<PurchaseResult>(
        '/payments/$paymentId/mock-confirmations',
        decode: PurchaseResult.fromJson,
      )).data;

  @override
  Future<List<Membership>> getCurrentMemberships() =>
      _list('/memberships/me', Membership.fromJson);

  @override
  Future<List<Membership>> getMembershipHistory() =>
      _list('/memberships/me/history', Membership.fromJson);

  Future<List<T>> _list<T>(String path, T Function(Object?) decode) async =>
      (await _client.get<List<T>>(
        path,
        queryParameters: path == '/membership-plans' ? {'pageSize': 100} : null,
        decode: (value) => (value as List).map(decode).toList(),
      )).data;
}
