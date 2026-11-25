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
    expect(find.text('Chưa đăng ký'), findsOneWidget);
    expect(find.text('PT 24 buổi'), findsNothing);
    await tester.tap(find.text('Gói tháng').last);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết giao dịch'), findsOneWidget);
    expect(find.text('MG-123'), findsOneWidget);
    expect(service.loadedPaymentId, 'payment-1');
  });

  testWidgets(
    'coach bento never infers Đang hiệu lực from invoice alone and renders real coach entitlement across 375x812 and 430x932',
    (tester) async {
      for (final size in const [Size(375, 812), Size(430, 932)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final serviceWithInvoiceOnly = _PaymentFixture(includeCoachInvoice: true);
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentHistoryPage(
              key: ValueKey('invoice-only-$size'),
              service: serviceWithInvoiceOnly,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đang hiệu lực'), findsNothing);
        expect(find.text('Xem lịch Coach'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: PaymentHistoryPage(
              key: ValueKey('with-coach-$size'),
              service: serviceWithInvoiceOnly,
              coachEntitlementsLoader: () async => [
                {
                  'id': 'ent-1',
                  'planName': 'Gói PT 24 buổi · Khung 90 phút',
                  'status': 'ACTIVE',
                  'relationshipStatus': 'ACTIVE',
                  'remainingSessions': 14,
                  'endsOn': '2030-01-05',
                },
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Còn 14 buổi'), findsOneWidget);
        expect(find.text('Đang hiệu lực'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

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
  _PaymentFixture({
    this.empty = false,
    this.failFirst = false,
    this.includeCoachInvoice = false,
  });

  final bool empty;
  final bool failFirst;
  final bool includeCoachInvoice;
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

  static const coachPayment = Payment(
    id: 'payment-coach-1',
    status: 'SUCCESS',
    planName: 'Gói Coach 24 buổi',
    amount: 8455000,
    method: 'VNPAY',
    transactionCode: 'MG-261120',
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
    if (empty) return [];
    return includeCoachInvoice ? [coachPayment, payment] : [payment];
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
