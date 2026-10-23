import 'dart:math';

import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';

abstract interface class MessagingService {
  Future<List<Conversation>> getConversations(int page);
  Future<List<ChatMessage>> getMessages(String relationshipId, int page);
  Future<ChatMessage> sendText(
    String relationshipId,
    String content,
    String clientMessageId,
  );
  Future<void> markRead(String relationshipId, String messageId);
}

String newClientMessageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class MessagingApi implements MessagingService {
  const MessagingApi(this.client);
  final ApiClient client;

  @override
  Future<List<Conversation>> getConversations(int page) async =>
      (await client.get<List<Conversation>>(
        '/conversations',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(Conversation.fromJson).toList(),
      )).data;

  @override
  Future<List<ChatMessage>> getMessages(
    String relationshipId,
    int page,
  ) async => (await client.get<List<ChatMessage>>(
    '/conversations/${Uri.encodeComponent(relationshipId)}/messages',
    queryParameters: {'page': page, 'pageSize': 20},
    decode: (value) => (value as List).map(ChatMessage.fromJson).toList(),
  )).data;

  @override
  Future<ChatMessage> sendText(
    String relationshipId,
    String content,
    String clientMessageId,
  ) async => (await client.post<ChatMessage>(
    '/conversations/${Uri.encodeComponent(relationshipId)}/messages',
    body: {
      'messageType': 'TEXT',
      'clientMessageId': clientMessageId,
      'content': content,
    },
    decode: ChatMessage.fromJson,
  )).data;

  @override
  Future<void> markRead(String relationshipId, String messageId) async {
    await client.patch<Map<String, dynamic>>(
      '/conversations/${Uri.encodeComponent(relationshipId)}/read-state',
      body: {'messageId': messageId},
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }
}
