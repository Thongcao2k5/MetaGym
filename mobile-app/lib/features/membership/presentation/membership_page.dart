import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:provider/provider.dart';

/// Màn hình Gói tập hội viên đồng bộ bảng màu & định dạng thẻ
/// với Trang chủ Hội viên (`member_dashboard_view.dart`) và Hồ sơ (`profile_page.dart`).
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MembershipController>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MembershipController>();
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        MetaGymCircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Quay lại',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HỘI VIÊN & ƯU ĐÃI',
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Gói tập',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MetaGymCircleIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Tải lại',
                        onTap: controller.isLoading ? null : controller.load,
                      ),
                    ],
                  ),
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (controller.errorMessage != null)
                                MetaGymGlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFF15B64),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          controller.errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFFF857D),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (controller.pendingPayment
                                  case final payment?) ...[
                                MetaGymHeroGlassCard(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0x24FF5A36),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0x4DFF5A36),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.qr_code_scanner_rounded,
                                              color: MetaGymTheme.brandOrange,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Thông tin thanh toán QR mô phỏng',
                                              style: TextStyle(
                                                color: Color(0xFFF7F9FC),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      MetaGymMetricPanel(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: SelectableText(
                                            payment.qrPayload ??
                                                'Không có dữ liệu QR',
                                            style: const TextStyle(
                                              color: Color(0xFFF7F9FC),
                                              fontSize: 14,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              MetaGymTheme.brandOrange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        onPressed: controller.isConfirming
                                            ? null
                                            : controller.confirmPayment,
                                        child: Text(
                                          controller.isConfirming
                                              ? 'Đang xác nhận…'
                                              : 'Xác nhận đã thanh toán',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12, top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        color: MetaGymTheme.brandOrange,
                                        size: 20,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Gói đang bán',
                                        style: TextStyle(
                                          color: Color(0xFFF7F9FC),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...controller.plans.map(
                                  (plan) => MetaGymGlassCard(
                                    featured: true,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0x24FF5A36),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x4DFF5A36),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.card_membership_rounded,
                                            color: MetaGymTheme.brandOrange,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                plan.name,
                                                style: const TextStyle(
                                                  color: Color(0xFFF7F9FC),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${money.format(plan.price)} • ${plan.durationDays} ngày',
                                                style: const TextStyle(
                                                  color: Color(0xFFEAE6E2),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                MetaGymTheme.brandOrange,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 10,
                                            ),
                                          ),
                                          onPressed: controller.isLoading
                                              ? null
                                              : () => controller.buy(plan),
                                          child: const Text(
                                            'Mua',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      color: MetaGymTheme.progressGreen,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Gói hiện tại',
                                      style: TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (controller.memberships.isEmpty)
                                const MetaGymGlassCard(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFFB7B2AF),
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Bạn chưa có gói đang hoạt động.',
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
                                ...controller.memberships.map(
                                  (item) => MetaGymHeroGlassCard(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0x262ECC71),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x4D2ECC71),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: MetaGymTheme.progressGreen,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.status,
                                                style: const TextStyle(
                                                  color: Color(0xFFF7F9FC),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.startDate} → ${item.endDate}',
                                                style: const TextStyle(
                                                  color: Color(0xFFEAE6E2),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      color: Color(0xFF8EB9E5),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Lịch sử',
                                      style: TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                                          'Chưa có lịch sử giao dịch.',
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
                                ...controller.history.map(
                                  (item) => MetaGymGlassCard(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0x268EB9E5),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.history_rounded,
                                            color: Color(0xFF8EB9E5),
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
                                                item.status,
                                                style: const TextStyle(
                                                  color: Color(0xFFF7F9FC),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.startDate} → ${item.endDate}',
                                                style: const TextStyle(
                                                  color: Color(0xFFB7B2AF),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
