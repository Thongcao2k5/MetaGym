class MealLog {
  const MealLog({
    required this.id,
    required this.eatenAt,
    required this.mealName,
    this.mealType,
    this.estimatedCalories,
    this.description,
    this.notes,
  });
  final String id;
  final String eatenAt;
  final String mealName;
  final String? mealType;
  final int? estimatedCalories;
  final String? description;
  final String? notes;

  factory MealLog.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return MealLog(
      id: json['id'] as String,
      eatenAt: json['eatenAt'] as String,
      mealName: json['mealName'] as String,
      mealType: json['mealType'] as String?,
      estimatedCalories: json['estimatedCalories'] as int?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
    );
  }

  String get typeLabel => switch (mealType) {
    'BREAKFAST' => 'Bữa sáng',
    'LUNCH' => 'Bữa trưa',
    'DINNER' => 'Bữa tối',
    'SNACK' => 'Bữa phụ',
    'OTHER' => 'Khác',
    _ => 'Chưa phân loại',
  };
}
