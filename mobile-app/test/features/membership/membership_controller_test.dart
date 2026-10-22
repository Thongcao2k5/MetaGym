import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';

void main() {
  test('shows only active plans', () async {
    final service = _FakeMembershipService();
    final controller = MembershipController(service);

    await controller.load();

    expect(controller.plans.map((plan) => plan.name), ['Gói tháng']);
  });

  test('repeated confirmation creates only one membership result', () async {
    final completer = Completer<PurchaseResult>();
    final service = _FakeMembershipService(confirmFuture: completer.future);
    final controller = MembershipController(service);
    await controller.load();
    await controller.buy(controller.plans.first);

    final first = controller.confirmPayment();
    final second = await controller.confirmPayment();
    expect(second, isFalse);
    expect(service.confirmCalls, 1);

    completer.complete(
      const PurchaseResult(
        payment: Payment(id: 'payment-1', status: 'SUCCESS'),
        membership: Membership(
          id: 'membership-1',
          startDate: '2026-10-22',
          endDate: '2026-11-20',
          status: 'ACTIVE',
        ),
      ),
    );
    expect(await first, isTrue);
    expect(controller.memberships, hasLength(1));
    expect(controller.history, hasLength(1));
  });

  test('supports a consecutive purchase with a new idempotency key', () async {
    final service = _FakeMembershipService();
    final controller = MembershipController(service);
    await controller.load();

    await controller.buy(controller.plans.first);
    await controller.confirmPayment();
    await controller.buy(controller.plans.first);
    await controller.confirmPayment();

    expect(service.idempotencyKeys, hasLength(2));
    expect(service.idempotencyKeys.toSet(), hasLength(2));
    expect(controller.history, hasLength(2));
  });
}

class _FakeMembershipService implements MembershipService {
  _FakeMembershipService({this.confirmFuture});

  final Future<PurchaseResult>? confirmFuture;
  int confirmCalls = 0;
  int createCalls = 0;
  final List<String> idempotencyKeys = [];

  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) {
    confirmCalls += 1;
    return confirmFuture ??
        Future.value(
          PurchaseResult(
            payment: Payment(id: 'payment-$confirmCalls', status: 'SUCCESS'),
            membership: Membership(
              id: 'membership-$confirmCalls',
              startDate: '2026-10-22',
              endDate: '2026-11-20',
              status: 'ACTIVE',
            ),
          ),
        );
  }

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async {
    createCalls += 1;
    idempotencyKeys.add(idempotencyKey);
    return Payment(
      id: 'payment-$createCalls',
      status: 'PENDING',
      qrPayload: 'META-GYM-MOCK:MG-$createCalls',
    );
  }

  @override
  Future<List<Membership>> getCurrentMemberships() async => const [];

  @override
  Future<List<Membership>> getMembershipHistory() async => const [];

  @override
  Future<List<MembershipPlan>> getPlans() async => const [
    MembershipPlan(
      id: 'plan-1',
      name: 'Gói tháng',
      price: 500000,
      durationDays: 30,
      status: 'ACTIVE',
    ),
    MembershipPlan(
      id: 'plan-2',
      name: 'Gói ẩn',
      price: 1,
      durationDays: 1,
      status: 'INACTIVE',
    ),
  ];
}
