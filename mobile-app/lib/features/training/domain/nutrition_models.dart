class NutritionGuide {
  const NutritionGuide({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    required this.version,
    this.publishedAt,
  });

  factory NutritionGuide.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return NutritionGuide(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      version: json['version'] as int,
      publishedAt: json['publishedAt'] as String?,
    );
  }

  final String id;
  final String title;
  final String content;
  final String status;
  final int version;
  final String? publishedAt;

  String get statusLabel => switch (status) {
    'DRAFT' => 'Bản nháp',
    'ACTIVE' => 'Đã công bố',
    'ARCHIVED' => 'Đã lưu trữ',
    _ => status,
  };

  String get publicationLabel => publishedAt == null
      ? 'Chưa công bố'
      : 'Công bố: ${publishedAt!.split('T').first}';
}
