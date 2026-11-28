import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/membership/data/loyalty_service.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/loyalty_models.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_history_page.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_my_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/loyalty_rewards_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:provider/provider.dart';

class _FakeMembershipService implements MembershipService {
  @override
  Future<List<MembershipPlan>> getPlans() async => const [
    MembershipPlan(
      id: 'plan-1m',
      name: 'Gói 1 Tháng',
      price: 590000,
      durationDays: 30,
      status: 'ACTIVE',
      description: 'Tập không giới hạn 30 ngày',
    ),
    MembershipPlan(
      id: 'plan-3m',
      name: 'Gói 3 Tháng',
      price: 1590000,
      durationDays: 90,
      status: 'ACTIVE',
      description: 'Tiết kiệm hơn cho lộ trình 90 ngày',
    ),
  ];

  @override
  Future<List<Membership>> getCurrentMemberships() async => const [
    Membership(
      id: 'mem-1',
      startDate: '2026-10-01',
      endDate: '2027-01-01',
      status: 'ACTIVE',
      planName: 'Gói 3 Tháng',
    ),
  ];

  @override
  Future<List<Membership>> getMembershipHistory() async =>
      getCurrentMemberships();

  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      const MembershipQuote(
        price: 590000,
        durationDays: 30,
        startDate: '2027-01-02',
        endDate: '2027-02-01',
        isRenewal: true,
      );

  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) async => const Payment(id: 'pay-1', status: 'PENDING', amount: 590000);

  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) async =>
      const PurchaseResult(
        payment: Payment(id: 'pay-1', status: 'SUCCESS', amount: 590000),
        membership: Membership(
          id: 'mem-2',
          startDate: '2027-01-02',
          endDate: '2027-02-01',
          status: 'ACTIVE',
          planName: 'Gói 1 Tháng',
        ),
      );
}

class _FakeLoyaltyService implements LoyaltyService {
  int _availablePoints = 1240;
  final int _tierPoints = 2150;

  final List<LoyaltyReward> _rewards = [
    const LoyaltyReward(
      id: 'rw-voucher-100',
      code: 'rw-voucher-100',
      category: 'VOUCHER',
      title: 'Voucher giảm 100.000đ',
      description: 'Giảm trực tiếp 100.000đ khi thanh toán gói tập tại Meta Gym.',
      pointsCost: 300,
      discountAmount: 100000,
      requiresStaffConfirm: false,
      stockRemaining: 12,
      isOutOfStock: false,
      validDays: 30,
      terms: ['Áp dụng trực tiếp tại màn thanh toán gói tập.'],
      status: 'ACTIVE',
    ),
    const LoyaltyReward(
      id: 'rw-inbody',
      code: 'INBODY_FREE',
      category: 'SERVICE',
      title: '1 lượt đo InBody chuyên sâu',
      description: 'Phân tích tỷ lệ cơ - mỡ tại quầy lễ tân Meta Gym.',
      pointsCost: 150,
      discountAmount: 0,
      requiresStaffConfirm: true,
      stockRemaining: 20,
      isOutOfStock: false,
      validDays: 45,
      terms: ['Xuất trình mã tại quầy lễ tân để nhân viên xác nhận.'],
      status: 'ACTIVE',
    ),
    const LoyaltyReward(
      id: 'rw-sold-out',
      code: 'LIMITED_GIFT',
      category: 'SERVICE',
      title: 'Bình lắc Meta Gym phiên bản giới hạn',
      description: 'Quà tặng hội viên số lượng giới hạn.',
      pointsCost: 400,
      discountAmount: 0,
      requiresStaffConfirm: true,
      stockRemaining: 0,
      isOutOfStock: true,
      validDays: 30,
      terms: ['Hết lượt đổi trong đợt này.'],
      status: 'ACTIVE',
    ),
  ];

  final List<LoyaltyRedemption> _redemptions = [
    const LoyaltyRedemption(
      id: 'red-existing-1',
      rewardId: 'rw-inbody',
      rewardCode: 'INBODY_FREE',
      category: 'SERVICE',
      title: '1 lượt đo InBody chuyên sâu',
      pointsSpent: 150,
      discountAmount: 0,
      voucherCode: 'MG-INB-8812',
      requiresStaffConfirm: true,
      conditionText: 'Xuất trình mã tại quầy lễ tân',
      status: 'UNUSED',
      redeemedAt: '2026-11-20T09:00:00Z',
      expiresAt: '2027-01-05T09:00:00Z',
    ),
  ];

