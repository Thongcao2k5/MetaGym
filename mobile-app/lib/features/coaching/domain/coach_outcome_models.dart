class CoachOutcomeCase {
  const CoachOutcomeCase({
    required this.id,
    required this.coachId,
    required this.goal,
    required this.durationWeeks,
    required this.beforeWeightKg,
    required this.afterWeightKg,
    this.beforeBodyFatPercent,
    this.afterBodyFatPercent,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    this.allowRealName = false,
    this.studentName = 'Học viên ẩn danh',
    this.studentInitials = 'HV',
    this.status = 'APPROVED',
    this.coachName,
    this.memberName,
    this.submittedAt,
  });

  factory CoachOutcomeCase.fromJson(Object? raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final allowRealName = json['allowRealName'] == true;
    final memberName = json['memberName'] as String?;
    return CoachOutcomeCase(
      id: json['id'] as String,
      coachId: json['coachId'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      durationWeeks: (json['durationWeeks'] as num?)?.toInt() ?? 1,
      beforeWeightKg: (json['beforeWeightKg'] as num?)?.toDouble() ?? 0,
      afterWeightKg: (json['afterWeightKg'] as num?)?.toDouble() ?? 0,
      beforeBodyFatPercent: (json['beforeBodyFatPercent'] as num?)?.toDouble(),
      afterBodyFatPercent: (json['afterBodyFatPercent'] as num?)?.toDouble(),
      beforePhotoUrl: json['beforePhotoUrl'] as String?,
      afterPhotoUrl: json['afterPhotoUrl'] as String?,
      allowRealName: allowRealName,
      studentName:
          json['studentName'] as String? ??
          (allowRealName && memberName != null
              ? memberName
              : 'Học viên ẩn danh'),
      studentInitials:
          json['studentInitials'] as String? ??
          (allowRealName && memberName != null ? _initials(memberName) : 'HV'),
      status: json['status'] as String? ?? 'APPROVED',
      coachName: json['coachName'] as String?,
      memberName: memberName,
      submittedAt: json['submittedAt'] as String?,
    );
  }

  final String id;
  final String coachId;
  final String goal;
  final int durationWeeks;
  final double beforeWeightKg;
  final double afterWeightKg;
  final double? beforeBodyFatPercent;
  final double? afterBodyFatPercent;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final bool allowRealName;
  final String studentName;
  final String studentInitials;
  final String status;
  final String? coachName;
  final String? memberName;
  final String? submittedAt;

  String get statusLabel => switch (status) {
    'PENDING_MEMBER' => 'Chờ học viên duyệt',
    'APPROVED' => 'Đã công khai',
    'DECLINED' => 'Học viên từ chối',
    'WITHDRAWN' => 'Đã thu hồi công khai',
    _ => status,
  };

  static String formatNumber(num value) {
    final fixed = value.toStringAsFixed(1);
    final trimmed = fixed.endsWith('.0')
        ? fixed.substring(0, fixed.length - 2)
        : fixed;
    return trimmed.replaceAll('.', ',');
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HV';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
