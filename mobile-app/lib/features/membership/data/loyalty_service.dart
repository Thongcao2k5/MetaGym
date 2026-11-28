import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';

abstract interface class LoyaltyService {
  Future<LoyaltySummary> getSummary();
  Future<List<LoyaltyReward>> getRewards({String category = 'ALL'});
  Future<List<LoyaltyRedemption>> getMyRedemptions({String status = 'ALL'});
  Future<LoyaltyRedeemResult> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  });
  Future<LoyaltyRedemption> markRedemptionUsed(String redemptionId);
  Future<List<LoyaltyPointTransaction>> getTransactions({String type = 'ALL'});
}
