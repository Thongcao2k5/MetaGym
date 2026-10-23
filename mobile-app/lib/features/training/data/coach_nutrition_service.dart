import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';

abstract interface class CoachNutritionService {
  Future<List<CoachMemberSummary>> getMembers();
  Future<List<NutritionGuide>> getGuides(String memberId);
  Future<NutritionGuide> create(String memberId, String title, String content);
  Future<NutritionGuide> update(
    String id,
    String title,
    String content, {
    bool publish = false,
  });
}

class CoachNutritionApi implements CoachNutritionService {
  const CoachNutritionApi(this.client);

  final ApiClient client;

  @override
  Future<List<CoachMemberSummary>> getMembers() =>
      CoachMembersApi(client).getMembers();

  @override
  Future<List<NutritionGuide>> getGuides(String memberId) async =>
      (await client.get<List<NutritionGuide>>(
        '/coach/members/${Uri.encodeComponent(memberId)}/nutrition-guides',
        decode: (value) =>
            (value as List).map(NutritionGuide.fromJson).toList(),
      )).data;

  @override
  Future<NutritionGuide> create(
    String memberId,
    String title,
    String content,
  ) async => (await client.post<NutritionGuide>(
    '/coach/members/${Uri.encodeComponent(memberId)}/nutrition-guides',
    body: {'title': title, 'content': content},
    decode: NutritionGuide.fromJson,
  )).data;

  @override
  Future<NutritionGuide> update(
    String id,
    String title,
    String content, {
    bool publish = false,
  }) async => (await client.patch<NutritionGuide>(
    '/coach/nutrition-guides/${Uri.encodeComponent(id)}',
    body: {'title': title, 'content': content, if (publish) 'publish': true},
    decode: NutritionGuide.fromJson,
  )).data;
}
