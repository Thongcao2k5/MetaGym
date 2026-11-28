import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';
import 'package:provider/provider.dart';

/// Màn hình Lịch sử cộng / trừ / điều chỉnh điểm Meta Points.
class LoyaltyHistoryPage extends StatefulWidget {
  const LoyaltyHistoryPage({super.key});

  @override
  State<LoyaltyHistoryPage> createState() => _LoyaltyHistoryPageState();
}

class _LoyaltyHistoryPageState extends State<LoyaltyHistoryPage> {
  String _typeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _optionalLoyalty(context);
      if (ctrl != null && ctrl.transactions.isEmpty && !ctrl.isLoading) {
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

  Future<void> _openPaymentHistory() => MetaGymNavigation.pushOnce<void>(
    context,
    MetaGymPageRoute<void>(builder: (_) => const PaymentHistoryPage()),
  );

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final controller = context.watch<LoyaltyController>();
    final summary = controller.summary;
    final all = controller.transactions;
    final filtered = _typeFilter == 'ALL'
        ? all
        : all.where((tx) => tx.txType == _typeFilter).toList();

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
                  eyebrow: 'SỔ GIAO DỊCH ĐIỂM',
                  title: 'Lịch sử điểm',
                  actions: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      child: TextButton(
                        onPressed: _openPaymentHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'Hóa đơn ›',
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

                              // Khối tổng quan 2 loại điểm (Hero Glass đồng bộ)
                              MetaGymHeroGlassCard(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
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
                                            const SizedBox(height: 4),
                                            Text(
                                              formatLoyaltyPoints(
                                                summary?.availablePoints ?? 0,
                                              ),
                                              style: TextStyle(
                                                color: palette.primaryText,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                fontFeatures:
                                                    MetaGymTheme.tabularFigures,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      VerticalDivider(
                                        width: 24,
                                        thickness: 1,
                                        color:
                                            MetaGymTheme.isLightPalette(context)
                                            ? palette.borderSolid
                                            : MetaGymWarmGlassTokens
                                                  .metricPanelBorder,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Điểm xét hạng',
                                              style: TextStyle(
                                                color: palette.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatLoyaltyPoints(
                                                summary?.tierPoints ?? 0,
                                              ),
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                fontFeatures:
                                                    MetaGymTheme.tabularFigures,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: [
                                    _TxFilterChip(
                                      label: 'Tất cả (${all.length})',
                                      selected: _typeFilter == 'ALL',
                                      onTap: () =>
                                          setState(() => _typeFilter = 'ALL'),
                                    ),
                                    const SizedBox(width: 8),
                                    _TxFilterChip(
                                      label: 'Cộng điểm',
                                      selected: _typeFilter == 'EARN',
                                      onTap: () =>
                                          setState(() => _typeFilter = 'EARN'),
                                    ),
                                    const SizedBox(width: 8),
                                    _TxFilterChip(
                                      label: 'Trừ điểm',
                                      selected: _typeFilter == 'SPEND',
                                      onTap: () =>
                                          setState(() => _typeFilter = 'SPEND'),
                                    ),
                                    const SizedBox(width: 8),
                                    _TxFilterChip(
                                      label: 'Điều chỉnh',
                                      selected: _typeFilter == 'ADJUST',
                                      onTap: () => setState(
                                        () => _typeFilter = 'ADJUST',
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
                                        MetaGymIcons.workoutHistory,
                                        size: 36,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Chưa có giao dịch điểm nào',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Điểm sẽ được ghi nhận khi bạn đăng ký/gia hạn gói tập, điểm danh phòng tập hoặc đổi ưu đãi.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (final tx in filtered)
                                  _LoyaltyTxTile(tx: tx),
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

class _TxFilterChip extends StatelessWidget {
  const _TxFilterChip({
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

class _LoyaltyTxTile extends StatelessWidget {
  const _LoyaltyTxTile({required this.tx});

  final LoyaltyPointTransaction tx;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isPositive = tx.pointsDelta >= 0;
    final (toneColor, iconData) = switch (tx.txType) {
      'EARN' => (palette.success, Icons.add_rounded),
      'SPEND' => (palette.warning, Icons.redeem_rounded),
      _ => (palette.info, Icons.sync_alt_rounded),
    };
    final signedPoints =
        '${isPositive ? '+' : ''}${formatLoyaltyPoints(tx.pointsDelta)}';

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: toneColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: toneColor.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, size: 20, color: toneColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tx.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    tx.detail,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatMembershipDateTime(tx.createdAt),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: toneColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tx.statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: toneColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            signedPoints,
            style: TextStyle(
              color: isPositive ? palette.success : palette.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
