import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';

abstract interface class CoachRequestsService {
  Future<List<CoachIncomingRequest>> getRequests();
  Future<CoachIncomingRequest> getRequest(String id);
  Future<CoachProfile> getCoach(String id);
  Future<void> decide(String id, String decision, {String? reason});
}

class CoachRequestsApi implements CoachRequestsService {
  const CoachRequestsApi(this.client);

  final ApiClient client;

  @override
  Future<List<CoachIncomingRequest>> getRequests() async =>
      (await client.get<List<CoachIncomingRequest>>(
        '/coach/requests',
        decode: (value) =>
            (value as List).map(CoachIncomingRequest.fromJson).toList(),
      )).data;

  @override
  Future<CoachIncomingRequest> getRequest(String id) async =>
      (await client.get<CoachIncomingRequest>(
        '/coach/requests/${Uri.encodeComponent(id)}',
        decode: CoachIncomingRequest.fromJson,
      )).data;

  @override
  Future<CoachProfile> getCoach(String id) async =>
      (await client.get<CoachProfile>(
        '/coaches/${Uri.encodeComponent(id)}',
        decode: CoachProfile.fromJson,
      )).data;

  @override
  Future<void> decide(String id, String decision, {String? reason}) async {
    await client.patch<Object?>(
      '/coach/requests/${Uri.encodeComponent(id)}',
      body: {'decision': decision, 'reason': ?reason},
      decode: (value) => value,
    );
  }
}
