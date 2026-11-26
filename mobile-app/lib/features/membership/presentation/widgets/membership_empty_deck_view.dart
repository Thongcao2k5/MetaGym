import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/membership_tier_widgets.dart';

class _EmptyWalletTierSpec {
  const _EmptyWalletTierSpec({
    required this.kind,
    required this.tabLabel,
    required this.shortName,
    required this.defaultTitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.defaultPrice,
    required this.periodLabel,
    required this.subtitle,
    required this.coachDiscount,
    required this.inBodyText,
    required this.pointsText,
    required this.cardAsset,
    required this.backCardAsset,
  });

  final MembershipTierKind kind;
  final String tabLabel;
  final String shortName;
  final String defaultTitle;
  final String badgeLabel;
  final Color badgeColor;
  final num defaultPrice;
  final String periodLabel;
  final String subtitle;
  final String coachDiscount;
  final String inBodyText;
  final String pointsText;
  final String cardAsset;
  final String backCardAsset;
}

const List<_EmptyWalletTierSpec> _kEmptyWalletTiers = [
  _EmptyWalletTierSpec(
    kind: MembershipTierKind.bronze,
    tabLabel: 'Đồng',
    shortName: 'Hạng Đồng',
    defaultTitle: 'Hạng Đồng — Starter 1 Tháng',
    badgeLabel: 'Khởi đầu',
    badgeColor: Color(0xFFA8B1C2),
    defaultPrice: 890000,
    periodLabel: '/ tháng',
    subtitle: '~29.600đ / ngày · Linh hoạt trải nghiệm',
    coachDiscount: '0%',
    inBodyText: 'Trả phí lẻ',
    pointsText: '×1.0 điểm',
    cardAsset: 'assets/images/membership/card_bronze.jpg',
    backCardAsset: 'assets/images/membership/card_bronze_horizontal.jpg',
  ),
  _EmptyWalletTierSpec(
    kind: MembershipTierKind.silver,
    tabLabel: 'Bạc',
    shortName: 'Hạng Bạc',
    defaultTitle: 'Hạng Bạc — Plus 3 Tháng',
    badgeLabel: 'Tiết kiệm',
    badgeColor: Color(0xFFA8B1C2),
    defaultPrice: 2490000,
    periodLabel: '/ 3 tháng',
    subtitle: '~830.000đ / tháng · Tặng 1 lần đo InBody',
    coachDiscount: '-3%',
    inBodyText: '1 lần miễn phí',
    pointsText: '×1.2 điểm',
    cardAsset: 'assets/images/membership/card_silver.jpg',
    backCardAsset: 'assets/images/membership/card_silver_horizontal.jpg',
  ),
  _EmptyWalletTierSpec(
    kind: MembershipTierKind.gold,
    tabLabel: 'Vàng',
    shortName: 'Hạng Vàng',
    defaultTitle: 'Hạng Vàng — Pro 6 Tháng',
    badgeLabel: 'Phổ biến nhất',
    badgeColor: MetaGymTheme.brandOrange,
    defaultPrice: 4490000,
    periodLabel: '/ 6 tháng',
    subtitle: '~748.000đ / tháng · Tặng 2 buổi PT 1:1',
    coachDiscount: '-5%',
    inBodyText: 'Hàng tháng',
    pointsText: '×1.5 điểm',
    cardAsset: 'assets/images/membership/card_gold.jpg',
    backCardAsset: 'assets/images/membership/card_gold_horizontal.jpg',
  ),
  _EmptyWalletTierSpec(
    kind: MembershipTierKind.diamond,
    tabLabel: 'Kim Cương',
    shortName: 'Kim Cương',
    defaultTitle: 'Kim Cương VIP — 12 Tháng',
    badgeLabel: 'VIP Cao cấp',
    badgeColor: MetaGymTheme.progressGreen,
    defaultPrice: 8490000,
    periodLabel: '/ năm',
    subtitle: '~707.000đ / tháng · Tặng 6 buổi PT 1:1',
    coachDiscount: '-10%',
    inBodyText: 'Không giới hạn',
    pointsText: '×2.0 điểm',
    cardAsset: 'assets/images/membership/card_diamond.jpg',
    backCardAsset: 'assets/images/membership/card_diamond_horizontal.jpg',
  ),
];

