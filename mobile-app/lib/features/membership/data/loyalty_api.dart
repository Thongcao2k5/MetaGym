import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/membership/data/loyalty_service.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';

class LoyaltyApi implements LoyaltyService {
  const LoyaltyApi(this._client);

  final ApiClient _client;

  @override
  Future<LoyaltySummary> getSummary() async => (await _client.get<LoyaltySummary>(
    '/loyalty/me',
    decode: LoyaltySummary.fromJson,
  )).data;

  @override
  Future<List<LoyaltyReward>> getRewards({String category = 'ALL'}) async =>
      (await _client.get<List<LoyaltyReward>>(
        '/loyalty/rewards',
        queryParameters: category == 'ALL' ? null : {'category': category},
        decode: (value) => (value as List).map(LoyaltyReward.fromJson).toList(),
      )).data;

  @override
  Future<List<LoyaltyRedemption>> getMyRedemptions({
    String status = 'ALL',
  }) async => (await _client.get<List<LoyaltyRedemption>>(
    '/loyalty/redemptions/me',
    queryParameters: status == 'ALL' ? null : {'status': status},
    decode: (value) => (value as List).map(LoyaltyRedemption.fromJson).toList(),
  )).data;

  @override
  Future<LoyaltyRedeemResult> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  }) async => (await _client.post<LoyaltyRedeemResult>(
    '/loyalty/redemptions',
    headers: {'idempotency-key': idempotencyKey},
    body: {'rewardId': rewardId},
    decode: LoyaltyRedeemResult.fromJson,
  )).data;

  @override
  Future<LoyaltyRedemption> markRedemptionUsed(String redemptionId) async =>
      (await _client.post<LoyaltyRedemption>(
        '/loyalty/redemptions/${Uri.encodeComponent(redemptionId)}/use',
        decode: LoyaltyRedemption.fromJson,
      )).data;

  @override
  Future<List<LoyaltyPointTransaction>> getTransactions({
    String type = 'ALL',
  }) async => (await _client.get<List<LoyaltyPointTransaction>>(
    '/loyalty/transactions/me',
    queryParameters: type == 'ALL' ? null : {'type': type},
    decode: (value) =>
        (value as List).map(LoyaltyPointTransaction.fromJson).toList(),
  )).data;
}
