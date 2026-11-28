import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_checkout_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Màn hình Ưu đãi của tôi (Voucher & Dịch vụ đã đổi bằng Meta Points).
class LoyaltyMyRewardsPage extends StatefulWidget {
  const LoyaltyMyRewardsPage({super.key});

  @override
  State<LoyaltyMyRewardsPage> createState() => _LoyaltyMyRewardsPageState();
}

class _LoyaltyMyRewardsPageState extends State<LoyaltyMyRewardsPage> {
  String _statusFilter = 'ALL';
  bool _openingCheckout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _optionalLoyalty(context);
      if (ctrl != null && ctrl.redemptions.isEmpty && !ctrl.isLoading) {
        ctrl.loadAll();
      }
    });
  }

  LoyaltyController? _optionalLoyalty(BuildContext context) {
    try {
      return context.read<LoyaltyController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  MembershipController? _optionalMembership(BuildContext context) {
    try {
      return context.read<MembershipController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _openCatalog() => MetaGymNavigation.pushOnce<void>(
    context,
    MetaGymPageRoute<void>(builder: (_) => const LoyaltyRewardsPage()),
  );

  Future<void> _applyVoucherDirectly(LoyaltyRedemption item) async {
    if (_openingCheckout) return;
    final loyaltyCtrl = _optionalLoyalty(context);
    loyaltyCtrl?.selectVoucherForCheckout(item);
    final membershipCtrl = _optionalMembership(context);
    if (membershipCtrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Đã chọn "${item.title}" — sẽ tự động áp dụng khi bạn mở thanh toán gói tập.',
            ),
          ),
        );
      return;
    }

    setState(() => _openingCheckout = true);
    try {
      if (membershipCtrl.plans.isEmpty && !membershipCtrl.isLoading) {
        await membershipCtrl.load();
      }
      if (!mounted) return;
      final plans = membershipCtrl.plans;
      if (plans.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Đã chọn "${item.title}" — tự động áp dụng khi thanh toán gói tập.',
              ),
            ),
          );
        return;
      }
      final activeName = membershipCtrl.memberships.firstOrNull?.planName;
      final MembershipPlan targetPlan = plans.firstWhere(
        (p) => activeName != null && p.name == activeName,
        orElse: () => plans.first,
      );
      final quote = await membershipCtrl.quote(targetPlan);
      if (!mounted || quote == null) return;
      await MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute<void>(
          builder: (_) =>
              MembershipCheckoutPage(plan: targetPlan, quote: quote),
        ),
      );
      if (mounted) {
        await loyaltyCtrl?.refreshSummaryAndRewards();
      }
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  Future<void> _showReceptionQr(LoyaltyRedemption item) async {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isLight ? palette.surfaceSolid : const Color(0xFF1F1C1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLight
                  ? palette.borderSolid
                  : MetaGymWarmGlassTokens.cardBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isLight
                        ? palette.borderSolid
                        : MetaGymWarmGlassTokens.cardBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Đưa mã QR này cho nhân viên lễ tân hoặc Huấn luyện viên quét để kích hoạt dịch vụ.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLight
                          ? palette.borderSolid
                          : MetaGymWarmGlassTokens.cardBorder,
                    ),
                  ),
                  child: QrImageView(
                    data: 'METAGYM:LOYALTY:${item.voucherCode}',
                    size: 196,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'Mã QR sử dụng ưu đãi ${item.title}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.voucherCode,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'HSD: ${formatMembershipDate(item.expiresAt)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final controller = context.watch<LoyaltyController>();
    final all = controller.redemptions;
    final unusedCount = all.where((r) => r.status == 'UNUSED').length;
    final usedCount = all.where((r) => r.status == 'USED').length;
    final expiredCount = all.where((r) => r.status == 'EXPIRED').length;

    final filtered = _statusFilter == 'ALL'
        ? all
        : all.where((r) => r.status == _statusFilter).toList();

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
                  eyebrow: 'VÍ ƯU ĐÃI HỘI VIÊN',
                  title: 'Ưu đãi của tôi',
                  actions: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      child: TextButton(
                        onPressed: _openCatalog,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text(
                          'Đổi thêm',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: controller.isLoading && all.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: MetaGymTheme.isLightPalette(context)
                              ? palette.surfaceSolid
                              : MetaGymWarmGlassTokens.navSolidFill,
                          onRefresh: controller.loadAll,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (controller.errorMessage case final error?)
                                MembershipErrorCard(
                                  message: error,
                                  onRetry: controller.isLoading
                                      ? null
                                      : controller.loadAll,
                                ),

                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    _StatusFilterChip(
                                      label: 'Tất cả (${all.length})',
                                      selected: _statusFilter == 'ALL',
                                      onTap: () =>
                                          setState(() => _statusFilter = 'ALL'),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusFilterChip(
                                      label: 'Chưa sử dụng ($unusedCount)',
                                      selected: _statusFilter == 'UNUSED',
                                      onTap: () => setState(
                                        () => _statusFilter = 'UNUSED',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusFilterChip(
                                      label: 'Đã sử dụng ($usedCount)',
                                      selected: _statusFilter == 'USED',
                                      onTap: () => setState(
                                        () => _statusFilter = 'USED',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusFilterChip(
                                      label: 'Hết hạn ($expiredCount)',
                                      selected: _statusFilter == 'EXPIRED',
                                      onTap: () => setState(
                                        () => _statusFilter = 'EXPIRED',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (filtered.isEmpty)
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/images/mascot/meta_kong_empty.webp',
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const MetaGymSvgIcon(
                                              MetaGymIcons.paymentCouponVoucher,
                                              size: 40,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Chưa có ưu đãi nào ở mục này',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Hãy tích lũy Meta Points và quy đổi voucher giảm giá hoặc dịch vụ InBody, PT trải nghiệm.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      MembershipPrimaryButton(
                                        label: 'Khám phá Danh mục ưu đãi',
                                        compact: true,
                                        onPressed: _openCatalog,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (final item in filtered)
                                  _RedemptionCard(
                                    item: item,
                                    busy: _openingCheckout,
                                    onUseVoucher: item.canApplyAtCheckout
                                        ? () => _applyVoucherDirectly(item)
                                        : null,
                                    onShowQr:
                                        item.status == 'UNUSED' &&
                                            item.requiresStaffConfirm
                                        ? () => _showReceptionQr(item)
                                        : null,
                                  ),
                            ],
                          ),
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

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Material(
        color: selected
            ? palette.chipActiveBg
            : (isLight
                  ? palette.surfaceSolid
                  : MetaGymWarmGlassTokens.cardFill),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.7)
                : (isLight
                      ? palette.borderSolid
                      : MetaGymWarmGlassTokens.cardBorder),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? palette.chipActiveText : palette.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({
    required this.item,
    required this.busy,
    this.onUseVoucher,
    this.onShowQr,
  });

  final LoyaltyRedemption item;
  final bool busy;
  final VoidCallback? onUseVoucher;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final statusColor = switch (item.status) {
      'UNUSED' => palette.success,
      'USED' => palette.textSecondary,
      _ => palette.error,
    };

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaGymTheme.isLightPalette(context)
                      ? palette.surfaceRaised
                      : MetaGymWarmGlassTokens.metricPanelFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.isLightPalette(context)
                        ? palette.borderSolid
                        : MetaGymWarmGlassTokens.metricPanelBorder,
                  ),
                ),
                child: Text(
                  item.categoryLabel,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MembershipStatusPill(
                label: item.statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đổi ngày ${formatMembershipDate(item.redeemedAt)} · HSD: ${formatMembershipDate(item.expiresAt)}',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.requiresStaffConfirm
                    ? Icons.support_agent_rounded
                    : Icons.bolt_rounded,
                size: 16,
                color: item.status == 'UNUSED'
                    ? palette.primaryText
                    : palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.canApplyAtCheckout
                      ? 'Tự động giảm ${formatMembershipMoney(item.discountAmount)} khi thanh toán gói tập — không cần nhập mã.'
                      : item.conditionText,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onUseVoucher != null) ...[
            const SizedBox(height: 12),
            MembershipPrimaryButton(
              key: ValueKey<String>('loyalty-use-voucher-${item.id}'),
              label: busy ? 'Đang mở thanh toán...' : 'Dùng khi thanh toán gói',
              icon: Icons.bolt_rounded,
              compact: true,
              onPressed: busy ? null : onUseVoucher,
            ),
          ] else if (onShowQr != null) ...[
            const SizedBox(height: 12),
            MembershipPrimaryButton(
              key: ValueKey<String>('loyalty-show-qr-${item.id}'),
              label: 'Mở mã QR dùng tại quầy',
              icon: Icons.qr_code_2_rounded,
              compact: true,
              onPressed: onShowQr,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Mã đối chiếu: ${item.voucherCode}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 11.5,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
