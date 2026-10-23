import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';

abstract interface class CallsService {
  Future<List<CallLog>> getCalls(int page);
  Future<List<Conversation>> getActiveRelationships();
  Future<CallLog> create(String relationshipId, String callType);
  Future<CallLog> updateStatus(
    String callId,
    String status, {
    String? failureReason,
  });
}

class CallsApi implements CallsService {
  const CallsApi(this.client);
  final ApiClient client;

  @override
  Future<List<CallLog>> getCalls(int page) async =>
      (await client.get<List<CallLog>>(
        '/calls',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(CallLog.fromJson).toList(),
      )).data;

  @override
  Future<List<Conversation>> getActiveRelationships() async =>
      (await client.get<List<Conversation>>(
        '/conversations',
        queryParameters: {'page': 1, 'pageSize': 100},
        decode: (value) => (value as List)
            .map(Conversation.fromJson)
            .where((item) => item.canSend)
            .toList(),
      )).data;

  @override
  Future<CallLog> create(String relationshipId, String callType) async =>
      (await client.post<CallLog>(
        '/calls',
        body: {'relationshipId': relationshipId, 'callType': callType},
        decode: CallLog.fromJson,
      )).data;

  @override
  Future<CallLog> updateStatus(
    String callId,
    String status, {
    String? failureReason,
  }) async => (await client.patch<CallLog>(
    '/calls/${Uri.encodeComponent(callId)}',
    body: {'status': status, 'failureReason': ?failureReason},
    decode: CallLog.fromJson,
  )).data;
}