  final List<LoyaltyPointTransaction> _transactions = [
    const LoyaltyPointTransaction(
      id: 'tx-1',
      txType: 'EARN',
      pointsDelta: 650,
      tierPointsDelta: 650,
      title: 'Đăng ký Gói 3 Tháng',
      detail: 'Cộng điểm khả dụng & điểm xét hạng',
      statusLabel: 'Thành công',
      createdAt: '2026-11-18T10:00:00Z',
    ),
  ];

  LoyaltySummary _buildSummary() {
    final unusedCount = _redemptions.where((r) => r.status == 'UNUSED').length;
    return LoyaltySummary(
      availablePoints: _availablePoints,
      tierPoints: _tierPoints,
      tier: 'GOLD',
      tierName: 'Vàng',
      tierLabel: 'Hạng Vàng',
      nextTier: 'DIAMOND',
      nextTierName: 'Kim Cương',
      nextTierLabel: 'Hạng Kim Cương',
      nextTierMinPoints: 6000,
      remainingToNextTier: 6000 - _tierPoints,
      progressFraction: (_tierPoints - 2000) / (6000 - 2000),
      coachDiscountPercent: 5,
      pointsMultiplier: 1.5,
      inBodyLabel: 'Miễn phí / tháng',
      perks: LoyaltyTierSpec.defaults[2].perks,
      unusedRedemptionsCount: unusedCount,
      tiers: LoyaltyTierSpec.defaults,
    );
  }

  @override
  Future<LoyaltySummary> getSummary() async => _buildSummary();

  @override
  Future<List<LoyaltyReward>> getRewards({String category = 'ALL'}) async {
    if (category == 'ALL') return List.unmodifiable(_rewards);
    return _rewards.where((r) => r.category == category).toList();
  }

  @override
  Future<List<LoyaltyRedemption>> getMyRedemptions({
    String status = 'ALL',
  }) async {
    if (status == 'ALL') return List.unmodifiable(_redemptions);
    return _redemptions.where((r) => r.status == status).toList();
  }

