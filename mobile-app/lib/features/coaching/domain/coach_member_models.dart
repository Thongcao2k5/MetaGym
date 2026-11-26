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
    final nestedMember = json['member'] is Map
        ? Map<String, dynamic>.from(json['member'] as Map)
        : null;
    final relationshipId =
        (json['id'] as String?) ?? (json['relationshipId'] as String);
    final memberId =
        (json['memberId'] as String?) ?? (nestedMember?['id'] as String);
    final memberFullName =
        (json['memberFullName'] as String?) ??
        (json['memberName'] as String?) ??
        (nestedMember?['fullName'] as String);
    return CoachMemberSummary(
      relationshipId: relationshipId,
      memberId: memberId,
      memberFullName: memberFullName,
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
    final member = json['member'] is Map
        ? Map<String, dynamic>.from(json['member'] as Map)
        : <String, dynamic>{
            'id': json['memberId'],
            'fullName': json['memberFullName'] ?? json['memberName'] ?? '',
            'email': json['memberEmail'] ?? '',
          };
    final relationshipId =
        (json['id'] as String?) ?? (json['relationshipId'] as String);
    return CoachMemberDetail(
      relationshipId: relationshipId,
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
    this.relationshipStatus,
    this.memberId,
    this.memberName,
    this.coachId,
    this.coachName,
    this.requestedByUserId,
    this.requestedByRole,
    this.requestedByName,
    this.counterpartyUserId,
    this.counterpartyName,
    this.counterpartyDecision,
    this.counterpartyReason,
    this.counterpartyDecidedAt,
    this.responseDeadlineAt,
    this.disputedAt,
    this.escalationReason,
    this.adminNote,
    this.decidedAt,
    this.createdAt,
  });

  factory CoachTerminationRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachTerminationRequest(
      id: json['id'] as String,
      relationshipId:
          (json['relationshipId'] ?? json['relationship_id']) as String,
      relationshipStatus: json['relationshipStatus'] as String?,
      memberId: json['memberId'] as String?,
      memberName: json['memberName'] as String?,
      coachId: json['coachId'] as String?,
      coachName: json['coachName'] as String?,
      requestedByUserId: json['requestedByUserId'] as String?,
      requestedByRole: json['requestedByRole'] as String?,
      requestedByName: json['requestedByName'] as String?,
      counterpartyUserId: json['counterpartyUserId'] as String?,
      counterpartyName: json['counterpartyName'] as String?,
      reason: json['reason'] as String,
      status: json['status'] as String,
      counterpartyDecision: json['counterpartyDecision'] as String?,
      counterpartyReason: json['counterpartyReason'] as String?,
      counterpartyDecidedAt: json['counterpartyDecidedAt'] as String?,
      responseDeadlineAt: json['responseDeadlineAt'] as String?,
      disputedAt: json['disputedAt'] as String?,
      escalationReason: json['escalationReason'] as String?,
      adminNote: (json['adminNote'] ?? json['admin_note']) as String?,
      decidedAt: json['decidedAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  final String id;
  final String relationshipId;
  final String? relationshipStatus;
  final String? memberId;
  final String? memberName;
  final String? coachId;
  final String? coachName;
  final String? requestedByUserId;
  final String? requestedByRole;
  final String? requestedByName;
  final String? counterpartyUserId;
  final String? counterpartyName;
  final String reason;
  final String status;
  final String? counterpartyDecision;
  final String? counterpartyReason;
  final String? counterpartyDecidedAt;
  final String? responseDeadlineAt;
  final String? disputedAt;
  final String? escalationReason;
  final String? adminNote;
  final String? decidedAt;
  final String? createdAt;

  bool get isPendingCounterparty =>
      status == 'PENDING_COUNTERPARTY' || status == 'PENDING';
  bool get isDisputed => status == 'DISPUTED';
  bool get isOpen => isPendingCounterparty || isDisputed;

  bool canRespondAsRole(String viewerRole) =>
      isPendingCounterparty &&
      requestedByRole != null &&
      requestedByRole != viewerRole;

  bool canWithdrawAsRole(String viewerRole) =>
      isPendingCounterparty && requestedByRole == viewerRole;

  String get requesterRoleLabel => switch (requestedByRole) {
    'MEMBER' => 'Hội viên',
    'COACH' => 'Coach',
    _ => 'Đối tác',
  };

  String? get escalationLabel => switch (escalationReason) {
    'COUNTERPARTY_REJECTED' => 'Đối tác đã từ chối yêu cầu',
    'TIMEOUT_72H' => 'Quá hạn 72 giờ không phản hồi',
    _ => null,
  };

  String get statusLabel => switch (status) {
    'PENDING_COUNTERPARTY' => 'Chờ đối tác phản hồi (72h)',
    'DISPUTED' => 'Đang tranh chấp · Chờ Admin',
    'ACCEPTED' => 'Đã đồng ý kết thúc',
    'ADMIN_APPROVED' => 'Admin duyệt kết thúc',
    'ADMIN_REJECTED' => 'Admin từ chối kết thúc',
    'CANCELLED' => 'Đã hủy yêu cầu',
    'PENDING' => 'Đang chờ duyệt',
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Đã từ chối',
    _ => status,
  };
}
