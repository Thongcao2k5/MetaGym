String formatConversationTimestamp(String? rawTimestamp, {DateTime? now}) {
  final trimmed = rawTimestamp?.trim();
  if (trimmed == null || trimmed.isEmpty) return '';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  final local = parsed.toLocal();
  final ref = (now ?? DateTime.now()).toLocal();
  final today = DateTime(ref.year, ref.month, ref.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(messageDay).inDays;
  if (diffDays <= 0) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (diffDays == 1) {
    return 'Hôm qua';
  }
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd/$mo';
}

class Conversation {
  const Conversation({
    required this.id,
    required this.relationshipId,
    required this.memberId,
    required this.coachId,
    required this.status,
    required this.unreadCount,
    this.memberName,
    this.coachName,
    this.lastMessageAt,
    this.lastMessageType,
    this.lastMessageContent,
    this.lastMessageSenderId,
  });

  final String id;
  final String? relationshipId;
  final String memberId;
  final String coachId;
  final String status;
  final int unreadCount;
  final String? memberName;
  final String? coachName;
  final String? lastMessageAt;
  final String? lastMessageType;
  final String? lastMessageContent;
  final String? lastMessageSenderId;

  String get messageKey => relationshipId ?? id;

  bool get canSend =>
      const {'NONE', 'ACTIVE', 'PAUSED', 'ENDED'}.contains(status);

  String get lastMessagePreview {
    if (lastMessageType == 'IMAGE') return 'Ảnh';
    final text = lastMessageContent?.trim();
    if (text != null && text.isNotEmpty) return text;
    return 'Chưa có tin nhắn';
  }

  String formatLastMessageTime({DateTime? now}) =>
      formatConversationTimestamp(lastMessageAt, now: now);

  String displayNameFor(String currentUserId) {
    final isMember = memberId == currentUserId;
    final name = (isMember ? coachName : memberName)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return isMember ? 'Coach $coachId' : 'Hội viên $memberId';
  }

  String initialsFor(String currentUserId) {
    final parts = displayNameFor(currentUserId)
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.isEmpty ? 'MG' : parts.first[0].toUpperCase();
  }

  Conversation copyWith({
    String? id,
    String? relationshipId,
    String? memberId,
    String? coachId,
    String? status,
    int? unreadCount,
    String? memberName,
    String? coachName,
    String? lastMessageAt,
    String? lastMessageType,
    String? lastMessageContent,
    String? lastMessageSenderId,
  }) {
    return Conversation(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      memberId: memberId ?? this.memberId,
      coachId: coachId ?? this.coachId,
      status: status ?? this.status,
      unreadCount: unreadCount ?? this.unreadCount,
      memberName: memberName ?? this.memberName,
      coachName: coachName ?? this.coachName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
    );
  }

  factory Conversation.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return Conversation(
      id: json['id'] as String,
      relationshipId: json['relationshipId'] as String?,
      memberId: json['memberId'] as String,
      coachId: json['coachId'] as String,
      status: json['status'] as String,
      unreadCount: json['unreadCount'] as int,
      memberName: json['memberName'] as String?,
      coachName: json['coachName'] as String?,
      lastMessageAt: json['lastMessageAt'] as String?,
      lastMessageType: json['lastMessageType'] as String?,
      lastMessageContent: json['lastMessageContent'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
    );
  }
}
