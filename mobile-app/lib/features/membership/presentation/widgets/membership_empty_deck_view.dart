import 'package:flutter/material.dart';
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
  ),
  _EmptyWalletTierSpec(
    kind: MembershipTierKind.gold,
    tabLabel: 'Vàng ★',
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
  ),
];

/// Màn hình 1.2b Gói tập (Chưa đăng ký):
/// 4 tab chọn hạng + Fan Deck 4 thẻ đứng full-bleed + thẻ quyền lợi Warm Smoked Glass
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

  void _step(int delta) {
    setState(() {
      _activeIndex = (_activeIndex + delta) % _kEmptyWalletTiers.length;
      if (_activeIndex < 0) _activeIndex += _kEmptyWalletTiers.length;
    });
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
    final cardW = (screenWidth * 0.51).clamp(174.0, 224.0);
    final cardH = (cardW * 1.44).clamp(250.0, 322.0);
    final sideOffset = (screenWidth * 0.345).clamp(118.0, 165.0);
    final stageH = cardH + 22.0;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: const Color(0xFF2B2622),
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...widget.topBanners,

                // 4 Tab chọn nhanh hạng thẻ (Đồng | Bạc | Vàng ★ | Kim Cương)
                Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x991C1917),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0x55A79D92),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _kEmptyWalletTiers.length; i++)
                        Expanded(
                          child: _WalletTabButton(
                            label: _kEmptyWalletTiers[i].tabLabel,
                            active: i == _activeIndex,
                            onTap: () => setState(() => _activeIndex = i),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4 Thẻ Đứng Trượt Ngang Full-Bleed (giống hệt animation Trang chủ)
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    final vx = details.primaryVelocity ?? 0;
                    if (vx < -180) _step(1);
                    if (vx > 180) _step(-1);
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
                          screenWidth: screenWidth,
                          cardW: cardW,
                          cardH: cardH,
                          sideOffset: sideOffset,
                          disableAnim: disableAnim,
                          onSelect: (index) =>
                              setState(() => _activeIndex = index),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pagination dots
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _kEmptyWalletTiers.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _activeIndex = i),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
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
                                    : const Color(0x55FFFFFF),
                                borderRadius: BorderRadius.circular(999),
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
                  padding: const EdgeInsets.all(14),
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
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
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
                              color: spec.badgeColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: spec.badgeColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              spec.badgeLabel,
                              style: TextStyle(
                                color: spec.badgeColor,
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
                            style: const TextStyle(
                              color: MetaGymTheme.brandOrange,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          Text(
                            displayPeriod,
                            style: const TextStyle(
                              color: MetaGymTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.subtitle,
                        style: const TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0x28FFF6EA)),
                      const SizedBox(height: 10),
                      const _EmptyPerkRow(
                        label: '✓ Quẹt thẻ kim loại NFC & QR Check-in',
                        value: 'Full giờ',
                        valueColor: MetaGymTheme.progressGreen,
                      ),
                      const SizedBox(height: 7),
                      _EmptyPerkRow(
                        label: '✓ Giảm trực tiếp phí Gói Coach 1:1',
                        value: spec.coachDiscount,
                        valueColor: MetaGymTheme.brandOrange,
                      ),
                      const SizedBox(height: 7),
                      _EmptyPerkRow(
                        label: '✓ Đo chỉ số cơ thể InBody',
                        value: spec.inBodyText,
                        valueColor: MetaGymTheme.textPrimary,
                      ),
                      const SizedBox(height: 7),
                      _EmptyPerkRow(
                        label: '✓ Hệ số tích điểm Meta Points',
                        value: spec.pointsText,
                        valueColor: MetaGymTheme.textPrimary,
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
          decoration: const BoxDecoration(
            color: Color(0xE615181F),
            border: Border(top: BorderSide(color: Color(0x26FFF6EA), width: 1)),
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
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? MetaGymTheme.brandOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? Colors.white : MetaGymTheme.textSecondary,
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
    required this.screenWidth,
    required this.cardW,
    required this.cardH,
    required this.sideOffset,
    required this.disableAnim,
    required this.onSelect,
  });

  final int activeIndex;
  final double screenWidth;
  final double cardW;
  final double cardH;
  final double sideOffset;
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

  Widget _buildCard({
    required int index,
    required int pos,
    required double centerX,
    required Duration duration,
  }) {
    final (dx, dy, angleDeg, scale, opacity) = switch (pos) {
      0 => (0.0, 4.0, 0.0, 1.0, 1.0),
      -1 => (-sideOffset, 18.0, -7.5, 0.86, 0.90),
      1 => (sideOffset, 18.0, 7.5, 0.86, 0.90),
      _ => (0.0, 26.0, 0.0, 0.76, 0.35),
    };

    return AnimatedPositioned(
      key: ValueKey<String>('empty-fan-card-$index'),
      duration: duration,
      curve: Curves.easeOutQuart,
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
            curve: Curves.easeOutQuart,
            turns: angleDeg / 360.0,
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutQuart,
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: pos == 0
                        ? const Color(0x66FFE2BE)
                        : const Color(0x2EFFFFFF),
                    width: pos == 0 ? 1.2 : 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: pos == 0 ? 0.55 : 0.30,
                      ),
                      blurRadius: pos == 0 ? 24 : 12,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  _kEmptyWalletTiers[index].cardAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF1F232C),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: MetaGymTheme.textSecondary,
                      size: 38,
                    ),
                  ),
                ),
              ),
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
