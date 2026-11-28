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

final RegExp _restOrRecoveryTitlePattern = RegExp(
  r'(nghỉ|phục hồi|hồi phục|\brest\b|recovery|off\s*day)',
  caseSensitive: false,
);

class TrainingDay {
  const TrainingDay({
    required this.dayNumber,
    required this.title,
    this.scheduledDate,
    this.notes,
    this.exercises = const [],
    this.meals = const [],
  });

  factory TrainingDay.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return TrainingDay(
      dayNumber: json['dayNumber'] as int,
      title: json['title'] as String,
      scheduledDate: json['scheduledDate'] as String?,
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List? ?? const [])
          .map(TrainingExercise.fromJson)
          .toList(),
      meals: (json['meals'] as List? ?? const [])
          .map(PlannedMeal.fromJson)
          .toList(),
    );
  }

  final int dayNumber;
  final String title;
  final String? scheduledDate;
  final String? notes;
  final List<TrainingExercise> exercises;
  final List<PlannedMeal> meals;

  bool get isRestOrRecovery =>
      exercises.isEmpty || _restOrRecoveryTitlePattern.hasMatch(title);

  bool get isTrainingDay => !isRestOrRecovery;

  int get recurringWeekday {
    final raw = scheduledDate?.trim();
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.weekday;
    }
    return ((dayNumber - 1) % DateTime.daysPerWeek) + 1;
  }
}

class PlannedMeal {
  const PlannedMeal({
    required this.displayOrder,
    required this.mealType,
    required this.title,
    this.scheduledTime,
    this.notes,
  });

  factory PlannedMeal.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return PlannedMeal(
      displayOrder: json['displayOrder'] as int,
      mealType: json['mealType'] as String,
      title: json['title'] as String,
      scheduledTime: json['scheduledTime'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final int displayOrder;
  final String mealType;
  final String title;
  final String? scheduledTime;
  final String? notes;

  String get typeLabel => switch (mealType) {
    'BREAKFAST' => 'Bữa sáng',
    'LUNCH' => 'Bữa trưa',
    'DINNER' => 'Bữa tối',
    'SNACK' => 'Bữa phụ',
    _ => 'Bữa ăn',
  };
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    this.relationshipId,
    this.coachId,
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
      relationshipId: json['relationshipId'] as String?,
      coachId: json['coachId'] as String?,
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
  final String? relationshipId;
  final String? coachId;
  final String? goal;
  final String? startDate;
  final String? endDate;
  final String? publishedAt;
  final List<TrainingDay> days;

  TrainingDay? dayForDate(DateTime date) {
    if (days.isEmpty) return null;
    final iso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    for (final day in days) {
      final scheduled = day.scheduledDate;
      if (scheduled != null &&
          scheduled.length >= 10 &&
          scheduled.substring(0, 10) == iso) {
        return day;
      }
    }
    for (final day in days) {
      if (day.recurringWeekday == date.weekday) return day;
    }
    return null;
  }

  bool isRestOrRecoveryDate(DateTime date) {
    if (days.isEmpty) return false;
    final day = dayForDate(date);
    return day == null || day.isRestOrRecovery;
  }

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Đã công bố',
    'ARCHIVED' => 'Đã lưu trữ',
    'DRAFT' => 'Bản nháp',
    _ => status,
  };
}
