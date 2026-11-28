import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';

class CatalogApi implements CatalogService {
  const CatalogApi(this._client);

  final ApiClient _client;

  @override
  Future<GymProfile> getGymProfile() async => (await _client.get<GymProfile>(
    '/gym-profile',
    decode: GymProfile.fromJson,
  )).data;

  @override
  Future<List<CatalogItem>> getEquipment({String? search}) =>
      _getItems('/equipment', search);

  @override
  Future<CatalogItem> getEquipmentDetail(String id) async =>
      (await _client.get<CatalogItem>(
        '/equipment/${Uri.encodeComponent(id)}',
        decode: CatalogItem.fromJson,
      )).data;

  @override
  Future<List<CatalogItem>> getExercises({String? search}) =>
      _getItems('/exercises', search);

  Future<List<CatalogItem>> _getItems(String path, String? search) async =>
      (await _client.get<List<CatalogItem>>(
        path,
        queryParameters: {
          'pageSize': 100,
          if (search != null && search.isNotEmpty) 'search': search,
        },
        decode: (value) => (value as List)
            .map(CatalogItem.fromJson)
            .where((item) {
              final status = item.status.toUpperCase();
              return status == 'ACTIVE' || status == 'MAINTENANCE';
            })
            .toList(),
      )).data;
}
