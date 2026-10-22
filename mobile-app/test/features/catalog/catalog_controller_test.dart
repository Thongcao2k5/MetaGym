import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_controller.dart';

void main() {
  test('loads gym content and excludes hidden catalog items', () async {
    final service = _FakeCatalogService(
      equipment: const [
        CatalogItem(id: '1', name: 'Máy chạy', status: 'ACTIVE'),
        CatalogItem(id: '2', name: 'Máy ẩn', status: 'HIDDEN'),
      ],
    );
    final controller = CatalogController(service);

    await controller.load();

    expect(controller.state, CatalogViewState.ready);
    expect(controller.equipment.map((item) => item.name), ['Máy chạy']);
    expect(controller.gym?.name, 'Meta Gym');
  });

  test('represents empty and error states explicitly', () async {
    final empty = CatalogController(_FakeCatalogService());
    await empty.load();
    expect(empty.state, CatalogViewState.empty);

    final failed = CatalogController(_FakeCatalogService(shouldFail: true));
    await failed.load();
    expect(failed.state, CatalogViewState.error);
    expect(failed.errorMessage, isNotEmpty);
  });

  test('search sends the trimmed query to both catalogs', () async {
    final service = _FakeCatalogService();
    final controller = CatalogController(service);

    await controller.search('  cardio  ');

    expect(service.equipmentSearch, 'cardio');
    expect(service.exerciseSearch, 'cardio');
  });
}

class _FakeCatalogService implements CatalogService {
  _FakeCatalogService({this.equipment = const [], this.shouldFail = false});

  final List<CatalogItem> equipment;
  final bool shouldFail;
  String? equipmentSearch;
  String? exerciseSearch;

  @override
  Future<List<CatalogItem>> getEquipment({String? search}) async {
    if (shouldFail) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Mất kết nối',
      );
    }
    equipmentSearch = search;
    return equipment;
  }

  @override
  Future<List<CatalogItem>> getExercises({String? search}) async {
    exerciseSearch = search;
    return const [];
  }

  @override
  Future<GymProfile> getGymProfile() async =>
      const GymProfile(name: 'Meta Gym', address: 'Thành phố Hồ Chí Minh');
}
