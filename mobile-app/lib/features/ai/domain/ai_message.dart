class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String role;
  final String content;
  final String status;
  final String createdAt;

  factory AiMessage.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return AiMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class AiReply {
  const AiReply({
    required this.id,
    required this.content,
    required this.createdAt,
  });
  final String id;
  final String content;
  final String createdAt;

  factory AiReply.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    return AiReply(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class AiAnswerResult {
  const AiAnswerResult({
    required this.requestId,
    required this.status,
    this.reply,
  });
  final String requestId;
  final String status;
  final AiReply? reply;
  bool get isComplete => status == 'COMPLETED' && reply != null;

  factory AiAnswerResult.fromJson(dynamic value) {
    final json = Map<String, dynamic>.from(value as Map);
    final status = json['status'] as String;
    final reply = json['reply'];
    if (status == 'COMPLETED' && reply == null) {
      throw const FormatException('Phản hồi AI chưa hoàn tất.');
    }
    return AiAnswerResult(
      requestId: json['requestId'] as String,
      status: status,
      reply: reply == null ? null : AiReply.fromJson(reply),
    );
  }
}
