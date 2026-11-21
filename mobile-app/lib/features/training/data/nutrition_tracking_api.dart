import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

typedef NutritionRecord = Map<String, dynamic>;

class NutritionTrackingApi {
  const NutritionTrackingApi(this.client);
  final ApiClient client;
  Future<void> update(String id, NutritionRecord item) async {
    await client.patch(
      '/member/nutrition/entries/${Uri.encodeComponent(id)}',
      body: item,
      decode: (_) => null,
    );
  }

  Future<void> delete(String id) async {
    await client.delete(
      '/member/nutrition/entries/${Uri.encodeComponent(id)}',
      decode: (_) => null,
    );
  }

  Future<String> upload(SelectedProgressImage image) async {
    final error = validateProgressImage(image);
    if (error != null) throw FormatException(error);
    return (await client.post(
      '/media/images',
      body: image.bytes,
      headers: {
        'content-type': image.mimeType,
        'x-image-purpose': 'MEAL_PHOTO',
        'x-file-name': image.name,
      },
      decode: (data) => (data as Map)['id'] as String,
    )).data;
  }

  Future<NutritionRecord> day(String date) async => (await client.get(
    '/member/nutrition/day',
    queryParameters: {'date': date},
    decode: (data) => Map<String, dynamic>.from(data as Map),
  )).data;
  Future<List<NutritionRecord>> foods() async => (await client.get(
    '/member/nutrition/foods',
    decode: (data) => (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
  )).data;
  Future<void> add(NutritionRecord item) async {
    await client.post(
      '/member/nutrition/entries',
      body: item,
      decode: (_) => null,
    );
  }
}
