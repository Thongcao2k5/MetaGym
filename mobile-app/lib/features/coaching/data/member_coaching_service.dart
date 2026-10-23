import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';

abstract interface class MemberCoachingService {
  Future<Map<String, String>> getCoachNames();
  Future<List<MemberCoachRequest>> getRequests();
  Future<MemberCoachRelationship?> getCurrentRelationship();
  Future<List<MemberCoachRelationship>> getRelationshipHistory();
  Future<void> cancelRequest(String id);
  Future<void> terminateRelationship(String id, String reason);
}

class MemberCoachingApi implements MemberCoachingService {
  const MemberCoachingApi(this.client);

  final ApiClient client;

  @override
  Future<Map<String, String>> getCoachNames() async => {
    for (final coach in await CoachSelectionApi(client).getCoaches())
      coach.id: coach.fullName,
  };

  @override
  Future<List<MemberCoachRequest>> getRequests() async =>
      (await client.get<List<MemberCoachRequest>>(
        '/coach-requests/me',
        decode: (value) =>
            (value as List).map(MemberCoachRequest.fromJson).toList(),
      )).data;

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async =>
      (await client.get<MemberCoachRelationship?>(
        '/relationships/me',
        decode: (value) =>
            value == null ? null : MemberCoachRelationship.fromJson(value),
      )).data;

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async =>
      (await client.get<List<MemberCoachRelationship>>(
        '/relationships/me/history',
        decode: (value) =>
            (value as List).map(MemberCoachRelationship.fromJson).toList(),
      )).data;

  @override
  Future<void> cancelRequest(String id) async {
    await client.delete<MemberCoachRequest>(
      '/coach-requests/${Uri.encodeComponent(id)}',
      decode: MemberCoachRequest.fromJson,
    );
  }

  @override
  Future<void> terminateRelationship(String id, String reason) async {
    await client.post<MemberCoachRelationship>(
      '/relationships/${Uri.encodeComponent(id)}/terminations',
      body: {'reason': reason},
      decode: MemberCoachRelationship.fromJson,
    );
  }
}
