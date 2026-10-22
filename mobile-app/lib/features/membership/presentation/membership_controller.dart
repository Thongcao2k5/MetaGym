import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

class MembershipController extends ChangeNotifier {
  MembershipController(this._service);

  final MembershipService _service;
  List<MembershipPlan> plans = const [];
  List<Membership> memberships = const [];
  List<Membership> history = const [];
  Payment? pendingPayment;
  bool isLoading = false;
  bool isConfirming = false;
  String? errorMessage;
  int _purchaseSequence = 0;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        _service.getPlans(),
        _service.getCurrentMemberships(),
        _service.getMembershipHistory(),
      ]);
      plans = (result[0] as List<MembershipPlan>)
          .where((plan) => plan.status == 'ACTIVE')
          .toList();
      memberships = result[1] as List<Membership>;
      history = result[2] as List<Membership>;
    } on ApiException catch (error) {
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buy(MembershipPlan plan) async {
    if (isLoading || pendingPayment != null) return false;
    isLoading = true;
    notifyListeners();
    try {
      pendingPayment = await _service.createPayment(
        planId: plan.id,
        idempotencyKey:
            'flutter-${plan.id}-${DateTime.now().microsecondsSinceEpoch}-${_purchaseSequence++}',
      );
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmPayment() async {
    final payment = pendingPayment;
    if (payment == null || isConfirming) return false;
    isConfirming = true;
    notifyListeners();
    try {
      final result = await _service.confirmMockPayment(payment.id);
      pendingPayment = null;
      memberships = [result.membership];
      history = [result.membership, ...history];
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } finally {
      isConfirming = false;
      notifyListeners();
    }
  }
}
