class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.status,
    this.description,
  });

  factory MembershipPlan.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MembershipPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as num,
      durationDays: json['durationDays'] as int,
      status: json['status'] as String,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String name;
  final num price;
  final int durationDays;
  final String status;
  final String? description;
}

class MembershipQuote {
  const MembershipQuote({
    required this.price,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    this.isRenewal = false,
  });

  factory MembershipQuote.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MembershipQuote(
      price: json['price'] as num,
      durationDays: json['durationDays'] as int,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      isRenewal: json['isRenewal'] as bool? ?? false,
    );
  }

  final num price;
  final int durationDays;
  final String startDate;
  final String endDate;
  final bool isRenewal;
}

class Payment {
  const Payment({
    required this.id,
    required this.status,
    this.qrPayload,
    this.planName,
    this.amount,
    this.discountAmount = 0,
    this.method,
    this.transactionCode,
    this.createdAt,
    this.confirmedAt,
    this.membershipId,
    this.paymentUrl,
  });

  factory Payment.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Payment(
      id: json['id'] as String,
      status: json['status'] as String,
      qrPayload: json['qrPayload'] as String?,
      planName: json['planName'] as String?,
      amount: json['amount'] as num?,
      discountAmount: (json['discountAmount'] as num?)?.toInt() ?? 0,
      method: json['method'] as String?,
      transactionCode: json['transactionCode'] as String?,
      createdAt: json['createdAt'] as String?,
      confirmedAt: json['confirmedAt'] as String?,
      membershipId: json['membershipId'] as String?,
      paymentUrl: json['paymentUrl'] as String?,
    );
  }

  final String id;
  final String status;
  final String? qrPayload;
  final String? planName;
  final num? amount;
  final int discountAmount;
  final String? method;
  final String? transactionCode;
  final String? createdAt;
  final String? confirmedAt;
  final String? membershipId;
  final String? paymentUrl;

  String get statusLabel => switch (status) {
    'PENDING' => 'Đang chờ',
    'SUCCESS' => 'Thành công',
    'FAILED' => 'Thất bại',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}

class Membership {
  const Membership({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.sourcePaymentId,
    this.planName,
  });

  factory Membership.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Membership(
      id: json['id'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      status: json['status'] as String,
      sourcePaymentId: json['sourcePaymentId'] as String?,
      planName: json['planName'] as String?,
    );
  }

  final String id;
  final String startDate;
  final String endDate;
  final String status;
  final String? sourcePaymentId;
  final String? planName;

  String get label => switch (status) {
    'ACTIVE' => 'Đang hiệu lực',
    'SCHEDULED' => 'Chờ hiệu lực',
    'EXPIRED' => 'Hết hạn',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };

  int? remainingDays(DateTime now) {
    if (status != 'ACTIVE') return null;
    final end = DateTime.tryParse('${endDate}T00:00:00Z');
    if (end == null) return null;
    final vietnamTime = now.toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(
      vietnamTime.year,
      vietnamTime.month,
      vietnamTime.day,
    );
    return (end.difference(today).inDays + 1).clamp(0, 3650);
  }
}

class PurchaseResult {
  const PurchaseResult({required this.payment, required this.membership});

  factory PurchaseResult.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return PurchaseResult(
      payment: Payment.fromJson(json['payment']),
      membership: Membership.fromJson(json['membership']),
    );
  }

  final Payment payment;
  final Membership membership;
}
