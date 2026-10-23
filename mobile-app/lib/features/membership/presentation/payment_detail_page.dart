import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';

class PaymentDetailPage extends StatefulWidget {
  const PaymentDetailPage({
    required this.paymentId,
    required this.service,
    super.key,
  });

  final String paymentId;
  final PaymentHistoryService service;

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  Payment? _payment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _payment = null;
      _error = null;
    });
    try {
      final payment = await widget.service.getPayment(widget.paymentId);
      if (mounted) setState(() => _payment = payment);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải chi tiết giao dịch.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: payment == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (payment != null) ...[
                  _detail('Trạng thái', payment.statusLabel),
                  _detail('Gói tập', payment.planName ?? 'Không có tên gói'),
                  if (payment.amount != null)
                    _detail('Số tiền', money.format(payment.amount)),
                  if (payment.method != null)
                    _detail('Phương thức', payment.method!),
                  if (payment.transactionCode != null)
                    _detail('Mã giao dịch', payment.transactionCode!),
                  if (payment.createdAt != null)
                    _detail('Ngày tạo', payment.createdAt!),
                  if (payment.confirmedAt != null)
                    _detail('Ngày xác nhận', payment.confirmedAt!),
                  if (payment.qrPayload != null)
                    _detail('Dữ liệu QR mô phỏng', payment.qrPayload!),
                ],
              ],
            ),
    );
  }

  Widget _detail(String label, String value) =>
      ListTile(title: Text(label), subtitle: SelectableText(value));
}
