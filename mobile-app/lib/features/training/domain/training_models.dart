class TrainingExercise {
  const TrainingExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.displayOrder,
    this.sets,
    this.reps,
    this.durationSeconds,
    this.restSeconds,
    this.weightGuidance,
    this.notes,
    this.instructions,
    this.safetyNotes,
  });

  factory TrainingExercise.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return TrainingExercise(
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      displayOrder: json['displayOrder'] as int,
      sets: json['sets'] as int?,
      reps: json['reps'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      restSeconds: json['restSeconds'] as int?,
      weightGuidance: json['weightGuidance'] as String?,
      notes: json['notes'] as String?,
      instructions: json['instructions'] as String?,
      safetyNotes: json['safetyNotes'] as String?,
    );
  }

  final String exerciseId;
  final String exerciseName;
  final int displayOrder;
  final int? sets;
  final String? reps;
  final int? durationSeconds;
  final int? restSeconds;
  final String? weightGuidance;
  final String? notes;
  final String? instructions;
  final String? safetyNotes;

  String get prescription => [
    if (sets != null) '$sets hiệp',
    if (reps != null) '$reps lần',
    if (durationSeconds != null) '$durationSeconds giây',
  ].join(' · ');
}

class TrainingDay {
  const TrainingDay({
    required this.dayNumber,
    required this.title,
    this.notes,
    this.exercises = const [],
  });

  factory TrainingDay.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return TrainingDay(
      dayNumber: json['dayNumber'] as int,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List? ?? const [])
          .map(TrainingExercise.fromJson)
          .toList(),
    );
  }

  final int dayNumber;
  final String title;
  final String? notes;
  final List<TrainingExercise> exercises;
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    this.goal,
    this.startDate,
    this.endDate,
    this.publishedAt,
    this.days = const [],
  });

  factory TrainingPlan.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return TrainingPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      version: json['version'] as int,
      goal: json['goal'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      publishedAt: json['publishedAt'] as String?,
      days: (json['days'] as List? ?? const [])
          .map(TrainingDay.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String status;
  final int version;
  final String? goal;
  final String? startDate;
  final String? endDate;
  final String? publishedAt;
  final List<TrainingDay> days;

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Đã công bố',
    'ARCHIVED' => 'Đã lưu trữ',
    'DRAFT' => 'Bản nháp',
    _ => status,
  };
}
