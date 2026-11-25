class SelfTrainingExercise {
  const SelfTrainingExercise({
    required this.id,
    required this.name,
    this.sets,
    this.reps,
  });

  factory SelfTrainingExercise.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final rawSets = json['sets'];
    final parsedSets = rawSets is num
        ? rawSets.toInt()
        : int.tryParse(rawSets?.toString() ?? '');
    final rawReps = json['reps']?.toString().trim();
    return SelfTrainingExercise(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      sets: (parsedSets != null && parsedSets > 0) ? parsedSets : null,
      reps: (rawReps != null && rawReps.isNotEmpty) ? rawReps : null,
    );
  }

  final String id;
  final String name;
  final int? sets;
  final String? reps;

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    if (sets != null) 'sets': sets,
    if (reps != null && reps!.isNotEmpty) 'reps': reps,
  };

  String? get volumeLabel {
    final cleanReps = reps?.trim();
    final hasReps = cleanReps != null && cleanReps.isNotEmpty;
    if (sets != null && hasReps) return '$sets set × $cleanReps rep';
    if (sets != null) return '$sets set';
    if (hasReps) return '$cleanReps rep';
    return null;
  }
}

class MemberSelfTrainingDay {
  const MemberSelfTrainingDay({
    required this.id,
    required this.planDate,
    required this.title,
    required this.exercises,
    this.startTime,
    this.notes = '',
    this.iconKey,
  });

  factory MemberSelfTrainingDay.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MemberSelfTrainingDay(
      id: json['id'] as String,
      planDate: json['planDate'] as String,
      title: json['title'] as String,
      startTime: json['startTime'] as String?,
      notes: json['notes'] as String? ?? '',
      iconKey: json['iconKey'] as String?,
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
  final String? iconKey;
  final List<SelfTrainingExercise> exercises;
}
