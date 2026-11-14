class JournalAchievement {
  const JournalAchievement({required this.title, required this.result});

  final String title;
  final String result;

  factory JournalAchievement.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return JournalAchievement(
      title: json['title'] as String,
      result: json['result'] as String,
    );
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.journalDate,
    required this.achievements,
    required this.photoMediaIds,
    this.notes,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
  });

  final String id;
  final String journalDate;
  final String? notes;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final List<JournalAchievement> achievements;
  final List<String> photoMediaIds;

  factory JournalEntry.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    double? number(String key) {
      final value = json[key];
      return value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
    }

    return JournalEntry(
      id: json['id'] as String,
      journalDate: json['journalDate'] as String,
      notes: json['notes'] as String?,
      chestCm: number('chestCm'),
      waistCm: number('waistCm'),
      hipsCm: number('hipsCm'),
      achievements: (json['achievements'] as List)
          .map(JournalAchievement.fromJson)
          .toList(),
      photoMediaIds: (json['photoMediaIds'] as List).cast<String>(),
    );
  }
}

class JournalChartPoint {
  const JournalChartPoint({
    required this.journalDate,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
  });

  final String journalDate;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;

  factory JournalChartPoint.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    double? number(String key) {
      final value = json[key];
      return value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
    }

    return JournalChartPoint(
      journalDate: json['journalDate'] as String,
      chestCm: number('chestCm'),
      waistCm: number('waistCm'),
      hipsCm: number('hipsCm'),
    );
  }
}
