class ProgressComment {
  const ProgressComment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.workoutLogId,
    this.mealLogId,
    this.measurementId,
    this.progressPhotoId,
  });
  final String id;
  final String content;
  final String createdAt;
  final String? workoutLogId;
  final String? mealLogId;
  final String? measurementId;
  final String? progressPhotoId;

  factory ProgressComment.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return ProgressComment(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
      workoutLogId: json['workoutLogId'] as String?,
      mealLogId: json['mealLogId'] as String?,
      measurementId: json['measurementId'] as String?,
      progressPhotoId: json['progressPhotoId'] as String?,
    );
  }
}
