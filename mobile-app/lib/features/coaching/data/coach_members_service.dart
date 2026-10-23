import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';

abstract interface class CoachMembersService {
  Future<List<CoachMemberSummary>> getMembers();
  Future<CoachMemberDetail> getMember(String memberId);
  Future<List<CoachTerminationRequest>> getTerminationRequests();
  Future<void> requestTermination(String relationshipId, String reason);
}

class CoachMembersApi implements CoachMembersService {
  const CoachMembersApi(this.client);

  final ApiClient client;

  @override
  Future<List<CoachMemberSummary>> getMembers() async =>
      (await client.get<List<CoachMemberSummary>>(
        '/coach/members',
        decode: (value) =>
            (value as List).map(CoachMemberSummary.fromJson).toList(),
      )).data;

  @override
  Future<CoachMemberDetail> getMember(String memberId) async =>
      (await client.get<CoachMemberDetail>(
        '/coach/members/${Uri.encodeComponent(memberId)}',
        decode: CoachMemberDetail.fromJson,
      )).data;

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      (await client.get<List<CoachTerminationRequest>>(
        '/coach/termination-requests',
        decode: (value) =>
            (value as List).map(CoachTerminationRequest.fromJson).toList(),
      )).data;

  @override
  Future<void> requestTermination(String relationshipId, String reason) async {
    await client.post<CoachTerminationRequest>(
      '/coach/termination-requests',
      body: {'relationshipId': relationshipId, 'reason': reason},
      decode: CoachTerminationRequest.fromJson,
    );
  }
}
