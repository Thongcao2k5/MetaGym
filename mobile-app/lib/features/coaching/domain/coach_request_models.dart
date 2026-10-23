class CoachIncomingRequest {
  const CoachIncomingRequest({
    required this.id,
    required this.memberId,
    required this.coachId,
    required this.status,
    this.message,
    this.rejectionReason,
    this.requestedAt,
    this.decidedAt,
  });

  factory CoachIncomingRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachIncomingRequest(
      id: json['id'] as String,
      memberId: json['memberId'] as String,
      coachId: json['coachId'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      requestedAt: json['requestedAt'] as String?,
      decidedAt: json['decidedAt'] as String?,
    );
  }

  final String id;
  final String memberId;
  final String coachId;
  final String status;
  final String? message;
  final String? rejectionReason;
  final String? requestedAt;
  final String? decidedAt;

  String get statusLabel => switch (status) {
    'PENDING' => 'Đang chờ',
    'ACCEPTED' => 'Đã chấp nhận',
    'REJECTED' => 'Đã từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}
