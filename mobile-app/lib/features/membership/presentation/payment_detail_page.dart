import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';

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

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép mã giao dịch.')));
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return Scaffold(
      backgroundColor: MetaGymTheme.paletteOf(context).canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                MembershipTopBar(
                  eyebrow: 'BIÊN LAI ĐIỆN TỬ',
                  title: 'Chi tiết giao dịch',
                  actions: [
                    MetaGymCircleIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Tải lại',
                      onTap: _load,
                    ),
                  ],
                ),
                Expanded(
                  child: payment == null && _error == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            if (_error != null)
                              MembershipErrorCard(
                                message: _error!,
                                onRetry: _load,
                              ),
                            if (payment != null) ...[
                              MetaGymHeroGlassCard(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        MembershipStatusPill(
                                          label: payment.statusLabel,
                                          color: membershipStatusColor(
                                            payment.status,
                                          ),
                                        ),
                                        if (payment.method != null)
                                          Text(
                                            formatPaymentMethodLabel(
                                              payment.method!,
                                            ),
                                            style: const TextStyle(
                                              color:
                                                  MetaGymTheme.reflectionBlue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    if (payment.amount != null)
                                      Text(
                                        formatMembershipMoney(payment.amount!),
                                        style: const TextStyle(
                                          color: MetaGymTheme.textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      payment.planName ?? 'Không có tên gói',
                                      style: const TextStyle(
                                        color: Color(0xFFD5CCBF),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MetaGymGlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _DetailRow(
                                      label: 'Trạng thái',
                                      value: payment.statusLabel,
                                    ),
                                    _DetailRow(
                                      label: 'Gói tập',
                                      value:
                                          payment.planName ??
                                          'Không có tên gói',
                                    ),
                                    if (payment.amount != null)
                                      _DetailRow(
                                        label: 'Số tiền',
                                        value: formatMembershipMoney(
                                          payment.amount!,
                                        ),
                                      ),
                                    if (payment.method != null)
                                      _DetailRow(
                                        label: 'Phương thức',
                                        value: formatPaymentMethodLabel(
                                          payment.method!,
                                        ),
                                      ),
                                    if (payment.transactionCode != null)
                                      _DetailRow(
                                        label: 'Mã giao dịch',
                                        value: payment.transactionCode!,
                                        onCopy: () =>
                                            _copyCode(payment.transactionCode!),
                                      ),
                                    if (payment.createdAt != null)
                                      _DetailRow(
                                        label: 'Ngày tạo',
                                        value: formatMembershipDateTime(
                                          payment.createdAt!,
                                        ),
                                      ),
                                    if (payment.confirmedAt != null)
                                      _DetailRow(
                                        label: 'Ngày xác nhận',
                                        value: formatMembershipDateTime(
                                          payment.confirmedAt!,
                                        ),
                                      ),
                                    if (payment.qrPayload != null)
                                      _DetailRow(
                                        label: 'Dữ liệu QR mô phỏng',
                                        value: payment.qrPayload!,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB7B2AF), fontSize: 13.5),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Sao chép $label',
                    child: MetaGymTap(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.copy_rounded,
                          size: 17,
                          color: MetaGymTheme.reflectionBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
