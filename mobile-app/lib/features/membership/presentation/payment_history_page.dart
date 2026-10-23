import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_detail_page.dart';
import 'package:provider/provider.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({this.service, super.key});

  final PaymentHistoryService? service;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  PaymentHistoryService? _service;
  List<Payment> _payments = const [];
  List<Membership> _memberships = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? PaymentHistoryApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final payments = await _service!.getPayments();
      final memberships = await _service!.getCurrentMemberships();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _memberships = memberships;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải dữ liệu thanh toán.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _membershipName(Membership membership) {
    for (final payment in _payments) {
      if (payment.id == membership.sourcePaymentId &&
          payment.planName != null) {
        return payment.planName!;
      }
    }
    return 'Gói tập';
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final active = _memberships.where((item) => item.status == 'ACTIVE');
    final scheduled = _memberships.where((item) => item.status == 'SCHEDULED');
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: _loading && _payments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  Text(
                    'Gói đang hoạt động',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (active.isEmpty)
                    const ListTile(title: Text('Chưa có gói đang hoạt động.')),
                  for (final item in active)
                    ListTile(
                      title: Text(_membershipName(item)),
                      subtitle: Text('${item.startDate} → ${item.endDate}'),
                    ),
                  if (scheduled.isNotEmpty) ...[
                    Text(
                      'Gói sắp tới',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final item in scheduled)
                      ListTile(
                        title: Text(_membershipName(item)),
                        subtitle: Text('${item.startDate} → ${item.endDate}'),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Lịch sử giao dịch',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_payments.isEmpty)
                    const ListTile(title: Text('Chưa có giao dịch.')),
                  for (final payment in _payments)
                    ListTile(
                      title: Text(payment.planName ?? 'Giao dịch'),
                      subtitle: Text(
                        '${payment.amount == null ? '' : money.format(payment.amount)} '
                        '• ${payment.statusLabel}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PaymentDetailPage(
                            paymentId: payment.id,
                            service: _service!,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
