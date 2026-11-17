import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:provider/provider.dart';

class MembershipCheckoutPage extends StatefulWidget {
  const MembershipCheckoutPage({super.key, this.plan, this.quote});

  final MembershipPlan? plan;
  final MembershipQuote? quote;

  @override
  State<MembershipCheckoutPage> createState() => _MembershipCheckoutPageState();
}

class _MembershipCheckoutPageState extends State<MembershipCheckoutPage> {
  late bool _reviewing = widget.quote != null;

  Future<void> _copyText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _cancel(MembershipController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1C1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x66A79D92)),
        ),
        title: const Text(
          'Hủy giao dịch này?',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn có thể chọn gói và tạo giao dịch mới sau đó.',
          style: TextStyle(color: Color(0xFFD5CCBF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Giữ giao dịch',
              style: TextStyle(color: Color(0xFFB7B2AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hủy giao dịch',
              style: TextStyle(
                color: MetaGymTheme.dangerCoral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await controller.cancelPayment();
  }

  Widget _info(String label, String value, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB7B2AF),
              fontSize: 13.5,
            ),
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
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing],
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MembershipController>();
    final payment = controller.pendingPayment ?? controller.checkoutPayment;
    final membership = controller.purchaseResult;
    final busy = controller.isLoading || controller.isConfirming;
    final quote = widget.quote;
    final plan = widget.plan;
    final reviewing = _reviewing && quote != null && plan != null;
    final pending = payment?.status == 'PENDING';
    final mock = payment?.method == 'MOCK_QR';
    final title = reviewing
        ? 'Kiểm tra đơn'
        : pending
        ? 'Thanh toán'
        : 'Kết quả giao dịch';
    final step = reviewing
        ? 1
        : pending
        ? 2
        : 3;
    final amount = reviewing ? quote.price : payment?.amount;

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                MembershipTopBar(
                  eyebrow: 'THANH TOÁN HỘI VIÊN',
                  title: title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _CheckoutStepper(step: step),
                      const SizedBox(height: 12),
                      if (controller.errorMessage case final message?)
                        MembershipErrorCard(message: message),

                      // KẾT QUẢ BƯỚC 3
                      if (!reviewing && !pending && payment != null)
                        _CheckoutOutcomeHero(payment: payment),

                      // BƯỚC 2: ĐẶT CỔNG VNPAY-QR & CỤM THAO TÁC CHÍNH LÊN TRÊN ĐỂ THAO TÁC NGAY
                      if (!reviewing && pending) ...[
                        if (mock) ...[
                          _VnPaySandboxQrCard(
                            qrSeed:
                                payment?.qrPayload ??
                                payment?.transactionCode ??
                                'META-GYM-MOCK',
                            qrPayload: payment?.qrPayload,
                            amount: amount,
                            onCopy: (text) => _copyText(
                              text,
                              'Đã sao chép mã giao dịch.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          MembershipPrimaryButton(
                            label: 'Mô phỏng thanh toán thành công',
                            icon: Icons.verified_rounded,
                            onPressed: busy ? null : controller.confirmPayment,
                          ),
                        ],
                        if (controller.checkoutService != null) ...[
                          const SizedBox(height: 8),
                          _RefreshStatusButton(
                            busy: busy,
                            onPressed: controller.refreshPayment,
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            children: [
                              if (payment?.transactionCode case final code?)
                                TextButton.icon(
                                  onPressed: () => _copyText(
                                    code,
                                    'Đã sao chép mã giao dịch.',
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        MetaGymTheme.reflectionBlue,
                                  ),
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Sao chép mã giao dịch'),
                                ),
                              if (mock)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _cancel(controller),
                                  style: TextButton.styleFrom(
                                    foregroundColor: MetaGymTheme.dangerCoral,
                                  ),
                                  child: const Text('Hủy giao dịch'),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],

                      // KHỐI THÔNG TIN ĐƠN HÀNG
                      MetaGymGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (reviewing) ...[
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Chi tiết gói đăng ký',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  MembershipStatusPill(
                                    label: '${quote.durationDays} ngày',
                                    color: MetaGymTheme.brandOrange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _info('Gói tập', plan.name),
                              _info('Thời hạn', '${quote.durationDays} ngày'),
                              _info(
                                'Bắt đầu dự kiến',
                                formatMembershipDate(quote.startDate),
                              ),
                              _info(
                                'Hết hạn dự kiến',
                                formatMembershipDate(quote.endDate),
                              ),
                              if (plan.description case final description?
                                  when description.trim().isNotEmpty)
                                _info('Thông tin gói', description),
                            ] else if (payment != null) ...[
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Thông tin giao dịch',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  MembershipStatusPill(
                                    label: payment.statusLabel,
                                    color: membershipStatusColor(
                                      payment.status,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (payment.planName case final name?)
                                _info('Gói tập', name),
                              if (payment.method case final method?)
                                _info(
                                  'Phương thức',
                                  formatPaymentMethodLabel(method),
                                ),
                              if (payment.transactionCode case final code?)
                                _info(
                                  'Mã giao dịch',
                                  code,
                                  trailing: Semantics(
                                    button: true,
                                    label: 'Sao chép mã giao dịch',
                                    child: InkWell(
                                      onTap: () => _copyText(
                                        code,
                                        'Đã sao chép mã giao dịch.',
                                      ),
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
                                ),
                              if (payment.status == 'SUCCESS' &&
                                  membership != null) ...[
                                _info('Gói hội viên', membership.label),
                                _info(
                                  'Bắt đầu',
                                  formatMembershipDate(membership.startDate),
                                ),
                                _info(
                                  'Hết hạn',
                                  formatMembershipDate(membership.endDate),
                                ),
                              ],
                            ] else
                              const Text(
                                'Không tìm thấy giao dịch.',
                                style: TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                ),
                              ),
                            if (amount != null) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  color: Color(0x30FFF6EA),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pending || reviewing
                                        ? 'Tổng thanh toán'
                                        : 'Số tiền',
                                    style: const TextStyle(
                                      color: MetaGymTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    formatMembershipMoney(amount),
                                    style: const TextStyle(
                                      color: MetaGymTheme.brandOrange,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // BƯỚC 1: TẠO GIAO DỊCH
                      if (reviewing) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: MetaGymTheme.reflectionBlue,
                                size: 17,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hệ thống sẽ khởi tạo mã VNPAY-QR giả lập để bạn xác nhận thanh toán.',
                                  style: TextStyle(
                                    color: Color(0xFFD5CCBF),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        MembershipPrimaryButton(
                          label: busy ? 'Đang tạo giao dịch…' : 'Tạo giao dịch',
                          icon: busy ? null : Icons.qr_code_2_rounded,
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await controller.buy(plan) && mounted) {
                                    setState(() => _reviewing = false);
                                  }
                                },
                        ),
                      ] else if (!pending) ...[
                        MembershipPrimaryButton(
                          label: 'Về Gói tập',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.of(context).pop(),
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

class _RefreshStatusButton extends StatelessWidget {
  const _RefreshStatusButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: MetaGymTheme.textPrimary,
          backgroundColor: const Color(0x902B2622),
          side: const BorderSide(color: Color(0x8CA79D92)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.sync_rounded, size: 18),
        label: Text(
          busy ? 'Đang xử lý…' : 'Kiểm tra trạng thái',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CheckoutStepper extends StatelessWidget {
  const _CheckoutStepper({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Kiểm tra đơn', 'Thanh toán', 'Kết quả'];
    return Semantics(
      label: 'Bước $step trên 3',
      child: MetaGymGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: step == index + 1
                            ? MetaGymTheme.brandOrange
                            : step > index + 1
                            ? MetaGymTheme.progressGreen
                            : const Color(0x38FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: step > index + 1
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${index + 1}. ${labels[index]}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: step == index + 1
                            ? MetaGymTheme.brandOrange
                            : step > index + 1
                            ? MetaGymTheme.progressGreen
                            : const Color(0xFFB7B2AF),
                        fontSize: 11.5,
                        fontWeight: step == index + 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 18,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: step > index + 1
                        ? MetaGymTheme.progressGreen
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VnPaySandboxQrCard extends StatelessWidget {
  const _VnPaySandboxQrCard({
    required this.qrSeed,
    required this.onCopy,
    this.qrPayload,
    this.amount,
  });

  final String qrSeed;
  final String? qrPayload;
  final num? amount;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MembershipStatusPill(
                label: 'VNPAY-QR',
                color: MetaGymTheme.infoSteelBlue,
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(width: 8),
              const MembershipStatusPill(
                label: 'Giả lập Sandbox',
                color: MetaGymTheme.warningAmber,
              ),
              const Spacer(),
              if (amount != null)
                Text(
                  formatMembershipMoney(amount!),
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Thanh toán QR mô phỏng',
            style: TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Chế độ thử nghiệm. Không chuyển tiền thật.',
            style: TextStyle(
              color: Color(0xFFD5CCBF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SimulatedVnPayQrBox(payload: qrSeed),
          if (qrPayload case final payload?) ...[
            const SizedBox(height: 12),
            MetaGymMetricPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      payload,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Sao chép mã',
                    onPressed: () => onCopy(payload),
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: MetaGymTheme.reflectionBlue,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutOutcomeHero extends StatelessWidget {
  const _CheckoutOutcomeHero({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isSuccess = payment.status == 'SUCCESS';
    final color = membershipStatusColor(payment.status);
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(
              isSuccess ? Icons.check_rounded : Icons.receipt_long_rounded,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSuccess
                ? 'Thanh toán thành công'
                : payment.status == 'CANCELLED'
                ? 'Giao dịch đã đóng'
                : 'Thanh toán không thành công',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSuccess
                ? 'Gói tập hội viên đã được ghi nhận vào tài khoản của bạn.'
                : 'Trạng thái giao dịch hiện tại: ${payment.statusLabel}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD5CCBF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
