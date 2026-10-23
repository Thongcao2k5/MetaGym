class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.mediaId,
    required this.takenAt,
    this.pose,
    this.notes,
  });
  final String id;
  final String mediaId;
  final String takenAt;
  final String? pose;
  final String? notes;

  factory ProgressPhoto.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return ProgressPhoto(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      takenAt: json['takenAt'] as String,
      pose: json['pose'] as String?,
      notes: json['notes'] as String?,
    );
  }

  String get poseLabel => switch (pose) {
    'FRONT' => 'Mặt trước',
    'SIDE' => 'Mặt bên',
    'BACK' => 'Mặt sau',
    _ => 'Khác',
  };
}
