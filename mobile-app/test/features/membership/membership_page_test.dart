import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('buy and confirm flow shows the current membership', (
    tester,
  ) async {
    final controller = MembershipController(_MembershipFixture());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: MembershipPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mua'));
    await tester.pumpAndSettle();
    expect(find.text('META-GYM-MOCK:MG-1'), findsOneWidget);

    await tester.tap(find.text('Xác nhận đã thanh toán'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.text('2026-10-22 → 2026-11-20'), findsWidgets);
  });
}

class _MembershipFixture implements MembershipService {
  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) async =>
      const PurchaseResult(
        payment: Payment(id: 'payment-1', status: 'SUCCESS'),
        membership: Membership(
          id: 'membership-1',
          startDate: '2026-10-22',
          endDate: '2026-11-20',
          status: 'ACTIVE',
        ),
      );

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async => const Payment(
    id: 'payment-1',
    status: 'PENDING',
    qrPayload: 'META-GYM-MOCK:MG-1',
  );

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
  ];
}
