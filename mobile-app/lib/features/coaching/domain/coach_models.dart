class CoachProfile {
  const CoachProfile({
    required this.id,
    required this.fullName,
    required this.memberLimit,
    required this.usedSlots,
    required this.availableSlots,
    this.biography,
    this.specialties = const [],
    this.qualifications,
    this.experienceYears,
    this.availabilityNote,
    this.avatarUrl,
  });

  factory CoachProfile.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      memberLimit: json['memberLimit'] as int,
      usedSlots: json['usedSlots'] as int,
      availableSlots: json['availableSlots'] as int,
      biography: json['biography'] as String?,
      specialties: (json['specialties'] as List? ?? const [])
          .map((value) => value as String)
          .toList(),
      qualifications: json['qualifications'] as String?,
      experienceYears: json['experienceYears'] as int?,
      availabilityNote: json['availabilityNote'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String? biography;
  final List<String> specialties;
  final String? qualifications;
  final int? experienceYears;
  final String? availabilityNote;
  final String? avatarUrl;
  final int memberLimit;
  final int usedSlots;
  final int availableSlots;
}

class CoachRequest {
  const CoachRequest({required this.id, required this.status});

  factory CoachRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachRequest(
      id: json['id'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String status;
}

class CoachPackagePlan {
  const CoachPackagePlan({
    required this.code,
    required this.name,
    required this.sessionCount,
    required this.durationDays,
    required this.price,
    required this.status,
  });

  factory CoachPackagePlan.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachPackagePlan(
      code: json['code'] as String,
      name: json['name'] as String,
      sessionCount: json['sessionCount'] as int,
      durationDays: json['durationDays'] as int,
      price: (json['price'] as num).toInt(),
      status: json['status'] as String,
    );
  }

  final String code;
  final String name;
  final int sessionCount;
  final int durationDays;
  final int price;
  final String status;
}

class CoachPaymentHold {
  const CoachPaymentHold({
    required this.id,
    required this.coachId,
    required this.planCode,
    required this.planName,
    required this.sessionCount,
    required this.durationDays,
    required this.amount,
    required this.status,
    required this.expiresAt,
  });

  factory CoachPaymentHold.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachPaymentHold(
      id: json['id'] as String,
      coachId: json['coachId'] as String,
      planCode: json['planCode'] as String,
      planName: json['planName'] as String,
      sessionCount: json['sessionCount'] as int,
      durationDays: json['durationDays'] as int,
      amount: (json['amount'] as num).toInt(),
      status: json['status'] as String,
      expiresAt: json['expiresAt'] as String,
    );
  }

  final String id;
  final String coachId;
  final String planCode;
  final String planName;
  final int sessionCount;
  final int durationDays;
  final int amount;
  final String status;
  final String expiresAt;
}

class CoachPaymentHoldConfirmation {
  const CoachPaymentHoldConfirmation({
    required this.hold,
    this.entitlementId,
  });

  factory CoachPaymentHoldConfirmation.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final hold = CoachPaymentHold.fromJson(json['hold']);
    final entitlement = json['entitlement'] as Map<String, dynamic>?;
    return CoachPaymentHoldConfirmation(
      hold: hold,
      entitlementId: entitlement?['id'] as String?,
    );
  }

  final CoachPaymentHold hold;
  final String? entitlementId;
}
