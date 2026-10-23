import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';

abstract interface class CoachSelectionService {
  Future<List<CoachProfile>> getCoaches();
  Future<CoachProfile> getCoach(String id);
  Future<CoachRequest> sendRequest(String coachId, String? message);
}

class CoachSelectionApi implements CoachSelectionService {
  const CoachSelectionApi(this.client);

  final ApiClient client;

  @override
  Future<List<CoachProfile>> getCoaches() async =>
      (await client.get<List<CoachProfile>>(
        '/coaches',
        decode: (value) => (value as List).map(CoachProfile.fromJson).toList(),
      )).data;

  @override
  Future<CoachProfile> getCoach(String id) async =>
      (await client.get<CoachProfile>(
        '/coaches/${Uri.encodeComponent(id)}',
        decode: CoachProfile.fromJson,
      )).data;

  @override
  Future<CoachRequest> sendRequest(String coachId, String? message) async =>
      (await client.post<CoachRequest>(
        '/coach-requests',
        body: {'coachId': coachId, 'message': message},
        decode: CoachRequest.fromJson,
      )).data;
}
