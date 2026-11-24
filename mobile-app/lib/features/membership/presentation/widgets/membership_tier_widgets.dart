import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';

enum MembershipTierKind { bronze, silver, gold, diamond }

class MembershipTierInfo {
  const MembershipTierInfo({
    required this.kind,
    required this.tierLabel,
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
    horizontalCardAsset: 'assets/images/membership/card_bronze_horizontal.jpg',
    borderColor: Color(0x73D29162),
    accentColor: Color(0xFFD29162),
    summaryPerks:
        'Quẹt thẻ Đồng NFC · Tập không giới hạn khu máy, Cardio & tủ Locker cá nhân',
    coachDiscountLabel: '-2%',
    inBodyLabel: 'Ưu đãi 50%',
    pointsMultiplierLabel: '×1.0 điểm',
    nextTierLabel: 'Hạng Bạc',
    nextTierTargetPoints: 800,
  );
}

/// Khối 1: Thẻ kim loại nằm ngang 16:10 + thẻ thông tin gói đang hiệu lực.
class ActiveMembershipNfcSection extends StatelessWidget {
  const ActiveMembershipNfcSection({
    required this.membership,
    required this.memberName,
    required this.now,
    required this.busy,
    required this.onRenew,
    required this.onRedeemPoints,
    super.key,
  });

  final Membership membership;
  final String memberName;
  final DateTime now;
  final bool busy;
  final VoidCallback? onRenew;
  final VoidCallback onRedeemPoints;

  @override
  Widget build(BuildContext context) {
    final tier = resolveMembershipTierInfo(planName: membership.planName);
    final remaining = membership.remainingDays(now);
    final dateRange =
        '${formatMembershipDate(membership.startDate)} → '
        '${formatMembershipDate(membership.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thẻ Hội viên Kim loại nằm ngang (16:10)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tier.borderColor.withValues(alpha: 0.45),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8C000000),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                tier.horizontalCardAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF1F232C),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: MetaGymTheme.textSecondary,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Thẻ tóm tắt quyền lợi & 2 nút hành động
        MetaGymGlassCard(
          solid: false,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          memberName.isNotEmpty
                              ? '$dateRange · $memberName'
                              : dateRange,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.textSecondary,
                            fontSize: 11.5,
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
                        horizontal: 10,
                        vertical: 5,
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
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tier.summaryPerks,
                style: const TextStyle(
                  color: Color(0xFFD5CCBF),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onRedeemPoints,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MetaGymTheme.textPrimary,
                          backgroundColor: const Color(0x18FFFFFF),
                          side: const BorderSide(
                            color: Color(0x45FFF6EA),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Khối 2: Ví điểm Meta Points & Tiến độ nâng hạng.
class MetaPointsWalletCard extends StatelessWidget {
  const MetaPointsWalletCard({
    required this.points,
    required this.tier,
    required this.onRedeemTap,
    super.key,
  });

  final int points;
  final MembershipTierInfo tier;
  final VoidCallback onRedeemTap;

  @override
  Widget build(BuildContext context) {
    final target = tier.nextTierTargetPoints;
    final progress = (points / target).clamp(0.06, 1.0);
    final remainingToNext = (target - points).clamp(0, target);
    final progressText = tier.nextTierLabel == null
        ? 'Đã đạt hạng cao nhất · Tích điểm đổi quà VIP'
        : remainingToNext == 0
        ? 'Đủ điểm nâng lên ${tier.nextTierLabel}'
        : 'Còn ${_formatPts(remainingToNext)} điểm lên ${tier.nextTierLabel}';

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              const Expanded(
                child: Text(
                  'Meta Points',
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_formatPts(points)} điểm',
                style: const TextStyle(
                  color: MetaGymTheme.brandOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0x28FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(
                MetaGymTheme.brandOrange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onRedeemTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Đổi quà ›',
                    style: TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Khối 3: Ưu đãi đặc quyền theo hạng thẻ đang áp dụng.
class ActiveTierPerksCard extends StatelessWidget {
  const ActiveTierPerksCard({required this.tier, super.key});

  final MembershipTierInfo tier;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          const SizedBox(height: 10),
          _PerkLine(
            label: '✓ Giảm tự động phí Gói Coach 1:1',
            value: tier.coachDiscountLabel,
            valueColor: MetaGymTheme.brandOrange,
          ),
          const SizedBox(height: 7),
          _PerkLine(
            label: '✓ Đo chỉ số InBody chuyên sâu',
            value: tier.inBodyLabel,
            valueColor: MetaGymTheme.progressGreen,
          ),
          const SizedBox(height: 7),
          _PerkLine(
            label: '✓ Tích điểm Check-in & Gia hạn',
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
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE0D9CE),
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.2,
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
