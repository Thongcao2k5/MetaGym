class GymProfile {
  const GymProfile({
    required this.name,
    required this.address,
    this.description,
    this.phone,
    this.email,
    this.rules,
    this.openingHours = const {},
  });

  factory GymProfile.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return GymProfile(
      name: json['name'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      rules: json['rules'] as String?,
      openingHours: Map<String, dynamic>.from(
        json['openingHours'] as Map? ?? const {},
      ),
    );
  }

  final String name;
  final String address;
  final String? description;
  final String? phone;
  final String? email;
  final String? rules;
  final Map<String, dynamic> openingHours;
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    this.status = 'ACTIVE',
    this.description,
    this.category,
    this.instructions,
    this.usageSteps = const [],
    this.safetyNotes,
    this.targetMuscles = const [],
    this.videoUrl,
  });

  factory CatalogItem.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return CatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      description: json['description'] as String?,
      category: json['category'] as String?,
      instructions: json['instructions'] as String?,
      usageSteps: (json['usageSteps'] as List? ?? const [])
          .map((value) => value as String)
          .toList(),
      safetyNotes: json['safetyNotes'] as String?,
      targetMuscles: (json['targetMuscles'] as List? ?? const [])
          .map((value) => value as String)
          .toList(),
      videoUrl: json['videoUrl'] as String?,
    );
  }

  final String id;
  final String name;
  final String status;
  final String? description;
  final String? category;
  final String? instructions;
  final List<String> usageSteps;
  final String? safetyNotes;
  final List<String> targetMuscles;
  final String? videoUrl;
}
