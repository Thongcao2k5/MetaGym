class CallLog {
  const CallLog({
    required this.id,
    required this.relationshipId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.initiatedAt,
    required this.durationSeconds,
    this.answeredAt,
    this.endedAt,
    this.failureReason,
  });

  final String id;
  final String relationshipId;
  final String callerId;
  final String receiverId;
  final String callType;
  final String status;
  final String initiatedAt;
  final String? answeredAt;
  final String? endedAt;
  final int durationSeconds;
  final String? failureReason;

  bool get isFinished =>
      ['REJECTED', 'MISSED', 'ENDED', 'FAILED'].contains(status);
  String get statusLabel => switch (status) {
    'CREATED' => 'Đã tạo',
    'RINGING' => 'Đang đổ chuông (metadata)',
    'ANSWERED' => 'Đã bắt máy (metadata)',
    'REJECTED' => 'Đã từ chối',
    'MISSED' => 'Cuộc gọi nhỡ',
    'ENDED' => 'Đã kết thúc',
    'FAILED' => 'Gọi lỗi',
    _ => status,
  };
  String get typeLabel => callType == 'VIDEO' ? 'Video' : 'Thoại';

  factory CallLog.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CallLog(
      id: json['id'] as String,
      relationshipId: json['relationshipId'] as String,
      callerId: json['callerId'] as String,
      receiverId: json['receiverId'] as String,
      callType: json['callType'] as String,
      status: json['status'] as String,
      initiatedAt: json['initiatedAt'] as String,
      answeredAt: json['answeredAt'] as String?,
      endedAt: json['endedAt'] as String?,
      durationSeconds: json['durationSeconds'] as int,
      failureReason: json['failureReason'] as String?,
    );
  }
}
