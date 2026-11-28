import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_my_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_reward_detail_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:provider/provider.dart';

/// Màn hình Danh mục ưu đãi Meta Points (lọc Tất cả / Voucher / Dịch vụ).
class LoyaltyRewardsPage extends StatefulWidget {
  const LoyaltyRewardsPage({super.key});

  @override
  State<LoyaltyRewardsPage> createState() => _LoyaltyRewardsPageState();
}

class _LoyaltyRewardsPageState extends State<LoyaltyRewardsPage> {
  String _categoryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _optionalLoyalty(context);
      if (ctrl != null && ctrl.rewards.isEmpty && !ctrl.isLoading) {
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

  Future<void> _openMyRewards() => MetaGymNavigation.pushOnce<void>(
    context,
    MetaGymPageRoute<void>(builder: (_) => const LoyaltyMyRewardsPage()),
  );

  Future<void> _openRewardDetail(LoyaltyReward reward) =>
      MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute<void>(
          builder: (_) => LoyaltyRewardDetailPage(reward: reward),
        ),
      );

  String _iconForReward(LoyaltyReward reward) {
    if (reward.code.contains('pt')) return MetaGymIcons.coachPkg1on1;
    if (reward.code.contains('inbody')) return MetaGymIcons.workoutHistory;
    if (reward.code.contains('vip')) return MetaGymIcons.premiumCrown;
    if (reward.code.contains('sold')) return MetaGymIcons.paymentGift;
    return MetaGymIcons.paymentCouponVoucher;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final controller = context.watch<LoyaltyController>();
    final summary = controller.summary;
    final available = summary?.availablePoints ?? 0;
    final unusedCount = summary?.unusedRedemptionsCount ??
        controller.redemptions.where((r) => r.status == 'UNUSED').length;

    final filtered = _categoryFilter == 'ALL'
        ? controller.rewards
        : controller.rewards
              .where((r) => r.category == _categoryFilter)
              .toList();

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
                  eyebrow: 'META POINTS · ĐỔI QUÀ',
                  title: 'Danh mục ưu đãi',
                  actions: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      child: OutlinedButton(
                        key: const Key('loyalty-open-my-rewards-chip'),
                        onPressed: _openMyRewards,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          backgroundColor: palette.chipActiveBg,
                          side: BorderSide(
                            color: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          'Của tôi ($unusedCount)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: controller.isLoading && controller.rewards.isEmpty
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

                              // Khối tóm tắt Điểm khả dụng (Hero Glass Card đồng bộ các trang chính)
                              MetaGymHeroGlassCard(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: MetaGymTheme.brandOrange
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: MetaGymTheme.brandOrange
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const MetaGymSvgIcon(
                                        MetaGymIcons.streakFlame,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Điểm khả dụng',
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${formatLoyaltyPoints(available)} điểm',
                                            style: TextStyle(
                                              color: palette.primaryText,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              fontFeatures:
                                                  MetaGymTheme.tabularFigures,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Đổi ưu đãi không làm giảm điểm xét hạng',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (summary != null) ...[
                                      const SizedBox(width: 8),
                                      MembershipStatusPill(
                                        label: summary.tierLabel,
                                        color:
                                            summary.currentTierSpec.accentColor,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Bộ lọc danh mục
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    _FilterChipButton(
                                      label:
                                          'Tất cả (${controller.rewards.length})',
                                      selected: _categoryFilter == 'ALL',
                                      onTap: () => setState(
                                        () => _categoryFilter = 'ALL',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChipButton(
                                      label: 'Voucher',
                                      selected: _categoryFilter == 'VOUCHER',
                                      onTap: () => setState(
                                        () => _categoryFilter = 'VOUCHER',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterChipButton(
                                      label: 'Dịch vụ',
                                      selected: _categoryFilter == 'SERVICE',
                                      onTap: () => setState(
                                        () => _categoryFilter = 'SERVICE',
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
                                      const MetaGymSvgIcon(
                                        MetaGymIcons.paymentCouponVoucher,
                                        size: 36,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Chưa có ưu đãi nào trong mục này',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Hãy thử chuyển sang bộ lọc Tất cả hoặc tải lại danh mục.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (final reward in filtered)
                                  _RewardCatalogCard(
                                    reward: reward,
                                    availablePoints: available,
                                    iconAsset: _iconForReward(reward),
                                    onTap: () => _openRewardDetail(reward),
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
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

class _RewardCatalogCard extends StatelessWidget {
  const _RewardCatalogCard({
    required this.reward,
    required this.availablePoints,
    required this.iconAsset,
    required this.onTap,
  });

  final LoyaltyReward reward;
  final int availablePoints;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final canRedeem = reward.canRedeem(availablePoints);
    final missing = reward.missingPoints(availablePoints);

    final (statusLabel, statusColor) = reward.isOutOfStock
        ? ('Hết lượt', palette.error)
        : canRedeem
        ? ('Có thể đổi', palette.success)
        : ('Thiếu ${formatLoyaltyPoints(missing)} điểm', palette.warning);

    return MetaGymGlassCard(
      key: ValueKey<String>('loyalty-reward-${reward.code}'),
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MetaGymTheme.isLightPalette(context)
                            ? palette.surfaceRaised
                            : MetaGymWarmGlassTokens.metricPanelFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: MetaGymTheme.isLightPalette(context)
                              ? palette.borderSolid
                              : MetaGymWarmGlassTokens.metricPanelBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: MetaGymSvgIcon(iconAsset, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.isLightPalette(context)
                                      ? palette.surfaceRaised
                                      : MetaGymWarmGlassTokens.metricPanelFill,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: MetaGymTheme.isLightPalette(context)
                                        ? palette.borderSolid
                                        : MetaGymWarmGlassTokens
                                              .metricPanelBorder,
                                  ),
                                ),
                                child: Text(
                                  reward.categoryLabel,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${formatLoyaltyPoints(reward.pointsCost)} điểm',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.primaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reward.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reward.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MembershipStatusPill(
                      label: statusLabel,
                      color: statusColor,
                    ),
                    Text(
                      canRedeem ? 'Xem & đổi ›' : 'Xem chi tiết ›',
                      style: TextStyle(
                        color: canRedeem
                            ? palette.primaryText
                            : palette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
