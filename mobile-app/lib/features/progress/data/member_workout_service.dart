import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';

abstract interface class MemberWorkoutService {
  Future<List<WorkoutLog>> getPage(int page);
  Future<WorkoutLog> create(Map<String, Object?> payload);
  Future<WorkoutLog> update(String id, Map<String, Object?> payload);
}

class MemberWorkoutApi implements MemberWorkoutService {
  const MemberWorkoutApi(this.client);
  final ApiClient client;

  @override
  Future<List<WorkoutLog>> getPage(int page) async =>
      (await client.get<List<WorkoutLog>>(
        '/workout-logs',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(WorkoutLog.fromJson).toList(),
      )).data;

  @override
  Future<WorkoutLog> create(Map<String, Object?> payload) async =>
      (await client.post<WorkoutLog>(
        '/workout-logs',
        body: payload,
        decode: WorkoutLog.fromJson,
      )).data;

  @override
  Future<WorkoutLog> update(String id, Map<String, Object?> payload) async =>
      (await client.patch<WorkoutLog>(
        '/workout-logs/${Uri.encodeComponent(id)}',
        body: payload,
        decode: WorkoutLog.fromJson,
      )).data;
}
