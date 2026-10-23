class WorkoutExercise {
  const WorkoutExercise({required this.name, this.setsCompleted});
  final String name;
  final int? setsCompleted;
  factory WorkoutExercise.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return WorkoutExercise(
      name: json['exerciseName'] as String,
      setsCompleted: json['setsCompleted'] as int?,
    );
  }
}

class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.performedAt,
    this.durationMinutes,
    this.completionLevel,
    this.notes,
    this.exercises = const [],
  });
  final String id;
  final String performedAt;
  final int? durationMinutes;
  final int? completionLevel;
  final String? notes;
  final List<WorkoutExercise> exercises;

  factory WorkoutLog.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return WorkoutLog(
      id: json['id'] as String,
      performedAt: json['performedAt'] as String,
      durationMinutes: json['durationMinutes'] as int?,
      completionLevel: json['completionLevel'] as int?,
      notes: json['notes'] as String?,
      exercises: ((json['exercises'] as List?) ?? [])
          .map(WorkoutExercise.fromJson)
          .toList(),
    );
  }
}
