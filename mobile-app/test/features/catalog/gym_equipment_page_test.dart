import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/equipment_detail_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_library_page.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

void main() {
  for (final state in ['data', 'empty', 'error']) {
    testWidgets('exercise library at 375px: $state', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: ExerciseLibraryPage(service: _GymFixture(exerciseState: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (state == 'data') expect(find.text('Squat'), findsOneWidget);
      if (state == 'error') expect(find.text('Fixture error'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows gym information and active equipment detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.textContaining('06:00-21:00'), findsOneWidget);
    expect(find.text('Mang khăn tập.'), findsOneWidget);
    expect(find.text('Máy chạy bộ'), findsOneWidget);
    expect(find.text('Máy ẩn'), findsNothing);

    await tester.ensureVisible(find.text('Máy chạy bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Máy chạy bộ'));
    await tester.pumpAndSettle();
    expect(find.text('Khởi động trước khi chạy'), findsOneWidget);
    expect(find.text('Giữ tay vịn khi lên máy'), findsOneWidget);
    expect(service.detailId, 'equipment-1');
  });

  testWidgets('searches, filters and shows an empty result', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tạ đơn'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tạ đơn'), findsOneWidget);
    final cardio = find.widgetWithText(ChoiceChip, 'Cardio');
    await tester.ensureVisible(cardio);
    await tester.tap(cardio);
    await tester.pumpAndSettle();
    expect(find.text('Tạ đơn'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('equipment-search')),
      'không có',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.search, 'không có');
    expect(find.text('Không có máy phù hợp.'), findsOneWidget);
  });

  testWidgets('shows load error and retries', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture(failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được thông tin gym.'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Meta Gym'), findsOneWidget);
    expect(service.profileLoads, 2);
  });

  testWidgets('shows maintenance status pill on gym equipment page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: GymEquipmentPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sẵn sàng'), findsAtLeastNWidgets(1));
    expect(find.text('Đang bảo trì'), findsOneWidget);
  });

  testWidgets(
    'equipment detail renders dark hero card, muscle pills, steps and safety notes',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _GymFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: EquipmentDetailPage(
            equipmentId: 'equipment-cable',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HƯỚNG DẪN THIẾT BỊ'), findsOneWidget);
      expect(find.text('Cable Crossover Dual'), findsAtLeastNWidgets(1));
      expect(find.text('● Sẵn sàng sử dụng'), findsOneWidget);
      expect(find.text('Ngực giữa'), findsOneWidget);
      expect(find.text('Vai trước'), findsOneWidget);
      expect(find.text('Tay sau'), findsOneWidget);
      expect(find.text('Hướng dẫn sử dụng từng bước'), findsOneWidget);
      expect(find.text('Bước 1'), findsOneWidget);
      expect(find.text('Bước 2'), findsOneWidget);
      expect(find.text('Chỉnh chốt ròng rọc ngang tầm vai.'), findsOneWidget);
      expect(find.text('Ép hai tay về phía trước ngực.'), findsOneWidget);
      expect(find.text('Lưu ý an toàn'), findsOneWidget);
      expect(
        find.text('Kiểm tra chốt tạ đã cắm chặt trước khi kéo.'),
        findsOneWidget,
      );
    },
  );
}

class _GymFixture implements CatalogService {
  _GymFixture({this.failFirst = false, this.exerciseState = 'empty'});

  final String exerciseState;

  final bool failFirst;
  int profileLoads = 0;
  String? search;
  String? detailId;

  @override
  Future<GymProfile> getGymProfile() async {
    profileLoads++;
    if (failFirst && profileLoads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được thông tin gym.',
      );
    }
    return const GymProfile(
      name: 'Meta Gym',
      address: 'Quận 1',
      openingHours: {'monday': '06:00-21:00'},
      rules: 'Mang khăn tập.',
    );
  }

  @override
  Future<List<CatalogItem>> getEquipment({String? search}) async {
    this.search = search;
    if (search == 'không có') return const [];
    return const [
      CatalogItem(id: 'equipment-1', name: 'Máy chạy bộ', category: 'Cardio'),
      CatalogItem(id: 'equipment-3', name: 'Tạ đơn', category: 'Sức mạnh'),
      CatalogItem(
        id: 'equipment-4',
        name: 'Technogym Artis Run',
        category: 'Cardio',
        status: 'MAINTENANCE',
      ),
      CatalogItem(id: 'equipment-2', name: 'Máy ẩn', status: 'HIDDEN'),
    ];
  }

  @override
  Future<CatalogItem> getEquipmentDetail(String id) async {
    detailId = id;
    if (id == 'equipment-cable') {
      return const CatalogItem(
        id: 'equipment-cable',
        name: 'Cable Crossover Dual',
        category: 'Máy cáp',
        description: 'Máy kéo cáp đa năng cho ngực, vai và tay sau.',
        targetMuscles: ['Ngực giữa', 'Vai trước', 'Tay sau'],
        usageSteps: [
          'Chỉnh chốt ròng rọc ngang tầm vai.',
          'Ép hai tay về phía trước ngực.',
        ],
        safetyNotes: 'Kiểm tra chốt tạ đã cắm chặt trước khi kéo.',
      );
    }
    return const CatalogItem(
      id: 'equipment-1',
      name: 'Máy chạy bộ',
      category: 'Cardio',
      usageSteps: ['Khởi động trước khi chạy'],
      safetyNotes: 'Giữ tay vịn khi lên máy',
    );
  }

  @override
  Future<List<CatalogItem>> getExercises({String? search}) async {
    if (exerciseState == 'error') {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Fixture error',
      );
    }
    return exerciseState == 'data'
        ? const [
            CatalogItem(
              id: 'exercise-1',
              name: 'Squat',
              targetMuscles: ['Legs'],
            ),
          ]
        : const [];
  }
}
