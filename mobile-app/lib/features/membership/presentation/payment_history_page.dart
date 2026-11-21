import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/data/payment_history_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_ui.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_detail_page.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final active = _memberships.where((item) => item.status == 'ACTIVE');
    final scheduled = _memberships.where((item) => item.status == 'SCHEDULED');

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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              if (_error != null)
                                MembershipErrorCard(
                                  message: _error!,
                                  onRetry: _load,
                                ),
                              const MembershipSectionHeader(
                                icon: Icons.verified_user_rounded,
                                iconColor: MetaGymTheme.progressGreen,
                                title: 'Gói đang hoạt động',
                              ),
                              if (active.isEmpty)
                                const MetaGymGlassCard(
                                  margin: EdgeInsets.only(bottom: 14),
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Chưa có gói đang hoạt động.',
                                    style: TextStyle(color: Color(0xFFD5CCBF)),
                                  ),
                                ),
                              for (final item in active)
                                _MembershipPeriodCard(
                                  title: _membershipName(item),
                                  membership: item,
                                  color: MetaGymTheme.progressGreen,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              if (scheduled.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const MembershipSectionHeader(
                                  icon: Icons.schedule_rounded,
                                  iconColor: MetaGymTheme.reflectionBlue,
                                  title: 'Gói sắp tới',
                                ),
                                for (final item in scheduled)
                                  _MembershipPeriodCard(
                                    title: _membershipName(item),
                                    membership: item,
                                    color: MetaGymTheme.reflectionBlue,
                                    icon: Icons.schedule_rounded,
                                  ),
                              ],
                              const SizedBox(height: 12),
                              const MembershipSectionHeader(
                                icon: Icons.receipt_long_rounded,
                                iconColor: MetaGymTheme.brandOrange,
                                title: 'Lịch sử giao dịch',
                              ),
                              if (_payments.isEmpty)
                                const MetaGymGlassCard(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Chưa có giao dịch.',
                                    style: TextStyle(color: Color(0xFFD5CCBF)),
                                  ),
                                ),
                              for (final payment in _payments)
                                MetaGymGlassCard(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: MetaGymTap(
                                    borderRadius: BorderRadius.circular(
                                      MetaGymTheme.radiusCard,
                                    ),
                                    onTap: () => MetaGymNavigation.pushOnce(
                                      context,
                                      MetaGymPageRoute<void>(
                                        builder: (_) => PaymentDetailPage(
                                          paymentId: payment.id,
                                          service: _service!,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: membershipStatusColor(
                                                payment.status,
                                              ).withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: Icon(
                                              Icons.qr_code_2_rounded,
                                              color: membershipStatusColor(
                                                payment.status,
                                              ),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  payment.planName ??
                                                      'Giao dịch',
                                                  style: const TextStyle(
                                                    color: MetaGymTheme
                                                        .textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${payment.amount == null ? '' : formatMembershipMoney(payment.amount!)} • ${payment.statusLabel}',
                                                  style: const TextStyle(
                                                    color: Color(0xFFD5CCBF),
                                                    fontSize: 13,
                                                    fontFeatures: [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF9AA3B2),
                                          ),
                                        ],
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

class _MembershipPeriodCard extends StatelessWidget {
  const _MembershipPeriodCard({
    required this.title,
    required this.membership,
    required this.color,
    required this.icon,
  });

  final String title;
  final Membership membership;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatMembershipDate(membership.startDate)} → '
                  '${formatMembershipDate(membership.endDate)}',
                  style: const TextStyle(
                    color: Color(0xFFD5CCBF),
                    fontSize: 13,
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
