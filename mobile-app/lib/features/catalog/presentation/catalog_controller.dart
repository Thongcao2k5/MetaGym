import 'package:flutter/foundation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';

enum CatalogViewState { loading, ready, empty, error }

class CatalogController extends ChangeNotifier {
  CatalogController(this._service);

  final CatalogService _service;
  CatalogViewState state = CatalogViewState.loading;
  GymProfile? gym;
  List<CatalogItem> equipment = const [];
  List<CatalogItem> exercises = const [];
  String? errorMessage;

  Future<void> load() => _load(null);

  Future<void> search(String query) => _load(query.trim());

  Future<void> _load(String? search) async {
    state = CatalogViewState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _service.getGymProfile(),
        _service.getEquipment(search: search),
        _service.getExercises(search: search),
      ]);
      gym = results[0] as GymProfile;
      equipment = (results[1] as List<CatalogItem>)
          .where((item) => item.status == 'ACTIVE')
          .toList();
      exercises = (results[2] as List<CatalogItem>)
          .where((item) => item.status == 'ACTIVE')
          .toList();
      state = equipment.isEmpty && exercises.isEmpty
          ? CatalogViewState.empty
          : CatalogViewState.ready;
    } on ApiException catch (error) {
      errorMessage = error.message;
      state = CatalogViewState.error;
    } finally {
      notifyListeners();
    }
  }
}
