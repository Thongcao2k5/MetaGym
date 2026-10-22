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

class Payment {
  const Payment({required this.id, required this.status, this.qrPayload});

  factory Payment.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Payment(
      id: json['id'] as String,
      status: json['status'] as String,
      qrPayload: json['qrPayload'] as String?,
    );
  }

  final String id;
  final String status;
  final String? qrPayload;
}

class Membership {
  const Membership({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory Membership.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Membership(
      id: json['id'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String startDate;
  final String endDate;
  final String status;
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
