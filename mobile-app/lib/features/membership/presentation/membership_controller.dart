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
  Future<void>? _loadInFlight;

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
    _loadInFlight = null;
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

  Future<void> load() {
    if (isConfirming) return Future<void>.value();
    if (_loadInFlight case final inFlight?) return inFlight;
    if (isLoading) return Future<void>.value();

    late final Future<void> future;
    future = _performLoad().whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
    _loadInFlight = future;
    return future;
  }

  Future<void> _performLoad() async {
    final generation = _generation;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object?>([
        _service.getPlans(),
        _service.getCurrentMemberships(),
        _service.getMembershipHistory(),
        checkoutService?.getPendingPayment() ?? Future<Payment?>.value(null),
      ]);
      if (generation != _generation) return;
      plans =
          (result[0] as List<MembershipPlan>)
              .where((plan) => plan.status == 'ACTIVE')
              .toList()
            ..sort((a, b) => a.durationDays.compareTo(b.durationDays));
      memberships = result[1] as List<Membership>;
      history = result[2] as List<Membership>;
      final recovered = result[3] as Payment?;
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
      pendingPayment = payment.status == 'PENDING' ? payment : null;
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

  Future<void> refreshPayment({bool reconcile = false}) async {
    final service = _onlinePaymentService;
    final method = pendingPayment?.method;
    if (reconcile &&
        service != null &&
        ['ZALOPAY', 'MOMO', 'VNPAY'].contains(method)) {
      await _updatePayment(
        (id) => service.reconcileOnlinePayment(id, method: method!),
      );
      return;
    }
    final checkout = checkoutService;
    if (checkout != null) await _updatePayment(checkout.getPayment);
  }

  Future<bool> resumeOnlinePayment(String id, {required String method}) async {
    final service = _onlinePaymentService;
    if (service == null) return false;
    return _updatePayment(
      (id) => service.reconcileOnlinePayment(id, method: method),
      paymentId: id,
    );
  }

  MembershipOnlinePaymentService? get _onlinePaymentService =>
      switch (_service) {
        final MembershipOnlinePaymentService service => service,
        _ => null,
      };

  Future<void> cancelPayment() async {
    final service = checkoutService;
    if (pendingPayment?.method == 'MOCK_QR' && service != null) {
      await _updatePayment(service.cancelPayment);
    }
  }

  Future<bool> _updatePayment(
    Future<Payment> Function(String) update, {
    String? paymentId,
  }) async {
    final id = paymentId ?? pendingPayment?.id;
    if (id == null || isLoading || isConfirming) return false;
    final generation = _generation;
    isConfirming = true;
    errorMessage = null;
    notifyListeners();
    try {
      final latest = await update(id);
      if (generation != _generation) return false;
      purchaseResult = null;
      if (latest.status == 'SUCCESS') {
        final current = await _service.getCurrentMemberships();
        final all = await _service.getMembershipHistory();
        if (generation != _generation) return false;
        memberships = current;
        history = all;
        purchaseResult = all
            .where(
              (item) =>
                  item.id == latest.membershipId ||
                  item.sourcePaymentId == latest.id,
            )
            .firstOrNull;
      }
      checkoutPayment = latest;
      pendingPayment = latest.status == 'PENDING' ? latest : null;
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
}
