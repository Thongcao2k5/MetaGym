class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.bodyFatPercent,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.notes,
  });
  final String id;
  final String measuredAt;
  final double weightKg;
  final double? bodyFatPercent;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final String? notes;

  factory BodyMeasurement.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    double? number(dynamic value) => value == null
        ? null
        : value is num
        ? value.toDouble()
        : double.parse(value as String);
    return BodyMeasurement(
      id: json['id'] as String,
      measuredAt: json['measuredAt'] as String,
      weightKg: number(json['weightKg'])!,
      bodyFatPercent: number(json['bodyFatPercent']),
      chestCm: number(json['chestCm']),
      waistCm: number(json['waistCm']),
      hipsCm: number(json['hipsCm']),
      armCm: number(json['armCm']),
      thighCm: number(json['thighCm']),
      notes: json['notes'] as String?,
    );
  }
}
