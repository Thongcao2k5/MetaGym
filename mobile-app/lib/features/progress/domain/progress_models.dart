class WeightPoint {
  const WeightPoint({
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
  });
  final String measuredAt;
  final double weightKg;
  final double? bodyFatPercent;

  factory WeightPoint.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    double? number(dynamic value) => value == null
        ? null
        : value is num
        ? value.toDouble()
        : double.parse(value as String);
    return WeightPoint(
      measuredAt: json['measuredAt'] as String,
      weightKg: number(json['weightKg'])!,
      bodyFatPercent: number(json['bodyFatPercent']),
    );
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.workoutCount,
    required this.mealCount,
    required this.progressPhotoCount,
    this.latestMeasurement,
  });
  final int workoutCount;
  final int mealCount;
  final int progressPhotoCount;
  final WeightPoint? latestMeasurement;

  factory ProgressSummary.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return ProgressSummary(
      workoutCount: json['workoutCount'] as int,
      mealCount: json['mealCount'] as int,
      progressPhotoCount: json['progressPhotoCount'] as int,
      latestMeasurement: json['latestMeasurement'] == null
          ? null
          : WeightPoint.fromJson(json['latestMeasurement']),
    );
  }
}
