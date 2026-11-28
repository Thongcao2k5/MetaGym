import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';

enum MembershipTierKind { bronze, silver, gold, diamond }

class MembershipTierInfo {
  const MembershipTierInfo({
    required this.kind,
    required this.tierLabel,
    required this.verticalCardAsset,
    required this.horizontalCardAsset,
    required this.borderColor,
    required this.accentColor,
    required this.summaryPerks,
    required this.coachDiscountLabel,
    required this.inBodyLabel,
    required this.pointsMultiplierLabel,
    required this.nextTierLabel,
    required this.nextTierTargetPoints,
  });

  final MembershipTierKind kind;
  final String tierLabel;
  final String verticalCardAsset;
  final String horizontalCardAsset;
  final Color borderColor;
  final Color accentColor;
  final String summaryPerks;
  final String coachDiscountLabel;
  final String inBodyLabel;
  final String pointsMultiplierLabel;
  final String? nextTierLabel;
  final int nextTierTargetPoints;
}

MembershipTierInfo resolveMembershipTierInfo({
  String? planName,
  int? durationDays,
}) {
  final lower = (planName ?? '').toLowerCase();
  if (lower.contains('kim cương') ||
      lower.contains('diamond') ||
      (durationDays != null && durationDays >= 300)) {
    return const MembershipTierInfo(
      kind: MembershipTierKind.diamond,
      tierLabel: 'Hạng Kim Cương',
      verticalCardAsset: 'assets/images/membership/card_diamond.jpg',
      horizontalCardAsset:
          'assets/images/membership/card_diamond_horizontal.jpg',
      borderColor: Color(0x8C70AEE8),
      accentColor: MetaGymTheme.reflectionBlue,
      summaryPerks:
          'Quẹt thẻ Kim Cương NFC · InBody không giới hạn · Tặng 6 buổi PT 1:1',
      coachDiscountLabel: '-10%',
      inBodyLabel: 'Không giới hạn',
      pointsMultiplierLabel: '×2.0 điểm',
      nextTierLabel: null,
      nextTierTargetPoints: 2000,
    );
  }
  if (lower.contains('vàng') ||
      lower.contains('gold') ||
      lower.contains('pro') ||
      (durationDays != null && durationDays >= 150)) {
    return const MembershipTierInfo(
      kind: MembershipTierKind.gold,
      tierLabel: 'Hạng Vàng',
      verticalCardAsset: 'assets/images/membership/card_gold.jpg',
      horizontalCardAsset: 'assets/images/membership/card_gold_horizontal.jpg',
      borderColor: Color(0x8CDAB066),
      accentColor: Color(0xFFF5B041),
      summaryPerks:
          'Quẹt thẻ NFC vào phòng tập · InBody hàng tháng · Tặng 2 buổi PT 1:1',
      coachDiscountLabel: '-5%',
      inBodyLabel: 'Miễn phí / tháng',
      pointsMultiplierLabel: '×1.5 điểm',
      nextTierLabel: 'Hạng Kim Cương',
      nextTierTargetPoints: 2000,
    );
  }
  if (lower.contains('bạc') ||
      lower.contains('silver') ||
      lower.contains('plus') ||
      (durationDays != null && durationDays >= 60)) {
    return const MembershipTierInfo(
      kind: MembershipTierKind.silver,
      tierLabel: 'Hạng Bạc',
      verticalCardAsset: 'assets/images/membership/card_silver.jpg',
      horizontalCardAsset:
          'assets/images/membership/card_silver_horizontal.jpg',
      borderColor: Color(0x6BC4CCDA),
      accentColor: Color(0xFFC4CCDA),
      summaryPerks:
          'Quẹt thẻ Bạc NFC · Tập full khung giờ · 1 lần đo InBody & tư vấn lộ trình',
      coachDiscountLabel: '-3%',
      inBodyLabel: '1 lần / quý',
      pointsMultiplierLabel: '×1.2 điểm',
      nextTierLabel: 'Hạng Vàng',
      nextTierTargetPoints: 1500,
    );
  }
  return const MembershipTierInfo(
    kind: MembershipTierKind.bronze,
    tierLabel: 'Hạng Đồng',
    verticalCardAsset: 'assets/images/membership/card_bronze.jpg',
    horizontalCardAsset: 'assets/images/membership/card_bronze_horizontal.jpg',
    borderColor: Color(0x73D29162),
    accentColor: Color(0xFFD29162),
    summaryPerks:
        'Quẹt thẻ Đồng NFC · Tập không giới hạn khu máy, Cardio & tủ Locker cá nhân',
    coachDiscountLabel: '0%',
    inBodyLabel: 'Trả phí lẻ',
    pointsMultiplierLabel: '×1.0 điểm',
    nextTierLabel: 'Hạng Bạc',
    nextTierTargetPoints: 800,
  );
}

