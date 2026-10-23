import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

abstract interface class PaymentHistoryService {
  Future<List<Payment>> getPayments();
  Future<Payment> getPayment(String id);
  Future<List<Membership>> getCurrentMemberships();
}

class PaymentHistoryApi implements PaymentHistoryService {
  const PaymentHistoryApi(this.client);

  final ApiClient client;

  @override
  Future<List<Payment>> getPayments() async => (await client.get<List<Payment>>(
    '/payments/me',
    decode: (value) => (value as List).map(Payment.fromJson).toList(),
  )).data;

  @override
  Future<Payment> getPayment(String id) async => (await client.get<Payment>(
    '/payments/${Uri.encodeComponent(id)}',
    decode: Payment.fromJson,
  )).data;

  @override
  Future<List<Membership>> getCurrentMemberships() async =>
      (await client.get<List<Membership>>(
        '/memberships/me',
        decode: (value) => (value as List).map(Membership.fromJson).toList(),
      )).data;
}
