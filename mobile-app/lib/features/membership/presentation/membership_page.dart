import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_history_page.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_my_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_checkout_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/membership_empty_deck_view.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/membership_tier_widgets.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/meta_points_redeem_sheet.dart';
import 'package:provider/provider.dart';

/// Màn hình 1.2a Gói tập (Đang hiệu lực) & 1.2b (Chưa đăng ký), đồng bộ
/// phong cách Warm Smoked Glass + Thẻ Hội viên Kim loại NFC 16:10.
class MembershipPage extends StatefulWidget {
  const MembershipPage({
    super.key,
    this.paymentReturnId,
    this.paymentReturnMethod,
  });

  final String? paymentReturnId;
  final String? paymentReturnMethod;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  int _metaPoints = 1240;

  LoyaltyController? _readLoyalty(BuildContext context) {
    try {
      return context.read<LoyaltyController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  LoyaltyController? _watchLoyalty(BuildContext context) {
    try {
      return context.watch<LoyaltyController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<MembershipController>();
      final loyalty = _readLoyalty(context);
      final paymentId = widget.paymentReturnId;
      final method = widget.paymentReturnMethod;
      if (paymentId != null &&
          method != null &&
          await controller.resumeOnlinePayment(paymentId, method: method)) {
        if (mounted) {
          await loyalty?.refreshSummaryAndRewards();
          if (mounted) await _openCheckout(const MembershipCheckoutPage());
        }
        return;
      }
      if (mounted) {
        await Future.wait<void>([
          controller.load(),
          if (loyalty != null) loyalty.loadAll(),
        ]);
      }
    });
  }

  Future<void> _reviewPurchase(MembershipPlan plan) async {
    final controller = context.read<MembershipController>();
    final quote = await controller.quote(plan);
    if (!mounted || quote == null) return;
    await _openCheckout(MembershipCheckoutPage(plan: plan, quote: quote));
  }

  Future<void> _openCheckout(MembershipCheckoutPage page) async {
    final controller = context.read<MembershipController>();
    final loyalty = _readLoyalty(context);
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute<void>(builder: (_) => page),
    );
    if (mounted && controller.pendingPayment == null) {
      await Future.wait<void>([
        controller.load(),
        if (loyalty != null) loyalty.refreshSummaryAndRewards(),
      ]);
    }
  }

  Future<void> _openHistory() => MetaGymNavigation.pushOnce<void>(
    context,
    MetaGymPageRoute<void>(builder: (_) => const PaymentHistoryPage()),
  );

