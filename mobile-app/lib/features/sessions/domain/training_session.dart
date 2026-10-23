class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.title,
    required this.scheduledStartAt,
    required this.status,
    this.scheduledEndAt,
    this.notes,
    this.cancellationReason,
  });

  final String id;
  final String title;
  final String scheduledStartAt;
  final String? scheduledEndAt;
  final String status;
  final String? notes;
  final String? cancellationReason;

  factory TrainingSession.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return TrainingSession(
      id: json['id'] as String,
      title: json['title'] as String,
      scheduledStartAt: json['scheduledStartAt'] as String,
      scheduledEndAt: json['scheduledEndAt'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
    );
  }

  String get statusLabel => switch (status) {
    'SCHEDULED' => 'Đã lên lịch',
    'COMPLETED' => 'Hoàn thành',
    'MEMBER_ABSENT' => 'Hội viên vắng',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}

String formatSessionLocalTime(String isoTime) {
  final time = DateTime.parse(isoTime).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year} '
      '${two(time.hour)}:${two(time.minute)}';
}
