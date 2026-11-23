import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';

void main() {
  testWidgets('shows current membership, payment list and payment detail', (
    tester,
  ) async {
    final service = _PaymentFixture();
    await tester.pumpWidget(
      MaterialApp(home: PaymentHistoryPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dịch vụ đang hoạt động'), findsOneWidget);
    expect(find.text('Gói tháng'), findsNWidgets(2));
    await tester.tap(find.text('Gói tháng').last);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết giao dịch'), findsOneWidget);
    expect(find.text('MG-123'), findsOneWidget);
    expect(service.loadedPaymentId, 'payment-1');
  });

  testWidgets('shows empty state and retries a failed list request', (
    tester,
  ) async {
    final service = _PaymentFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: PaymentHistoryPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải giao dịch.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có giao dịch.'), findsOneWidget);
    expect(service.loadCount, 2);
  });
}

class _PaymentFixture implements PaymentHistoryService {
  _PaymentFixture({this.empty = false, this.failFirst = false});

  final bool empty;
  final bool failFirst;
  int loadCount = 0;
  String? loadedPaymentId;

  static const payment = Payment(
    id: 'payment-1',
    status: 'SUCCESS',
    planName: 'Gói tháng',
    amount: 500000,
    method: 'MOCK_QR',
    transactionCode: 'MG-123',
  );

  @override
  Future<List<Payment>> getPayments() async {
    loadCount++;
    if (failFirst && loadCount == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không thể tải giao dịch.',
      );
    }
    return empty ? [] : [payment];
  }

  @override
  Future<Payment> getPayment(String id) async {
    loadedPaymentId = id;
    return payment;
  }

  @override
  Future<List<Membership>> getCurrentMemberships() async => empty
      ? []
      : const [
          Membership(
            id: 'membership-1',
            startDate: '2026-10-22',
            endDate: '2026-11-20',
            status: 'ACTIVE',
            sourcePaymentId: 'payment-1',
          ),
        ];
}
