import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_detail_page.dart';
import 'package:provider/provider.dart';

enum _PaymentFilterTab { all, membership, coach }

/// Màn hình 1.4 Thanh toán & Giao dịch đồng bộ Warm Smoked Glass.
class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({
    this.service,
    this.coachEntitlementsLoader,
    super.key,
  });

  final PaymentHistoryService? service;
  final Future<List<CoachRecord>> Function()? coachEntitlementsLoader;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  PaymentHistoryService? _service;
  List<Payment> _payments = const [];
  List<Membership> _memberships = const [];
  List<CoachRecord> _coachEntitlements = const [];
  bool _loading = true;
  String? _error;
  _PaymentFilterTab _filter = _PaymentFilterTab.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? PaymentHistoryApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<List<CoachRecord>> _loadCoachEntitlementsSafely() async {
    try {
      if (widget.coachEntitlementsLoader != null) {
        return await widget.coachEntitlementsLoader!();
      }
      if (widget.service != null) return const [];
      final client = optionalProvider<ApiClient>(context);
      if (client == null) return const [];
      return await CoachV2Api(client).list('/coach-entitlements');
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final payments = await _service!.getPayments();
      final memberships = await _service!.getCurrentMemberships();
      final entitlements = await _loadCoachEntitlementsSafely();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _memberships = memberships;
        _coachEntitlements = entitlements;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải dữ liệu thanh toán.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _membershipName(Membership membership) {
    if (membership.planName case final name? when name.trim().isNotEmpty) {
      return name;
    }
    for (final payment in _payments) {
      if (payment.id == membership.sourcePaymentId &&
          payment.planName != null) {
        return payment.planName!;
      }
    }
    return 'Gói tập';
  }

  bool _isCoachPayment(Payment payment) {
    final lower = (payment.planName ?? '').toLowerCase();
    return lower.contains('coach') || lower.contains('pt ');
  }

  bool _isEntitlementExpired(CoachRecord pack, DateTime now) {
    final endsOnRaw = pack['endsOn'] as String?;
    if (endsOnRaw == null || endsOnRaw.isEmpty) return false;
    final parsed = DateTime.tryParse(endsOnRaw);
    if (parsed == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(parsed.year, parsed.month, parsed.day);
    return endDay.isBefore(today);
  }

  ({String title, String pillLabel, Color pillColor}) _resolveCoachBentoState(
    DateTime now,
    Payment? latestCoachInvoice,
  ) {
    final activeEntitlement = _coachEntitlements.where((pack) {
      final status = pack['status'] as String?;
      final rel = pack['relationshipStatus'] as String?;
      final remaining = (pack['remainingSessions'] as num?)?.toInt() ?? 0;
      return status == 'ACTIVE' &&
          rel != 'PAUSED' &&
          !_isEntitlementExpired(pack, now) &&
          remaining > 0;
    }).firstOrNull;

    if (activeEntitlement != null) {
      final remaining =
          (activeEntitlement['remainingSessions'] as num?)?.toInt() ?? 0;
      final planName = (activeEntitlement['planName'] as String?)?.trim();
      return (
        title: (planName != null && planName.isNotEmpty)
            ? planName
            : (latestCoachInvoice?.planName ?? 'Gói Coach 1:1'),
        pillLabel: 'Còn $remaining buổi',
        pillColor: MetaGymTheme.brandOrange,
      );
    }

    final latestEntitlement = _coachEntitlements.firstOrNull;
    if (latestEntitlement != null) {
      final planName = (latestEntitlement['planName'] as String?)?.trim();
      final rel = latestEntitlement['relationshipStatus'] as String?;
      final status = latestEntitlement['status'] as String?;
      final remaining =
          (latestEntitlement['remainingSessions'] as num?)?.toInt() ?? 0;
      final (label, color) = rel == 'PAUSED'
          ? ('Tạm ngưng', MetaGymTheme.warningAmber)
          : _isEntitlementExpired(latestEntitlement, now)
          ? ('Hết hạn', const Color(0xFFA8B1C2))
          : (status == 'ACTIVE' && remaining <= 0)
          ? ('Hết lượt', const Color(0xFFA8B1C2))
          : status == 'QUEUED'
          ? ('Chờ kích hoạt', MetaGymTheme.reflectionBlue)
          : ('Đã kết thúc', const Color(0xFFA8B1C2));
      return (
        title: (planName != null && planName.isNotEmpty)
            ? planName
            : (latestCoachInvoice?.planName ?? 'Gói Coach 1:1'),
        pillLabel: label,
        pillColor: color,
      );
    }

    if (latestCoachInvoice != null) {
      return (
        title: latestCoachInvoice.planName ?? 'Gói Coach 1:1',
        pillLabel: 'Xem lịch Coach',
        pillColor: const Color(0xFFA8B1C2),
      );
    }

    return (
      title: 'Chưa đăng ký',
      pillLabel: 'Tìm Coach',
      pillColor: const Color(0xFFA8B1C2),
    );
  }

  List<Payment> get _filteredPayments => switch (_filter) {
    _PaymentFilterTab.all => _payments,
    _PaymentFilterTab.membership =>
      _payments.where((p) => !_isCoachPayment(p)).toList(),
    _PaymentFilterTab.coach => _payments.where(_isCoachPayment).toList(),
  };

  void _openRouteIfAvailable(String route) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final now = DateTime.now();
    final active = _memberships
        .where((item) => item.status == 'ACTIVE')
        .toList();
    final scheduled = _memberships
        .where((item) => item.status == 'SCHEDULED')
        .toList();
    final filtered = _filteredPayments;
    final primaryActive = active.firstOrNull;
    final remainingDays = primaryActive?.remainingDays(now);
    final latestCoachInvoice = _payments.where(_isCoachPayment).firstOrNull;
    final coachBento = _resolveCoachBentoState(now, latestCoachInvoice);

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
                  eyebrow: 'GIAO DỊCH HỘI VIÊN',
                  title: 'Thanh toán',
                  actions: [
                    MetaGymCircleIconButton(
                      svgAsset: MetaGymIcons.commonRefresh,
                      icon: Icons.refresh_rounded,
                      tooltip: 'Tải lại',
                      onTap: _loading ? null : _load,
                    ),
                  ],
                ),
                Expanded(
                  child: _loading && _payments.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: palette.surfaceSolid,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 36),
                            children: [
                              if (_error != null)
                                MembershipErrorCard(
                                  message: _error!,
                                  onRetry: _load,
                                ),

                              // 1. DỊCH VỤ ĐANG HOẠT ĐỘNG (2 CỘT BENTO WARM SMOKED GLASS)
                              const MembershipSectionHeader(
                                svgAsset: MetaGymIcons.membershipActiveSeal,
                                title: 'Dịch vụ đang hoạt động',
                              ),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _ActiveServiceBentoCard(
                                        eyebrow: 'Thẻ Hội viên',
                                        title: primaryActive != null
                                            ? _membershipName(primaryActive)
                                            : 'Chưa có gói',
                                        pillLabel: remainingDays != null
                                            ? 'Còn $remainingDays ngày'
                                            : primaryActive != null
                                            ? primaryActive.label
                                            : 'Chưa kích hoạt',
                                        pillColor: primaryActive != null
                                            ? palette.success
                                            : palette.textSecondary,
                                        accentBorder: primaryActive != null,
                                        onTap: () => _openRouteIfAvailable(
                                          '/member/features/membership',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ActiveServiceBentoCard(
                                        eyebrow: 'Gói Coach 1:1',
                                        title: coachBento.title,
                                        pillLabel: coachBento.pillLabel,
                                        pillColor: coachBento.pillColor,
                                        accentBorder: false,
                                        onTap: () => _openRouteIfAvailable(
                                          '/member/features/sessions',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (scheduled.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                MembershipSectionHeader(
                                  icon: Icons.schedule_rounded,
                                  iconColor: palette.reflection,
                                  title: 'Gói sắp tới',
                                ),
                                for (final item in scheduled)
                                  _ScheduledPeriodTile(
                                    title: _membershipName(item),
                                    membership: item,
                                  ),
                              ],

                              const SizedBox(height: 10),

                              // 2. BỘ LỌC 3 TAB (TẤT CẢ | THẺ HỘI VIÊN | GÓI COACH)
                              Container(
                                padding: const EdgeInsets.all(3),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: palette.metricPanelBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.metricPanelBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _FilterPillButton(
                                        label: 'Tất cả',
                                        selected:
                                            _filter == _PaymentFilterTab.all,
                                        onTap: () => setState(
                                          () =>
                                              _filter = _PaymentFilterTab.all,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: _FilterPillButton(
                                        label: 'Thẻ Hội viên',
                                        selected:
                                            _filter ==
                                            _PaymentFilterTab.membership,
                                        onTap: () => setState(
                                          () => _filter =
                                              _PaymentFilterTab.membership,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: _FilterPillButton(
                                        label: 'Gói Coach',
                                        selected:
                                            _filter == _PaymentFilterTab.coach,
                                        onTap: () => setState(
                                          () => _filter =
                                              _PaymentFilterTab.coach,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 3. LỊCH SỬ GIAO DỊCH
                              MembershipSectionHeader(
                                svgAsset: MetaGymIcons.paymentReceiptInvoice,
                                title: 'Lịch sử giao dịch',
                                trailing: Text(
                                  '${filtered.length} hóa đơn',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ),
                              if (filtered.isEmpty)
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.all(18),
                                  child: Text(
                                    'Chưa có giao dịch.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: palette.textWarmMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                for (final payment in filtered)
                                  _PaymentInvoiceCard(
                                    payment: payment,
                                    onTap: () => MetaGymNavigation.pushOnce(
                                      context,
                                      MetaGymPageRoute<void>(
                                        builder: (_) => PaymentDetailPage(
                                          paymentId: payment.id,
                                          service: _service!,
                                        ),
                                      ),
                                    ),
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

class _ActiveServiceBentoCard extends StatelessWidget {
  const _ActiveServiceBentoCard({
    required this.eyebrow,
    required this.title,
    required this.pillLabel,
    required this.pillColor,
    required this.accentBorder,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String pillLabel;
  final Color pillColor;
  final bool accentBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Container(
      decoration: BoxDecoration(
        color: isLight ? palette.surfaceSolid : const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentBorder
              ? (isLight
                    ? MetaGymTheme.brandOrange.withValues(alpha: 0.55)
                    : const Color(0x88FF8A5B))
              : palette.warmGlassBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? const Color(0x120F172A)
                : const Color(0x40000000),
            blurRadius: isLight ? 12 : 16,
            offset: Offset(0, isLight ? 4 : 8),
          ),
        ],
      ),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
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
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pillColor.withValues(alpha: 0.42)),
                ),
                child: Text(
                  pillLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pillColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPillButton extends StatelessWidget {
  const _FilterPillButton({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? MetaGymTheme.brandOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : palette.textSecondary,
            fontSize: 12.2,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PaymentInvoiceCard extends StatelessWidget {
  const _PaymentInvoiceCard({required this.payment, required this.onTap});

  final Payment payment;
  final VoidCallback onTap;

  String _methodSvg(String? method) => switch (method) {
    'VNPAY' => MetaGymIcons.payVnpay,
    'MOMO' => MetaGymIcons.payMomo,
    'ZALOPAY' => MetaGymIcons.payZalopay,
    _ => MetaGymIcons.paymentReceiptInvoice,
  };

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final statusColor = membershipStatusColor(payment.status);
    final dateText = payment.createdAt != null
        ? formatMembershipDate(payment.createdAt!)
        : null;
    final codeText = payment.transactionCode != null
        ? '#${payment.transactionCode}'
        : null;
    final subLine = [
      if (dateText != null && dateText.isNotEmpty) dateText,
      if (codeText != null && codeText.isNotEmpty) codeText,
    ].join(' · ');

    final rewardPoints =
        payment.status == 'SUCCESS' && (payment.amount ?? 0) >= 1000000
        ? (payment.amount! / 20000).round()
        : null;
    final badgeText = rewardPoints != null
        ? '+$rewardPoints điểm'
        : payment.status == 'SUCCESS'
        ? 'Đã hoàn tất'
        : payment.statusLabel;
    final badgeColor = rewardPoints != null
        ? palette.success
        : payment.status == 'SUCCESS'
        ? palette.textSecondary
        : statusColor;

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 8),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isLight
                      ? palette.metricPanelBg
                      : const Color(0x70181513),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight
                        ? palette.metricPanelBorder
                        : const Color(0x45FFF6EA),
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(_methodSvg(payment.method), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.planName ?? 'Giao dịch',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subLine.isNotEmpty
                          ? subLine
                          : formatPaymentMethodLabel(payment.method),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (payment.amount != null)
                    Text(
                      formatMembershipMoney(payment.amount!),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduledPeriodTile extends StatelessWidget {
  const _ScheduledPeriodTile({required this.title, required this.membership});

  final String title;
  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.reflection.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: palette.reflection,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMembershipDate(membership.startDate)} → '
                  '${formatMembershipDate(membership.endDate)}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          MembershipStatusPill(
            label: membership.label,
            color: palette.reflection,
          ),
        ],
      ),
    );
  }
}
