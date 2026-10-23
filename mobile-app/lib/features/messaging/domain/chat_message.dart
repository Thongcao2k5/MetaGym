class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.messageType,
    required this.sentAt,
    this.content,
    this.mediaId,
  });

  final String id;
  final String senderId;
  final String messageType;
  final String sentAt;
  final String? content;
  final String? mediaId;

  factory ChatMessage.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      messageType: json['messageType'] as String,
      sentAt: json['sentAt'] as String,
      content: json['content'] as String?,
      mediaId: json['mediaId'] as String?,
    );
  }
}
