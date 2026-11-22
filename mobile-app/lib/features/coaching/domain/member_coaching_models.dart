class MemberCoachRequest {
  const MemberCoachRequest({
    required this.id,
    required this.coachId,
    required this.status,
    this.message,
    this.rejectionReason,
    this.requestedAt,
  });

  factory MemberCoachRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MemberCoachRequest(
      id: json['id'] as String,
      coachId: json['coachId'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      requestedAt: json['requestedAt'] as String?,
    );
  }

  final String id;
  final String coachId;
  final String status;
  final String? message;
  final String? rejectionReason;
  final String? requestedAt;

  String get statusLabel => switch (status) {
    'PENDING' => 'Đang chờ',
    'ACCEPTED' => 'Đã chấp nhận',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}

class MemberCoachRelationship {
  const MemberCoachRelationship({
    required this.id,
    required this.coachId,
    required this.status,
    this.coachName,
    this.coachAvatarUrl,
    this.pauseReason,
    this.startedAt,
    this.endedAt,
  });

  factory MemberCoachRelationship.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MemberCoachRelationship(
      id: json['id'] as String,
      coachId: json['coachId'] as String,
      status: json['status'] as String,
      coachName: json['coachName'] as String?,
      coachAvatarUrl: json['coachAvatarUrl'] as String?,
      pauseReason: json['pauseReason'] as String?,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
    );
  }

  final String id;
  final String coachId;
  final String status;
  final String? coachName;
  final String? coachAvatarUrl;
  final String? pauseReason;
  final String? startedAt;
  final String? endedAt;

  bool get isPaused => status == 'PAUSED';
  bool get isCoachLocked => isPaused && pauseReason == 'COACH_LOCKED';
  bool get isMemberLocked => isPaused && pauseReason == 'MEMBER_LOCKED';
  bool get isMembershipExpired =>
      isPaused && (pauseReason == null || pauseReason == 'MEMBERSHIP_EXPIRED');

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Đang hoạt động',
    'PAUSED' => switch (pauseReason) {
      'COACH_LOCKED' => 'Coach đang tạm khóa',
      'MEMBER_LOCKED' => 'Tài khoản đang tạm khóa',
      'MEMBERSHIP_EXPIRED' || null => 'Tạm ngưng do Gym hết hạn',
      _ => 'Đang tạm ngưng',
    },
    'ENDED' => 'Đã kết thúc',
    _ => status,
  };
}

class CoachLockChoiceResult {
  const CoachLockChoiceResult({
    required this.incidentId,
    required this.relationshipId,
    required this.status,
    required this.memberChoice,
    this.memberChoiceAt,
    this.memberChoiceNote,
  });

  factory CoachLockChoiceResult.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachLockChoiceResult(
      incidentId: (json['incidentId'] ?? json['id']) as String,
      relationshipId: json['relationshipId'] as String,
      status: json['status'] as String,
      memberChoice: json['memberChoice'] as String,
      memberChoiceAt: json['memberChoiceAt'] as String?,
      memberChoiceNote: json['memberChoiceNote'] as String?,
    );
  }

  final String incidentId;
  final String relationshipId;
  final String status;
  final String memberChoice;
  final String? memberChoiceAt;
  final String? memberChoiceNote;

  String get choiceLabel => switch (memberChoice) {
    'WAIT' => 'Chờ Coach mở khóa',
    'REFUND' => 'Yêu cầu hoàn mô phỏng / chuyển Coach',
    _ => memberChoice,
  };
}
