import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/membership/data/loyalty_service.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';

class LoyaltyController extends ChangeNotifier {
  LoyaltyController(this._service, {SessionController? session})
    : _session = session,
      _userId = session?.user?.id {
    _session?.addListener(_syncAccount);
  }

  final LoyaltyService _service;
  final SessionController? _session;
  String? _userId;
  int _generation = 0;

  LoyaltySummary? summary;
  List<LoyaltyReward> rewards = const [];
  List<LoyaltyRedemption> redemptions = const [];
  List<LoyaltyPointTransaction> transactions = const [];
  LoyaltyRedemption? selectedCheckoutVoucher;
  bool isLoading = false;
  bool isRedeeming = false;
  String? errorMessage;
  int _redeemSequence = 0;
  final Map<String, String> _redeemKeys = {};

  void _syncAccount() {
    final userId = _session?.user?.id;
    if (_userId == userId) return;
    _userId = userId;
    _generation++;
    summary = null;
    rewards = const [];
    redemptions = const [];
    transactions = const [];
    selectedCheckoutVoucher = null;
    isLoading = false;
    isRedeeming = false;
    errorMessage = null;
    _redeemKeys.clear();
    notifyListeners();
  }

  void selectVoucherForCheckout(LoyaltyRedemption? voucher) {
    selectedCheckoutVoucher =
        (voucher != null && voucher.canApplyAtCheckout) ? voucher : null;
    notifyListeners();
  }

  void clearSelectedCheckoutVoucher() {
    if (selectedCheckoutVoucher == null) return;
    selectedCheckoutVoucher = null;
    notifyListeners();
  }

  void _reconcileSelectedVoucher() {
    final current = selectedCheckoutVoucher;
    if (current == null) return;
    final stillUsable = redemptions
        .where((r) => r.id == current.id && r.canApplyAtCheckout)
        .firstOrNull;
    selectedCheckoutVoucher = stillUsable;
  }

  @override
  void dispose() {
    _generation++;
    _session?.removeListener(_syncAccount);
    super.dispose();
  }

  Future<void> loadAll() async {
    if (isLoading) return;
    final generation = _generation;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _service.getSummary(),
        _service.getRewards(),
        _service.getMyRedemptions(),
        _service.getTransactions(),
      ]);
      if (generation != _generation) return;
      summary = results[0] as LoyaltySummary;
      rewards = results[1] as List<LoyaltyReward>;
      redemptions = results[2] as List<LoyaltyRedemption>;
      transactions = results[3] as List<LoyaltyPointTransaction>;
      _reconcileSelectedVoucher();
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
    } catch (_) {
      if (generation == _generation) {
        errorMessage = 'Không tải được dữ liệu Meta Points.';
      }
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshSummaryAndRewards() async {
    final generation = _generation;
    try {
      final results = await Future.wait<Object>([
        _service.getSummary(),
        _service.getRewards(),
        _service.getMyRedemptions(),
        _service.getTransactions(),
      ]);
      if (generation != _generation) return;
      summary = results[0] as LoyaltySummary;
      rewards = results[1] as List<LoyaltyReward>;
      redemptions = results[2] as List<LoyaltyRedemption>;
      transactions = results[3] as List<LoyaltyPointTransaction>;
      _reconcileSelectedVoucher();
      errorMessage = null;
      notifyListeners();
    } catch (_) {
      // Keep cached data on silent background refresh.
    }
  }

  Future<LoyaltyRedeemResult?> redeem(LoyaltyReward reward) async {
    if (isRedeeming) return null;
    final generation = _generation;
    isRedeeming = true;
    errorMessage = null;
    notifyListeners();
    try {
      final idempotencyKey = _redeemKeys.putIfAbsent(
        reward.id,
        () =>
            'flutter-loyalty-${reward.id}-${DateTime.now().microsecondsSinceEpoch}-${_redeemSequence++}',
      );
      final result = await _service.redeemReward(
        rewardId: reward.id,
        idempotencyKey: idempotencyKey,
      );
      if (generation != _generation) return null;
      _redeemKeys.remove(reward.id);
      summary = result.summary;
      redemptions = [
        result.redemption,
        ...redemptions.where((item) => item.id != result.redemption.id),
      ];
      if (result.redemption.canApplyAtCheckout) {
        selectedCheckoutVoucher = result.redemption;
      }
      if (result.transaction case final tx?) {
        transactions = [
          tx,
          ...transactions.where((item) => item.id != tx.id),
        ];
      }
      // Refresh catalog stock & server state cleanly if needed.
      try {
        rewards = await _service.getRewards();
      } catch (_) {}
      return result;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
      return null;
    } catch (_) {
      if (generation == _generation) {
        errorMessage = 'Không thể đổi ưu đãi lúc này.';
      }
      return null;
    } finally {
      if (generation == _generation) {
        isRedeeming = false;
        notifyListeners();
      }
    }
  }

  Future<LoyaltyRedemption?> markUsed(String redemptionId) async {
    final generation = _generation;
    try {
      final updated = await _service.markRedemptionUsed(redemptionId);
      if (generation != _generation) return null;
      redemptions = [
        for (final item in redemptions)
          if (item.id == updated.id) updated else item,
      ];
      try {
        summary = await _service.getSummary();
      } catch (_) {}
      notifyListeners();
      return updated;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  List<LoyaltyRedemption> get usableCheckoutVouchers =>
      redemptions.where((r) => r.canApplyAtCheckout).toList();
}
