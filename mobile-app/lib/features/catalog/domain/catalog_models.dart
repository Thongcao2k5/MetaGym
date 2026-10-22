class GymProfile {
  const GymProfile({
    required this.name,
    required this.address,
    this.description,
  });

  factory GymProfile.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return GymProfile(
      name: json['name'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
    );
  }

  final String name;
  final String address;
  final String? description;
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    this.status = 'ACTIVE',
    this.description,
    this.category,
    this.instructions,
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
    );
  }

  final String id;
  final String name;
  final String status;
  final String? description;
  final String? category;
  final String? instructions;
}
