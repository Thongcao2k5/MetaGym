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
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_detail_page.dart';
import 'package:provider/provider.dart';

enum _PaymentFilterTab { all, membership, coach }

/// Màn hình 1.4 Thanh toán & Giao dịch đồng bộ Warm Smoked Glass.
class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({this.service, super.key});

  final PaymentHistoryService? service;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  PaymentHistoryService? _service;
  List<Payment> _payments = const [];
  List<Membership> _memberships = const [];
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
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _memberships = memberships;
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
    final hasCoachInvoice = _payments.any(_isCoachPayment);

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
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
                          backgroundColor: const Color(0xFF2B2622),
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
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
                              Row(
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
                                          ? MetaGymTheme.progressGreen
                                          : const Color(0xFFA8B1C2),
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
                                      title: hasCoachInvoice ||
                                              primaryActive != null
                                          ? 'PT 24 buổi'
                                          : 'Chưa đăng ký',
                                      pillLabel: hasCoachInvoice ||
                                              primaryActive != null
                                          ? 'Còn 14 buổi'
                                          : 'Tìm Coach',
                                      pillColor: hasCoachInvoice ||
                                              primaryActive != null
                                          ? MetaGymTheme.brandOrange
                                          : const Color(0xFFA8B1C2),
                                      accentBorder: false,
                                      onTap: () => _openRouteIfAvailable(
                                        '/member/features/sessions',
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (scheduled.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const MembershipSectionHeader(
                                  icon: Icons.schedule_rounded,
                                  iconColor: MetaGymTheme.reflectionBlue,
                                  title: 'Gói sắp tới',
                                ),
                                for (final item in scheduled)
                                  _ScheduledPeriodTile(
                                    title: _membershipName(item),
                                    membership: item,
                                  ),
                              ],

                              const SizedBox(height: 14),

                              // 2. BỘ LỌC 3 TAB (TẤT CẢ | THẺ HỘI VIÊN | GÓI COACH)
                              Container(
                                padding: const EdgeInsets.all(4),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xB8211E1C),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0x9A8C8176),
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
                                  style: const TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ),
                              if (filtered.isEmpty)
                                const MetaGymGlassCard(
                                  solid: false,
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                    'Chưa có giao dịch.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFD5CCBF),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentBorder
              ? const Color(0x88FF8A5B)
              : const Color(0xA3A79D92),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MetaGymTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.16),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
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
            color: selected ? Colors.white : MetaGymTheme.textSecondary,
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
        ? MetaGymTheme.progressGreen
        : payment.status == 'SUCCESS'
        ? const Color(0xFFA8B1C2)
        : statusColor;

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x70181513),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x45FFF6EA)),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(_methodSvg(payment.method), size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.planName ?? 'Giao dịch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subLine.isNotEmpty
                          ? subLine
                          : formatPaymentMethodLabel(payment.method),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.textSecondary,
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
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.16),
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
              color: MetaGymTheme.reflectionBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: MetaGymTheme.reflectionBlue,
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
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
          MembershipStatusPill(
            label: membership.label,
            color: MetaGymTheme.reflectionBlue,
          ),
        ],
      ),
    );
  }
}
