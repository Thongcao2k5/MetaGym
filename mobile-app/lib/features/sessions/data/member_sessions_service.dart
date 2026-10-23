import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';

abstract interface class MemberSessionsService {
  Future<List<TrainingSession>> getMine();
  Future<TrainingSession> getDetail(String id);
}

class MemberSessionsApi implements MemberSessionsService {
  const MemberSessionsApi(this.client);

  final ApiClient client;

  @override
  Future<List<TrainingSession>> getMine() async =>
      (await client.get<List<TrainingSession>>(
        '/training-sessions/me',
        decode: (value) =>
            (value as List).map(TrainingSession.fromJson).toList(),
      )).data;

  @override
  Future<TrainingSession> getDetail(String id) async =>
      (await client.get<TrainingSession>(
        '/training-sessions/${Uri.encodeComponent(id)}',
        decode: TrainingSession.fromJson,
      )).data;
}
