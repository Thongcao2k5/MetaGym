import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';

abstract interface class MessagingService {
  Future<List<Conversation>> getConversations(int page);
  Future<List<ChatMessage>> getMessages(String relationshipId, int page);
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
}
