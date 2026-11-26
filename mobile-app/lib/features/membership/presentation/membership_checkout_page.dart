import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/membership_tier_widgets.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class _CheckoutVoucher {
  const _CheckoutVoucher({required this.code, required this.discount});

  final String code;
  final num discount;
}

class MembershipCheckoutPage extends StatefulWidget {
  const MembershipCheckoutPage({super.key, this.plan, this.quote});

  final MembershipPlan? plan;
  final MembershipQuote? quote;

  @override
  State<MembershipCheckoutPage> createState() => _MembershipCheckoutPageState();
}

class _MembershipCheckoutPageState extends State<MembershipCheckoutPage>
    with WidgetsBindingObserver {
  late bool _reviewing = widget.quote != null;
  late final Timer _statusPoll;
  final TextEditingController _voucherController = TextEditingController();
  _CheckoutVoucher? _appliedVoucher;
  String? _voucherMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusPoll = Timer.periodic(
      const Duration(seconds: 4),
      (timer) => _refreshOnlinePaymentIfPending(
        allowZalopayQuery: timer.tick % 15 == 0,
      ),
    );
  }

  @override
  void dispose() {
    _statusPoll.cancel();
    _voucherController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applyVoucherInput() {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _appliedVoucher = null;
        _voucherMessage = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _appliedVoucher = null;
      _voucherMessage =
          'Hiện chưa có mã ưu đãi "$code" khả dụng từ máy chủ cho gói này.';
    });
  }

  void _selectVoucher(_CheckoutVoucher? voucher) {
    setState(() {
      _appliedVoucher = voucher;
      _voucherController.text = voucher?.code ?? '';
      _voucherMessage = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOnlinePaymentIfPending(reconcile: true);
    }
  }

  void _refreshOnlinePaymentIfPending({
    bool reconcile = false,
    bool allowZalopayQuery = false,
  }) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final controller = context.read<MembershipController>();
    final method = controller.pendingPayment?.method;
    if (['ZALOPAY', 'MOMO', 'VNPAY'].contains(method)) {
      unawaited(
        controller.refreshPayment(
          reconcile: reconcile || (allowZalopayQuery && method == 'ZALOPAY'),
        ),
      );
    }
  }

  Uri? _paymentCheckoutUri(Payment payment) {
    final url = Uri.tryParse(payment.paymentUrl ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        url.port != 443 ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    final validCheckout = switch (payment.method) {
      'ZALOPAY' => [
        'qcgateway.zalopay.vn',
        'sbgateway.zalopay.vn',
      ].contains(url.host),
      'MOMO' =>
        url.host == 'test-payment.momo.vn' &&
            (url.path == '/v2/gateway/pay' ||
                url.path == '/gateway/pay' ||
                url.path.startsWith('/gw_payment/')),
      'VNPAY' =>
        url.host == 'sandbox.vnpayment.vn' &&
            url.path == '/paymentv2/vpcpay.html',
      _ => false,
    };
    return validCheckout ? url : null;
  }

  Future<void> _openOnlinePayment(Payment payment) async {
    if (payment.method == 'ZALOPAY') return;
    final url = _paymentCheckoutUri(payment);
    if (url != null) {
      try {
        if (await launchUrl(
          url,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
          webOnlyWindowName: payment.method == 'ZALOPAY' ? '_blank' : '_self',
        )) {
          return;
        }
      } catch (_) {
        // Keep the order recoverable and let the member try opening it again.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chưa mở được ${formatPaymentMethodLabel(payment.method)}. Hãy kiểm tra trạng thái rồi thử lại.',
        ),
      ),
    );
  }

  Future<void> _copyText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel(MembershipController controller) async {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final confirmed = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isLight
            ? palette.surfaceSolid
            : const Color(0xFF1F1C1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLight ? palette.borderSolid : const Color(0x66A79D92),
          ),
        ),
        title: Text(
          'Hủy giao dịch này?',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Bạn có thể chọn gói và tạo giao dịch mới sau đó.',
          style: TextStyle(color: palette.textWarmMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Giữ giao dịch',
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hủy giao dịch',
              style: TextStyle(
                color: palette.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await controller.cancelPayment();
  }

  Widget _info(String label, String value, {Widget? trailing}) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.textSecondary, fontSize: 13.5),
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
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
  }

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
    final succeeded = !reviewing && payment?.status == 'SUCCESS';
    final checkoutUri = payment == null ? null : _paymentCheckoutUri(payment);
    final mock =
        payment?.method == 'MOCK_QR' ||
        (payment?.method == 'VNPAY' && checkoutUri == null);
    final online =
        !mock && ['ZALOPAY', 'MOMO', 'VNPAY'].contains(payment?.method);
    final title = reviewing
        ? 'Thanh toán gói tập'
        : pending
        ? 'Thanh toán VNPay'
        : 'Kết quả giao dịch';
    final eyebrow = reviewing ? 'XÁC NHẬN ĐƠN HÀNG' : 'THANH TOÁN HỘI VIÊN';
    final step = reviewing
        ? 1
        : pending
        ? 2
        : 3;
    final rawAmount = reviewing ? quote.price : payment?.amount;
    final discount = reviewing && _appliedVoucher != null && rawAmount != null
        ? (_appliedVoucher!.discount > rawAmount
              ? rawAmount
              : _appliedVoucher!.discount)
        : 0;
    final payableAmount = rawAmount == null
        ? null
        : (rawAmount - discount).clamp(0, rawAmount);
    final tierInfo = plan != null
        ? resolveMembershipTierInfo(
            planName: plan.name,
            durationDays: plan.durationDays,
          )
        : null;

    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                MembershipTopBar(
                  eyebrow: eyebrow,
                  title: title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      reviewing ? 24 : 36,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!reviewing) ...[
                          _CheckoutStepper(step: step),
                          const SizedBox(height: 12),
                        ],
                        if (controller.errorMessage case final message?)
                          MembershipErrorCard(message: message),

                        // KẾT QUẢ BƯỚC 3
                        if (!reviewing && !pending && payment != null)
                          _CheckoutOutcomeHero(payment: payment),

                        if (!reviewing && pending) ...[
                          if (online && payment != null) ...[
                            if (payment.method == 'ZALOPAY' &&
                                checkoutUri != null)
                              _ZalopayQrCard(data: payment.paymentUrl!)
                            else
                              MetaGymGlassCard(
                                solid: false,
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  checkoutUri == null
                                      ? 'Chưa có liên kết thanh toán. Hãy bấm Kiểm tra trạng thái để thử lại.'
                                      : 'Đang chờ ${formatPaymentMethodLabel(payment.method)} xác nhận. Sau khi thanh toán, quay lại MetaGym để xem kết quả.',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                            if (checkoutUri != null &&
                                payment.method != 'ZALOPAY') ...[
                              const SizedBox(height: 10),
                              MembershipPrimaryButton(
                                label:
                                    'Mở lại ${formatPaymentMethodLabel(payment.method)}',
                                icon: Icons.open_in_new_rounded,
                                onPressed: () => _openOnlinePayment(payment),
                              ),
                            ],
                          ],
                          if (mock) ...[
                            _VnPaySandboxQrCard(
                              qrSeed:
                                  payment?.qrPayload ??
                                  payment?.transactionCode ??
                                  'VNPAY-METAGYM',
                              qrPayload: payment?.qrPayload,
                              amount: payableAmount,
                              onCopy: (text) =>
                                  _copyText(text, 'Đã sao chép mã giao dịch.'),
                            ),
                            const SizedBox(height: 10),
                            MembershipPrimaryButton(
                              label: 'Mô phỏng thanh toán thành công',
                              icon: Icons.verified_rounded,
                              onPressed: busy
                                  ? null
                                  : controller.confirmPayment,
                            ),
                          ],
                          if (controller.checkoutService != null) ...[
                            const SizedBox(height: 8),
                            _RefreshStatusButton(
                              busy: busy,
                              onPressed: () =>
                                  controller.refreshPayment(reconcile: online),
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
                                        foregroundColor: palette.reflection,
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
                                        foregroundColor: palette.error,
                                      ),
                                      child: const Text('Hủy giao dịch'),
                                    ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],

                      // === BƯỚC 1: 1.2c THANH TOÁN GÓI TẬP ===
                      if (reviewing) ...[
                        // 1. Tóm tắt gói đã chọn + thẻ NFC thu nhỏ
                        MetaGymGlassCard(
                          solid: false,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x73000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  tierInfo!.horizontalCardAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF1F232C),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.credit_card_rounded,
                                      color: MetaGymTheme.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            plan.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: MetaGymTheme.brandOrange
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: MetaGymTheme.brandOrange
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: Text(
                                            'NFC',
                                            style: TextStyle(
                                              color: palette.primaryText,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Hiệu lực: ${formatMembershipDate(quote.startDate)} → ${formatMembershipDate(quote.endDate)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11.5,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 1.5,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: palette.success,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${tierInfo.inBodyLabel} · Coach 1:1 ${tierInfo.coachDiscountLabel}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.success,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. Card Mã ưu đãi (Voucher) thiết kế lại dạng vé cao cấp
                        _LuxuryPromoCodeCard(
                          controller: _voucherController,
                          appliedVoucher: _appliedVoucher,
                          message: _voucherMessage,
                          onApplyInput: _applyVoucherInput,
                          onSelectVoucher: _selectVoucher,
                        ),

                        // 3. Phương thức thanh toán (tạm thời chỉ hiển thị VNPay)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Phương thức thanh toán',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '1 cổng hỗ trợ',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? palette.surfaceSolid
                                : const Color(0xD0322722),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: MetaGymTheme.brandOrange.withValues(
                                alpha: 0.72,
                              ),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF005BAA),
                                      Color(0xFFE11D48),
                                    ],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'VNPay',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VNPay QR / Thẻ nội địa',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Hỗ trợ 35+ ứng dụng ngân hàng Việt Nam',
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: MetaGymTheme.brandOrange,
                                    width: 5.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. Chi tiết thanh toán (phong cách Shopee: thẳng hàng trái-phải sắc nét)
                        MetaGymGlassCard(
                          solid: false,
                          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Chi tiết thanh toán',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SummaryPriceRow(
                                label: 'Tổng tiền gói tập',
                                value: formatMembershipMoney(quote.price),
                              ),
                              if (!quote.isRenewal)
                                _SummaryPriceRow(
                                  label: 'Bắt đầu dự kiến',
                                  value: formatMembershipDate(quote.startDate),
                                ),
                              _SummaryPriceRow(
                                label: quote.isRenewal
                                    ? 'Hạn mới dự kiến'
                                    : 'Hết hạn dự kiến',
                                value: formatMembershipDate(quote.endDate),
                              ),
                              if (_appliedVoucher != null && discount > 0)
                                _SummaryPriceRow(
                                  label: 'Ưu đãi mã ${_appliedVoucher!.code}',
                                  value: '-${formatMembershipMoney(discount)}',
                                  valueColor: palette.primaryText,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: isLight
                                      ? palette.borderSolid
                                      : const Color(0x2EFFF6EA),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tổng thanh toán',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formatMembershipMoney(
                                          payableAmount ?? 0,
                                        ),
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                          child: Text(
                            'Nhấn "Thanh toán" đồng nghĩa với việc bạn đồng ý tuân theo Điều khoản sử dụng của Meta Gym.',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ] else ...[
                          // KHỐI THÔNG TIN GIAO DỊCH (BƯỚC 2 & 3)
                          MetaGymGlassCard(
                            solid: false,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (payment != null) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Thông tin giao dịch',
                                          style: TextStyle(
                                            color: palette.textPrimary,
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
                                        child: MetaGymTap(
                                          onTap: () => _copyText(
                                            code,
                                            'Đã sao chép mã giao dịch.',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 17,
                                              color: palette.reflection,
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
                                      formatMembershipDate(
                                        membership.startDate,
                                      ),
                                    ),
                                    _info(
                                      'Hết hạn',
                                      formatMembershipDate(membership.endDate),
                                    ),
                                  ],
                                ] else
                                  Text(
                                    'Không tìm thấy giao dịch.',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                if (payableAmount != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: isLight
                                          ? palette.borderSolid
                                          : const Color(0x30FFF6EA),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        pending ? 'Tổng thanh toán' : 'Số tiền',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        formatMembershipMoney(payableAmount),
                                        style: TextStyle(
                                          color: palette.primaryText,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!pending && !succeeded)
                            MembershipPrimaryButton(
                              label: 'Về Gói tập',
                              icon: Icons.check_rounded,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                // BOTTOM CHECKOUT BAR: CTA toàn chiều rộng khớp 1.2c (chỉ VNPay thật)
                if (reviewing)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: BoxDecoration(
                      color: isLight
                          ? palette.surfaceSolid.withValues(alpha: 0.96)
                          : const Color(0xF215181F),
                      border: Border(
                        top: BorderSide(
                          color: isLight
                              ? palette.borderSolid
                              : const Color(0x2EFFF6EA),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: const Key('checkout-pay-submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          disabledBackgroundColor: MetaGymTheme.brandOrange
                              .withValues(alpha: 0.45),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: busy
                            ? null
                            : () async {
                                if (await controller.buy(plan) && mounted) {
                                  setState(() => _reviewing = false);
                                  final order = controller.pendingPayment;
                                  if (order?.paymentUrl != null &&
                                      order?.method != 'ZALOPAY') {
                                    await _openOnlinePayment(order!);
                                  }
                                }
                              },
                        child: Text(
                          busy
                              ? 'Đang xử lý…'
                              : 'Thanh toán ${formatMembershipMoney(payableAmount ?? 0)} · VNPay',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (succeeded) const _SuccessfulCheckoutReturn(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng hiển thị nhãn trái – giá trị phải gọn gàng cho Chi tiết thanh toán.
class _SummaryPriceRow extends StatelessWidget {
  const _SummaryPriceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? palette.textPrimary,
              fontSize: 13.5,
              fontWeight: valueColor != null
                  ? FontWeight.w700
                  : FontWeight.w600,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card Mã ưu đãi (Voucher) tinh gọn: chỉ nhập mã & bấm Áp dụng.
class _LuxuryPromoCodeCard extends StatelessWidget {
  const _LuxuryPromoCodeCard({
    required this.controller,
    required this.appliedVoucher,
    required this.message,
    required this.onApplyInput,
    required this.onSelectVoucher,
  });

  final TextEditingController controller;
  final _CheckoutVoucher? appliedVoucher;
  final String? message;
  final VoidCallback onApplyInput;
  final ValueChanged<_CheckoutVoucher?> onSelectVoucher;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final hasVoucher = appliedVoucher != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isLight ? palette.surfaceSolid : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xD6362A23), Color(0xC826211D)],
              ),
        border: Border.all(
          color: hasVoucher
              ? (isLight
                    ? MetaGymTheme.brandOrange.withValues(alpha: 0.65)
                    : const Color(0x88FF8A5B))
              : palette.warmGlassBorder,
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x140F172A)
                : const Color(0x4D000000),
            blurRadius: isLight ? 14 : 20,
            offset: Offset(0, isLight ? 4 : 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x3DFF5E36), Color(0x22F5B041)],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x55FF5E36)),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymSvgIcon(
                    MetaGymIcons.premiumCrown,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã ưu đãi',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Nhập mã giảm giá để áp dụng ưu đãi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Thanh nhập mã liền mạch + nút Áp dụng nổi bật
            Container(
              height: 42,
              padding: const EdgeInsets.only(left: 11, right: 4),
              decoration: BoxDecoration(
                color: isLight
                    ? palette.surfaceRaised
                    : const Color(0xAA14161C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLight
                      ? palette.borderSolid
                      : const Color(0x45FFF6EA),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: MetaGymTheme.brandOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã ưu đãi...',
                        hintStyle: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => onApplyInput(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: onApplyInput,
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (message != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(
                        color: hasVoucher ? palette.success : palette.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasVoucher)
                    GestureDetector(
                      onTap: () => onSelectVoucher(null),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Gỡ mã',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessfulCheckoutReturn extends StatefulWidget {
  const _SuccessfulCheckoutReturn();

  @override
  State<_SuccessfulCheckoutReturn> createState() =>
      _SuccessfulCheckoutReturnState();
}

class _SuccessfulCheckoutReturnState extends State<_SuccessfulCheckoutReturn> {
  late final Timer _timer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (10 - timer.tick).clamp(0, 10);
      if (_secondsLeft != remaining) {
        setState(() => _secondsLeft = remaining);
      }
      if (remaining == 0) _returnToMembership();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _returnToMembership() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _timer.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _secondsLeft > 0
              ? 'Tự động về Gói tập sau $_secondsLeft giây'
              : 'Đang về Gói tập…',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaGymTheme.paletteOf(context).textSecondary,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        MembershipPrimaryButton(
          label: 'Về Gói tập',
          icon: Icons.check_rounded,
          onPressed: _returnToMembership,
        ),
      ],
    ),
  );
}

class _RefreshStatusButton extends StatelessWidget {
  const _RefreshStatusButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0x902B2622),
          side: BorderSide(
            color: isLight ? palette.borderSolid : const Color(0x8CA79D92),
          ),
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
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
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
                            ? palette.success
                            : (isLight
                                  ? const Color(0xFFDCE4EE)
                                  : const Color(0x38FFFFFF)),
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
                              style: TextStyle(
                                color: step == index + 1
                                    ? Colors.white
                                    : (isLight
                                          ? palette.textSecondary
                                          : Colors.white),
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
                            ? palette.primaryText
                            : step > index + 1
                            ? palette.success
                            : palette.textSecondary,
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
                        ? palette.success
                        : (isLight
                              ? const Color(0xFFDCE4EE)
                              : const Color(0x33FFFFFF)),
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

class _ZalopayQrCard extends StatelessWidget {
  const _ZalopayQrCard({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Mã QR ZaloPay Sandbox',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: data,
            size: 224,
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.white,
            semanticsLabel: 'Mã QR thanh toán thử nghiệm ZaloPay',
          ),
          const SizedBox(height: 12),
          Text(
            'Mở ví ZaloPay Sandbox trên điện thoại khác và quét mã này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textPrimary),
          ),
        ],
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
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MembershipStatusPill(
                label: 'VNPAY-QR',
                color: palette.info,
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(width: 8),
              MembershipStatusPill(
                label: 'Giả lập Sandbox',
                color: palette.warning,
              ),
              const Spacer(),
              if (amount != null)
                Text(
                  formatMembershipMoney(amount!),
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thanh toán QR mô phỏng',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chế độ thử nghiệm. Không chuyển tiền thật.',
            style: TextStyle(color: palette.textWarmMuted, fontSize: 12),
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
                      style: TextStyle(
                        color: palette.textPrimary,
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
                    icon: Icon(
                      Icons.copy_rounded,
                      color: palette.reflection,
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
            style: TextStyle(
              color: MetaGymTheme.paletteOf(context).textWarmMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
