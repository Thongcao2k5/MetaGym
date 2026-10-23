class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String createdAt;
  final String updatedAt;

  factory AiConversation.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return AiConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
