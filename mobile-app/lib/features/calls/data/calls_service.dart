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

  Future<CallLog> createLiveCall(
    String relationshipId,
    String callType,
  ) async => (await client.post<CallLog>(
    '/calls',
    body: {
      'relationshipId': relationshipId,
      'callType': callType,
      'live': true,
    },
    decode: CallLog.fromJson,
  )).data;

  Future<CallLog?> getIncoming() async => (await client.get<List<CallLog>>(
    '/calls/incoming',
    decode: (value) => (value as List).map(CallLog.fromJson).toList(),
  )).data.firstOrNull;

  Future<CallLog> getCall(String callId) async => (await client.get<CallLog>(
    '/calls/${Uri.encodeComponent(callId)}',
    decode: CallLog.fromJson,
  )).data;

  Future<({String url, String token})> getRoomAccess(String callId) async =>
      (await client.post<({String url, String token})>(
        '/calls/${Uri.encodeComponent(callId)}/access-tokens',
        body: const <String, dynamic>{},
        decode: (value) {
          final data = value as Map;
          return (
            url: data['serverUrl'] as String,
            token: data['accessToken'] as String,
          );
        },
      )).data;

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
