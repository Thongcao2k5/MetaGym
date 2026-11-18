import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

class MembershipApi
    implements
        MembershipService,
        MembershipCheckoutService,
        MembershipOnlinePaymentService {
  const MembershipApi(this._client);

  final ApiClient _client;

  @override
  Future<List<MembershipPlan>> getPlans() =>
      _list('/membership-plans', MembershipPlan.fromJson);

  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      (await _client.get<MembershipQuote>(
        '/membership-plans/$planId/quote',
        decode: MembershipQuote.fromJson,
      )).data;

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async => (await _client.post<Payment>(
    '/payments',
    headers: {'idempotency-key': idempotencyKey},
    body: {'planId': planId, 'method': 'ZALOPAY'},
    receiveTimeout: const Duration(seconds: 40),
    decode: Payment.fromJson,
  )).data;

  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) async =>
      (await _client.post<PurchaseResult>(
        '/payments/$paymentId/mock-confirmations',
        decode: PurchaseResult.fromJson,
      )).data;

  @override
  Future<Payment?> getPendingPayment() async {
    final payments = await _list('/payments/me', Payment.fromJson);
    return payments
        .where(
          (payment) =>
              payment.method == 'ZALOPAY' && payment.status == 'PENDING',
        )
        .firstOrNull;
  }

  @override
  Future<Payment> getPayment(String id) async => (await _client.get<Payment>(
    '/payments/${Uri.encodeComponent(id)}',
    decode: Payment.fromJson,
  )).data;

  @override
  Future<Payment> reconcileOnlinePayment(
    String id, {
    required String method,
  }) async => (await _client.post<Payment>(
    '/payments/${Uri.encodeComponent(id)}/${method.toLowerCase()}-status',
    receiveTimeout: method == 'MOMO' || method == 'ZALOPAY'
        ? const Duration(seconds: 70)
        : null,
    decode: Payment.fromJson,
  )).data;

  @override
  Future<Payment> cancelPayment(String id) async =>
      (await _client.post<Payment>(
        '/payments/${Uri.encodeComponent(id)}/cancellations',
        decode: Payment.fromJson,
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
