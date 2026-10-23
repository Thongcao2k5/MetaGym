import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';

abstract interface class AiService {
  Future<List<AiConversation>> getConversations(int page);
  Future<AiConversation> create();
  Future<AiConversation> rename(String id, String title);
  Future<void> delete(String id);
}

class AiApi implements AiService {
  const AiApi(this.client);
  final ApiClient client;

  @override
  Future<List<AiConversation>> getConversations(int page) async =>
      (await client.get<List<AiConversation>>(
        '/ai-conversations',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) =>
            (value as List).map(AiConversation.fromJson).toList(),
      )).data;

  @override
  Future<AiConversation> create() async => (await client.post<AiConversation>(
    '/ai-conversations',
    body: <String, Object?>{},
    decode: AiConversation.fromJson,
  )).data;

  @override
  Future<AiConversation> rename(String id, String title) async =>
      (await client.patch<AiConversation>(
        '/ai-conversations/${Uri.encodeComponent(id)}',
        body: {'title': title},
        decode: AiConversation.fromJson,
      )).data;

  @override
  Future<void> delete(String id) async {
    await client.delete<Map<String, dynamic>>(
      '/ai-conversations/${Uri.encodeComponent(id)}',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }
}
