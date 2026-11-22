import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';

abstract interface class MemberCoachingService {
  Future<Map<String, String>> getCoachNames();
  Future<List<MemberCoachRequest>> getRequests();
  Future<MemberCoachRelationship?> getCurrentRelationship();
  Future<List<MemberCoachRelationship>> getRelationshipHistory();
  Future<void> cancelRequest(String id);
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  });
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests();
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  );
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  });
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
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    return (await client.post<CoachLockChoiceResult>(
      '/relationships/me/coach-lock-choice',
      body: {
        'choice': choice,
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
      },
      decode: CoachLockChoiceResult.fromJson,
    )).data;
  }

  @override
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests() async =>
      (await client.get<List<CoachTerminationRequest>>(
        '/early-termination-requests/me',
        decode: (value) =>
            (value as List).map(CoachTerminationRequest.fromJson).toList(),
      )).data;

  @override
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  ) async =>
      (await client.post<CoachTerminationRequest>(
        '/relationships/${Uri.encodeComponent(relationshipId)}/early-termination-requests',
        body: {'reason': reason.trim()},
        decode: CoachTerminationRequest.fromJson,
      )).data;

  @override
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();
    return (await client.patch<CoachTerminationRequest>(
      '/early-termination-requests/${Uri.encodeComponent(requestId)}/respond',
      body: {
        'decision': decision,
        if (trimmedReason != null && trimmedReason.isNotEmpty)
          'reason': trimmedReason,
      },
      decode: CoachTerminationRequest.fromJson,
    )).data;
  }
}
