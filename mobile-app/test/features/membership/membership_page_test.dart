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
    expect(find.text('Bắt đầu dự kiến'), findsOneWidget);
    await tester.tap(find.text('Tạo giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('META-GYM-MOCK:MG-1'), findsOneWidget);

    await tester.tap(find.text('Mô phỏng thanh toán thành công'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thanh toán thành công'), findsOneWidget);
    expect(find.text('20/11/2026'), findsOneWidget);
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
    expect(find.text('Mua'), findsOneWidget);
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
            startDate: '2026-11-01',
            endDate: '2026-11-30',
            status: 'ACTIVE',
            planName: 'Gói tháng',
          ),
        ],
        availablePlans: const [
          MembershipPlan(
            id: 'plan-day',
            name: 'Gói ngày',
            price: 60000,
            durationDays: 1,
            status: 'ACTIVE',
            description: 'Tập trải nghiệm cả ngày tại phòng gym.',
          ),
          MembershipPlan(
            id: 'plan-month',
            name: 'Gói tháng',
            price: 500000,
            durationDays: 30,
            status: 'ACTIVE',
            description: 'Lựa chọn cân đối cho lịch tập đều đặn.',
          ),
          MembershipPlan(
            id: 'plan-year',
            name: 'Gói năm',
            price: 5000000,
            durationDays: 365,
            status: 'ACTIVE',
            description: 'Cam kết dài hạn với mức giá tối ưu nhất.',
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

      expect(find.text('Gói của tôi'), findsOneWidget);
      expect(find.text('Gói đang bán'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('LINH HOẠT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('LINH HOẠT'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PHỔ BIẾN NHẤT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PHỔ BIẾN NHẤT'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('TIẾT KIỆM NHẤT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TIẾT KIỆM NHẤT'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lịch sử gói'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lịch sử gói'), findsOneWidget);
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
