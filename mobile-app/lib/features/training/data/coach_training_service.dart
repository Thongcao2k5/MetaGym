import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_api.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

abstract interface class CoachTrainingService {
  Future<List<CoachMemberSummary>> getMembers();
  Future<List<CatalogItem>> getExercises();
  Future<List<TrainingPlan>> getPlans(String memberId);
  Future<TrainingPlan> getPlan(String id);
  Future<TrainingPlan> create(String memberId, Map<String, Object?> payload);
  Future<TrainingPlan> update(String id, Map<String, Object?> payload);
  Future<TrainingPlan> publish(String id);
}

class CoachTrainingApi implements CoachTrainingService {
  const CoachTrainingApi(this.client);

  final ApiClient client;

  @override
  Future<List<CoachMemberSummary>> getMembers() =>
      CoachMembersApi(client).getMembers();

  @override
  Future<List<CatalogItem>> getExercises() => CatalogApi(client).getExercises();

  @override
  Future<List<TrainingPlan>> getPlans(String memberId) async =>
      (await client.get<List<TrainingPlan>>(
        '/coach/members/${Uri.encodeComponent(memberId)}/training-plans',
        decode: (value) => (value as List).map(TrainingPlan.fromJson).toList(),
      )).data;

  @override
  Future<TrainingPlan> getPlan(String id) async =>
      (await client.get<TrainingPlan>(
        '/training-plans/${Uri.encodeComponent(id)}',
        decode: TrainingPlan.fromJson,
      )).data;

  @override
  Future<TrainingPlan> create(
    String memberId,
    Map<String, Object?> payload,
  ) async => (await client.post<TrainingPlan>(
    '/coach/members/${Uri.encodeComponent(memberId)}/training-plans',
    body: payload,
    decode: TrainingPlan.fromJson,
  )).data;

  @override
  Future<TrainingPlan> update(String id, Map<String, Object?> payload) async =>
      (await client.patch<TrainingPlan>(
        '/coach/training-plans/${Uri.encodeComponent(id)}',
        body: payload,
        decode: TrainingPlan.fromJson,
      )).data;

  @override
  Future<TrainingPlan> publish(String id) async =>
      (await client.post<TrainingPlan>(
        '/coach/training-plans/${Uri.encodeComponent(id)}/publications',
        body: const <String, Object?>{},
        decode: TrainingPlan.fromJson,
      )).data;
}
