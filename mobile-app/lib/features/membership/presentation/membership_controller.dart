import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

class MembershipController extends ChangeNotifier {
  MembershipController(this._service, {SessionController? session})
    : _session = session,
      _userId = session?.user?.id {
    _session?.addListener(_syncAccount);
  }

  final MembershipService _service;
  final SessionController? _session;
  String? _userId;
  int _generation = 0;
  List<MembershipPlan> plans = const [];
  List<Membership> memberships = const [];
  List<Membership> history = const [];
  Payment? pendingPayment;
  Payment? checkoutPayment;
  Membership? purchaseResult;
  bool isLoading = false;
  bool isConfirming = false;
  String? errorMessage;
  int _purchaseSequence = 0;
  final Map<String, String> _purchaseKeys = {};

  MembershipCheckoutService? get checkoutService => switch (_service) {
    final MembershipCheckoutService service => service,
    _ => null,
  };

  void _syncAccount() {
    final userId = _session?.user?.id;
    if (_userId == userId) return;
    _userId = userId;
    _generation++;
    plans = const [];
    memberships = const [];
    history = const [];
    pendingPayment = null;
    checkoutPayment = null;
    purchaseResult = null;
    errorMessage = null;
    isLoading = false;
    isConfirming = false;
    _purchaseKeys.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _session?.removeListener(_syncAccount);
    super.dispose();
  }

  Future<MembershipQuote?> quote(MembershipPlan plan) async {
    if (isLoading || pendingPayment != null) return null;
    final generation = _generation;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _service.getQuote(plan.id);
      return generation == _generation ? result : null;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
      return null;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> load() async {
    if (isLoading || isConfirming) return;
    final generation = _generation;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        _service.getPlans(),
        _service.getCurrentMemberships(),
        _service.getMembershipHistory(),
      ]);
      final recovered = await checkoutService?.getPendingPayment();
      if (generation != _generation) return;
      plans =
          (result[0] as List<MembershipPlan>)
              .where((plan) => plan.status == 'ACTIVE')
              .toList()
            ..sort((a, b) => a.durationDays.compareTo(b.durationDays));
      memberships = result[1] as List<Membership>;
      history = result[2] as List<Membership>;
      pendingPayment =
          recovered ?? (checkoutService == null ? pendingPayment : null);
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> buy(MembershipPlan plan) async {
    if (isLoading || pendingPayment != null) return false;
    final generation = _generation;
    isLoading = true;
    errorMessage = null;
    purchaseResult = null;
    checkoutPayment = null;
    notifyListeners();
    try {
      final payment = await _service.createPayment(
        planId: plan.id,
        idempotencyKey: _purchaseKeys.putIfAbsent(
          plan.id,
          () =>
              'flutter-${plan.id}-${DateTime.now().microsecondsSinceEpoch}-${_purchaseSequence++}',
        ),
      );
      if (generation != _generation) return false;
      pendingPayment = payment;
      checkoutPayment = payment;
      _purchaseKeys.remove(plan.id);
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
      return false;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> confirmPayment() async {
    final payment = pendingPayment;
    if (payment == null || isConfirming || isLoading) return false;
    final generation = _generation;
    isConfirming = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _service.confirmMockPayment(payment.id);
      if (generation != _generation) return false;
      pendingPayment = null;
      checkoutPayment = result.payment;
      final membership = result.membership;
      purchaseResult = membership;
      memberships = [
        ...memberships.where((item) => item.id != membership.id),
        membership,
      ]..sort((a, b) => a.startDate.compareTo(b.startDate));
      history = [
        membership,
        ...history.where((item) => item.id != membership.id),
      ];
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
      return false;
    } finally {
      if (generation == _generation) {
        isConfirming = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshPayment() async {
    final service = checkoutService;
    if (service != null) await _updatePayment(service.getPayment);
  }

  Future<void> cancelPayment() async {
    final service = checkoutService;
    if (pendingPayment?.method == 'MOCK_QR' && service != null) {
      await _updatePayment(service.cancelPayment);
    }
  }

  Future<void> _updatePayment(Future<Payment> Function(String) update) async {
    final payment = pendingPayment;
    if (payment == null || isLoading || isConfirming) return;
    final generation = _generation;
    isConfirming = true;
    errorMessage = null;
    notifyListeners();
    try {
      final latest = await update(payment.id);
      if (generation != _generation) return;
      if (latest.status == 'SUCCESS') {
        final current = await _service.getCurrentMemberships();
        final all = await _service.getMembershipHistory();
        if (generation != _generation) return;
        memberships = current;
        history = all;
        purchaseResult = all
            .where((item) => item.sourcePaymentId == latest.id)
            .firstOrNull;
      }
      checkoutPayment = latest;
      pendingPayment = latest.status == 'PENDING' ? latest : null;
    } on ApiException catch (error) {
      if (generation == _generation) errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        isConfirming = false;
        notifyListeners();
      }
    }
  }
}
