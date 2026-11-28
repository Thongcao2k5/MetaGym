import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    await tester.tap(find.byKey(const Key('empty-membership-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán gói tập'), findsOneWidget);
    expect(find.text('VNPay QR / Thẻ nội địa'), findsOneWidget);
    expect(find.text('Mã ưu đãi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout-pay-submit')));
    await tester.pumpAndSettle();
    expect(find.text('META-GYM-MOCK:MG-1'), findsOneWidget);

    await tester.tap(find.text('Mô phỏng thanh toán thành công'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thanh toán thành công'), findsOneWidget);
    expect(find.textContaining('20/11/2026'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resumes and cancels a pending checkout from the backend', (
    tester,
  ) async {
    final fixture = _MembershipFixture(
      recovered: const Payment(
        id: 'previous',
        status: 'PENDING',
        method: 'MOCK_QR',
        transactionCode: 'MG-PREVIOUS',
        amount: 500000,
      ),
    );
    final controller = MembershipController(fixture);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: MembershipPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch chờ thanh toán'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục thanh toán'));
    await tester.pumpAndSettle();
    expect(find.text('MG-PREVIOUS'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra trạng thái'));
    await tester.pumpAndSettle();
    expect(fixture.checkedId, 'previous');
    await tester.ensureVisible(find.text('Hủy giao dịch'));
    await tester.tap(find.text('Hủy giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hủy giao dịch').last);
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy'), findsOneWidget);
    await tester.tap(find.text('Về Gói tập'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty-membership-cta')), findsOneWidget);
  });

  testWidgets('shows a QR for a pending ZaloPay order', (tester) async {
    const orderUrl =
        'https://qcgateway.zalopay.vn/openinapp?order=sandbox-order';
    final controller = MembershipController(
      _MembershipFixture(
        recovered: const Payment(
          id: 'zalopay-pending',
          status: 'PENDING',
          method: 'ZALOPAY',
          amount: 150000,
          paymentUrl: orderUrl,
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: MembershipPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục thanh toán'));
    await tester.pumpAndSettle();
    final qr = find.byType(QrImageView);
    expect(qr, findsOneWidget);
    expect(
      find.descendant(of: qr, matching: find.byType(CustomPaint)),
      findsWidgets,
    );
    expect(find.text('Mã QR ZaloPay Sandbox'), findsOneWidget);
    expect(find.text('Mở lại ZaloPay Sandbox'), findsNothing);
    expect(find.text('Kiểm tra trạng thái'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'compact 360x640 viewport renders active membership hero and 3 tiered plans without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = _MembershipFixture(
        currentMemberships: const [
          Membership(
            id: 'mem-active',
            startDate: '2026-10-22',
            endDate: '2027-01-03',
            status: 'ACTIVE',
            planName: 'Hạng Vàng — Pro 6 Tháng',
          ),
        ],
        availablePlans: const [
          MembershipPlan(
            id: 'plan-diamond',
            name: 'Kim Cương VIP',
            price: 8490000,
            durationDays: 365,
            status: 'ACTIVE',
            description:
                'Thẻ Kim Cương NFC · InBody không giới hạn · 6 buổi PT 1:1',
          ),
          MembershipPlan(
            id: 'plan-gold',
            name: 'Hạng Vàng — Pro 6 Tháng',
            price: 4490000,
            durationDays: 180,
            status: 'ACTIVE',
            description: 'Thẻ Vàng NFC · InBody hàng tháng · 2 buổi PT 1:1',
          ),
          MembershipPlan(
            id: 'plan-silver',
            name: 'Hạng Bạc — Plus',
            price: 2490000,
            durationDays: 90,
            status: 'ACTIVE',
            description: 'Thẻ Bạc NFC · Tập full khung giờ · 1 lần InBody',
          ),
        ],
      );
      final controller = MembershipController(fixture);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: MembershipPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thẻ hội viên của tôi'), findsOneWidget);
      expect(find.text('Hiệu lực'), findsOneWidget);
      expect(find.text('Mặt sau · Lật'), findsOneWidget);
      expect(find.text('Gia hạn thẻ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('active-membership-flip-card')));
      await tester.pumpAndSettle();
      expect(find.text('Mặt trước · Lật'), findsOneWidget);
      await tester.tap(find.byKey(const Key('active-membership-flip-card')));
      await tester.pumpAndSettle();
      expect(find.text('Mặt sau · Lật'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('active-membership-flip-card')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mặt trước · Lật'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Meta Points'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Meta Points'), findsOneWidget);
      expect(find.text('1.240 điểm'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Ưu đãi Hạng Vàng đang áp dụng'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ưu đãi Hạng Vàng đang áp dụng'), findsOneWidget);
      expect(find.text('3 đặc quyền'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Nâng cấp gói tập'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nâng cấp gói tập'), findsOneWidget);
      expect(find.text('Kim Cương VIP'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Lịch sử gói'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lịch sử gói'), findsOneWidget);

      // Mở luồng đổi điểm (fallback modal khi không có LoyaltyController provider) và đổi voucher 300 điểm
      await tester.scrollUntilVisible(
        find.byKey(const Key('membership-redeem-rewards-btn')),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('membership-redeem-rewards-btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('membership-redeem-rewards-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Đổi điểm Meta Points'), findsOneWidget);
      await tester.tap(find.text('Đổi ngay').first);
      await tester.pumpAndSettle();
      expect(find.text('940 điểm'), findsWidgets);
    },
  );

  testWidgets(
    '1.2b empty membership state renders 4-tier wallet deck and updates perks/CTA on tab tap without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = _MembershipFixture(
        currentMemberships: const [],
        availablePlans: const [
          MembershipPlan(
            id: 'p-bronze',
            name: 'Hạng Đồng — Starter 1 Tháng',
            price: 890000,
            durationDays: 30,
            status: 'ACTIVE',
          ),
          MembershipPlan(
            id: 'p-silver',
            name: 'Hạng Bạc — Plus 3 Tháng',
            price: 2490000,
            durationDays: 90,
            status: 'ACTIVE',
          ),
          MembershipPlan(
            id: 'p-gold',
            name: 'Hạng Vàng — Pro 6 Tháng',
            price: 4490000,
            durationDays: 180,
            status: 'ACTIVE',
          ),
          MembershipPlan(
            id: 'p-diamond',
            name: 'Kim Cương VIP — 12 Tháng',
            price: 8490000,
            durationDays: 365,
            status: 'ACTIVE',
          ),
        ],
      );
      final controller = MembershipController(fixture);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: MembershipPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chọn gói tập'), findsOneWidget);
      expect(find.text('Chưa có gói'), findsOneWidget);
      expect(find.text('Hạng Vàng — Pro 6 Tháng'), findsOneWidget);
      expect(find.text('Phổ biến nhất'), findsOneWidget);
      expect(find.text('-5%'), findsOneWidget);

      await tester.tap(find.text('Kim Cương'));
      await tester.pumpAndSettle();
      expect(find.text('Kim Cương VIP — 12 Tháng'), findsOneWidget);
      expect(find.text('VIP Cao cấp'), findsOneWidget);
      expect(find.text('-10%'), findsOneWidget);
      expect(find.text('×2.0 điểm'), findsOneWidget);

      expect(
        find.byKey(const Key('empty-membership-promo-strip')),
        findsOneWidget,
      );
      expect(find.text('Mở khóa đặc quyền VIP'), findsOneWidget);

      await tester.tap(find.byKey(const Key('empty-membership-promo-strip')));
      await tester.pumpAndSettle();
      expect(find.text('Đặc quyền & Ưu đãi hội viên VIP'), findsOneWidget);
      expect(find.text('Lật mặt sau'), findsOneWidget);
      expect(find.text('Mặt sau · Lật'), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('promo-select-tier-diamond')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('promo-select-tier-diamond')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đặc quyền & Ưu đãi hội viên VIP'), findsNothing);
      expect(find.text('Kim Cương VIP — 12 Tháng'), findsOneWidget);
      expect(find.text('Lật mặt sau'), findsOneWidget);

      expect(find.text('Đo chỉ số cơ thể InBody'), findsOneWidget);
      expect(find.text('Lật mặt sau'), findsOneWidget);
      await tester.tap(find.byKey(const Key('empty-membership-flip-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Mặt sau · Lật'), findsOneWidget);

      await tester.tap(find.text('Đồng'));
      await tester.pumpAndSettle();
      expect(find.text('Lật mặt sau'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Trả phí lẻ'), findsOneWidget);

      await tester.tap(find.byKey(const Key('empty-membership-cta')));
      await tester.pumpAndSettle();

      expect(find.text('1 cổng hỗ trợ'), findsOneWidget);
      expect(find.text('VNPay QR / Thẻ nội địa'), findsOneWidget);
      expect(find.text('Ví điện tử MoMo'), findsNothing);
      expect(find.text('Ví ZaloPay'), findsNothing);
      await tester.enterText(find.byType(TextField), 'METAGYM200');
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('500.000'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('checkout-pay-submit')),
          matching: find.textContaining('VNPay'),
        ),
        findsOneWidget,
      );
    },
  );
}

class _MembershipFixture
    implements MembershipService, MembershipCheckoutService {
  _MembershipFixture({
    this.recovered,
    this.currentMemberships = const [],
    List<MembershipPlan>? availablePlans,
  }) : _availablePlans = availablePlans ?? _defaultPlans;

  static const _defaultPlans = [
    MembershipPlan(
      id: 'plan-1',
      name: 'Gói tháng',
      price: 500000,
      durationDays: 30,
      status: 'ACTIVE',
    ),
  ];

  Payment? recovered;
  String? checkedId;
  final List<Membership> currentMemberships;
  final List<MembershipPlan> _availablePlans;

  @override
  Future<Payment?> getPendingPayment() async => recovered;

  @override
  Future<Payment> getPayment(String id) async {
    checkedId = id;
    return recovered!;
  }

  @override
  Future<Payment> cancelPayment(String id) async {
    recovered = null;
    return Payment(id: id, status: 'CANCELLED', method: 'MOCK_QR');
  }

  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      const MembershipQuote(
        price: 500000,
        durationDays: 30,
        startDate: '2026-10-22',
        endDate: '2026-11-20',
      );

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
    method: 'MOCK_QR',
    qrPayload: 'META-GYM-MOCK:MG-1',
  );

  @override
  Future<List<Membership>> getCurrentMemberships() async => currentMemberships;

  @override
  Future<List<Membership>> getMembershipHistory() async => currentMemberships;

  @override
  Future<List<MembershipPlan>> getPlans() async => _availablePlans;
}