  Future<void> _openLoyaltyRewards() async {
    final loyalty = _readLoyalty(context);
    if (loyalty == null) {
      await _openRedeemPoints();
      return;
    }
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute<void>(builder: (_) => const LoyaltyRewardsPage()),
    );
  }

  Future<void> _openLoyaltyMyRewards() async {
    final loyalty = _readLoyalty(context);
    if (loyalty == null) return;
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute<void>(builder: (_) => const LoyaltyMyRewardsPage()),
    );
  }

  Future<void> _openLoyaltyHistory() async {
    final loyalty = _readLoyalty(context);
    if (loyalty == null) {
      await _openHistory();
      return;
    }
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute<void>(builder: (_) => const LoyaltyHistoryPage()),
    );
  }

  Future<void> _openRedeemPoints() async {
    final reward = await showMetaPointsRedeemSheet(
      context,
      currentPoints: _metaPoints,
    );
    if (!mounted || reward == null) return;
    setState(() {
      _metaPoints = (_metaPoints - reward.costPoints).clamp(0, 999999);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F232C),
          content: Text(
            'Đã đổi "${reward.title}" (-${reward.costPoints} điểm) · Mã: ${reward.voucherPrefix}26',
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  MembershipPlan? _findRenewalPlan(
    Membership active,
    List<MembershipPlan> plans,
  ) {
    if (plans.isEmpty) return null;
    final activeLower = (active.planName ?? '').toLowerCase();
    for (final plan in plans) {
      if (plan.name.toLowerCase() == activeLower) return plan;
    }
    final activeTier = resolveMembershipTierInfo(planName: active.planName).kind;
    for (final plan in plans) {
      final planTier = resolveMembershipTierInfo(
        planName: plan.name,
        durationDays: plan.durationDays,
      ).kind;
      if (planTier == activeTier) return plan;
    }
    return plans.first;
  }

  String _resolveMemberName(BuildContext context) {
    try {
      return context.select<SessionController, String>(
        (session) => session.user?.fullName ?? '',
      );
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final controller = context.watch<MembershipController>();
    final loyaltyController = _watchLoyalty(context);
    final loyaltySummary = loyaltyController?.summary;
    final memberName = _resolveMemberName(context);
    final now = DateTime.now();

    final primaryMembership = controller.memberships
        .where((m) => m.status == 'ACTIVE')
        .firstOrNull ??
        controller.memberships.firstOrNull;
    final secondaryMemberships = controller.memberships
        .where((m) => m.id != primaryMembership?.id)
        .toList();
    final primaryTier = loyaltySummary != null
        ? loyaltySummary.toMembershipTierInfo()
        : (primaryMembership != null
            ? resolveMembershipTierInfo(planName: primaryMembership.planName)
            : null);

    final isEmptySelectionMode =
        primaryMembership == null &&
        controller.pendingPayment == null &&
        controller.plans.isNotEmpty;

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
                  eyebrow: isEmptySelectionMode
                      ? 'THẺ HỘI VIÊN NFC · 4 HẠNG'
                      : 'HỘI VIÊN & ƯU ĐÃI',
                  title: isEmptySelectionMode ? 'Chọn gói tập' : 'Gói tập',
                  actions: isEmptySelectionMode
                      ? const [
                          MembershipStatusPill(
                            label: 'Chưa có gói',
                            color: Color(0xFFA8B1C2),
                          ),
                        ]
                      : [
                          MetaGymCircleIconButton(
                            key: const Key('membership-loyalty-history-btn'),
                            svgAsset: MetaGymIcons.workoutHistory,
                            icon: Icons.history_rounded,
                            tooltip: 'Lịch sử điểm',
                            onTap: _openLoyaltyHistory,
                          ),
                        ],
                ),
                Expanded(
                  child: controller.isLoading && controller.plans.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : isEmptySelectionMode
                      ? MembershipEmptyDeckView(
                          plans: controller.plans,
                          busy: controller.isLoading,
                          onSelectPlan: _reviewPurchase,
                          onRefresh: () async {
                            await Future.wait<void>([
                              controller.load(),
                              if (loyaltyController != null)
                                loyaltyController.loadAll(),
                            ]);
                          },
                          topBanners: [
                            if (controller.errorMessage case final error?)
                              MembershipErrorCard(
                                message: error,
                                onRetry: controller.isLoading
                                    ? null
                                    : controller.load,
                              ),
                          ],
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: palette.surfaceSolid,
                          onRefresh: () async {
                            await Future.wait<void>([
                              controller.load(),
                              if (loyaltyController != null)
                                loyaltyController.loadAll(),
                            ]);
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 36),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (controller.errorMessage case final error?)
                                MembershipErrorCard(
                                  message: error,
                                  onRetry: controller.isLoading
                                      ? null
                                      : controller.load,
                                ),
                              if (controller.pendingPayment case final payment?)
                                _PendingCheckoutBanner(
                                  payment: payment,
                                  busy: controller.isLoading,
                                  onContinue: () => _openCheckout(
                                    const MembershipCheckoutPage(),
                                  ),
                                ),

                              // 1. THẺ HỘI VIÊN CỦA TÔI
                              MembershipSectionHeader(
                                svgAsset: MetaGymIcons.membershipActiveSeal,
                                title: 'Thẻ hội viên của tôi',
                                trailing: primaryMembership != null
                                    ? MembershipStatusPill(
                                        label: primaryMembership.status ==
                                                'ACTIVE'
                                            ? 'Hiệu lực'
                                            : primaryMembership.label,
                                        color: membershipStatusColor(
                                          primaryMembership.status,
                                        ),
                                      )
                                    : null,
                              ),
                              if (primaryMembership == null)
                                const _EmptyMembershipHeroCard()
                              else ...[
                                ActiveMembershipNfcSection(
                                  membership: primaryMembership,
                                  memberName: memberName,
                                  now: now,
                                  busy: controller.isLoading,
                                  tierOverride: primaryTier,
                                  onRenew: controller.plans.isEmpty
                                      ? null
                                      : () {
                                          final target = _findRenewalPlan(
                                            primaryMembership,
                                            controller.plans,
                                          );
                                          if (target != null) {
                                            _reviewPurchase(target);
                                          }
                                        },
                                ),
                                for (final extra in secondaryMemberships)
                                  _ScheduledMembershipBanner(membership: extra),

                                // 2. VÍ ĐIỂM META POINTS & TIẾN ĐỘ NÂNG HẠNG
                                MetaPointsWalletCard(
                                  points: loyaltySummary?.availablePoints ??
                                      _metaPoints,
                                  tierPoints: loyaltySummary?.tierPoints,
                                  remainingToNextTier:
                                      loyaltySummary?.remainingToNextTier,
                                  progressFraction:
                                      loyaltySummary?.progressFraction,
                                  unusedRedemptionsCount:
                                      loyaltySummary?.unusedRedemptionsCount ??
                                          0,
                                  tier: primaryTier!,
                                  onRedeemTap: _openLoyaltyRewards,
                                  onMyRewardsTap: loyaltyController != null
                                      ? _openLoyaltyMyRewards
                                      : null,
                                  onTierInfoTap: loyaltySummary != null
                                      ? () => showLoyaltyTiersSheet(
                                            context,
                                            summary: loyaltySummary,
                                          )
                                      : null,
                                ),

                                // 3. ƯU ĐÃI HẠNG THẺ ĐANG ÁP DỤNG
                                ActiveTierPerksCard(tier: primaryTier),
                              ],

                              // 4. NÂNG CẤP GÓI TẬP (CAROUSEL VUỐT NGANG)
                              if (controller.pendingPayment == null) ...[
                                const SizedBox(height: 2),
                                MembershipSectionHeader(
                                  svgAsset: MetaGymIcons.premiumCrown,
                                  title: 'Nâng cấp gói tập',
                                  trailing: controller.plans.isNotEmpty
                                      ? Text(
                                          'Vuốt ngang · ${controller.plans.length} gói',
                                          style: TextStyle(
                                            color: palette.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            fontFeatures:
                                                MetaGymTheme.tabularFigures,
                                          ),
                                        )
                                      : null,
                                ),
                                if (controller.plans.isEmpty &&
                                    controller.errorMessage == null)
                                  const MetaGymGlassCard(
                                    solid: false,
                                    padding: EdgeInsets.all(18),
                                    child: Text(
                                      'Chưa có gói tập đang bán.',
                                      style: TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                else
                                  _MembershipPlanCarousel(
                                    plans: controller.plans,
                                    activeMembership: primaryMembership,
                                    busy: controller.isLoading,
                                    onBuy: _reviewPurchase,
                                  ),
                              ],

                              // 5. LỊCH SỬ GÓI & GIAO DỊCH
                              const SizedBox(height: 6),
                              MembershipSectionHeader(
                                svgAsset: MetaGymIcons.workoutHistory,
                                title: 'Lịch sử gói',
                                trailing: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _openHistory,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        MetaGymSvgIcon(
                                          MetaGymIcons.paymentReceiptInvoice,
                                          size: 14,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Giao dịch',
                                          style: TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (controller.history.isEmpty &&
                                  controller.errorMessage == null)
                                const MetaGymGlassCard(
                                  solid: false,
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Chưa có lịch sử gói tập nào.',
                                    style: TextStyle(
                                      color: MetaGymTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                for (final item in controller.history)
                                  _HistoryMembershipTile(membership: item),
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

class _PendingCheckoutBanner extends StatelessWidget {
  const _PendingCheckoutBanner({
    required this.payment,
    required this.busy,
    required this.onContinue,
  });

  final Payment payment;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x2CF39C12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x75F39C12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0x33F39C12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: MetaGymTheme.warningAmber,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Giao dịch chờ thanh toán',
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              const MembershipStatusPill(
                label: 'Đang chờ',
                color: MetaGymTheme.warningAmber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn đang có giao dịch ${payment.planName ?? 'gói tập'} '
            'chưa hoàn tất qua ${formatPaymentMethodLabel(payment.method)}.',
            style: const TextStyle(
              color: Color(0xFFFDE3B2),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          MembershipPrimaryButton(
            label: 'Tiếp tục thanh toán',
            icon: Icons.arrow_forward_rounded,
            compact: true,
            onPressed: busy ? null : onContinue,
          ),
        ],
      ),
    );
  }
}

class _ScheduledMembershipBanner extends StatelessWidget {
  const _ScheduledMembershipBanner({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.planName ?? membership.label,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMembershipDate(membership.startDate)} → '
                  '${formatMembershipDate(membership.endDate)}',
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MembershipStatusPill(
            label: membership.label,
            color: membershipStatusColor(membership.status),
          ),
        ],
      ),
    );
  }
}

class _EmptyMembershipHeroCard extends StatelessWidget {
  const _EmptyMembershipHeroCard();

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.42),
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(
                  MetaGymIcons.membershipActiveSeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có gói tập hiệu lực',
                      style: TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kích hoạt thẻ để mở khóa check-in QR/NFC và thuê Coach',
                      style: TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCardMeta {
  const _PlanCardMeta({
    required this.badgeLabel,
    required this.badgeColor,
    required this.borderColor,
    required this.ctaLabel,
    required this.isPrimaryCta,
    required this.periodSuffix,
  });

  final String badgeLabel;
  final Color badgeColor;
  final Color borderColor;
  final String ctaLabel;
  final bool isPrimaryCta;
  final String periodSuffix;
}

_PlanCardMeta _resolvePlanCardMeta({
  required MembershipPlan plan,
  required List<MembershipPlan> plans,
  required Membership? activeMembership,
}) {
  final tier = resolveMembershipTierInfo(
    planName: plan.name,
    durationDays: plan.durationDays,
  );
  final activeName = (activeMembership?.planName ?? '').toLowerCase();
  final activeTier = activeMembership != null
      ? resolveMembershipTierInfo(planName: activeMembership.planName).kind
      : null;
  final isCurrent =
      activeMembership != null &&
      (plan.name.toLowerCase() == activeName || activeTier == tier.kind);

  final periodSuffix = switch (plan.durationDays) {
    >= 300 => '/ năm',
    >= 150 => '/ 6 tháng',
    >= 60 => '/ 3 tháng',
    >= 28 => '/ tháng',
    _ => '/ ${plan.durationDays} ngày',
  };

  if (isCurrent) {
    return _PlanCardMeta(
      badgeLabel: 'Đang dùng',
      badgeColor: MetaGymTheme.progressGreen,
      borderColor: tier.borderColor,
      ctaLabel: 'Gia hạn thêm',
      isPrimaryCta: false,
      periodSuffix: periodSuffix,
    );
  }

  if (tier.kind == MembershipTierKind.diamond || plans.length == 1) {
    return _PlanCardMeta(
      badgeLabel: 'Đề xuất',
      badgeColor: MetaGymTheme.reflectionBlue,
      borderColor: tier.borderColor,
      ctaLabel: activeMembership != null ? 'Nâng cấp gói này' : 'Chọn gói này',
      isPrimaryCta: true,
      periodSuffix: periodSuffix,
    );
  }

  if (tier.kind == MembershipTierKind.gold) {
    return _PlanCardMeta(
      badgeLabel: 'Phổ biến',
      badgeColor: MetaGymTheme.brandOrange,
      borderColor: tier.borderColor,
      ctaLabel: 'Chọn gói này',
      isPrimaryCta: activeMembership == null,
      periodSuffix: periodSuffix,
    );
  }

  if (tier.kind == MembershipTierKind.silver) {
    return _PlanCardMeta(
      badgeLabel: '3 Tháng',
      badgeColor: const Color(0xFFA8B1C2),
      borderColor: tier.borderColor,
      ctaLabel: 'Chọn gói này',
      isPrimaryCta: false,
      periodSuffix: periodSuffix,
    );
  }

  return _PlanCardMeta(
    badgeLabel: plan.durationDays >= 28 ? '1 Tháng' : '${plan.durationDays} ngày',
    badgeColor: const Color(0xFFA8B1C2),
    borderColor: tier.borderColor,
    ctaLabel: 'Chọn gói này',
    isPrimaryCta: false,
    periodSuffix: periodSuffix,
  );
}

class _MembershipPlanCarousel extends StatefulWidget {
  const _MembershipPlanCarousel({
    required this.plans,
    required this.activeMembership,
    required this.busy,
    required this.onBuy,
  });

  final List<MembershipPlan> plans;
  final Membership? activeMembership;
  final bool busy;
  final ValueChanged<MembershipPlan> onBuy;

  @override
  State<_MembershipPlanCarousel> createState() =>
      _MembershipPlanCarouselState();
}

class _MembershipPlanCarouselState extends State<_MembershipPlanCarousel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<MembershipPlan> _orderedPlans() {
    // Ưu tiên hiển thị gói hạng cao nhất (Kim Cương VIP) trước giống preview 1.2a
    final sorted = [...widget.plans];
    sorted.sort((a, b) => b.durationDays.compareTo(a.durationDays));
    return sorted;
  }

  Widget _card(MembershipPlan plan, List<MembershipPlan> ordered) =>
      _MembershipPlanCard(
        plan: plan,
        meta: _resolvePlanCardMeta(
          plan: plan,
          plans: ordered,
          activeMembership: widget.activeMembership,
        ),
        busy: widget.busy,
        onBuy: () => widget.onBuy(plan),
      );

  @override
  Widget build(BuildContext context) {
    final plans = _orderedPlans();
    if (plans.length == 1) return _card(plans.single, plans);

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final scrollBehavior = ScrollConfiguration.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cardWidth = (constraints.maxWidth * 0.78).clamp(242.0, 290.0);
        final stride = cardWidth + gap;

        return Column(
          children: [
            ScrollConfiguration(
              behavior: scrollBehavior.copyWith(
                dragDevices: {
                  ...scrollBehavior.dragDevices,
                  PointerDeviceKind.mouse,
                },
              ),
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: disableAnimations
                    ? null
                    : _MembershipPlanSnapPhysics(stride: stride),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, plan) in plans.indexed) ...[
                        if (index > 0) const SizedBox(width: gap),
                        SizedBox(width: cardWidth, child: _card(plan, plans)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _MembershipPlanSnapPhysics extends ScrollPhysics {
  const _MembershipPlanSnapPhysics({required this.stride, super.parent});

  final double stride;

  @override
  _MembershipPlanSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _MembershipPlanSnapPhysics(stride: stride, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange ||
        (position.pixels <= position.minScrollExtent && velocity <= 0) ||
        (position.pixels >= position.maxScrollExtent && velocity >= 0)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final page = position.pixels / stride;
    final momentum = (velocity / 900).clamp(-0.5, 0.5);
    final target = ((page + momentum).round() * stride).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final tolerance = toleranceFor(position);
    if ((target - position.pixels).abs() < tolerance.distance) return null;

    return ScrollSpringSimulation(
      const SpringDescription(mass: 1, stiffness: 170, damping: 25),
      position.pixels,
      target,
      velocity.clamp(-stride * 4, stride * 4),
      tolerance: tolerance,
    );
  }
}

class _MembershipPlanCard extends StatelessWidget {
  const _MembershipPlanCard({
    required this.plan,
    required this.meta,
    required this.busy,
    required this.onBuy,
  });

  final MembershipPlan plan;
  final _PlanCardMeta meta;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final description = (plan.description ?? '').trim().isNotEmpty
        ? plan.description!.trim()
        : resolveMembershipTierInfo(
            planName: plan.name,
            durationDays: plan.durationDays,
          ).summaryPerks;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: meta.borderColor, width: 1.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: meta.badgeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: meta.badgeColor.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Text(
                        meta.badgeLabel,
                        style: TextStyle(
                          color: meta.badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      formatMembershipMoney(plan.price),
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    Text(
                      meta.periodSuffix,
                      style: const TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '+${formatLoyaltyPoints(bonusPointsForPlanDuration(plan.durationDays))} điểm Meta Points thưởng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD5CCBF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: meta.isPrimaryCta
                  ? FilledButton(
                      onPressed: busy ? null : onBuy,
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        disabledBackgroundColor: MetaGymTheme.brandOrange
                            .withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        meta.ctaLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: busy ? null : onBuy,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaGymTheme.textPrimary,
                        backgroundColor: const Color(0x16FFFFFF),
                        side: const BorderSide(
                          color: Color(0x45FFF6EA),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        meta.ctaLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMembershipTile extends StatelessWidget {
  const _HistoryMembershipTile({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final color = membershipStatusColor(membership.status);
    final label = membership.status == 'EXPIRED'
        ? 'Đã hết hạn'
        : membership.label;
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.planName ?? membership.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMembershipDate(membership.startDate)} → '
                  '${formatMembershipDate(membership.endDate)}',
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