/// Khối 1: Thẻ kim loại ngang CR80 lật 3D vật lý (Mặt sau <-> Mặt trước 1426:900) + thẻ thông tin gói.
class ActiveMembershipNfcSection extends StatelessWidget {
  const ActiveMembershipNfcSection({
    required this.membership,
    required this.memberName,
    required this.now,
    required this.busy,
    required this.onRenew,
    this.onRedeemPoints,
    this.tierOverride,
    super.key,
  });

  final Membership membership;
  final String memberName;
  final DateTime now;
  final bool busy;
  final VoidCallback? onRenew;
  final VoidCallback? onRedeemPoints;
  final MembershipTierInfo? tierOverride;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final tier =
        tierOverride ?? resolveMembershipTierInfo(planName: membership.planName);
    final remaining = membership.remainingDays(now);
    final dateRange =
        '${formatMembershipDate(membership.startDate)} → '
        '${formatMembershipDate(membership.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FlippableActiveMembershipCard(tier: tier),

        // Thẻ tóm tắt gói tập đang dùng & nút Gia hạn
        MetaGymGlassCard(
          solid: false,
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.planName ?? membership.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          memberName.isNotEmpty
                              ? '$dateRange\n$memberName'
                              : dateRange,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      child: Text(
                        'Còn $remaining ngày',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tier.summaryPerks,
                style: TextStyle(
                  color: palette.textWarmMuted,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: busy ? null : onRenew,
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.brandOrange,
                          disabledBackgroundColor: MetaGymTheme.brandOrange
                              .withValues(alpha: 0.45),
                          foregroundColor: Colors.white,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Gia hạn thẻ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onRedeemPoints != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: onRedeemPoints,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            backgroundColor: palette.metricPanelBg,
                            side: BorderSide(
                              color: palette.metricPanelBorder,
                              width: 1,
                            ),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Đổi điểm ưu đãi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Khối 2: Ví điểm Meta Points (tách Điểm khả dụng & Điểm xét hạng) + lối vào Ưu đãi.
class MetaPointsWalletCard extends StatelessWidget {
  const MetaPointsWalletCard({
    required this.points,
    required this.tier,
    required this.onRedeemTap,
    this.tierPoints,
    this.remainingToNextTier,
    this.progressFraction,
    this.unusedRedemptionsCount = 0,
    this.onMyRewardsTap,
    this.onTierInfoTap,
    super.key,
  });

  final int points;
  final int? tierPoints;
  final int? remainingToNextTier;
  final double? progressFraction;
  final int unusedRedemptionsCount;
  final MembershipTierInfo tier;
  final VoidCallback onRedeemTap;
  final VoidCallback? onMyRewardsTap;
  final VoidCallback? onTierInfoTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final effectiveTierPoints = tierPoints ?? points;
    final target = tier.nextTierTargetPoints;
    final computedProgress =
        progressFraction ?? (effectiveTierPoints / target).clamp(0.06, 1.0);
    final remaining =
        remainingToNextTier ?? (target - effectiveTierPoints).clamp(0, target);
    final progressText = tier.nextTierLabel == null
        ? 'Đã đạt hạng cao nhất · Tích điểm đổi quà VIP'
        : remaining == 0
        ? 'Đủ điểm nâng lên ${tier.nextTierLabel}'
        : 'Còn ${_formatPts(remaining)} điểm lên ${tier.nextTierLabel}';

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MetaGymSvgIcon(
                MetaGymIcons.streakFlame,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Meta Points',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                key: const Key('loyalty-tier-info-pill'),
                borderRadius: BorderRadius.circular(999),
                onTap: onTierInfoTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tier.accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: tier.accentColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    onTierInfoTap != null
                        ? '${tier.tierLabel} ›'
                        : tier.tierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tier.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 2 cột tách bạch: Điểm khả dụng vs Điểm xét hạng
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.metricPanelBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.metricPanelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Điểm khả dụng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatPts(points)} điểm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Dùng để đổi ưu đãi',
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.metricPanelBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.metricPanelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Điểm xét hạng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatPts(effectiveTierPoints)} điểm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Không giảm khi đổi quà',
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: computedProgress.clamp(0.05, 1.0),
              minHeight: 5,
              backgroundColor: palette.borderSolid.withValues(alpha: 0.55),
              valueColor: const AlwaysStoppedAnimation<Color>(
                MetaGymTheme.brandOrange,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            progressText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('membership-redeem-rewards-btn'),
                    onPressed: onRedeemTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đổi ưu đãi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onMyRewardsTap != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      key: const Key('membership-my-rewards-btn'),
                      onPressed: onMyRewardsTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        backgroundColor: palette.metricPanelBg,
                        side: BorderSide(color: palette.metricPanelBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        unusedRedemptionsCount > 0
                            ? 'Ưu đãi ($unusedRedemptionsCount)'
                            : 'Ưu đãi của tôi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal xem nhanh 4 Hạng thành viên & Ngưỡng điểm xét hạng (không cần trang riêng trùng lặp).
Future<void> showLoyaltyTiersSheet(
  BuildContext context, {
  required LoyaltySummary summary,
}) {
  final palette = MetaGymTheme.paletteOf(context);
  final isLight = MetaGymTheme.isLightPalette(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: isLight ? palette.surfaceSolid : const Color(0xFF1F1C1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? palette.borderSolid
                : MetaGymWarmGlassTokens.cardBorder,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '4 Hạng thành viên Meta Gym',
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
                    icon: Icon(Icons.close_rounded, color: palette.textPrimary),
                  ),
                ],
              ),
              Text(
                'Hạng được xét theo Điểm xét hạng tích lũy (${_formatPts(summary.tierPoints)} điểm). Đổi ưu đãi không làm giảm Điểm xét hạng.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              const SizedBox(height: 12),
              for (final spec in summary.tiers) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: spec.code == summary.tier
                        ? spec.accentColor.withValues(alpha: 0.12)
                        : palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: spec.code == summary.tier
                          ? spec.accentColor.withValues(alpha: 0.65)
                          : palette.borderSolid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.tierLabel,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Từ ${_formatPts(spec.minPoints)} điểm · Coach ${spec.coachDiscountPercent > 0 ? '-${spec.coachDiscountPercent}%' : '0%'} · ×${spec.pointsMultiplier.toStringAsFixed(1)} điểm',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MembershipStatusPill(
                        label: spec.code == summary.tier
                            ? 'Hiện tại'
                            : summary.tierPoints >= spec.minPoints
                            ? 'Đã đạt'
                            : 'Chưa đạt',
                        color: spec.code == summary.tier
                            ? spec.accentColor
                            : summary.tierPoints >= spec.minPoints
                            ? palette.success
                            : palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Khối 3: Ưu đãi đặc quyền theo hạng thẻ đang áp dụng.
class ActiveTierPerksCard extends StatelessWidget {
  const ActiveTierPerksCard({required this.tier, super.key});

  final MembershipTierInfo tier;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ưu đãi ${tier.tierLabel} đang áp dụng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: MetaGymTheme.progressGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.progressGreen.withValues(alpha: 0.42),
                  ),
                ),
                child: const Text(
                  '3 đặc quyền',
                  style: TextStyle(
                    color: MetaGymTheme.progressGreen,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _PerkLine(
            label: 'Giảm tự động phí Gói Coach 1:1',
            value: tier.coachDiscountLabel,
            valueColor: MetaGymTheme.brandOrange,
          ),
          const SizedBox(height: 4),
          _PerkLine(
            label: 'Đo chỉ số InBody chuyên sâu',
            value: tier.inBodyLabel,
            valueColor: MetaGymTheme.progressGreen,
          ),
          const SizedBox(height: 4),
          _PerkLine(
            label: 'Tích điểm Check-in & Gia hạn',
            value: tier.pointsMultiplierLabel,
            valueColor: MetaGymTheme.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _PerkLine extends StatelessWidget {
  const _PerkLine({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_rounded,
          size: 14,
          color: MetaGymTheme.progressGreen,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE0D9CE),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}

String _formatPts(int points) {
  final raw = points.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

class _FlippableActiveMembershipCard extends StatefulWidget {
  const _FlippableActiveMembershipCard({required this.tier});

  final MembershipTierInfo tier;

  @override
  State<_FlippableActiveMembershipCard> createState() =>
      _FlippableActiveMembershipCardState();
}

class _FlippableActiveMembershipCardState
    extends State<_FlippableActiveMembershipCard>
    with TickerProviderStateMixin {
  static const SpringDescription _kFlipSpring = SpringDescription(
    mass: 1.0,
    stiffness: 185.0,
    damping: 20.0,
  );

  late final AnimationController _angleController =
      AnimationController.unbounded(vsync: this, value: 0.0);
  late final AnimationController _releaseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _releaseCurve = CurvedAnimation(
    parent: _releaseController,
    curve: Curves.easeOutCubic,
  );

  int _dragStartHalf = 0;
  int _lastCrossedHalf = 0;
  bool _pointerHeld = false;
  double _tiltX = 0.0;
  double _pressLift = 0.0;
  double _releaseFromTiltX = 0.0;
  double _releaseFromLift = 0.0;

  bool get _animationsDisabled =>
      MetaGymTheme.isFlutterTestEnvironment ||
      MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCardFaces();
  }

  @override
  void didUpdateWidget(covariant _FlippableActiveMembershipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier.kind != widget.tier.kind) {
      _precacheCardFaces();
    }
  }

  void _precacheCardFaces() {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    precacheImage(AssetImage(widget.tier.horizontalCardAsset), context);
    precacheImage(AssetImage(widget.tier.verticalCardAsset), context);
  }

  @override
  void dispose() {
    _angleController.dispose();
    _releaseController.dispose();
    super.dispose();
  }

  void _animateToHalf(int targetHalf, {double velocityRad = 0.0}) {
    final targetAngle = targetHalf * math.pi;
    if (_animationsDisabled) {
      _angleController.stop();
      _angleController.value = targetAngle;
      return;
    }
    final simulation = SpringSimulation(
      _kFlipSpring,
      _angleController.value,
      targetAngle,
      velocityRad,
    );
    _angleController.animateWith(simulation);
  }

  void _handlePointerTilt(Offset localPosition, Size cardSize) {
    final normalizedY = ((localPosition.dy / cardSize.height) - 0.5) * 2.0;
    _tiltX = (-normalizedY * 0.09).clamp(-0.09, 0.09);
    _pressLift = 1.0;
    _pointerHeld = true;
    _releaseController.stop();
    // Triggers repaint only when subtle touch tilt changes
    if (mounted) setState(() {});
  }

  void _releasePointerTilt() {
    if (!_pointerHeld) return;
    _pointerHeld = false;
    _releaseFromTiltX = _tiltX;
    _releaseFromLift = _pressLift;
    if (_animationsDisabled) {
      _tiltX = 0.0;
      _pressLift = 0.0;
      return;
    }
    _releaseController.forward(from: 0.0);
  }

  Widget _cardFallback() => Container(
    color: const Color(0xFF1F232C),
    alignment: Alignment.center,
    child: const Icon(
      Icons.credit_card_rounded,
      color: MetaGymTheme.textSecondary,
      size: 42,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 340.0;
          final cardHeight = cardWidth / (1426 / 900);
          final cardSize = Size(cardWidth, cardHeight);

          return AnimatedBuilder(
            animation: Listenable.merge([_angleController, _releaseController]),
            builder: (context, _) {
              final angle = _angleController.value;
              final cosA = math.cos(angle);
              final sinA = math.sin(angle);
              final isFrontFace = cosA < 0;
              final edgeFactor = sinA.abs();

              final activeTiltX = _pointerHeld
                  ? _tiltX
                  : _releaseFromTiltX * (1.0 - _releaseCurve.value);
              final activePressLift = _pointerHeld
                  ? _pressLift
                  : _releaseFromLift * (1.0 - _releaseCurve.value);

              final liftScale =
                  1.0 + edgeFactor * 0.026 + activePressLift * 0.014;
              final badgeOpacity = ((cosA.abs() - 0.18) / 0.82).clamp(0.0, 1.0);
              final rimColor = Color.lerp(
                tier.borderColor.withValues(alpha: 0.48),
                tier.accentColor.withValues(alpha: 0.88),
                edgeFactor,
              )!;
              final sheenAlpha =
                  (0.04 + edgeFactor * 0.24 + activePressLift * 0.06).clamp(
                    0.0,
                    0.34,
                  );
              final sweep = sinA * 1.15;
              final sheenTint = Color.lerp(
                Colors.white,
                tier.accentColor,
                0.28,
              )!;

              final faceImage = isFrontFace
                  ? RotatedBox(
                      quarterTurns: 3,
                      child: Image.asset(
                        tier.verticalCardAsset,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => _cardFallback(),
                      ),
                    )
                  : Image.asset(
                      tier.horizontalCardAsset,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => _cardFallback(),
                    );

              final orientedFace = isFrontFace
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: faceImage,
                    )
                  : faceImage;

              final cardBody = Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: rimColor,
                    width: 1.0 + edgeFactor * 0.45,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x96000000),
                      blurRadius: 24 + edgeFactor * 14,
                      offset: Offset(-sinA * 14, 12 + edgeFactor * 8),
                    ),
                    BoxShadow(
                      color: tier.accentColor.withValues(
                        alpha: 0.08 + edgeFactor * 0.14,
                      ),
                      blurRadius: 22 + edgeFactor * 12,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      orientedFace,
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(
                                -0.9 + sweep,
                                -0.8 - activeTiltX * 2.5,
                              ),
                              end: Alignment(
                                0.9 + sweep,
                                0.8 + activeTiltX * 2.5,
                              ),
                              colors: [
                                Colors.transparent,
                                sheenTint.withValues(alpha: sheenAlpha),
                                Colors.transparent,
                              ],
                              stops: const [0.16, 0.50, 0.84],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Semantics(
                button: true,
                label: isFrontFace
                    ? 'Thẻ hội viên mặt trước, chạm hoặc vuốt để lật sang mặt sau'
                    : 'Thẻ hội viên mặt sau, chạm hoặc vuốt để lật sang mặt trước',
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) =>
                      _handlePointerTilt(e.localPosition, cardSize),
                  onPointerMove: (e) =>
                      _handlePointerTilt(e.localPosition, cardSize),
                  onPointerUp: (_) => _releasePointerTilt(),
                  onPointerCancel: (_) => _releasePointerTilt(),
                  child: GestureDetector(
                    key: const Key('active-membership-flip-card'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final dir =
                          details.localPosition.dx >= cardWidth / 2 ? 1 : -1;
                      if (!_animationsDisabled) {
                        HapticFeedback.lightImpact();
                      }
                      final currentHalf =
                          (_angleController.value / math.pi).round();
                      _animateToHalf(
                        currentHalf + dir,
                        velocityRad: dir * 6.2,
                      );
                    },
                    onHorizontalDragStart: (_) {
                      _angleController.stop();
                      _dragStartHalf =
                          (_angleController.value / math.pi).round();
                      _lastCrossedHalf =
                          ((_angleController.value + math.pi / 2) / math.pi)
                              .floor();
                    },
                    onHorizontalDragUpdate: (details) {
                      _angleController.value -=
                          (details.delta.dx / cardWidth) * math.pi * 1.18;
                      final crossed =
                          ((_angleController.value + math.pi / 2) / math.pi)
                              .floor();
                      if (crossed != _lastCrossedHalf) {
                        _lastCrossedHalf = crossed;
                        if (!_animationsDisabled) {
                          HapticFeedback.selectionClick();
                        }
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      final vRad =
                          -(details.primaryVelocity ?? 0.0) /
                          cardWidth *
                          math.pi *
                          1.15;
                      final int targetHalf;
                      if (vRad.abs() > 1.8) {
                        targetHalf = _dragStartHalf + (vRad > 0 ? 1 : -1);
                      } else if ((_angleController.value -
                                  _dragStartHalf * math.pi)
                              .abs() >
                          math.pi * 0.26) {
                        targetHalf =
                            _dragStartHalf +
                            (_angleController.value > _dragStartHalf * math.pi
                                ? 1
                                : -1);
                      } else {
                        targetHalf = _dragStartHalf;
                      }
                      _animateToHalf(
                        targetHalf,
                        velocityRad: vRad.clamp(-14.0, 14.0),
                      );
                    },
                    onHorizontalDragCancel: () {
                      _releasePointerTilt();
                      _animateToHalf(
                        (_angleController.value / math.pi).round(),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: AspectRatio(
                        aspectRatio: 1426 / 900,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.scale(
                              scale: liftScale,
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.00145)
                                  ..rotateX(
                                    activeTiltX * (1.0 - edgeFactor * 0.65),
                                  )
                                  ..rotateY(angle),
                                child: cardBody,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 10,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: badgeOpacity,
                                  child: Container(
                                    key: const Key(
                                      'active-membership-flip-badge',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xB8181513),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0x55FFF6EA),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.flip_rounded,
                                          size: 12.5,
                                          color: MetaGymTheme.brandOrange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isFrontFace
                                              ? 'Mặt trước · Lật'
                                              : 'Mặt sau · Lật',
                                          style: const TextStyle(
                                            color: MetaGymTheme.textPrimary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