/// Màn hình 1.2b Gói tập (Chưa đăng ký):
/// 4 tab chọn hạng + Fan Deck 4 thẻ đứng lật 3D mặt trước/sau + thẻ quyền lợi Warm Smoked Glass
/// + thanh Bottom CTA Dock cố định theo hạng thẻ đang chọn.
class MembershipEmptyDeckView extends StatefulWidget {
  const MembershipEmptyDeckView({
    required this.plans,
    required this.busy,
    required this.onSelectPlan,
    required this.onRefresh,
    this.topBanners = const [],
    super.key,
  });

  final List<MembershipPlan> plans;
  final bool busy;
  final ValueChanged<MembershipPlan> onSelectPlan;
  final Future<void> Function() onRefresh;
  final List<Widget> topBanners;

  @override
  State<MembershipEmptyDeckView> createState() =>
      _MembershipEmptyDeckViewState();
}

class _MembershipEmptyDeckViewState extends State<MembershipEmptyDeckView> {
  int _activeIndex = 2; // Mặc định chọn Hạng Vàng ★ giống bản preview 1.2b
  bool _centerFlipped = false;
  double _dragAccumX = 0.0;
  bool _isDragging = false;

  void _step(int delta) {
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _activeIndex = (_activeIndex + delta) % _kEmptyWalletTiers.length;
      if (_activeIndex < 0) _activeIndex += _kEmptyWalletTiers.length;
      _centerFlipped = false;
      _dragAccumX = 0.0;
      _isDragging = false;
    });
  }

  void _selectTier(int index, {bool toggleFlipIfActive = false}) {
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      if (index == _activeIndex) {
        if (toggleFlipIfActive) {
          _centerFlipped = !_centerFlipped;
        }
      } else {
        _activeIndex = index;
        _centerFlipped = false;
      }
      _dragAccumX = 0.0;
      _isDragging = false;
    });
  }

  Future<void> _openVipPromotionsSheet() async {
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      HapticFeedback.lightImpact();
    }
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xA607080B),
      builder: (sheetContext) => _VipPromotionsSheet(
        activeIndex: _activeIndex,
        plans: widget.plans,
        resolvePlan: _resolvePlanForTier,
      ),
    );
    if (!mounted || selectedIndex == null) return;
    _selectTier(selectedIndex);
  }

  MembershipPlan? _resolvePlanForTier(_EmptyWalletTierSpec tier) {
    if (widget.plans.isEmpty) return null;
    for (final plan in widget.plans) {
      final info = resolveMembershipTierInfo(
        planName: plan.name,
        durationDays: plan.durationDays,
      );
      if (info.kind == tier.kind) return plan;
    }
    return widget.plans.first;
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final spec = _kEmptyWalletTiers[_activeIndex];
    final matchedPlan = _resolvePlanForTier(spec);
    final displayTitle = matchedPlan?.name ?? spec.defaultTitle;
    final displayPrice = matchedPlan?.price ?? spec.defaultPrice;
    final displayPeriod = matchedPlan == null
        ? spec.periodLabel
        : switch (matchedPlan.durationDays) {
            >= 300 => '/ năm',
            >= 150 => '/ 6 tháng',
            >= 60 => '/ 3 tháng',
            >= 28 => '/ tháng',
            _ => '/ ${matchedPlan.durationDays} ngày',
          };
    final formattedPrice = formatMembershipMoney(displayPrice);
    final ctaLabel = 'Đăng ký ${spec.shortName} · $formattedPrice →';
    final disableAnim =
        MetaGymTheme.isFlutterTestEnvironment ||
        MediaQuery.disableAnimationsOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardW = (screenWidth * 0.37).clamp(134.0, 168.0);
    final cardH = (cardW * (1426 / 900)).clamp(212.0, 266.0);
    final sideOffset = (screenWidth * 0.27).clamp(92.0, 130.0);
    final stageH = cardH + 16.0;
    final dragOffset = (_dragAccumX * 0.28).clamp(-38.0, 38.0);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: palette.surfaceSolid,
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...widget.topBanners,

                // Banner Meta Kong VIP đồng bộ preview 1.2b
                MetaGymGlassCard(
                  key: const Key('empty-membership-promo-strip'),
                  solid: false,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  borderColor: const Color(0x5CF5B041),
                  onTap: _openVipPromotionsSheet,
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/mascot/meta_kong_membership_promo.webp',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFF5B041),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mở khóa đặc quyền VIP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Chọn thẻ kim loại NFC & nhận ưu đãi Coach 1:1',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Ưu đãi ›',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4 Tab chọn nhanh hạng thẻ (Đồng | Bạc | Vàng | Kim Cương)
                Container(
                  padding: const EdgeInsets.all(3),
                  margin: const EdgeInsets.only(bottom: 7),
                  decoration: BoxDecoration(
                    color: palette.metricPanelBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: palette.metricPanelBorder,
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _kEmptyWalletTiers.length; i++)
                        Expanded(
                          child: _WalletTabButton(
                            label: _kEmptyWalletTiers[i].tabLabel,
                            showStar:
                                _kEmptyWalletTiers[i].kind ==
                                MembershipTierKind.gold,
                            active: i == _activeIndex,
                            onTap: () => _selectTier(i),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4 Thẻ Ngang CR80 Trượt Ngang Full-Bleed (đồng bộ Trang chủ) + Lật 3D
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    setState(() {
                      _isDragging = true;
                      _dragAccumX = 0.0;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() => _dragAccumX += details.delta.dx);
                  },
                  onHorizontalDragEnd: (details) {
                    final vx = details.primaryVelocity ?? 0;
                    if (vx < -140 || _dragAccumX < -44) {
                      _step(1);
                    } else if (vx > 140 || _dragAccumX > 44) {
                      _step(-1);
                    } else {
                      setState(() {
                        _isDragging = false;
                        _dragAccumX = 0.0;
                      });
                    }
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _isDragging = false;
                      _dragAccumX = 0.0;
                    });
                  },
                  child: SizedBox(
                    height: stageH,
                    width: double.infinity,
                    child: OverflowBox(
                      maxWidth: screenWidth,
                      minWidth: screenWidth,
                      maxHeight: stageH,
                      minHeight: stageH,
                      child: ClipRect(
                        child: _EmptyFanStage(
                          activeIndex: _activeIndex,
                          centerFlipped: _centerFlipped,
                          screenWidth: screenWidth,
                          cardW: cardW,
                          cardH: cardH,
                          sideOffset: sideOffset,
                          dragOffset: dragOffset,
                          isDragging: _isDragging,
                          disableAnim: disableAnim,
                          onSelect: (idx) =>
                              _selectTier(idx, toggleFlipIfActive: true),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pagination dots + nút lật mặt trước/sau
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _kEmptyWalletTiers.length; i++)
                        GestureDetector(
                          onTap: () => _selectTier(i),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: AnimatedContainer(
                              duration: disableAnim
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              width: i == _activeIndex ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _activeIndex
                                    ? MetaGymTheme.brandOrange
                                    : palette.textSecondary.withValues(
                                        alpha: 0.35,
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const Key('empty-membership-flip-btn'),
                        onTap: () {
                          if (!MetaGymTheme.isFlutterTestEnvironment) {
                            HapticFeedback.lightImpact();
                          }
                          setState(() => _centerFlipped = !_centerFlipped);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _centerFlipped
                                  ? MetaGymTheme.brandOrange.withValues(
                                      alpha: 0.14,
                                    )
                                  : palette.metricPanelBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _centerFlipped
                                    ? MetaGymTheme.brandOrange.withValues(
                                        alpha: 0.7,
                                      )
                                    : palette.metricPanelBorder,
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flip_rounded,
                                  size: 12.5,
                                  color: _centerFlipped
                                      ? palette.primaryText
                                      : palette.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _centerFlipped
                                      ? 'Mặt sau · Lật'
                                      : 'Lật mặt sau',
                                  style: TextStyle(
                                    color: _centerFlipped
                                        ? palette.primaryText
                                        : palette.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Thẻ chi tiết quyền lợi hạng thẻ đang chọn (Warm Smoked Glass)
                MetaGymGlassCard(
                  solid: false,
                  padding: const EdgeInsets.all(12),
                  child: AnimatedSwitcher(
                    duration: disableAnim
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey<int>(_activeIndex),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: spec.badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: spec.badgeColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              spec.badgeLabel,
                              style: TextStyle(
                                color: isLight
                                    ? palette.textPrimary
                                    : spec.badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            formattedPrice,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          Text(
                            displayPeriod,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.subtitle,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: isLight
                            ? palette.borderSolid
                            : const Color(0x28FFF6EA),
                      ),
                      const SizedBox(height: 10),
                      _EmptyPerkRow(
                        label: 'Quẹt thẻ kim loại NFC & QR Check-in',
                        value: 'Full giờ',
                        valueColor: palette.success,
                      ),
                      const SizedBox(height: 6),
                      _EmptyPerkRow(
                        label: 'Giảm trực tiếp phí Gói Coach 1:1',
                        value: spec.coachDiscount,
                        valueColor: palette.primaryText,
                      ),
                      const SizedBox(height: 6),
                      _EmptyPerkRow(
                        label: 'Đo chỉ số cơ thể InBody',
                        value: spec.inBodyText,
                        valueColor: palette.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      _EmptyPerkRow(
                        label: 'Hệ số tích điểm Meta Points',
                        value: spec.pointsText,
                        valueColor: palette.textPrimary,
                      ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom CTA Dock cố định
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: isLight
                ? palette.surfaceSolid.withValues(alpha: 0.96)
                : const Color(0xE615181F),
            border: Border(
              top: BorderSide(
                color: isLight ? palette.borderSolid : const Color(0x26FFF6EA),
                width: 1,
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const Key('empty-membership-cta'),
              onPressed: widget.busy || matchedPlan == null
                  ? null
                  : () => widget.onSelectPlan(matchedPlan),
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                disabledBackgroundColor: MetaGymTheme.brandOrange.withValues(
                  alpha: 0.45,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                ctaLabel,
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
      ],
    );
  }
}

class _WalletTabButton extends StatelessWidget {
  const _WalletTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.showStar = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showStar;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final textColor = active
        ? (isLight ? palette.primaryText : MetaGymTheme.textPrimary)
        : palette.textSecondary;
    final starColor = showStar
        ? (isLight ? palette.warning : const Color(0xFFF5B041))
        : textColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (isLight
                    ? MetaGymTheme.brandOrange.withValues(alpha: 0.14)
                    : const Color(0x28FF5E36))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.78),
                  width: 1.2,
                )
              : null,
        ),
        child: showStar
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.star_rounded, size: 12, color: starColor),
                ],
              )
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _EmptyFanStage extends StatelessWidget {
  const _EmptyFanStage({
    required this.activeIndex,
    required this.centerFlipped,
    required this.screenWidth,
    required this.cardW,
    required this.cardH,
    required this.sideOffset,
    required this.dragOffset,
    required this.isDragging,
    required this.disableAnim,
    required this.onSelect,
  });

  final int activeIndex;
  final bool centerFlipped;
  final double screenWidth;
  final double cardW;
  final double cardH;
  final double sideOffset;
  final double dragOffset;
  final bool isDragging;
  final bool disableAnim;
  final ValueChanged<int> onSelect;

  int _relativePos(int index) {
    final len = _kEmptyWalletTiers.length;
    final diff = (index - activeIndex + len) % len;
    if (diff == 0) return 0; // Center
    if (diff == 1) return 1; // Right
    if (diff == len - 1) return -1; // Left
    return 2; // Back
  }

  Widget _cardErrorFallback() => Container(
    color: const Color(0xFF1F232C),
    alignment: Alignment.center,
    child: const Icon(
      Icons.credit_card_rounded,
      color: MetaGymTheme.textSecondary,
      size: 38,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final duration = disableAnim
        ? Duration.zero
        : const Duration(milliseconds: 300);

    // Vẽ từ sau ra trước: pos 2 -> pos -1 -> pos 1 -> pos 0 (nổi trên cùng)
    final order = List<int>.generate(_kEmptyWalletTiers.length, (i) => i)
      ..sort((a, b) {
        int priority(int pos) => switch (pos) {
          2 => 0,
          -1 => 1,
          1 => 2,
          _ => 3,
        };
        return priority(_relativePos(a)).compareTo(priority(_relativePos(b)));
      });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final index in order)
          _buildCard(
            index: index,
            pos: _relativePos(index),
            centerX: screenWidth / 2,
            duration: duration,
          ),
      ],
    );
  }

  Widget _buildCardFrame({
    required String assetPath,
    required bool isCenter,
    int quarterTurns = 0,
    double extraShadow = 0.0,
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isCenter ? const Color(0x70FFE2BE) : const Color(0x2EFFFFFF),
        width: isCenter ? 1.2 : 0.9,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isCenter ? 0.56 : 0.30),
          blurRadius: (isCenter ? 24 : 12) + extraShadow * 10,
          offset: Offset(0, 10 + extraShadow * 6),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: RotatedBox(
      quarterTurns: quarterTurns,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _cardErrorFallback(),
      ),
    ),
  );

  Widget _buildCard({
    required int index,
    required int pos,
    required double centerX,
    required Duration duration,
  }) {
    final (dx, dy, angleDeg, scale, opacity) = switch (pos) {
      0 => (dragOffset, 4.0, 0.0, 1.0, 1.0),
      -1 => (
        -sideOffset + dragOffset * 0.35,
        18.0,
        -7.5,
        0.86,
        centerFlipped ? 0.25 : 0.88,
      ),
      1 => (
        sideOffset + dragOffset * 0.35,
        18.0,
        7.5,
        0.86,
        centerFlipped ? 0.25 : 0.88,
      ),
      _ => (0.0, 26.0, 0.0, 0.76, centerFlipped ? 0.15 : 0.32),
    };

    final spec = _kEmptyWalletTiers[index];
    final frontCard = _buildCardFrame(
      assetPath: spec.cardAsset,
      isCenter: pos == 0,
    );

    final faceContent = pos == 0
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(end: centerFlipped ? math.pi : 0.0),
            duration: disableAnim
                ? Duration.zero
                : const Duration(milliseconds: 560),
            curve: Curves.easeInOutCubic,
            builder: (context, flipAngle, _) {
              final showBack = flipAngle > math.pi / 2;
              final edgeSin = math.sin(flipAngle).abs();
              final liftScale = 1.0 + edgeSin * 0.03;
              final face = showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _buildCardFrame(
                        assetPath: spec.backCardAsset,
                        isCenter: true,
                        quarterTurns: 1,
                        extraShadow: edgeSin,
                      ),
                    )
                  : _buildCardFrame(
                      assetPath: spec.cardAsset,
                      isCenter: true,
                      extraShadow: edgeSin,
                    );

              return Transform.scale(
                scale: liftScale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.00145)
                    ..rotateY(flipAngle),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        face,
                        if (edgeSin > 0.03)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -0.85 + math.sin(flipAngle) * 1.1,
                                    -0.8,
                                  ),
                                  end: Alignment(
                                    0.85 + math.sin(flipAngle) * 1.1,
                                    0.8,
                                  ),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                      alpha: (edgeSin * 0.24).clamp(0.0, 0.24),
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : frontCard;

    return AnimatedPositioned(
      key: ValueKey<String>('empty-fan-card-$index'),
      duration: isDragging ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      left: centerX - (cardW / 2) + dx,
      top: dy,
      width: cardW,
      height: cardH,
      child: GestureDetector(
        onTap: () => onSelect(index),
        child: AnimatedOpacity(
          duration: duration,
          opacity: opacity,
          child: AnimatedRotation(
            duration: duration,
            curve: Curves.easeOutCubic,
            turns: angleDeg / 360.0,
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: scale,
              child: faceContent,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPerkRow extends StatelessWidget {
  const _EmptyPerkRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      children: [
        Icon(
          Icons.check_rounded,
          size: 14,
          color: palette.success,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textWarmMuted,
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

class _VipPromotionsSheet extends StatelessWidget {
  const _VipPromotionsSheet({
    required this.activeIndex,
    required this.plans,
    required this.resolvePlan,
  });

  final int activeIndex;
  final List<MembershipPlan> plans;
  final MembershipPlan? Function(_EmptyWalletTierSpec tier) resolvePlan;

  static const _highlightedIndices = [3, 2, 1]; // Kim Cương, Vàng, Bạc

  Color _tierAccent(MembershipTierKind kind) => switch (kind) {
    MembershipTierKind.diamond => MetaGymTheme.reflectionBlue,
    MembershipTierKind.gold => const Color(0xFFF5B041),
    MembershipTierKind.silver => const Color(0xFFC4CCDA),
    MembershipTierKind.bronze => const Color(0xFFD29162),
  };

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final disableAnimations =
        MetaGymTheme.isFlutterTestEnvironment ||
        MediaQuery.disableAnimationsOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final featuredIdx = activeIndex == 2 ? 3 : 2;

    final content = Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isLight ? palette.surfaceSolid : const Color(0xF2171A21),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(
          color: isLight ? palette.borderSolid : const Color(0x38FFF6EA),
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? palette.borderSolid
                      : const Color(0x45FFF6EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0x33F5B041), Color(0x14F5B041)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0x55F5B041)),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/mascot/meta_kong_membership_promo.webp',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFF5B041),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đặc quyền & Ưu đãi hội viên VIP',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kích hoạt tự động theo hạng thẻ kim loại NFC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isLight
                            ? palette.surfaceRaised
                            : const Color(0x8824201D),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLight
                              ? palette.borderSolid
                              : const Color(0x45FFF6EA),
                          width: 0.9,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final idx in _highlightedIndices) ...[
              _buildPromoTierCard(
                context,
                idx,
                isFeatured: idx == featuredIdx,
              ),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ưu đãi Coach 1:1 và hệ số tích điểm Meta Points tự động kích hoạt sau khi đăng ký thành công.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (disableAnimations || isLight) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MetaGymTheme.overlayGlassBlur,
          sigmaY: MetaGymTheme.overlayGlassBlur,
        ),
        child: content,
      ),
    );
  }

  Widget _buildPromoTierCard(
    BuildContext context,
    int idx, {
    required bool isFeatured,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final spec = _kEmptyWalletTiers[idx];
    final plan = resolvePlan(spec);
    final title = plan?.name ?? spec.defaultTitle;
    final price = formatMembershipMoney(plan?.price ?? spec.defaultPrice);
    final isCurrentChoice = idx == activeIndex;
    final accent = _tierAccent(spec.kind);
    final borderColor = isCurrentChoice
        ? palette.success.withValues(alpha: 0.65)
        : isFeatured
        ? accent.withValues(alpha: 0.58)
        : (isLight ? palette.borderSolid : const Color(0x5CA79D92));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(idx),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isLight ? palette.surfaceRaised : null,
            gradient: isLight
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isFeatured ? 0.14 : 0.08),
                      const Color(0xD6231F1C),
                    ],
                  ),
            border: Border.all(
              color: borderColor,
              width: isCurrentChoice || isFeatured ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Mini CR80 thumbnail + Title & Price + Tier badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.58),
                        width: 0.9,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      spec.backCardAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: price,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: ' ${spec.periodLabel}',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: spec.badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: spec.badgeColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      spec.badgeLabel,
                      style: TextStyle(
                        color: isLight ? palette.textPrimary : spec.badgeColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Scannable Perk Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _PromoPerkChip(
                    icon: Icons.fitness_center_rounded,
                    label: 'Coach 1:1 ${spec.coachDiscount}',
                    color: palette.primaryText,
                  ),
                  _PromoPerkChip(
                    icon: Icons.monitor_heart_outlined,
                    label: 'InBody: ${spec.inBodyText}',
                    color: palette.success,
                  ),
                  _PromoPerkChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Tích điểm ${spec.pointsText}',
                    color: palette.warning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: isLight ? palette.borderSolid : const Color(0x26A79D92),
              ),
              const SizedBox(height: 9),

              // Row 3: Bonus highlight + Single-primary CTA
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: palette.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildSelectTierCta(
                    context,
                    idx: idx,
                    kind: spec.kind,
                    isCurrentChoice: isCurrentChoice,
                    isFeatured: isFeatured,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectTierCta(
    BuildContext context, {
    required int idx,
    required MembershipTierKind kind,
    required bool isCurrentChoice,
    required bool isFeatured,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final key = ValueKey<String>('promo-select-tier-${kind.name}');
    if (isCurrentChoice) {
      return OutlinedButton(
        key: key,
        onPressed: () => Navigator.of(context).pop(idx),
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.success.withValues(alpha: 0.14),
          foregroundColor: palette.success,
          side: BorderSide(
            color: palette.success.withValues(alpha: 0.55),
          ),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: const Text(
          '✓ Đang chọn',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    if (isFeatured) {
      return FilledButton(
        key: key,
        onPressed: () => Navigator.of(context).pop(idx),
        style: FilledButton.styleFrom(
          backgroundColor: MetaGymTheme.brandOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: const Text(
          'Chọn hạng →',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
    }

    return OutlinedButton(
      key: key,
      onPressed: () => Navigator.of(context).pop(idx),
      style: OutlinedButton.styleFrom(
        backgroundColor: isLight
            ? palette.surfaceSolid
            : const Color(0x1AFFFFFF),
        foregroundColor: palette.textPrimary,
        side: BorderSide(
          color: isLight ? palette.borderSolid : const Color(0x4DFFF6EA),
        ),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      child: const Text(
        'Chọn hạng',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PromoPerkChip extends StatelessWidget {
  const _PromoPerkChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: isLight ? palette.surfaceSolid : const Color(0x901C1815),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.34), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: color),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