  @override
  Future<LoyaltyRedeemResult> redeemReward({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    final reward = _rewards.firstWhere((r) => r.id == rewardId);
    _availablePoints -= reward.pointsCost;
    final redemption = LoyaltyRedemption(
      id: 'red-new-${_redemptions.length + 1}',
      rewardId: reward.id,
      rewardCode: reward.code,
      category: reward.category,
      title: reward.title,
      pointsSpent: reward.pointsCost,
      discountAmount: reward.discountAmount,
      voucherCode: 'MG-VCH-100K',
      requiresStaffConfirm: reward.requiresStaffConfirm,
      conditionText: reward.terms.first,
      status: 'UNUSED',
      redeemedAt: '2026-11-28T10:00:00Z',
      expiresAt: '2026-12-28T10:00:00Z',
    );
    _redemptions.insert(0, redemption);
    final tx = LoyaltyPointTransaction(
      id: 'tx-spend-${_transactions.length + 1}',
      txType: 'SPEND',
      pointsDelta: -reward.pointsCost,
      tierPointsDelta: 0,
      title: 'Trừ điểm đổi ưu đãi: ${reward.title}',
      detail: 'Điểm xét hạng được giữ nguyên',
      statusLabel: 'Thành công',
      createdAt: '2026-11-28T10:00:00Z',
    );
    _transactions.insert(0, tx);
    return LoyaltyRedeemResult(
      redemption: redemption,
      summary: _buildSummary(),
      transaction: tx,
    );
  }

  @override
  Future<LoyaltyRedemption> markRedemptionUsed(String redemptionId) async {
    final index = _redemptions.indexWhere((r) => r.id == redemptionId);
    final current = _redemptions[index];
    final updated = LoyaltyRedemption(
      id: current.id,
      rewardId: current.rewardId,
      rewardCode: current.rewardCode,
      category: current.category,
      title: current.title,
      pointsSpent: current.pointsSpent,
      discountAmount: current.discountAmount,
      voucherCode: current.voucherCode,
      requiresStaffConfirm: current.requiresStaffConfirm,
      conditionText: current.conditionText,
      status: 'USED',
      redeemedAt: current.redeemedAt,
      expiresAt: current.expiresAt,
      usedAt: '2026-11-28T11:00:00Z',
    );
    _redemptions[index] = updated;
    return updated;
  }

  @override
  Future<List<LoyaltyPointTransaction>> getTransactions({
    String type = 'ALL',
  }) async {
    if (type == 'ALL') return List.unmodifiable(_transactions);
    return _transactions.where((t) => t.txType == type).toList();
  }
}

void main() {
  testWidgets(
    'Full Loyalty end-to-end flow: Membership -> Rewards -> Detail -> Redeem preserves tierPoints -> My Rewards -> History',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final membershipCtrl = MembershipController(_FakeMembershipService());
      final loyaltyCtrl = LoyaltyController(_FakeLoyaltyService());
      addTearDown(membershipCtrl.dispose);
      addTearDown(loyaltyCtrl.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MembershipController>.value(
              value: membershipCtrl,
            ),
            ChangeNotifierProvider<LoyaltyController>.value(value: loyaltyCtrl),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MembershipPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Main Membership screen shows split availablePoints (1.240) and tierPoints (2.150)
      expect(find.text('Meta Points'), findsOneWidget);
      expect(find.text('Điểm khả dụng'), findsOneWidget);
      expect(find.text('Điểm xét hạng'), findsOneWidget);
      expect(find.text('1.240 điểm'), findsOneWidget);
      expect(find.text('2.150 điểm'), findsOneWidget);

      // Tap tier pill to view 4 tiers modal
      await tester.ensureVisible(
        find.byKey(const Key('loyalty-tier-info-pill')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('loyalty-tier-info-pill')));
      await tester.pumpAndSettle();
      expect(find.text('4 Hạng thành viên Meta Gym'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      // 2. Navigate to Danh mục ưu đãi
      await tester.ensureVisible(
        find.byKey(const Key('membership-redeem-rewards-btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('membership-redeem-rewards-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Danh mục ưu đãi'), findsOneWidget);
      expect(find.text('Voucher giảm 100.000đ'), findsOneWidget);
      expect(find.text('Hết lượt'), findsOneWidget);

      // 3. Open Voucher detail and confirm redeem (-300 points)
      await tester.tap(
        find.byKey(const ValueKey<String>('loyalty-reward-rw-voucher-100')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết ưu đãi'), findsOneWidget);
      expect(find.textContaining('2.150 điểm'), findsWidgets);

      await tester.tap(find.byKey(const Key('loyalty-confirm-redeem-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Đổi ưu đãi thành công'), findsOneWidget);

      // Verify availablePoints dropped to 940 while tierPoints STAYED 2150,
      // and the redeemed checkout voucher was automatically armed!
      expect(loyaltyCtrl.summary?.availablePoints, 940);
      expect(loyaltyCtrl.summary?.tierPoints, 2150);
      expect(loyaltyCtrl.summary?.tier, 'GOLD');
      expect(loyaltyCtrl.selectedCheckoutVoucher?.voucherCode, 'MG-VCH-100K');

      // 4. Jump straight to Ưu đãi của tôi
      await tester.tap(
        find.byKey(const Key('loyalty-success-view-my-rewards')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ưu đãi của tôi'), findsOneWidget);
      expect(find.text('Voucher giảm 100.000đ'), findsWidgets);
      expect(find.text('Dùng khi thanh toán gói'), findsWidgets);
      expect(find.text('Mở mã QR dùng tại quầy'), findsWidgets);

      // 5. Return to Membership and open Lịch sử điểm
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('940 điểm'), findsOneWidget);
      expect(find.text('2.150 điểm'), findsOneWidget);

      await tester.tap(find.byKey(const Key('membership-loyalty-history-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử điểm'), findsOneWidget);
      expect(
        find.textContaining('Trừ điểm đổi ưu đãi: Voucher giảm 100.000đ'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Loyalty sub-screens render cleanly in Light Mode & 1.3x text scaling at 375x812 and 812x375 without overflow',
    (tester) async {
      final membershipCtrl = MembershipController(_FakeMembershipService());
      final loyaltyCtrl = LoyaltyController(_FakeLoyaltyService());
      await loyaltyCtrl.loadAll();
      addTearDown(membershipCtrl.dispose);
      addTearDown(loyaltyCtrl.dispose);

      for (final size in const [Size(375, 812), Size(812, 375)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final page in const <Widget>[
          LoyaltyRewardsPage(),
          LoyaltyMyRewardsPage(),
          LoyaltyHistoryPage(),
        ]) {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<MembershipController>.value(
                  value: membershipCtrl,
                ),
                ChangeNotifierProvider<LoyaltyController>.value(
                  value: loyaltyCtrl,
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page threw in Light Mode at ${size.width}x${size.height}',
          );
        }
      }
    },
  );
}
