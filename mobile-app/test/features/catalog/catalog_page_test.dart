import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_controller.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('catalog page renders gym equipment and exercises', (
    tester,
  ) async {
    final controller = CatalogController(_CatalogFixture());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: CatalogPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Máy chạy bộ'), findsOneWidget);
    expect(find.text('Chạy bộ'), findsOneWidget);
    expect(find.text('Không có nội dung phù hợp.'), findsNothing);
  });
}

class _CatalogFixture implements CatalogService {
  @override
  Future<List<CatalogItem>> getEquipment({String? search}) async => const [
    CatalogItem(id: 'equipment-1', name: 'Máy chạy bộ', category: 'Cardio'),
  ];

  @override
  Future<List<CatalogItem>> getExercises({String? search}) async => const [
    CatalogItem(
      id: 'exercise-1',
      name: 'Chạy bộ',
      instructions: 'Khởi động kỹ',
    ),
  ];

  @override
  Future<GymProfile> getGymProfile() async =>
      const GymProfile(name: 'Meta Gym', address: 'Thành phố Hồ Chí Minh');
}
