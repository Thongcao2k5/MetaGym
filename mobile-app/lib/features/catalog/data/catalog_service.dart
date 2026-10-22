import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';

abstract interface class CatalogService {
  Future<GymProfile> getGymProfile();
  Future<List<CatalogItem>> getEquipment({String? search});
  Future<List<CatalogItem>> getExercises({String? search});
}
