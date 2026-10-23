import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';

abstract interface class MemberMealService {
  Future<List<MealLog>> getPage(int page);
  Future<MealLog> create(Map<String, Object?> payload);
  Future<MealLog> update(String id, Map<String, Object?> payload);
}

class MemberMealApi implements MemberMealService {
  const MemberMealApi(this.client);
  final ApiClient client;
  @override
  Future<List<MealLog>> getPage(int page) async =>
      (await client.get<List<MealLog>>(
        '/meal-logs',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(MealLog.fromJson).toList(),
      )).data;
  @override
  Future<MealLog> create(Map<String, Object?> payload) async =>
      (await client.post<MealLog>(
        '/meal-logs',
        body: payload,
        decode: MealLog.fromJson,
      )).data;
  @override
  Future<MealLog> update(String id, Map<String, Object?> payload) async =>
      (await client.patch<MealLog>(
        '/meal-logs/${Uri.encodeComponent(id)}',
        body: payload,
        decode: MealLog.fromJson,
      )).data;
}
