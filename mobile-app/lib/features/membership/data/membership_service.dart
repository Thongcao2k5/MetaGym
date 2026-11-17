import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

abstract interface class MembershipService {
  Future<MembershipQuote> getQuote(String planId);
  Future<List<MembershipPlan>> getPlans();
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  });
  Future<PurchaseResult> confirmMockPayment(String paymentId);
  Future<List<Membership>> getCurrentMemberships();
  Future<List<Membership>> getMembershipHistory();
}

abstract interface class MembershipCheckoutService {
  Future<Payment?> getPendingPayment();
  Future<Payment> getPayment(String id);
  Future<Payment> cancelPayment(String id);
}
