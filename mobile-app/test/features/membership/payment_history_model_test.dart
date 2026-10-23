import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

void main() {
  test('decodes payment history fields returned by the API', () {
    final payment = Payment.fromJson({
      'id': 'payment-1',
      'status': 'PENDING',
      'planName': 'Gói tháng',
      'amount': 500000,
      'method': 'MOCK_QR',
      'transactionCode': 'MG-123',
      'createdAt': '2026-10-23T08:00:00Z',
      'confirmedAt': null,
      'qrPayload': 'META-GYM-MOCK:MG-123',
    });

    expect(payment.planName, 'Gói tháng');
    expect(payment.amount, 500000);
    expect(payment.statusLabel, 'Đang chờ');
    expect(payment.transactionCode, 'MG-123');
    expect(payment.qrPayload, 'META-GYM-MOCK:MG-123');
    expect(payment.confirmedAt, isNull);
  });
}
