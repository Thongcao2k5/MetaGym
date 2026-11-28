import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/membership/presentation/widgets/membership_tier_widgets.dart';

class LoyaltyTierSpec {
  const LoyaltyTierSpec({
    required this.code,
    required this.name,
    required this.tierLabel,
    required this.minPoints,
    required this.coachDiscountPercent,
    required this.pointsMultiplier,
    required this.inBodyLabel,
    required this.tagline,
    required this.perks,
  });

  factory LoyaltyTierSpec.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return LoyaltyTierSpec(
      code: (json['code'] as String? ?? 'BRONZE').toUpperCase(),
      name: json['name'] as String? ?? 'Đồng',
      tierLabel: json['tierLabel'] as String? ?? 'Hạng Đồng',
      minPoints: (json['minPoints'] as num?)?.toInt() ?? 0,
      coachDiscountPercent: (json['coachDiscountPercent'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      inBodyLabel: json['inBodyLabel'] as String? ?? 'Trả phí lẻ',
      tagline: json['tagline'] as String? ?? '',
      perks: (json['perks'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final String code;
  final String name;
  final String tierLabel;
  final int minPoints;
  final int coachDiscountPercent;
  final double pointsMultiplier;
  final String inBodyLabel;
  final String tagline;
  final List<String> perks;

  MembershipTierKind get kind => switch (code.toUpperCase()) {
    'DIAMOND' => MembershipTierKind.diamond,
    'GOLD' => MembershipTierKind.gold,
    'SILVER' => MembershipTierKind.silver,
    _ => MembershipTierKind.bronze,
  };

  MembershipTierInfo toMembershipTierInfo({
    String? nextTierNameOverride,
    int? nextTierMinPointsOverride,
  }) {
    final base = switch (kind) {
      MembershipTierKind.diamond => resolveMembershipTierInfo(planName: 'Kim Cương'),
      MembershipTierKind.gold => resolveMembershipTierInfo(planName: 'Hạng Vàng'),
      MembershipTierKind.silver => resolveMembershipTierInfo(planName: 'Hạng Bạc'),
      MembershipTierKind.bronze => resolveMembershipTierInfo(planName: 'Hạng Đồng'),
    };
    return MembershipTierInfo(
      kind: kind,
      tierLabel: tierLabel,
      verticalCardAsset: base.verticalCardAsset,
      horizontalCardAsset: base.horizontalCardAsset,
      borderColor: base.borderColor,
      accentColor: base.accentColor,
      summaryPerks: tagline.isNotEmpty ? tagline : base.summaryPerks,
      coachDiscountLabel: coachDiscountPercent > 0 ? '-$coachDiscountPercent%' : '0%',
      inBodyLabel: inBodyLabel,
      pointsMultiplierLabel: '×${pointsMultiplier.toStringAsFixed(1)} điểm',
      nextTierLabel: nextTierNameOverride ?? base.nextTierLabel,
      nextTierTargetPoints: nextTierMinPointsOverride ?? base.nextTierTargetPoints,
    );
  }

  Color get accentColor => switch (kind) {
    MembershipTierKind.diamond => MetaGymTheme.reflectionBlue,
    MembershipTierKind.gold => const Color(0xFFF5B041),
    MembershipTierKind.silver => const Color(0xFFC4CCDA),
    MembershipTierKind.bronze => const Color(0xFFD29162),
  };

  static const List<LoyaltyTierSpec> defaults = [
    LoyaltyTierSpec(
      code: 'BRONZE',
      name: 'Đồng',
      tierLabel: 'Hạng Đồng',
      minPoints: 0,
      coachDiscountPercent: 0,
      pointsMultiplier: 1.0,
      inBodyLabel: 'Trả phí lẻ',
      tagline: 'Khởi đầu hành trình tập luyện tại Meta Gym',
      perks: [
        'Check-in QR/NFC không chạm tại phòng tập',
        'Tích điểm khả dụng & xét hạng khi đăng ký gói hoặc check-in',
        'Truy cập danh mục ưu đãi thành viên cơ bản',
      ],
    ),
    LoyaltyTierSpec(
      code: 'SILVER',
      name: 'Bạc',
      tierLabel: 'Hạng Bạc',
      minPoints: 800,
      coachDiscountPercent: 3,
      pointsMultiplier: 1.2,
      inBodyLabel: '1 lần / quý',
      tagline: 'Tăng nhịp ổn định cùng đặc quyền InBody & ưu đãi Coach',
      perks: [
        'Giảm tự động 3% mọi gói Coach 1:1',
        'Hệ số tích điểm check-in ×1.2',
        'Đo chỉ số InBody chuyên sâu 1 lần / quý',
      ],
    ),
    LoyaltyTierSpec(
      code: 'GOLD',
      name: 'Vàng',
      tierLabel: 'Hạng Vàng',
      minPoints: 2000,
      coachDiscountPercent: 5,
      pointsMultiplier: 1.5,
      inBodyLabel: 'Miễn phí / tháng',
      tagline: 'Hội viên gắn bó với ưu đãi Coach 1:1 và InBody định kỳ',
      perks: [
        'Giảm tự động 5% mọi gói Coach 1:1',
        'Đo chỉ số InBody chuyên sâu miễn phí hàng tháng',
        'Hệ số tích điểm check-in ×1.5 & mở khóa ưu đãi Vàng',
      ],
    ),
    LoyaltyTierSpec(
      code: 'DIAMOND',
      name: 'Kim Cương',
      tierLabel: 'Hạng Kim Cương',
      minPoints: 6000,
      coachDiscountPercent: 10,
      pointsMultiplier: 2.0,
      inBodyLabel: 'Không giới hạn',
      tagline: 'Hạng cao nhất dành cho hội viên đồng hành bền vững cùng Meta Gym',
      perks: [
        'Giảm tự động 10% mọi gói Coach 1:1',
        'Đo chỉ số InBody chuyên sâu không giới hạn',
        'Hệ số tích điểm check-in ×2.0 & ưu tiên chăm sóc câu lạc bộ',
      ],
    ),
  ];
}

class LoyaltySummary {
  const LoyaltySummary({
    required this.availablePoints,
    required this.tierPoints,
    required this.tier,
    required this.tierName,
    required this.tierLabel,
    required this.nextTier,
    required this.nextTierName,
    required this.nextTierLabel,
    required this.nextTierMinPoints,
    required this.remainingToNextTier,
    required this.progressFraction,
    required this.coachDiscountPercent,
    required this.pointsMultiplier,
    required this.inBodyLabel,
    required this.perks,
    required this.unusedRedemptionsCount,
    required this.tiers,
  });

  factory LoyaltySummary.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final rawTiers = (json['tiers'] as List?)
            ?.map(LoyaltyTierSpec.fromJson)
            .toList() ??
        LoyaltyTierSpec.defaults;
    return LoyaltySummary(
      availablePoints: (json['availablePoints'] as num?)?.toInt() ?? 0,
      tierPoints: (json['tierPoints'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as String? ?? 'BRONZE').toUpperCase(),
      tierName: json['tierName'] as String? ?? 'Đồng',
      tierLabel: json['tierLabel'] as String? ?? 'Hạng Đồng',
      nextTier: (json['nextTier'] as String?)?.toUpperCase(),
      nextTierName: json['nextTierName'] as String?,
      nextTierLabel: json['nextTierLabel'] as String?,
      nextTierMinPoints: (json['nextTierMinPoints'] as num?)?.toInt(),
      remainingToNextTier: (json['remainingToNextTier'] as num?)?.toInt() ?? 0,
      progressFraction: (json['progressFraction'] as num?)?.toDouble() ?? 0.0,
      coachDiscountPercent: (json['coachDiscountPercent'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (json['pointsMultiplier'] as num?)?.toDouble() ?? 1.0,
      inBodyLabel: json['inBodyLabel'] as String? ?? 'Trả phí lẻ',
      perks: (json['perks'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      unusedRedemptionsCount:
          (json['unusedRedemptionsCount'] as num?)?.toInt() ?? 0,
      tiers: rawTiers.isEmpty ? LoyaltyTierSpec.defaults : rawTiers,
    );
  }

  final int availablePoints;
  final int tierPoints;
  final String tier;
  final String tierName;
  final String tierLabel;
  final String? nextTier;
  final String? nextTierName;
  final String? nextTierLabel;
  final int? nextTierMinPoints;
  final int remainingToNextTier;
  final double progressFraction;
  final int coachDiscountPercent;
  final double pointsMultiplier;
  final String inBodyLabel;
  final List<String> perks;
  final int unusedRedemptionsCount;
  final List<LoyaltyTierSpec> tiers;

  bool get isMaxTier => nextTier == null;

  LoyaltyTierSpec get currentTierSpec => tiers.firstWhere(
    (t) => t.code == tier,
    orElse: () => LoyaltyTierSpec.defaults.first,
  );

  MembershipTierInfo toMembershipTierInfo() => currentTierSpec.toMembershipTierInfo(
    nextTierNameOverride: nextTierLabel,
    nextTierMinPointsOverride: nextTierMinPoints,
  );

  LoyaltySummary copyWith({
    int? availablePoints,
    int? tierPoints,
    int? unusedRedemptionsCount,
  }) => LoyaltySummary(
    availablePoints: availablePoints ?? this.availablePoints,
    tierPoints: tierPoints ?? this.tierPoints,
    tier: tier,
    tierName: tierName,
    tierLabel: tierLabel,
    nextTier: nextTier,
    nextTierName: nextTierName,
    nextTierLabel: nextTierLabel,
    nextTierMinPoints: nextTierMinPoints,
    remainingToNextTier: remainingToNextTier,
    progressFraction: progressFraction,
    coachDiscountPercent: coachDiscountPercent,
    pointsMultiplier: pointsMultiplier,
    inBodyLabel: inBodyLabel,
    perks: perks,
    unusedRedemptionsCount:
        unusedRedemptionsCount ?? this.unusedRedemptionsCount,
    tiers: tiers,
  );
}

class LoyaltyReward {
  const LoyaltyReward({
    required this.id,
    required this.code,
    required this.category,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.discountAmount,
    required this.requiresStaffConfirm,
    required this.stockRemaining,
    required this.isOutOfStock,
    required this.validDays,
    required this.terms,
    required this.status,
  });

  factory LoyaltyReward.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final stock = (json['stockRemaining'] as num?)?.toInt();
    return LoyaltyReward(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      category: (json['category'] as String? ?? 'VOUCHER').toUpperCase(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pointsCost: (json['pointsCost'] as num?)?.toInt() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toInt() ?? 0,
      requiresStaffConfirm: json['requiresStaffConfirm'] as bool? ?? false,
      stockRemaining: stock,
      isOutOfStock:
          json['isOutOfStock'] as bool? ?? (stock != null && stock <= 0),
      validDays: (json['validDays'] as num?)?.toInt() ?? 30,
      terms: (json['terms'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: (json['status'] as String? ?? 'ACTIVE').toUpperCase(),
    );
  }

  final String id;
  final String code;
  final String category;
  final String title;
  final String description;
  final int pointsCost;
  final int discountAmount;
  final bool requiresStaffConfirm;
  final int? stockRemaining;
  final bool isOutOfStock;
  final int validDays;
  final List<String> terms;
  final String status;

  String get categoryLabel => category == 'SERVICE' ? 'Dịch vụ' : 'Voucher';

  bool canRedeem(int availablePoints) =>
      !isOutOfStock && availablePoints >= pointsCost;

  int missingPoints(int availablePoints) =>
      (pointsCost - availablePoints).clamp(0, pointsCost);
}

class LoyaltyRedemption {
  const LoyaltyRedemption({
    required this.id,
    required this.rewardId,
    required this.rewardCode,
    required this.category,
    required this.title,
    required this.pointsSpent,
    required this.discountAmount,
    required this.voucherCode,
    required this.requiresStaffConfirm,
    required this.conditionText,
    required this.status,
    required this.redeemedAt,
    required this.expiresAt,
    this.usedAt,
  });

  factory LoyaltyRedemption.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return LoyaltyRedemption(
      id: json['id'] as String,
      rewardId: json['rewardId'] as String? ?? '',
      rewardCode: json['rewardCode'] as String? ?? '',
      category: (json['category'] as String? ?? 'VOUCHER').toUpperCase(),
      title: json['title'] as String? ?? '',
      pointsSpent: (json['pointsSpent'] as num?)?.toInt() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toInt() ?? 0,
      voucherCode: json['voucherCode'] as String? ?? '',
      requiresStaffConfirm: json['requiresStaffConfirm'] as bool? ?? false,
      conditionText: json['conditionText'] as String? ?? '',
      status: (json['status'] as String? ?? 'UNUSED').toUpperCase(),
      redeemedAt: json['redeemedAt'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      usedAt: json['usedAt'] as String?,
    );
  }

  final String id;
  final String rewardId;
  final String rewardCode;
  final String category;
  final String title;
  final int pointsSpent;
  final int discountAmount;
  final String voucherCode;
  final bool requiresStaffConfirm;
  final String conditionText;
  final String status;
  final String redeemedAt;
  final String expiresAt;
  final String? usedAt;

  String get categoryLabel => category == 'SERVICE' ? 'Dịch vụ' : 'Voucher';

  String get statusLabel => switch (status) {
    'UNUSED' => 'Chưa sử dụng',
    'USED' => 'Đã sử dụng',
    'EXPIRED' => 'Hết hạn',
    _ => status,
  };

  bool get canApplyAtCheckout =>
      status == 'UNUSED' &&
      category == 'VOUCHER' &&
      discountAmount > 0 &&
      !requiresStaffConfirm;
}

class LoyaltyPointTransaction {
  const LoyaltyPointTransaction({
    required this.id,
    required this.txType,
    required this.pointsDelta,
    required this.tierPointsDelta,
    required this.title,
    required this.detail,
    required this.statusLabel,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
  });

  factory LoyaltyPointTransaction.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return LoyaltyPointTransaction(
      id: json['id'] as String,
      txType: (json['txType'] as String? ?? 'EARN').toUpperCase(),
      pointsDelta: (json['pointsDelta'] as num?)?.toInt() ?? 0,
      tierPointsDelta: (json['tierPointsDelta'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? 'Thành công',
      createdAt: json['createdAt'] as String? ?? '',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
    );
  }

  final String id;
  final String txType;
  final int pointsDelta;
  final int tierPointsDelta;
  final String title;
  final String detail;
  final String statusLabel;
  final String createdAt;
  final String? referenceType;
  final String? referenceId;
}

class LoyaltyRedeemResult {
  const LoyaltyRedeemResult({
    required this.redemption,
    required this.summary,
    this.transaction,
  });

  factory LoyaltyRedeemResult.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return LoyaltyRedeemResult(
      redemption: LoyaltyRedemption.fromJson(json['redemption']),
      summary: LoyaltySummary.fromJson(json['summary']),
      transaction: json['transaction'] != null
          ? LoyaltyPointTransaction.fromJson(json['transaction'])
          : null,
    );
  }

  final LoyaltyRedemption redemption;
  final LoyaltySummary summary;
  final LoyaltyPointTransaction? transaction;
}

int bonusPointsForPlanDuration(int durationDays) {
  if (durationDays >= 1000) return 5000;
  if (durationDays >= 300) return 1500;
  if (durationDays >= 150) return 650;
  if (durationDays >= 60) return 250;
  return 100;
}

String formatLoyaltyPoints(int points) {
  final negative = points < 0;
  final raw = points.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }
  return negative ? '-$buffer' : buffer.toString();
}
