class SelfTrainingExercise {
  const SelfTrainingExercise({required this.id, required this.name});

  factory SelfTrainingExercise.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return SelfTrainingExercise(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  final String id;
  final String name;
}

class MemberSelfTrainingDay {
  const MemberSelfTrainingDay({
    required this.id,
    required this.planDate,
    required this.title,
    required this.exercises,
    this.startTime,
    this.notes = '',
  });

  factory MemberSelfTrainingDay.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MemberSelfTrainingDay(
      id: json['id'] as String,
      planDate: json['planDate'] as String,
      title: json['title'] as String,
      startTime: json['startTime'] as String?,
      notes: json['notes'] as String? ?? '',
      exercises: (json['exercises'] as List? ?? const [])
          .map(SelfTrainingExercise.fromJson)
          .toList(),
    );
  }

  final String id;
  final String planDate;
  final String title;
  final String? startTime;
  final String notes;
  final List<SelfTrainingExercise> exercises;
}
