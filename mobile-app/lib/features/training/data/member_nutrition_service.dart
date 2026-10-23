import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';

abstract interface class MemberNutritionService {
  Future<NutritionGuide?> getActive();
  Future<List<NutritionGuide>> getHistory();
}

class MemberNutritionApi implements MemberNutritionService {
  const MemberNutritionApi(this.client);

  final ApiClient client;

  @override
  Future<NutritionGuide?> getActive() async =>
      (await client.get<NutritionGuide?>(
        '/nutrition-guides/me/active',
        decode: (value) =>
            value == null ? null : NutritionGuide.fromJson(value),
      )).data;

  @override
  Future<List<NutritionGuide>> getHistory() async =>
      (await client.get<List<NutritionGuide>>(
        '/nutrition-guides/me/history',
        decode: (value) =>
            (value as List).map(NutritionGuide.fromJson).toList(),
      )).data;
}
