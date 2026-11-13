class Conversation {
  const Conversation({
    required this.id,
    required this.relationshipId,
    required this.memberId,
    required this.coachId,
    required this.status,
    required this.unreadCount,
    this.lastMessageAt,
  });

  final String id;
  final String? relationshipId;
  final String memberId;
  final String coachId;
  final String status;
  final int unreadCount;
  final String? lastMessageAt;

  String get messageKey => relationshipId ?? id;

  bool get canSend => const {'NONE', 'ACTIVE', 'PAUSED', 'ENDED'}.contains(status);

  factory Conversation.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Conversation(
      id: json['id'] as String,
      relationshipId: json['relationshipId'] as String?,
      memberId: json['memberId'] as String,
      coachId: json['coachId'] as String,
      status: json['status'] as String,
      unreadCount: json['unreadCount'] as int,
      lastMessageAt: json['lastMessageAt'] as String?,
    );
  }
}
