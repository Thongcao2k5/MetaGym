import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_my_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:provider/provider.dart';

/// Màn hình Chi tiết & Xác nhận đổi ưu đãi Meta Points.
class LoyaltyRewardDetailPage extends StatefulWidget {
  const LoyaltyRewardDetailPage({required this.reward, super.key});

  final LoyaltyReward reward;

  @override
  State<LoyaltyRewardDetailPage> createState() =>
      _LoyaltyRewardDetailPageState();
}

class _LoyaltyRewardDetailPageState extends State<LoyaltyRewardDetailPage> {
  String _iconForReward(LoyaltyReward reward) {
    if (reward.code.contains('pt')) return MetaGymIcons.coachPkg1on1;
    if (reward.code.contains('inbody')) return MetaGymIcons.workoutHistory;
    if (reward.code.contains('vip')) return MetaGymIcons.premiumCrown;
    if (reward.code.contains('sold')) return MetaGymIcons.paymentGift;
    return MetaGymIcons.paymentCouponVoucher;
  }

  MembershipController? _optionalMembership(BuildContext context) {
    try {
      return context.read<MembershipController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _confirmRedeem(LoyaltyController controller) async {
    final result = await controller.redeem(widget.reward);
    if (!mounted) return;
    if (result == null) {
      final msg = controller.errorMessage ?? 'Không thể đổi ưu đãi lúc này.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final isInstantApplied = result.redemption.status == 'USED';
    final isCheckoutVoucher = result.redemption.canApplyAtCheckout;
    if (isInstantApplied) {
      await _optionalMembership(context)?.load();
      if (!mounted) return;
    }

    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final dialogBg = isLight
        ? palette.surfaceSolid
        : const Color(0xFF1F1C1A);
    final dialogBorder = isLight
        ? palette.borderSolid
        : MetaGymWarmGlassTokens.cardBorder;
    final infoMessage = isInstantApplied
        ? (result.redemption.conditionText.isNotEmpty
              ? result.redemption.conditionText
              : 'Ưu đãi đã được áp dụng thẳng vào tài khoản của bạn.')
        : isCheckoutVoucher
        ? 'Voucher giảm ${formatMembershipMoney(result.redemption.discountAmount)} đã lưu vào Ưu đãi của tôi và sẽ tự động trừ khi bạn thanh toán gói tập.'
        : 'Ưu đãi dịch vụ đã lưu vào Ưu đãi của tôi. Bạn chỉ cần mở mã QR trong ví để lễ tân hoặc Coach xác nhận tại quầy.';

    final openMyRewards = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: dialogBorder),
        ),
        title: Row(
          children: [
            const MetaGymSvgIcon(MetaGymIcons.paymentSuccess, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isInstantApplied
                    ? 'Đã áp dụng ưu đãi thành công'
                    : 'Đổi ưu đãi thành công',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bạn đã đổi "${result.redemption.title}" (-${formatLoyaltyPoints(result.redemption.pointsSpent)} điểm khả dụng).',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.success.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isInstantApplied
                        ? Icons.check_circle_rounded
                        : isCheckoutVoucher
                        ? Icons.bolt_rounded
                        : Icons.qr_code_2_rounded,
                    color: palette.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      infoMessage,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Điểm khả dụng còn lại: ${formatLoyaltyPoints(result.summary.availablePoints)} điểm · Điểm xét hạng giữ nguyên ${formatLoyaltyPoints(result.summary.tierPoints)} điểm.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.4,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Về danh mục',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            key: const Key('loyalty-success-view-my-rewards'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Xem Ưu đãi của tôi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (openMyRewards == true) {
      Navigator.of(context).pushReplacement(
        MetaGymPageRoute<void>(builder: (_) => const LoyaltyMyRewardsPage()),
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final controller = context.watch<LoyaltyController>();
    final summary = controller.summary;
    final available = summary?.availablePoints ?? 0;
    final tierPoints = summary?.tierPoints ?? 0;
    final reward = controller.rewards
            .where((r) => r.id == widget.reward.id)
            .firstOrNull ??
        widget.reward;
    final canRedeem = reward.canRedeem(available);
    final missing = reward.missingPoints(available);
    final remainingAfter = (available - reward.pointsCost).clamp(0, available);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                const MembershipTopBar(
                  eyebrow: 'XÁC NHẬN QUY ĐỔI',
                  title: 'Chi tiết ưu đãi',
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      // Hero thông tin ưu đãi
                      MetaGymHeroGlassCard(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: MetaGymTheme.brandOrange.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: MetaGymSvgIcon(
                                    _iconForReward(reward),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MembershipStatusPill(
                                        label: reward.categoryLabel,
                                        color: palette.reflection,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        reward.title,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              reward.description,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            if (reward.requiresStaffConfirm) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: palette.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.info.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: palette.info,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ưu đãi dịch vụ cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận trực tiếp tại câu lạc bộ khi sử dụng.',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Khối đối chiếu điểm trước / sau khi đổi
                      MetaGymGlassCard(
                        solid: false,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Đối chiếu điểm Meta Points',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _PointsCompareRow(
                              label: 'Điểm khả dụng hiện tại',
                              value: '${formatLoyaltyPoints(available)} điểm',
                              valueColor: palette.textPrimary,
                            ),
                            const SizedBox(height: 8),
                            _PointsCompareRow(
                              label: 'Điểm cần đổi',
                              value:
                                  '-${formatLoyaltyPoints(reward.pointsCost)} điểm',
                              valueColor: palette.primaryText,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                height: 1,
                                color: isLight
                                    ? palette.borderSolid
                                    : MetaGymWarmGlassTokens.metricPanelBorder,
                              ),
                            ),
                            _PointsCompareRow(
                              label: canRedeem
                                  ? 'Điểm khả dụng sau khi đổi'
                                  : 'Còn thiếu điểm khả dụng',
                              value: canRedeem
                                  ? '${formatLoyaltyPoints(remainingAfter)} điểm'
                                  : '${formatLoyaltyPoints(missing)} điểm',
                              valueColor: canRedeem
                                  ? palette.success
                                  : palette.error,
                              bold: true,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.success.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    size: 18,
                                    color: palette.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Điểm xét hạng (${formatLoyaltyPoints(tierPoints)} điểm) giữ nguyên, không bị giảm khi đổi ưu đãi.',
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Điều kiện sử dụng
                      MetaGymGlassCard(
                        solid: false,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điều kiện sử dụng (hạn ${reward.validDays} ngày)',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final term in reward.terms)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: palette.success,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        term,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Pinned bottom CTA dock với SafeArea
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: isLight
                        ? palette.surfaceSolid
                        : MetaGymWarmGlassTokens.navSolidFill,
                    border: Border(
                      top: BorderSide(
                        color: isLight
                            ? palette.borderSolid
                            : MetaGymWarmGlassTokens.cardBorder,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!canRedeem)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            reward.isOutOfStock
                                ? 'Ưu đãi này hiện đã hết lượt đổi.'
                                : 'Bạn cần thêm ${formatLoyaltyPoints(missing)} điểm khả dụng để quy đổi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: OutlinedButton(
                                onPressed: controller.isRedeeming
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.textPrimary,
                                  side: BorderSide(
                                    color: isLight
                                        ? palette.borderSolid
                                        : MetaGymWarmGlassTokens.cardBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Để sau',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: FilledButton(
                                key: const Key('loyalty-confirm-redeem-btn'),
                                onPressed:
                                    (!canRedeem || controller.isRedeeming)
                                    ? null
                                    : () => _confirmRedeem(controller),
                                style: FilledButton.styleFrom(
                                  backgroundColor: MetaGymTheme.brandOrange,
                                  disabledBackgroundColor: MetaGymTheme
                                      .brandOrange
                                      .withValues(alpha: 0.35),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: controller.isRedeeming
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Xác nhận đổi',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
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
        ],
      ),
    );
  }
}

class _PointsCompareRow extends StatelessWidget {
  const _PointsCompareRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? palette.textPrimary : palette.textSecondary,
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}
