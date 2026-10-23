class CoachProfile {
  const CoachProfile({
    required this.id,
    required this.fullName,
    required this.memberLimit,
    required this.usedSlots,
    required this.availableSlots,
    this.biography,
    this.specialties = const [],
    this.qualifications,
    this.experienceYears,
    this.availabilityNote,
  });

  factory CoachProfile.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachProfile(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      memberLimit: json['memberLimit'] as int,
      usedSlots: json['usedSlots'] as int,
      availableSlots: json['availableSlots'] as int,
      biography: json['biography'] as String?,
      specialties: (json['specialties'] as List? ?? const [])
          .map((value) => value as String)
          .toList(),
      qualifications: json['qualifications'] as String?,
      experienceYears: json['experienceYears'] as int?,
      availabilityNote: json['availabilityNote'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String? biography;
  final List<String> specialties;
  final String? qualifications;
  final int? experienceYears;
  final String? availabilityNote;
  final int memberLimit;
  final int usedSlots;
  final int availableSlots;
}

class CoachRequest {
  const CoachRequest({required this.id, required this.status});

  factory CoachRequest.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CoachRequest(
      id: json['id'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String status;
}
