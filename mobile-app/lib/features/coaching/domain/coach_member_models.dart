class CoachMemberSummary {
  const CoachMemberSummary({
    required this.relationshipId,
    required this.memberId,
    required this.memberFullName,
    required this.status,
    this.pauseReason,
  });

  factory CoachMemberSummary.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachMemberSummary(
      relationshipId: json['id'] as String,
      memberId: json['memberId'] as String,
      memberFullName: json['memberFullName'] as String,
      status: json['status'] as String,
      pauseReason: json['pauseReason'] as String?,
    );
  }

  final String relationshipId;
  final String memberId;
  final String memberFullName;
  final String status;
  final String? pauseReason;

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Đang hoạt động',
    'PAUSED' => switch (pauseReason) {
      'MEMBER_LOCKED' => 'Tài khoản hội viên tạm khóa',
      'COACH_LOCKED' => 'Coach đang tạm khóa',
      _ => 'Tạm dừng',
    },
    _ => status,
  };
}

class CoachMemberDetail extends CoachMemberSummary {
  const CoachMemberDetail({
    required super.relationshipId,
    required super.memberId,
    required super.memberFullName,
    required super.status,
    super.pauseReason,
    required this.email,
    this.fitnessGoal,
    this.healthNotes,
    this.injuryNotes,
    this.heightCm,
    this.weightKg,
    this.bodyFatPercent,
    this.healthDeclarationCompletedAt,
  });

  factory CoachMemberDetail.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final member = Map<String, dynamic>.from(json['member'] as Map);
    return CoachMemberDetail(
      relationshipId: json['id'] as String,
      memberId: member['id'] as String,
      memberFullName: member['fullName'] as String,
      status: json['status'] as String,
      pauseReason: json['pauseReason'] as String?,
      email: member['email'] as String,
      fitnessGoal: member['fitnessGoal'] as String?,
      healthNotes: member['healthNotes'] as String?,
      injuryNotes: member['injuryNotes'] as String?,
      heightCm: (member['heightCm'] as num?)?.toDouble(),
      weightKg: (member['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (member['bodyFatPercent'] as num?)?.toDouble(),
      healthDeclarationCompletedAt:
          member['healthDeclarationCompletedAt'] as String?,
    );
  }

  final String email;
  final String? fitnessGoal;
  final String? healthNotes;
  final String? injuryNotes;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPercent;
  final String? healthDeclarationCompletedAt;
}

class CoachTerminationRequest {
  const CoachTerminationRequest({
    required this.id,
    required this.relationshipId,
    required this.reason,
    required this.status,
    this.adminNote,
  });

  factory CoachTerminationRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachTerminationRequest(
      id: json['id'] as String,
      relationshipId: json['relationship_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      adminNote: json['admin_note'] as String?,
    );
  }

  final String id;
  final String relationshipId;
  final String reason;
  final String status;
  final String? adminNote;

  String get statusLabel => switch (status) {
    'PENDING' => 'Đang chờ duyệt',
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}
