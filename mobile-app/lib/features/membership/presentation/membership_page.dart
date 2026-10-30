import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:provider/provider.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MembershipController>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MembershipController>();
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    if (controller.isLoading && controller.plans.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gói tập')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Gói tập')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.errorMessage != null)
            Text(
              controller.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (controller.pendingPayment case final payment?) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Thông tin thanh toán QR mô phỏng'),
                    const SizedBox(height: 8),
                    SelectableText(payment.qrPayload ?? 'Không có dữ liệu QR'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.isConfirming
                          ? null
                          : controller.confirmPayment,
                      child: Text(
                        controller.isConfirming
                            ? 'Đang xác nhận…'
                            : 'Xác nhận đã thanh toán',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text('Gói đang bán', style: Theme.of(context).textTheme.titleLarge),
            ...controller.plans.map(
              (plan) => Card(
                child: ListTile(
                  title: Text(plan.name),
                  subtitle: Text(
                    '${money.format(plan.price)} • ${plan.durationDays} ngày',
                  ),
                  trailing: FilledButton(
                    onPressed: controller.isLoading
                        ? null
                        : () => controller.buy(plan),
                    child: const Text('Mua'),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Gói hiện tại', style: Theme.of(context).textTheme.titleLarge),
          if (controller.memberships.isEmpty)
            const Text('Bạn chưa có gói đang hoạt động.')
          else
            ...controller.memberships.map(
              (item) => ListTile(
                title: Text(item.status),
                subtitle: Text('${item.startDate} → ${item.endDate}'),
              ),
            ),
          Text('Lịch sử', style: Theme.of(context).textTheme.titleLarge),
          ...controller.history.map(
            (item) => ListTile(
              title: Text(item.status),
              subtitle: Text('${item.startDate} → ${item.endDate}'),
            ),
          ),
        ],
      ),
    );
  }
}
