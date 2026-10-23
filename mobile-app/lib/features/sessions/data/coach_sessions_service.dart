import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';

abstract interface class CoachSessionsService {
  Future<List<TrainingSession>> getAll();
  Future<TrainingSession> create(Map<String, Object?> payload);
  Future<TrainingSession> update(String id, Map<String, Object?> payload);
}

class CoachSessionsApi implements CoachSessionsService {
  const CoachSessionsApi(this.client);
  final ApiClient client;

  @override
  Future<List<TrainingSession>> getAll() async =>
      (await client.get<List<TrainingSession>>(
        '/coach/training-sessions',
        decode: (value) =>
            (value as List).map(TrainingSession.fromJson).toList(),
      )).data;

  @override
  Future<TrainingSession> create(Map<String, Object?> payload) async =>
      (await client.post<TrainingSession>(
        '/coach/training-sessions',
        body: payload,
        decode: TrainingSession.fromJson,
      )).data;

  @override
  Future<TrainingSession> update(
    String id,
    Map<String, Object?> payload,
  ) async => (await client.patch<TrainingSession>(
    '/coach/training-sessions/${Uri.encodeComponent(id)}',
    body: payload,
    decode: TrainingSession.fromJson,
  )).data;
}
