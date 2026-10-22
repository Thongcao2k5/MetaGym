import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

abstract interface class MembershipService {
  Future<List<MembershipPlan>> getPlans();
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  });
  Future<PurchaseResult> confirmMockPayment(String paymentId);
  Future<List<Membership>> getCurrentMemberships();
  Future<List<Membership>> getMembershipHistory();
}
