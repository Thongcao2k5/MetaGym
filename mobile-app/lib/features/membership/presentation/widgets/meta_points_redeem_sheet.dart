import 'package:meta_gym_app/core/theme/theme_controller.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class MetaPointsReward {
  const MetaPointsReward({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.costPoints,
    required this.voucherPrefix,
    required this.svgAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final int costPoints;
  final String voucherPrefix;
  final String svgAsset;
}

const List<MetaPointsReward> kMetaPointsRewards = [
  MetaPointsReward(
    id: 'voucher-100k',
    title: 'Voucher giảm 100.000đ',
    subtitle: 'Áp dụng trực tiếp khi gia hạn hoặc nâng cấp thẻ',
    costPoints: 300,
    voucherPrefix: 'MG100K',
    svgAsset: MetaGymIcons.paymentReceiptInvoice,
  ),
  MetaPointsReward(
    id: 'inbody-vip',
    title: '1 lần đo InBody 970 VIP',
    subtitle: 'Phân tích chuyên sâu cơ – mỡ – nước cùng chuyên gia',
    costPoints: 400,
    voucherPrefix: 'MGINBODY',
    svgAsset: MetaGymIcons.healthShield,
  ),
  MetaPointsReward(
    id: 'pt-trial',
    title: '1 buổi PT 1:1 cùng Coach',
    subtitle: 'Chỉnh form compound & thiết kế lộ trình cá nhân hoá',
    costPoints: 900,
    voucherPrefix: 'MGPT11',
    svgAsset: MetaGymIcons.premiumCrown,
  ),
];

/// Modal Level 3 Overlay Glass cho phép hội viên đổi điểm Meta Points lấy ưu đãi.
Future<MetaPointsReward?> showMetaPointsRedeemSheet(
  BuildContext context, {
  required int currentPoints,
}) {
  return showModalBottomSheet<MetaPointsReward>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA607080B),
    builder: (sheetContext) =>
        _MetaPointsRedeemSheet(currentPoints: currentPoints),
  );
}

class _MetaPointsRedeemSheet extends StatelessWidget {
  const _MetaPointsRedeemSheet({required this.currentPoints});

  final int currentPoints;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final content = Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xF0171A21),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: const Color(0x38FFF6EA), width: 1.0),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x52FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.42),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymSvgIcon(
                    MetaGymIcons.streakFlame,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đổi điểm Meta Points',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Số dư khả dụng: ${_formatPoints(currentPoints)} điểm',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: MetaGymTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final reward in kMetaPointsRewards) ...[
              _RewardTile(
                reward: reward,
                canAfford: currentPoints >= reward.costPoints,
                onRedeem: () => Navigator.of(context).pop(reward),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );

    if (disableAnimations) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        enabled: !MetaGymSurfacePreferences.reduceBlurOf(context),
        filter: ImageFilter.blur(
          sigmaX: MetaGymTheme.overlayGlassBlur,
          sigmaY: MetaGymTheme.overlayGlassBlur,
        ),
        child: content,
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.canAfford,
    required this.onRedeem,
  });

  final MetaPointsReward reward;
  final bool canAfford;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canAfford ? const Color(0xA3A79D92) : const Color(0x40A79D92),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x20FF5E36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x45FF5E36)),
            ),
            alignment: Alignment.center,
            child: MetaGymSvgIcon(reward.svgAsset, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatPoints(reward.costPoints)} điểm',
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: canAfford ? onRedeem : null,
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                disabledBackgroundColor: const Color(0x33FFFFFF),
                foregroundColor: Colors.white,
                disabledForegroundColor: MetaGymTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                canAfford ? 'Đổi ngay' : 'Chưa đủ',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPoints(int points) {
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
