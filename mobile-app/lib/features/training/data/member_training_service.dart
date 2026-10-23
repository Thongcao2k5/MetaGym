import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

abstract interface class MemberTrainingService {
  Future<TrainingPlan?> getActive();
  Future<List<TrainingPlan>> getHistory();
  Future<TrainingPlan> getPlan(String id);
}

class MemberTrainingApi implements MemberTrainingService {
  const MemberTrainingApi(this.client);

  final ApiClient client;

  @override
  Future<TrainingPlan?> getActive() async => (await client.get<TrainingPlan?>(
    '/training-plans/me/active',
    decode: (value) => value == null ? null : TrainingPlan.fromJson(value),
  )).data;

  @override
  Future<List<TrainingPlan>> getHistory() async =>
      (await client.get<List<TrainingPlan>>(
        '/training-plans/me/history',
        decode: (value) => (value as List).map(TrainingPlan.fromJson).toList(),
      )).data;

  @override
  Future<TrainingPlan> getPlan(String id) async =>
      (await client.get<TrainingPlan>(
        '/training-plans/${Uri.encodeComponent(id)}',
        decode: TrainingPlan.fromJson,
      )).data;
}
