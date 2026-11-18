import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_checkout_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';
import 'package:provider/provider.dart';

/// Màn hình Gói tập hội viên đồng bộ bảng màu Warm Smoked Glass
/// (`DESIGN.md` / `MASTER.md`) cùng Trang chủ Hội viên & Hồ sơ.
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key, this.paymentReturnId, this.paymentReturnMethod});

  final String? paymentReturnId;
  final String? paymentReturnMethod;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<MembershipController>();
      final paymentId = widget.paymentReturnId;
      final method = widget.paymentReturnMethod;
      if (paymentId != null && method != null &&
          await controller.resumeOnlinePayment(paymentId, method: method)) {
        if (mounted) await _openCheckout(const MembershipCheckoutPage());
        return;
      }
      if (mounted) await controller.load();
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
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted && controller.pendingPayment == null) await controller.load();
  }

  Future<void> _openHistory() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const PaymentHistoryPage()),
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MembershipController>();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                const MembershipTopBar(
                  eyebrow: 'HỘI VIÊN & ƯU ĐÃI',
                  title: 'Gói tập',
                ),
                Expanded(
                  child: controller.isLoading && controller.plans.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: const Color(0xFF2B2622),
                          onRefresh: () => controller.load(),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (controller.purchaseResult case final result?)
                                _PurchaseSuccessBanner(membership: result),
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

                              // 1. THẺ HỘI VIÊN CỦA BẠN (NỔI BẬT TRÊN CÙNG)
                              const MembershipSectionHeader(
                                icon: Icons.workspace_premium_rounded,
                                iconColor: MetaGymTheme.progressGreen,
                                title: 'Gói của tôi',
                              ),
                              if (controller.memberships.isEmpty)
                                const _EmptyMembershipHeroCard()
                              else
                                for (final item in controller.memberships)
                                  _ActiveMembershipHeroCard(
                                    membership: item,
                                    now: now,
                                  ),

                              // 2. DANH SÁCH GÓI ĐANG BÁN (PHÂN HẠNG CHI TIẾT)
                              if (controller.pendingPayment == null) ...[
                                const SizedBox(height: 8),
                                MembershipSectionHeader(
                                  icon: Icons.bolt_rounded,
                                  iconColor: MetaGymTheme.brandOrange,
                                  title: 'Gói đang bán',
                                  trailing: controller.plans.isNotEmpty
                                      ? Text(
                                          '${controller.plans.length} lựa chọn',
                                          style: const TextStyle(
                                            color: MetaGymTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                                if (controller.plans.isEmpty &&
                                    controller.errorMessage == null)
                                  const MetaGymGlassCard(
                                    padding: EdgeInsets.all(18),
                                    child: Text(
                                      'Chưa có gói tập đang bán.',
                                      style: TextStyle(
                                        color: Color(0xFFD5CCBF),
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                else if (controller.plans.isNotEmpty)
                                  _MembershipPlanCarousel(
                                    plans: controller.plans,
                                    busy: controller.isLoading,
                                    onBuy: _reviewPurchase,
                                  ),
                              ],

                              // 3. LỊCH SỬ GÓI & GIAO DỊCH
                              const SizedBox(height: 10),
                              MembershipSectionHeader(
                                icon: Icons.history_rounded,
                                iconColor: MetaGymTheme.reflectionBlue,
                                title: 'Lịch sử gói',
                                trailing: TextButton.icon(
                                  onPressed: _openHistory,
                                  style: TextButton.styleFrom(
                                    foregroundColor: MetaGymTheme.brandOrange,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Giao dịch',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              if (controller.history.isEmpty)
                                const MetaGymGlassCard(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        color: Color(0xFFB7B2AF),
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Chưa có lịch sử gói tập.',
                                          style: TextStyle(
                                            color: Color(0xFFEAE6E2),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
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

class _PurchaseSuccessBanner extends StatelessWidget {
  const _PurchaseSuccessBanner({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x242ECC71),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x662ECC71)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: MetaGymTheme.progressGreen,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thanh toán thành công. ${membership.label} '
              '(${formatMembershipDate(membership.startDate)} → '
              '${formatMembershipDate(membership.endDate)}).',
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
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
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0x28F39C12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0x60F39C12)),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: MetaGymTheme.warningAmber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giao dịch chờ thanh toán',
                      style: TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatPaymentMethodLabel(payment.method)} · Chờ xác nhận',
                      style: const TextStyle(
                        color: MetaGymTheme.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (payment.planName != null || payment.amount != null) ...[
            const SizedBox(height: 12),
            MetaGymMetricPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      payment.planName ?? 'Gói tập hội viên',
                      style: const TextStyle(
                        color: Color(0xFFEAE6E2),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (payment.amount case final amount?)
                    Text(
                      formatMembershipMoney(amount),
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          MembershipPrimaryButton(
            label: 'Tiếp tục thanh toán',
            icon: Icons.arrow_forward_rounded,
            onPressed: busy ? null : onContinue,
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
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x24FF5E36),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x52FF5E36)),
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              color: MetaGymTheme.brandOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn chưa có gói đang hoạt động.',
                  style: TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Chọn gói tập phù hợp bên dưới để kích hoạt quyền check-in QR tại phòng gym và kết nối Coach.',
                  style: TextStyle(
                    color: Color(0xFFD5CCBF),
                    fontSize: 13,
                    height: 1.45,
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

class _ActiveMembershipHeroCard extends StatelessWidget {
  const _ActiveMembershipHeroCard({
    required this.membership,
    required this.now,
  });

  final Membership membership;
  final DateTime now;

  double? _progressRatio(int remaining) {
    final start = DateTime.tryParse('${membership.startDate}T00:00:00Z');
    final end = DateTime.tryParse('${membership.endDate}T00:00:00Z');
    if (start == null || end == null) return null;
    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 0) return null;
    final used = (totalDays - remaining).clamp(0, totalDays);
    return (used / totalDays).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final color = membershipStatusColor(membership.status);
    final remaining = membership.remainingDays(now);
    final progress = remaining != null ? _progressRatio(remaining) : null;

    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.42)),
                ),
                child: Icon(
                  membership.status == 'ACTIVE'
                      ? Icons.verified_rounded
                      : Icons.event_available_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.planName ?? 'Gói hội viên',
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      membership.status == 'ACTIVE'
                          ? 'Thẻ hội viên đang kích hoạt'
                          : 'Gói kế tiếp sẽ tự kích hoạt',
                      style: const TextStyle(
                        color: Color(0xFFD5CCBF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              MembershipStatusPill(label: membership.label, color: color),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$remaining',
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Còn $remaining ngày',
                  style: const TextStyle(
                    color: MetaGymTheme.progressGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.04, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetaGymMetricPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatMembershipDate(membership.startDate),
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetaGymMetricPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hết hạn',
                        style: TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatMembershipDate(membership.endDate),
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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

class _PlanTierMeta {
  const _PlanTierMeta({
    required this.badgeLabel,
    required this.badgeColor,
    required this.isFeatured,
  });

  final String badgeLabel;
  final Color badgeColor;
  final bool isFeatured;
}

_PlanTierMeta _resolvePlanTier(
  MembershipPlan plan,
  List<MembershipPlan> plans,
) {
  if (plans.length == 1) {
    return const _PlanTierMeta(
      badgeLabel: 'KHUYÊN DÙNG',
      badgeColor: MetaGymTheme.brandOrange,
      isFeatured: true,
    );
  }
  if (plan.durationDays >= 300) {
    return const _PlanTierMeta(
      badgeLabel: 'TIẾT KIỆM NHẤT',
      badgeColor: MetaGymTheme.progressGreen,
      isFeatured: false,
    );
  }
  if (plan.durationDays >= 28 && plan.durationDays <= 45) {
    return const _PlanTierMeta(
      badgeLabel: 'PHỔ BIẾN NHẤT',
      badgeColor: MetaGymTheme.brandOrange,
      isFeatured: true,
    );
  }
  return const _PlanTierMeta(
    badgeLabel: 'LINH HOẠT',
    badgeColor: MetaGymTheme.reflectionBlue,
    isFeatured: false,
  );
}

class _MembershipPlanCarousel extends StatefulWidget {
  const _MembershipPlanCarousel({
    required this.plans,
    required this.busy,
    required this.onBuy,
  });

  final List<MembershipPlan> plans;
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

  Widget _card(MembershipPlan plan) => _MembershipPlanCard(
    plan: plan,
    tier: _resolvePlanTier(plan, widget.plans),
    busy: widget.busy,
    onBuy: () => widget.onBuy(plan),
  );

  @override
  Widget build(BuildContext context) {
    final plans = widget.plans;
    if (plans.length == 1) return _card(plans.single);

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final scrollBehavior = ScrollConfiguration.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final peek = constraints.maxWidth >= 300 ? 26.0 : 0.0;
        final cardWidth = constraints.maxWidth - peek;
        final stride = cardWidth + gap;
        double position() => _scroll.hasClients ? _scroll.offset / stride : 0;
        double focusAt(double page, int index) {
          final distance = (page - index).abs().clamp(0.0, 1.0);
          return 1 - Curves.easeInOut.transform(distance);
        }

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, plan) in plans.indexed) ...[
                      if (index > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cardWidth,
                        child: AnimatedBuilder(
                          animation: _scroll,
                          child: _card(plan),
                          builder: (context, child) {
                            if (disableAnimations) return child!;
                            return Transform.scale(
                              alignment: Alignment.topCenter,
                              scale: 0.98 + focusAt(position(), index) * 0.02,
                              child: child,
                            );
                          },
                        ),
                      ),
                    ],
                    SizedBox(width: peek),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final page = position();
                final selected = page.round().clamp(0, plans.length - 1);
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (index, plan) in plans.indexed)
                      Semantics(
                        selected: selected == index,
                        child: IconButton(
                          tooltip: plan.name,
                          onPressed: () {
                            final offset = (index * stride)
                                .clamp(0.0, _scroll.position.maxScrollExtent)
                                .toDouble();
                            if (disableAnimations) {
                              _scroll.jumpTo(offset);
                            } else {
                              _scroll.animateTo(
                                offset,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          icon: _PlanPositionDot(
                            emphasis: disableAnimations
                                ? (selected == index ? 1 : 0)
                                : focusAt(page, index),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PlanPositionDot extends StatelessWidget {
  const _PlanPositionDot({required this.emphasis});

  final double emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6 + 12 * emphasis,
      height: 6,
      decoration: BoxDecoration(
        color: Color.lerp(
          MetaGymTheme.textSecondary,
          MetaGymTheme.brandOrange,
          emphasis,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
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
    required this.tier,
    required this.busy,
    required this.onBuy,
  });

  final MembershipPlan plan;
  final _PlanTierMeta tier;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final perDay = plan.durationDays > 1 && plan.price > 0
        ? (plan.price / plan.durationDays).round()
        : null;
    final perMonth = plan.durationDays >= 300 && plan.price > 0
        ? (plan.price / 12).round()
        : null;

    final cardContent = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tier.badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: tier.badgeColor.withValues(alpha: 0.42),
                  ),
                ),
                child: Icon(
                  tier.isFeatured
                      ? Icons.local_fire_department_rounded
                      : Icons.card_membership_rounded,
                  color: tier.badgeColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thời hạn ${plan.durationDays} ngày',
                      style: const TextStyle(
                        color: Color(0xFFD5CCBF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              MembershipStatusPill(
                label: tier.badgeLabel,
                color: tier.badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatMembershipMoney(plan.price),
                style: TextStyle(
                  color: tier.isFeatured
                      ? MetaGymTheme.brandOrange
                      : MetaGymTheme.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (perDay != null)
                Text(
                  perMonth != null
                      ? '~${formatMembershipMoney(perMonth)} / tháng'
                      : '~${formatMembershipMoney(perDay)} / ngày',
                  style: const TextStyle(
                    color: Color(0xFFB7B2AF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (plan.description case final description?
              when description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE0D9CE),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x28FFF6EA)),
          const SizedBox(height: 12),
          const _PlanBenefitRow(text: 'Mở khóa check-in QR tại phòng tập'),
          const SizedBox(height: 6),
          const _PlanBenefitRow(
            text: 'Đồng bộ lịch tập, nhật ký & thuê Coach 1:1',
          ),
          const SizedBox(height: 16),
          MembershipPrimaryButton(
            label: 'Mua',
            icon: Icons.arrow_forward_rounded,
            onPressed: busy ? null : onBuy,
          ),
        ],
      ),
    );

    if (tier.isFeatured) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: MetaGymTheme.brandOrange.withValues(alpha: 0.72),
              width: 1.3,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xD4382A23), Color(0xCE28221E)],
            ),
            boxShadow: [
              BoxShadow(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: cardContent,
        ),
      );
    }

    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: cardContent,
    );
  }
}

class _PlanBenefitRow extends StatelessWidget {
  const _PlanBenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: MetaGymTheme.progressGreen,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD5CCBF),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryMembershipTile extends StatelessWidget {
  const _HistoryMembershipTile({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final color = membershipStatusColor(membership.status);
    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.history_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membership.planName ?? membership.label,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMembershipDate(membership.startDate)} → '
                  '${formatMembershipDate(membership.endDate)}',
                  style: const TextStyle(
                    color: Color(0xFFB7B2AF),
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          MembershipStatusPill(label: membership.label, color: color),
        ],
      ),
    );
  }
}
